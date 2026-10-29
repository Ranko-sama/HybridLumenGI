"""Independent URP-relative direct diffuse + source-geometry hard visibility.

Not native shadow-map PCF, glossy lighting, temporal filtering or a D solver.
"""
from __future__ import annotations
import copy
import math
import numpy as np
from geometry import Scene, array, unit, EPS
from loader import InputError
from materials import interpret, srgb_to_linear, texture_bound, UnsupportedInput


def boolean(value, name):
    if type(value) is not bool: raise InputError("Missing boolean: " + name)
    return value


def finite(value, name, low=None, high=None):
    if type(value) not in (int, float) or not math.isfinite(value): raise InputError("Nonfinite scalar: " + name)
    if (low is not None and value < low) or (high is not None and value > high):
        raise UnsupportedInput("Out-of-range " + name)
    return float(value)


def mask(value, name):
    if type(value) is not int or not -(1 << 31) <= value <= (1 << 32)-1: raise InputError("Invalid mask: " + name)
    return value & 0xffffffff


def distance_attenuation(distance_squared, range_value):
    """Nominal URP range smoothing; no lumen/4pi conversion."""
    d2 = np.asarray(distance_squared, dtype=np.float64)
    if np.any(d2 <= 0) or not np.isfinite(d2).all(): raise UnsupportedInput("point-source-singularity")
    factor = d2 / max(range_value * range_value, .0001)
    return np.maximum(0, 1 - factor * factor) ** 2 / d2


def spot_attenuation(cosine, inner_degrees, outer_degrees):
    outer = math.cos(math.radians(outer_degrees) / 2)
    inner = math.cos(math.radians(inner_degrees) / 2)
    return np.clip((np.asarray(cosine) - outer) / max(.001, inner - outer), 0, 1) ** 2


def interpret_light(light, rendering, use_layers):
    if rendering.get("colorSpace") != "Linear" or rendering.get("lightsUseLinearIntensity") is not True:
        raise UnsupportedInput("requires-linear-project-and-linear-light-intensity")
    if type(rendering.get("lightsUseColorTemperature")) is not bool:
        raise InputError("Missing global color temperature flag")
    if light.get("type") not in ("Directional", "Point", "Spot"): raise UnsupportedInput("unmodeled-light-type")
    if light.get("bakeType") != "Realtime": raise UnsupportedInput("non-realtime-light")
    if rendering["lightsUseColorTemperature"] and boolean(light.get("useColorTemperature"), "useColorTemperature"):
        raise UnsupportedInput("active-CCT-native-linear-multiplier-not-exported")
    if texture_bound(light.get("cookie")): raise UnsupportedInput("light-cookie")
    if finite(light.get("bounceIntensity"), "bounceIntensity", 0) != 1:
        raise UnsupportedInput("nonunit-indirect-light-multiplier")
    intensity = finite(light.get("intensity"), "intensity", 0)
    authored = array(light.get("color"), (4,), "light.color")[:3]
    linear = srgb_to_linear(authored) * intensity
    matrix = array(light.get("localToWorld"), (16,), "light.localToWorld").reshape(4,4)
    if not np.array_equal(matrix[3], [0,0,0,1]): raise InputError("Light affine matrix")
    to_light = array(light.get("toLight"), (3,), "light.toLight")
    direction, length = unit(to_light[None])
    if length[0] == 0: raise UnsupportedInput("zero-light-direction")
    matrix_direction, matrix_length = unit(-matrix[:3,2][None])
    if matrix_length[0] == 0 or np.max(np.abs(matrix_direction-direction)) > 32*np.finfo(np.float32).eps:
        raise UnsupportedInput("inconsistent-light-transform-and-direction")
    kind = light["type"]
    radius = finite(light.get("range"), "range", 0)
    if kind != "Directional" and radius <= 0: raise UnsupportedInput("zero-punctual-range")
    outer = finite(light.get("spotAngle"), "spotAngle", 0, 180)
    inner = finite(light.get("innerSpotAngle"), "innerSpotAngle", 0, outer)
    if kind == "Spot" and outer <= 0: raise UnsupportedInput("zero-spot-angle")
    shadow = light.get("shadows")
    if shadow not in ("None", "Hard", "Soft"): raise UnsupportedInput("unknown-shadow-mode")
    strength = finite(light.get("shadowStrength"), "shadowStrength", 0, 1) if shadow != "None" else 0.
    extra = light.get("additional")
    if not isinstance(extra,dict): raise InputError("Missing additional light source metadata")
    receiver_layers = mask(extra.get("renderingLayers"), "light receiver layers")
    shadow_layers = mask(light.get("renderingLayerMask"), "actual light shadow layers")
    expected_shadow = mask(extra.get("shadowRenderingLayers") if boolean(extra.get("customShadowLayers"), "customShadowLayers") else extra.get("renderingLayers"), "resolved shadow layers")
    if use_layers and shadow_layers != expected_shadow:
        raise UnsupportedInput("inconsistent-actual-shadow-rendering-layers")
    return dict(key=light["key"],name=light.get("name", ""),kind=kind,color=linear,position=matrix[:3,3].copy(),
                toLight=direction[0],range=radius,inner=inner,outer=outer,strength=strength,
                cullingMask=mask(light.get("cullingMask"), "light culling mask"),receiverLayers=receiver_layers,
                shadowLayers=shadow_layers,authoredShadowMode=shadow,
                model="source geometry hard visibility; Soft does not supply an emitter area or PCF model")


