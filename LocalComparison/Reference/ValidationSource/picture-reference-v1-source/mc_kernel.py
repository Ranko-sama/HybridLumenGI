"""Independent CPU diffuse path sampler. Numba is CPU acceleration, no GPU use."""
import math
import numpy as np
from numba import njit, prange


def build_bvh(vertices):
    lo=[];hi=[];children=[];ranges=[];order=[]
    centers=vertices.mean(axis=1)
    def node(ids):
        i=len(lo);lo.append(vertices[ids].min(axis=(0,1)));hi.append(vertices[ids].max(axis=(0,1)))
        children.append([-1,-1]);ranges.append([0,0])
        if len(ids)<=4:
            ranges[i]=[len(order),len(ids)];order.extend(ids)
        else:
            axis=np.argmax(np.ptp(centers[ids],axis=0));ids=ids[np.argsort(centers[ids,axis],kind='stable')];mid=len(ids)//2
            children[i]=[node(ids[:mid]),node(ids[mid:])]
        return i
    node(np.arange(len(vertices)))
    return np.array(lo),np.array(hi),np.array(children,np.int32),np.array(ranges,np.int32),np.array(order,np.int32)


@njit
def dot(a,b):return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]


@njit
def cross(a,b):return np.array((a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]))


@njit
def normalized(a):return a/math.sqrt(dot(a,a))


@njit
def random01(state):
    # xorshift64*: deterministic per pixel/sample; no scheduling-dependent RNG.
    state ^= state >> np.uint64(12);state ^= state << np.uint64(25);state ^= state >> np.uint64(27)
    value=state*np.uint64(2685821657736338717)
    return state,float(value >> np.uint64(11))*(1./9007199254740992.)


@njit
def cosine_direction(normal,state):
    state,u=random01(state);state,v=random01(state)
    r=math.sqrt(u);angle=2*math.pi*v
    axis=np.array((0.,0.,1.)) if abs(normal[2])<.9 else np.array((0.,1.,0.))
    tangent=normalized(cross(axis,normal));bitangent=cross(normal,tangent)
    return tangent*(r*math.cos(angle))+bitangent*(r*math.sin(angle))+normal*math.sqrt(1-u),state


@njit
def box_hit(origin,direction,lower,upper,limit,epsilon):
    near=epsilon;far=limit
    for k in range(3):
        if abs(direction[k])<1e-30:
            if origin[k]<lower[k] or origin[k]>upper[k]:return False
        else:
            a=(lower[k]-origin[k])/direction[k];b=(upper[k]-origin[k])/direction[k]
            near=max(near,min(a,b));far=min(far,max(a,b))
            if far<near:return False
    return True


@njit
def intersect(origin,direction,limit,ignore,shadow,lightmask,lightlayers,use_layers,
              vertices,culls,castculls,layers,gamebits,bvh):
    lower,upper,children,ranges,order=bvh
    stack=np.empty(64,np.int32);stack[0]=0;size=1;hit=-1;bu=0.;bv=0.
    epsilon=1e-6*max(1.,abs(origin[0]),abs(origin[1]),abs(origin[2]))
    while size:
        size-=1;node=stack[size]
        if not box_hit(origin,direction,lower[node],upper[node],limit,epsilon):continue
        if ranges[node,1]==0:
            stack[size]=children[node,0];stack[size+1]=children[node,1];size+=2;continue
        for q in range(ranges[node,0],ranges[node,0]+ranges[node,1]):
            index=order[q]
            if index==ignore:continue
            cull=culls[index]
            if shadow:
                cull=castculls[index]
                if cull<0 or not (gamebits[index]&lightmask) or (use_layers and not (layers[index]&lightlayers)):continue
            e1=vertices[index,1]-vertices[index,0];e2=vertices[index,2]-vertices[index,0]
            p=cross(direction,e2);det=dot(e1,p)
            if abs(det)<1e-14:continue
            # Shadow ray travels opposite to the light's raster visibility ray.
            oriented=-det if shadow else det
            if (cull==2 and oriented<=0) or (cull==1 and oriented>=0):continue
            tv=origin-vertices[index,0];u=dot(tv,p)/det
            if u<0 or u>1:continue
            crossq=cross(tv,e1);v=dot(direction,crossq)/det
            if v<0 or u+v>1:continue
            t=dot(e2,crossq)/det
            if t<=epsilon or t>=limit-epsilon:continue
            if shadow:return index,t,u,v
            hit=index;limit=t;bu=u;bv=v
    return hit,limit,bu,bv


