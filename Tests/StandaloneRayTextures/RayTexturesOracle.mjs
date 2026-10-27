import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir]=process.argv.slice(2);if(!dir)throw Error('prepare|verify artifactDirectory');
const f=Math.fround,clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
// Arithmetic binary16 oracle, independent of GPU conversion/integer load implementation.
const roundEven=x=>{const n=Math.floor(x),r=x-n;return r>.5||(r===.5&&(n&1))?n+1:n;};
function encodeHalf(value){
    const sign=value<0||Object.is(value,-0)?32768:0,a=Math.abs(value);
    if(a===0)return sign;if(!Number.isFinite(a))return sign|0x7c00|(Number.isNaN(a)?1:0);
    if(a<2**-14)return sign|roundEven(a*2**24);
    let e=Math.floor(Math.log2(a)),m=roundEven(a/2**e*1024)-1024;
    if(m===1024){e++;m=0;}return sign|((e+15)<<10)|m;
}
function decodeHalf(bits){const sign=bits&32768?-1:1,e=(bits>>10)&31,m=bits&1023;return sign*(e===0?m*2**-24:e===31?(m?NaN:Infinity):(1+m/1024)*2**(e-15));}
const wrap=(i,size,mode)=>{
    if(mode===1||mode===3)return clamp(i,0,size-1);
    const period=mode===2?size*2:size,positive=((i%period)+period)%period;
    return mode===2&&positive>=size?period-1-positive:positive;
};
// Double oracle: map the coordinate into the infinite periodic/reflected image,
// then explicitly sum the nearest texel or four tent-kernel contributions. It
// does not reproduce HLSL float operations, mip address traversal or lerps.
function coordinate(uv,mode){
    if(mode===0)return uv%1;
    if(mode===1)return clamp(uv,0,1);
    if(mode===3)return clamp(Math.abs(uv),0,1);
    const p=Math.abs(uv)%2;return p<=1?p:2-p;
}
function sampleReference(texture,sampler,uv,lod,bias){
    const [filter,wu,wv]=sampler;
    const l=clamp(lod+bias,texture.first,texture.mips-1);
    const levels=filter===2?[[Math.floor(l),1-(l%1)],[Math.min(Math.floor(l)+1,texture.mips-1),l%1]]:[[Math.floor(l+.5),1]];
    const result=[0,0,0,0];
    for(const [level,levelWeight] of levels){
        const image=texture.levels[level],w=image.w,h=image.h;
        const x=coordinate(uv[0],wu)*w-(filter===0?0:.5),y=coordinate(uv[1],wv)*h-(filter===0?0:.5);
        const ix=Math.floor(x),iy=Math.floor(y);
        const taps=filter===0?[[0,0,1]]:[[0,0,(1-(x-ix))*(1-(y-iy))],[1,0,(x-ix)*(1-(y-iy))],[0,1,(1-(x-ix))*(y-iy)],[1,1,(x-ix)*(y-iy)]];
        for(const [dx,dy,weight] of taps){
            const texel=image.pixels[wrap(iy+dy,h,wv)*w+wrap(ix+dx,w,wu)];
            for(let c=0;c<4;c++)result[c]+=texel[c]*weight*levelWeight;
        }
    }
    return result;
}
let seed=0x74d591ac;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
if(mode==='prepare'){
    const texels=[],metadata=[],cases=[],inputs=[],textures=[];
    function texture(w,h,mips,first=0,constant=null,half=false){
        const entry={w,h,mips,first,half,offset:texels.length,count:0,levels:{}};
        for(let m=first;m<mips;m++){
            const mw=Math.max(1,w>>m),mh=Math.max(1,h>>m),pixels=[];
            for(let y=0;y<mh;y++)for(let x=0;x<mw;x++){
                const pixel=(constant??[((x*7+y*11+m*17)%31-10)/13,((x*3+y*17+m*7)%29)/7,(x+5*y+3*m)%11,(x*13+y*5+m)%17/16]).map(f);
                pixels.push(half?pixel.map(x=>decodeHalf(encodeHalf(x))):pixel);if(!half)texels.push(pixel);
            }
            if(half)for(let y=0;y<mh;y++)for(let x=0;x<mw;x+=2){
                const values=[...pixels[y*mw+x],...(x+1<mw?pixels[y*mw+x+1]:[0,0,0,0])].map(encodeHalf);
                texels.push({bits:[0,1,2,3].map(i=>(values[i*2]|(values[i*2+1]<<16))>>>0)});
            }
            entry.count+=mw*mh;
            entry.levels[m]={w:mw,h:mh,pixels};
        }
        textures.push(entry);return entry;
    }
    const layouts=[texture(1,1,1),texture(3,5,3),texture(8,4,4),texture(17,9,5),texture(259,3,9),texture(16384,1,15),texture(16384,1,15,12),texture(17,9,3,1),texture(13,7,4,3)];
    function meta(texture,sampler,bias=0,aniso=1){
        const [filter,wu,wv]=sampler;
        const row=[texture.offset,texture.w,texture.h,texture.first,texture.mips,37,1,filter|(wu<<8)|(wv<<16)|(texture.half?0x01000000:0),texture.count,0,0,0,f(bias),aniso,0,0];
        metadata.push(row);return metadata.length-1;
    }
    function add(name,index,uv,lod,expected,known=true,generation=37){
        inputs.push({handle:[index,generation],uv:uv.map(f),lod:f(lod)});
        cases.push({name,known,expected:known?expected:[0,0,0,0]});
    }
    const uvs=[[0,0],[1,1],[-.25,1.25],[.5,.5],[f(-1e-8),f(1e-8)],[-1,-2],[-1.5,2.5],[f(1-2**-20),f(1+2**-20)],[-32768.25,32768.75],[f(1e30),f(-1e30)],[f(3.4e38),f(-3.4e38)],[.125,.375]];
    const descriptors=[];
    for(let t=0;t<layouts.length;t++)for(let filter=0;filter<3;filter++)for(let wu=0;wu<4;wu++)for(let wv=0;wv<4;wv++){
        const image=layouts[t],sampler=[filter,wu,wv],bias=f(t%2?-.25:.25),index=meta(image,sampler,bias,t%3?1:16);
        descriptors.push({image,sampler,bias,index});
        for(const uv of uvs)for(const lod of [-100,0,.25,1.25,100])add(`layout${t}-f${filter}-wrap${wu}${wv}-${uv}-${lod}`,index,uv,lod,sampleReference(image,sampler,uv.map(f),f(lod),bias));
    }
    for(let i=0;i<8192;i++){
        const d=descriptors[Math.floor(random()*descriptors.length)],uv=[f((random()-.5)*32),f((random()-.5)*32)],lod=f((random()-.2)*16);
        add('random-'+i,d.index,uv,lod,sampleReference(d.image,d.sampler,uv,lod,d.bias));
    }
    for(let rectangle=0;rectangle<64;rectangle++){
        const width=3+2*Math.floor(random()*32),height=3+2*Math.floor(random()*20);
        const full=1+Math.floor(Math.log2(Math.max(width,height))),mips=1+Math.floor(random()*full),first=Math.floor(random()*mips);
        const image=texture(width,height,mips,first);
        for(let variant=0;variant<4;variant++){
            const sampler=[Math.floor(random()*3),Math.floor(random()*4),Math.floor(random()*4)],bias=f((random()-.5)*4),index=meta(image,sampler,bias,variant===0?0:16);
            for(let sample=0;sample<8;sample++){
                const uv=[f((random()-.5)*256),f((random()-.5)*256)],lod=f((random()-.25)*(mips+4));
                add(`random-rectangle-${rectangle}-${width}x${height}-chain${first}..${mips}-${variant}-${sample}`,index,uv,lod,sampleReference(image,sampler,uv,lod,bias));
            }
        }
    }
    // No gamma conversion: negative/HDR/alpha are retained as source values.
    for(const pixel of [[.25,.5,.75,.125],[-2,128,65504,.5],[1e-30,1e30,0,1]]){
        const image=texture(2,2,2,0,pixel),sampler=[2,0,0],index=meta(image,sampler);
        add('linear-hdr-'+pixel,index,[.7,-.2],.4,pixel.map(f));
    }
    for(const image of [texture(1,9,4,0,null,true),texture(3,5,3,0,null,true),texture(17,9,5,0,null,true),texture(17,9,5,3,null,true),texture(3,2,2,0,[-2,65504,2**-24,.5],true)]){
        for(let filter=0;filter<3;filter++)for(let wu=0;wu<4;wu++){
            const sampler=[filter,wu,3-wu],index=meta(image,sampler,.125);
            for(const uv of [[0,0],[1,1],[-.25,1.5],[.37,.59]])for(const lod of [0,1.25,99])
                add(`half-${image.w}x${image.h}-first${image.first}-${filter}-${wu}-${uv}-${lod}`,index,uv,lod,sampleReference(image,sampler,uv.map(f),f(lod),f(.125)));
        }
    }
    const base=metadata[49];
    function bad(name,component,value){const row=base.slice();row[component]=value;metadata.push(row);add(name,metadata.length-1,[.3,.7],1,null,false);}
    for(const [name,component,value] of [
        ['width-zero',1,0],['height-zero',2,0],['width-too-large',1,16385],['height-too-large',2,0xffffffff],
        ['mips-zero',4,0],['mips-too-many',4,16],['invented-mip',4,2],['first-outside',3,1],
        ['generation-zero',5,0],['not-ready',6,0],['unknown-ready-bits',6,3],
        ['filter-invalid',7,3],['wrapU-invalid',7,4<<8],['wrapV-invalid',7,4<<16],['sampler-reserved',7,0x80000000],
        ['offset-overflow',0,0xffffffff],['count-zero',8,0],['count-short',8,0],['count-long',8,2],['count-overflow',8,0xffffffff],
        ['storage-reserved',9,1],['sampling-reserved',14,1],['negative-aniso',13,-1],['large-aniso',13,17],['fractional-aniso',13,1.5]
    ])bad(name,component,value);
    add('handle-outside',0xffffffff,[0,0],0,null,false);add('generation-mismatch',0,[0,0],0,null,false,38);add('handle-generation-zero',0,[0,0],0,null,false,0);
    for(const value of [NaN,Infinity,-Infinity]){
        add('uvU-'+value,0,[value,0],0,null,false);add('uvV-'+value,0,[0,value],0,null,false);add('lod-'+value,0,[0,0],value,null,false);
        bad('bias-'+value,12,value);bad('aniso-'+value,13,value);
        const image=texture(1,1,1,0,[value,0,0,1]),index=meta(image,[0,0,0]);add('nonfinite-texel-'+value,index,[0,0],0,null,false);
    }
    const overflow=base.slice();overflow[12]=f(3.4e38);metadata.push(overflow);add('overflow-lod-bias',metadata.length-1,[0,0],f(3.4e38),null,false);
    const invented=base.slice();invented[1]=invented[2]=1;invented[4]=2;invented[8]=2;metadata.push(invented);add('invented-extra-1x1-level',metadata.length-1,[0,0],0,null,false);
    // Complete tight layout and buffer checks, including tails inside a valid pool.
    bad('offset-outside',0,texels.length);bad('stored-count-short-positive',8,1);
    const invalidTail=metadata[descriptors.findIndex(d=>d.image.first>0)].slice();invalidTail[8]++;metadata.push(invalidTail);add('wrong-tail-count',metadata.length-1,[0,0],0,null,false);
    const binary=Buffer.alloc(12+metadata.length*64+texels.length*16+inputs.length*32);
    binary.writeUInt32LE(inputs.length,0);binary.writeUInt32LE(metadata.length,4);binary.writeUInt32LE(texels.length,8);let offset=12;
    for(const row of metadata)for(let c=0;c<16;c++){if(c<12)binary.writeUInt32LE(row[c]>>>0,offset);else binary.writeFloatLE(row[c],offset);offset+=4;}
    for(const pixel of texels)for(const value of (pixel.bits??pixel)){if(pixel.bits)binary.writeUInt32LE(value,offset);else binary.writeFloatLE(value,offset);offset+=4;}
    for(const entry of inputs){binary.writeUInt32LE(entry.handle[0]>>>0,offset);binary.writeUInt32LE(entry.handle[1]>>>0,offset+4);binary.writeFloatLE(entry.uv[0],offset+8);binary.writeFloatLE(entry.uv[1],offset+12);binary.writeFloatLE(entry.lod,offset+16);offset+=32;}
    fs.writeFileSync(path.join(dir,'inputs.bin'),binary);fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({count:cases.length,metadataCount:metadata.length,texelCount:texels.length,cases},null,2));
    console.log(`Prepared ${cases.length} samples / ${metadata.length} metadata rows / ${texels.length} original mip texels.`);
}else if(mode==='verify'){
    const fixture=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'),'utf8')),binary=fs.readFileSync(path.join(dir,'outputs.bin'));
    assert.equal(binary.length,fixture.count*32);let checks=0,knownCount=0,unknownCount=0,maxScaledError=0,worstCase='';
    const require=(condition,message)=>{checks++;assert(condition,message);};
    for(let i=0;i<fixture.count;i++){
        const test=fixture.cases[i],known=binary.readUInt32LE(i*32+16)!==0,rgba=[0,1,2,3].map(c=>binary.readFloatLE(i*32+c*4));
        require(known===test.known,`${test.name}: expected known=${test.known}, actual=${known}.`);
        require(rgba.every(Number.isFinite),`${test.name}: nonfinite return.`);
        if(!known){unknownCount++;require(rgba.every(x=>x===0),`${test.name}: unknown return must be zero plus false, not a proven alpha.`);continue;}
        knownCount++;
        const error=Math.max(...rgba.map((x,c)=>Math.abs(x-test.expected[c])/Math.max(1,Math.abs(test.expected[c]))));
        if(error>maxScaledError){maxScaledError=error;worstCase=test.name;}
        require(error<=5e-5,`${test.name}: scaled error=${error}, actual=${rgba}, oracle=${test.expected}.`);
    }
    const result={status:'passed',count:fixture.count,checks,knownCount,unknownCount,maxScaledError,worstCase,
        scope:'Actual RayTextures.hlsl DXIL on D3D12 WARP with descriptor-backed metadata/texel SRVs and double periodic-image oracle. Explicit isotropic LOD only; not Unity texture copy, streaming, native sampler bit parity, DXR alpha or a physical GPU.'};
    fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('Unknown mode');