class Lighting:
    def __init__(self, snapshot, source_unsupported=()):
        self.snapshot=snapshot
        self.unsupported=list(source_unsupported)
        self.materials={};self.lights=[]
        settings=snapshot.get("rendering",{}).get("urp",{}).get("pipeline",[])
        values=[x.get("value") for x in settings if x.get("name")=="useRenderingLayers"]
        if len(values)!=1 or values[0] not in ("true","false"):raise InputError("Missing/ambiguous useRenderingLayers")
        self.use_layers=values[0]=="true"
        seen=set()
        for m in snapshot["materials"]:
            if m["key"] in seen:raise InputError("Repeated material key")
            seen.add(m["key"])
            try:self.materials[m["key"]]=interpret(m)
            except UnsupportedInput as error:self.unsupported.append(m["key"]+":"+str(error))
        seen=set()
        for light in snapshot["lights"]:
            if not isinstance(light.get("key"),str) or light["key"] in seen:raise InputError("Light identity")
            seen.add(light["key"])
            if not boolean(light.get("enabled"),"light.enabled") or not boolean(light.get("active"),"light.active"):continue
            try:self.lights.append(interpret_light(light,snapshot["rendering"],self.use_layers))
            except UnsupportedInput as error:self.unsupported.append(light["key"]+":"+str(error))
        # Shadow geometry must not be culled by this camera's primary visibility mask.
        world=copy.deepcopy(snapshot)
        world["rendering"]["cameraCullingMask"]=-1
        for setting in world["rendering"]["urp"]["renderer"]:
            if setting["name"]=="opaqueLayerMask":setting["value"]="-1"
        self.scene=Scene(world,shadow_geometry=True)
        self.unsupported += self.scene.unsupported
        self.geometry={g["key"]:g for g in snapshot["geometry"]}
        self.caster=[]
        for index,record in enumerate(self.scene.records):
            g=self.geometry[self.scene.objects[record["owner"]]["key"]]
            mode=g.get("shadowCasting")
            if mode not in ("Off","On","TwoSided","ShadowsOnly"):
                self.unsupported.append(g["key"]+":shadow-caster-mode");continue
            if mode=="Off":continue
            material=self.scene.materials[record['materialKey']]
            if not dict(zip(material['passes'],material['passEnabled'])).get('ShadowCaster',False):continue
            self.caster.append((index,mask(g.get("renderingLayerMask"),"renderer layers"),g["layer"],0 if mode=="TwoSided" else int(self.scene.culls[index])))
        self.unsupported=sorted(set(self.unsupported))

    def hard_visibility(self, positions, directions, limits, origin_triangles, light):
        """Open ray segments, no HLGI bias/distance. Numeric edge/touch => unknown.

        Only the exact source origin triangle is excluded. Other near-zero contacts
        are unknown, rather than shifted past a possible thin occluder.
        """
        n=len(positions);blocked=np.zeros(n,bool);uncertain=np.zeros(n,bool)
        scale=np.maximum(1,np.max(np.abs(positions),axis=1));epsilon=256*EPS*scale
        for index,layers,layer,cull in self.caster:
            if not (light["cullingMask"] & (1<<layer)):continue
            if self.use_layers and not (light["shadowLayers"] & layers):continue
            triangle=self.scene.vertices[index];e1,e2=triangle[1]-triangle[0],triangle[2]-triangle[0]
            p=np.cross(directions,e2);det=p@e1;guard=64*EPS*np.linalg.norm(e1)*np.linalg.norm(e2)
            eligible=origin_triangles!=index
            # ShadowCaster culling is seen from the light. Our ray travels in the
            # opposite direction (surface -> light), so front-face sign reverses.
            front=det < -guard if cull==2 else det>guard if cull==1 else np.abs(det)>guard
            valid=eligible & front
            inv=np.divide(1.,det,out=np.zeros(n),where=valid)
            tvec=positions-triangle[0];u=np.einsum('ij,ij->i',tvec,p)*inv
            q=np.cross(tvec,e1);v=np.einsum('ij,ij->i',directions,q)*inv;t=(q@e2)*inv
            inside=valid & (u>=-128*EPS)&(v>=-128*EPS)&(u+v<=1+128*EPS)
            interior=inside & (u>128*EPS)&(v>128*EPS)&(u+v<1-128*EPS)
            segment=inside & (t>=-epsilon)&(t<=limits+epsilon)
            clear_hit=interior & (t>epsilon)&(t<limits-epsilon)
            blocked |= clear_hit
            uncertain |= segment & ~clear_hit
            # Coplanar/grazing rays may have no stable determinant; retain unknown.
            ng=np.cross(e1,e2);plane=np.abs(tvec@ng)/np.linalg.norm(ng)
            uncertain |= eligible & (np.abs(det)<=guard)&(plane<=epsilon)
        # A separate definite blocker establishes zero visibility even if another
        # contact is ambiguous; no expected brightness can leak through it.
        known=blocked | ~uncertain
        return (~blocked).astype(np.float64),known

    def evaluate(self, positions, normals, triangle_ids):
        positions=np.asarray(positions,dtype=np.float64);normals=np.asarray(normals,dtype=np.float64)
        if positions.ndim!=2 or positions.shape[1]!=3 or normals.shape!=positions.shape or not np.isfinite(positions).all() or not np.isfinite(normals).all():raise InputError("Surface query arrays")
        ids=np.asarray(triangle_ids)
        if ids.shape!=(len(positions),) or ids.dtype.kind not in 'iu' or np.any(ids<0) or np.any(ids>=len(self.scene.records)):raise InputError("Source triangle IDs")
        normals,length=unit(normals)
        if np.any(length==0):raise InputError("Zero query normal")
        n=len(ids);direct=np.zeros((n,3));known=np.ones(n,bool)
        rho=np.zeros((n,3));emission=np.zeros((n,3));receives=np.zeros(n,bool);layers=np.zeros(n,np.uint32);game_layers=np.zeros(n,np.int32)
        for index in np.unique(ids):
            use=ids==index;rec=self.scene.records[index];g=self.geometry[self.scene.objects[rec['owner']]['key']]
            material=self.materials.get(rec['materialKey'])
            if material is None:known[use]=False;continue
            rho[use]=material['rho'];emission[use]=material['emission']
            receives[use]=boolean(g.get('receiveShadows'),'receiver.receiveShadows') and material['receivesShadows']
            layers[use]=mask(g.get('renderingLayerMask'),'receiver layers');game_layers[use]=g['layer']
        if self.unsupported:known[:]=False
        light_results=[]
        for light in self.lights:
            affected=np.array([bool(light['cullingMask'] & (1<<int(i))) for i in game_layers])
            if self.use_layers:affected &= (layers & light['receiverLayers'])!=0
            if light['kind']=='Directional':
                direction=np.tile(light['toLight'],(n,1));limit=np.full(n,np.inf);attenuation=np.ones(n)
            else:
                offset=light['position']-positions;direction,limit=unit(offset)
                singular=limit<=0;known[singular & affected]=False
                # A singular query is unknown, not a huge finite radiance estimate.
                d2=np.where(singular,1.,limit*limit)
                attenuation=distance_attenuation(d2,light['range'])
                attenuation[singular]=0
                if light['kind']=='Spot':attenuation*=spot_attenuation(direction@light['toLight'],light['inner'],light['outer'])
            cosine=np.maximum(0,np.einsum('ij,ij->i',normals,direction))
            active=affected & (cosine>0)&(attenuation>0)&np.any(light['color']>0)
            visibility=np.ones(n);shadow_known=np.ones(n,bool)
            shadow=active & receives & (light['strength']>0)
            if shadow.any():
                hard,valid=self.hard_visibility(positions[shadow],direction[shadow],limit[shadow],ids[shadow],light)
                visibility[shadow]=1-light['strength']*(1-hard);shadow_known[shadow]=valid
            known &= (~active)|shadow_known
            contribution=light['color']*(cosine*attenuation*visibility*affected)[:,None]
            contribution[~active]=0
            direct+=contribution
            light_results.append(dict(key=light['key'],active=int(active.sum()),shadowQueries=int(shadow.sum()),unknown=int((active&~shadow_known).sum())))
        outgoing=rho*direct+emission
        # Unknown numeric estimates must never be consumed as valid expected values.
        direct[~known]=0;outgoing[~known]=0
        return dict(directD=direct,rho=rho,emission=emission,outgoingSource=outgoing,known=known,lightDiagnostics=light_results)