@njit
def direct(position,normal,triangle,vertices,culls,castculls,layers,gamebits,receives,bvh,lights,use_layers):
    # packed lights: kind,color3,position3,direction3,range,innerCos,outerCos,strength,gameMask,receiverLayers,shadowLayers
    result=np.zeros(3)
    for l in lights:
        if not (gamebits[triangle]&int(l[14])) or (use_layers and not (layers[triangle]&int(l[15]))):continue
        if l[0]==0:
            direction=l[7:10];limit=math.inf;attenuation=1.
        else:
            offset=l[4:7]-position;d2=dot(offset,offset)
            if d2<=1e-12:continue # input scope rejects source lights on surfaces before rendering
            limit=math.sqrt(d2);direction=offset/limit
            f=d2/max(l[10]*l[10],.0001);attenuation=max(0.,1.-f*f)**2/d2
            if l[0]==2:attenuation*=max(0.,min(1.,(dot(direction,l[7:10])-l[12])/max(.001,l[11]-l[12])))**2
        weight=max(0.,dot(normal,direction))*attenuation
        if weight<=0:continue
        if receives[triangle] and l[13]>0:
            blocker,_,_,_=intersect(position,direction,limit,triangle,True,int(l[14]),int(l[16]),use_layers,vertices,culls,castculls,layers,gamebits,bvh)
            if blocker>=0:weight*=1-l[13]
        result += l[1:4]*weight
    return result


@njit(parallel=True)
def render(positions,normals,primary_ids,valid,spp,max_depth,seed,vertices,vertex_normals,culls,castculls,layers,gamebits,receives,rho,emission,metallic,bvh,lights,use_layers,emitter_ids,emitter_cdf):
    count=len(positions);mean=np.zeros((count,3));stderr=np.zeros((count,3));metal_fraction=np.zeros(count);truncated_fraction=np.zeros(count)
    for pixel in prange(count):
        if not valid[pixel]:continue
        total=np.zeros(3);square=np.zeros(3);metals=0;truncated=0
        for sample in range(spp):
            state=np.uint64(seed)^((np.uint64(pixel)+np.uint64(1))*np.uint64(11400714819323198485))^((np.uint64(sample)+np.uint64(1))*np.uint64(13787848793156543929))
            if state==0:state=np.uint64(1)
            position=positions[pixel].copy();normal=normals[pixel].copy();ignore=primary_ids[pixel]
            throughput=np.ones(3);value=np.zeros(3);metal=False;still_active=False
            for depth in range(max_depth):
                # Explicit area-emission sampling avoids a rare bright-hit oracle.
                # Emission on the cosine branch is excluded to avoid double counting.
                if len(emitter_ids):
                    state,pick=random01(state);state,a=random01(state);state,b=random01(state)
                    chosen=np.searchsorted(emitter_cdf,pick*emitter_cdf[-1]);emitter=emitter_ids[min(chosen,len(emitter_ids)-1)]
                    root=math.sqrt(a);ep=vertices[emitter,0]*(1-root)+vertices[emitter,1]*(root*(1-b))+vertices[emitter,2]*(root*b)
                    delta=ep-position;d2=dot(delta,delta)
                    if emitter!=ignore and d2>1e-12:
                        distance=math.sqrt(d2);toward=delta/distance
                        en=normalized(cross(vertices[emitter,1]-vertices[emitter,0],vertices[emitter,2]-vertices[emitter,0]))
                        factor=max(0.,dot(normal,toward))*max(0.,-dot(en,toward))*emitter_cdf[-1]/(math.pi*d2)
                        if factor>0:
                            occluder,_,_,_=intersect(position,toward,distance,ignore,False,0,0,use_layers,vertices,culls,castculls,layers,gamebits,bvh)
                            if occluder<0:value+=throughput*emission[emitter]*factor
                direction,state=cosine_direction(normal,state)
                index,t,u,v=intersect(position,direction,math.inf,ignore,False,0,0,use_layers,vertices,culls,castculls,layers,gamebits,bvh)
                if index<0:break # only explicitly supported black environment
                position=position+direction*t
                normal=normalized(vertex_normals[index,0]*(1-u-v)+vertex_normals[index,1]*u+vertex_normals[index,2]*v)
                if metallic[index]>0:metal=True
                d=direct(position,normal,index,vertices,culls,castculls,layers,gamebits,receives,bvh,lights,use_layers)
                value += throughput*rho[index]*d
                throughput *= rho[index];ignore=index
                if np.max(throughput)==0:break
                if depth==max_depth-1:still_active=True
            total+=value;square+=value*value
            if metal:metals+=1
            if still_active:truncated+=1
        mean[pixel]=total/spp
        # Standard error of sample mean, not a hard bound or model-error estimate.
        stderr[pixel]=np.sqrt(np.maximum(0.,square-total*total/spp)/(spp*(spp-1)))
        metal_fraction[pixel]=metals/spp;truncated_fraction[pixel]=truncated/spp
    return mean,stderr,metal_fraction,truncated_fraction
