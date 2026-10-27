import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir]=process.argv.slice(2);if(!dir)throw Error('prepare|verify artifactDirectory');
const f=Math.fround,sentinel=[-1234.5,2468.25,-5678.75,.3125];
const chain=(w,h,mips)=>Array.from({length:mips},(_,m)=>Math.max(1,w>>m)*Math.max(1,h>>m)).reduce((a,b)=>a+b,0);
const elements=(w,h,mips)=>Array.from({length:mips},(_,m)=>Math.ceil(Math.max(1,w>>m)/2)*Math.max(1,h>>m)).reduce((a,b)=>a+b,0);
const halfValue=bits=>{const sign=bits&32768?-1:1,exponent=(bits>>10)&31,mantissa=bits&1023;return sign*(exponent===0?mantissa*2**-24:exponent===31?(mantissa?NaN:Infinity):(1+mantissa/1024)*2**(exponent-15));};
const roundEven=x=>{const n=Math.floor(x),r=x-n;return r>.5||(r===.5&&(n&1))?n+1:n;};
function nearestHalf(value){
    const sign=value<0||Object.is(value,-0)?-1:1,a=Math.abs(value);
    if(a<2**-14)return sign*roundEven(a*2**24)*2**-24;
    const exponent=Math.floor(Math.log2(a));return sign*roundEven(a/2**exponent*1024)*2**(exponent-10);
}
const decode=value=>{const s=value/255;return s<=.04045?s/12.92:((s+.055)/1.055)**2.4;};
let seed=0x2aaf39d1;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
if(mode==='prepare'){
    const cases=[],chunks=[];
    function add(name,options={}){
        const c={width:17,height:9,mips:5,first:0,viewCount:null,format:0,logicalWidth:null,logicalHeight:null,logicalMips:null,
            offset:3,metadataFirst:0,generation:37,commandGeneration:37,ready:false,expected:true,expectedFirst:null,extraCapacity:7,...options};
        c.viewCount??=c.mips-c.first;c.logicalWidth??=c.width;c.logicalHeight??=c.height;c.logicalMips??=c.mips;c.expectedFirst??=c.first;
        const fullCount=chain(c.logicalWidth,c.logicalHeight,Math.max(1,c.logicalMips));
        const allocation=c.allocation??(c.half?elements(c.logicalWidth,c.logicalHeight,Math.max(1,c.logicalMips)):fullCount)+c.extraCapacity,poolCount=3+Math.max(1,allocation)+5;
        const commandCapacity=c.commandCapacity??allocation;
        const meta=[c.offset,c.logicalWidth,c.logicalHeight,c.metadataFirst,c.logicalMips,c.generation,c.ready?1:0,c.half?0x01000000:0,
            c.initialCount??0,0,0,0,0,1,0,0];
        const source=[],pixels=[];const palette=[0,1,10,11,32,64,128,192,254,255];
        for(let mip=0;mip<c.mips;mip++){
            const w=Math.max(1,c.width>>mip),h=Math.max(1,c.height>>mip),image=[];
            for(let y=0;y<h;y++)for(let x=0;x<w;x++){
                let p=c.format===0?[(x*3-y*2+mip)/7,(y+x*5+mip*3)/11,128+mip*4+x-y,(x+y+mip)%17/16].map(f):
                    [palette[(x+3*y+mip)%palette.length],palette[(2*x+y+3*mip)%palette.length],palette[(3*x+2*y+mip)%palette.length],palette[(x+y+2*mip)%palette.length]];
                if(c.constant)p=c.constant.map(f);
                if(c.nonfinite&&mip===0&&x===0&&y===0)p[0]=c.nonfinite==='NaN'?NaN:c.nonfinite==='Infinity'?Infinity:-Infinity;
                image.push(c.format===0?p:[decode(p[0]),decode(p[1]),decode(p[2]),p[3]/255]);
                const bytes=Buffer.alloc(c.format===0?16:4);p.forEach((v,i)=>c.format===0?bytes.writeFloatLE(v,i*4):bytes.writeUInt8(v,i));source.push(bytes);
            }
            pixels.push(image);
        }
        const make=(kernel,mip=0,gx=1,gy=1,gz=1,index=0,generation=c.commandGeneration,capacity=commandCapacity)=>[kernel,mip,gx,gy,gz,index,generation,capacity,0,0];
        let commands=[make(0)];
        // Deliberately dispatch the logical chain. If the view starts at a later
        // mip this overdispatches dimensions and has harmless out-of-range mip
        // calls. This mirrors the public importer contract, not the shader code.
        for(let mip=0;mip<Math.max(1,c.logicalMips);mip++)commands.push(make(1,mip,Math.ceil(Math.max(1,c.logicalWidth>>mip)/8),Math.ceil(Math.max(1,c.logicalHeight>>mip)/8)));
        commands.push(make(2));
        if(c.rangeChunk){
            commands=[make(0)];
            for(let start=0;start<commandCapacity;start+=c.rangeChunk){const count=Math.min(c.rangeChunk,commandCapacity-start),command=make(3,0,Math.ceil(count/64));command[8]=start;command[9]=count;commands.push(command);}
            commands.push(make(2));
        }
        if(c.schedule)commands=c.schedule(commands,make);
        const raw=Buffer.concat(source),header=Buffer.alloc(48),metadata=Buffer.alloc(64),schedule=Buffer.alloc(commands.length*40);
        [c.width,c.height,c.mips,c.first,c.viewCount,c.format,poolCount,commands.length,raw.length,0,0,0].forEach((v,i)=>header.writeUInt32LE(v>>>0,i*4));
        meta.forEach((v,i)=>i<12?metadata.writeUInt32LE(v>>>0,i*4):metadata.writeFloatLE(v,i*4));
        commands.forEach((command,i)=>command.forEach((v,j)=>schedule.writeUInt32LE(v>>>0,i*40+j*4)));
        chunks.push(header,metadata,schedule,raw);
        const packedPixels=[];
        if(c.half)for(let m=c.first;m<c.first+c.viewCount;m++){
            const w=Math.max(1,c.width>>m),h=Math.max(1,c.height>>m);
            for(let y=0;y<h;y++)for(let x=0;x<w;x+=2)packedPixels.push([pixels[m][y*w+x],x+1<w?pixels[m][y*w+x+1]:[0,0,0,0]]);
        }
        cases.push({name,half:!!c.half,packedPixels,format:c.format,expected:c.expected,first:c.expectedFirst,poolCount,allocation,offset:c.offset,
            expectedTexels:c.expected?pixels.slice(c.first,c.first+c.viewCount).flat():null,
            expectedGeneration:c.generation,expectedLogical:[c.logicalWidth,c.logicalHeight,c.logicalMips],
            guardAll:!!c.guardAll,initialMetadata:meta});
    }
    add('rgba32f-full-npot');add('srgb8-full-npot',{format:1});
    add('rgba32f-1x1',{width:1,height:1,mips:1});add('srgb8-1x1',{width:1,height:1,mips:1,format:1});
    add('rgba32f-MostDetailedMip-tail',{width:16,height:8,mips:5,first:2});
    add('srgb8-MostDetailedMip-tail',{width:16,height:8,mips:5,first:2,format:1});
    add('reduced-physical-resource-matches-logical-tail',{width:4,height:2,mips:3,logicalWidth:16,logicalHeight:8,logicalMips:5,expectedFirst:2});
    add('truncated-logical-chain',{mips:3});
    add('overdispatch-xyz',{schedule:(commands)=>commands.map(c=>c[0]===1?[c[0],c[1],c[2]+2,c[3]+1,2,...c.slice(5)]:c)});
    add('reverse-mip-order',{schedule:c=>[c[0],...c.slice(1,-1).reverse(),c.at(-1)]});
    add('missing-Begin',{expected:false,guardAll:true,schedule:c=>c.slice(1)});
    add('Finish-without-Begin',{expected:false,guardAll:true,schedule:(_,make)=>[make(2)]});
    add('Begin-no-copy',{expected:false,guardAll:true,schedule:(_,make)=>[make(0),make(2)]});
    add('copy-without-Finish',{expected:false,schedule:c=>c.slice(0,-1)});
    add('missing-middle-mip',{expected:false,schedule:c=>c.filter(x=>!(x[0]===1&&x[1]===2))});
    add('missing-last-mip',{expected:false,schedule:c=>c.filter(x=>!(x[0]===1&&x[1]===4))});
    add('duplicate-first-mip',{expected:false,schedule:c=>[c[0],c[1],...c.slice(1)]});
    add('duplicate-middle-mip',{expected:false,schedule:c=>[...c.slice(0,-1),c[3],c.at(-1)]});
    add('underdispatch-first-mip',{width:16,height:16,mips:2,expected:false,schedule:c=>c.map(x=>x[0]===1&&x[1]===0?[x[0],x[1],1,2,...x.slice(4)]:x)});
    // Without per-mip duplicate rejection, 128 + 3*64 == 320 would fool the old
    // aggregate count + mip-mask proof despite half of mip zero remaining stale.
    add('combined-underdispatch-duplicate-compensation',{width:16,height:16,mips:2,expected:false,
        schedule:(_,make)=>[make(0),make(1,0,1,2),make(1,1),make(1,1),make(1,1),make(2)]});
    add('zero-dispatch-mip',{expected:false,schedule:c=>c.map(x=>x[0]===1&&x[1]===0?[x[0],x[1],0,1,...x.slice(4)]:x)});
    add('restart-then-full-copy',{schedule:c=>[c[0],c[1],...c]});
    add('restart-then-Finish',{expected:false,schedule:c=>[...c.slice(0,-1),c[0],c.at(-1)]});
    add('Finish-twice',{expected:false,schedule:c=>[...c,c.at(-1)]});
    add('old-ready-no-Begin',{ready:true,expected:false,guardAll:true,schedule:c=>c.slice(1)});
    add('wrong-logical-dimensions',{logicalWidth:19,expected:false,guardAll:true});
    add('view-mip-count-does-not-match-logical-chain',{width:16,height:8,mips:5,viewCount:3,expected:false,guardAll:true});
    add('capacity-one-texel-short',{allocation:chain(17,9,5)-1,expected:false,guardAll:true});
    add('capacity-exceeds-buffer',{commandCapacity:0xffffffff,expected:false,guardAll:true});
    add('zero-capacity',{commandCapacity:0,expected:false,guardAll:true});
    add('offset-outside-buffer',{offset:0xffffffff,expected:false,guardAll:true});
    add('zero-generation',{commandGeneration:0,expected:false,guardAll:true});
    add('stale-generation',{commandGeneration:38,expected:false,guardAll:true});
    add('wrong-metadata-index',{expected:false,guardAll:true,schedule:c=>c.map(x=>[...x.slice(0,5),1,...x.slice(6)])});
    add('logical-zero-dimension',{logicalWidth:0,expected:false,guardAll:true});
    add('logical-zero-mips',{logicalMips:0,expected:false,guardAll:true});
    for(const nonfinite of ['NaN','Infinity','-Infinity'])add('nonfinite-source-'+nonfinite,{nonfinite,expected:false});
    add('exact-capacity-no-unused-allocation',{extraCapacity:0});
    add('extra-out-of-view-copy-mip-is-no-op',{schedule:(c,make)=>[...c.slice(0,-1),make(1,0xffffffff),c.at(-1)]});
    for(let i=0;i<32;i++){
        const width=3+2*Math.floor(random()*20),height=3+2*Math.floor(random()*16),full=1+Math.floor(Math.log2(Math.max(width,height)));
        const mips=1+Math.floor(random()*full),first=Math.floor(random()*mips);
        add('random-source-'+i,{width,height,mips,first,format:i%2});
    }
    for(const [width,height,mips] of [[1,1,1],[1,9,4],[3,5,3],[17,9,5],[8,3,4]])
        for(const format of [0,1])add(`half-row-${width}x${height}-${format}`,{width,height,mips,format,half:true,extraCapacity:0});
    add('half-reduced-view',{width:17,height:9,mips:5,first:2,half:true});
    add('half-reduced-physical',{width:4,height:2,mips:3,logicalWidth:16,logicalHeight:8,logicalMips:5,expectedFirst:2,half:true});
    add('half-limit-and-subnormal',{width:3,height:5,mips:3,half:true,constant:[65504,-65504,2**-24,0]});
    add('half-nearest-even-ties',{width:3,height:5,mips:3,half:true,constant:[1+2**-11,1+3*2**-11,2**-25,3*2**-25]});
    add('half-negative-subnormal-ties',{width:1,height:5,mips:3,half:true,constant:[-(2**-25),-3*2**-25,-0,-(1+2**-11)]});
    add('half-overflow-rejected',{half:true,constant:[65520,0,0,1],expected:false});
    add('half-nonfinite-rejected',{half:true,nonfinite:'NaN',expected:false});
    add('half-capacity-one-element-short',{half:true,allocation:elements(17,9,5)-1,expected:false,guardAll:true});
    add('range-wide-npot',{rangeChunk:17});
    add('range-half-npot',{half:true,rangeChunk:7});
    add('range-half-column',{width:1,height:9,mips:4,half:true,rangeChunk:1});
    add('range-half-srgb',{half:true,format:1,rangeChunk:13});
    add('range-reduced-view',{width:17,height:9,mips:5,first:2,half:true,rangeChunk:11});
    add('range-truncated',{mips:3,rangeChunk:19});
    add('range-duplicate',{rangeChunk:17,expected:false,schedule:c=>[c[0],c[1],...c.slice(1)]});
    add('range-gap',{rangeChunk:17,expected:false,schedule:c=>c.filter((_,i)=>i!==2)});
    add('range-underdispatch',{rangeChunk:128,expected:false,schedule:c=>c.map(x=>x[0]===3?[x[0],x[1],1,...x.slice(3)]:x)});
    add('range-prefix-remains-unready',{rangeChunk:17,expected:false,schedule:c=>c.slice(0,2)});
    add('range-prefix-Finish-rejects',{rangeChunk:17,expected:false,schedule:c=>[c[0],c[1],c.at(-1)]});
    add('range-overallocation-bound',{rangeChunk:17,expected:false,schedule:c=>c.map(x=>x[0]===3&&x[8]===0?[...x.slice(0,9),0xffffffff]:x)});
    const header=Buffer.alloc(4);header.writeUInt32LE(cases.length);
    fs.writeFileSync(path.join(dir,'inputs.bin'),Buffer.concat([header,...chunks]));
    fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({count:cases.length,cases},null,2));
    console.log(`Prepared ${cases.length} real Texture2D upload/view/dispatch schedules.`);
}else if(mode==='verify'){
    const fixture=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'),'utf8')),binary=fs.readFileSync(path.join(dir,'outputs.bin'));
    assert.equal(binary.readUInt32LE(0),fixture.count);let offset=4,checks=0,readyCount=0,notReadyCount=0,texelsChecked=0,maxFloatError=0,maxSrgbError=0;
    const require=(condition,message)=>{checks++;assert(condition,message);};
    for(const entry of fixture.cases){
        const poolCount=binary.readUInt32LE(offset);offset+=4;require(poolCount===entry.poolCount,`${entry.name}: output pool size.`);
        const metadata=Array.from({length:12},(_,i)=>binary.readUInt32LE(offset+i*4));offset+=64;
        const ready=metadata[6]===1;
        require(ready===entry.expected,`${entry.name}: expected ready=${entry.expected}, actual flag=${metadata[6]}, storage=${metadata.slice(8)}.`);
        require(metadata[5]===entry.expectedGeneration,`${entry.name}: generation was overwritten.`);
        if(ready){
            readyCount++;require(metadata[3]===entry.first,`${entry.name}: wrong logical resident first mip.`);
            require(metadata[8]===entry.expectedTexels.length,`${entry.name}: wrong tight-chain count.`);
            require(metadata.slice(9,12).every(v=>v===0),`${entry.name}: ready descriptor retains transient counters.`);
            require(metadata[1]===entry.expectedLogical[0]&&metadata[2]===entry.expectedLogical[1]&&metadata[4]===entry.expectedLogical[2],`${entry.name}: logical source identity changed.`);
        }else notReadyCount++;
        for(let i=0;i<poolCount;i++){
            const pixel=[0,1,2,3].map(c=>binary.readFloatLE(offset+c*4));
            const halfPixels=entry.half?[0,1].map(p=>[0,1,2,3].map(c=>halfValue(binary.readUInt16LE(offset+p*8+c*2)))):null;offset+=16;
            const storedCount=entry.half?entry.packedPixels.length:entry.expectedTexels?.length;
            const stored=ready&&i>=entry.offset&&i<entry.offset+storedCount;
            const guard=entry.guardAll||i<entry.offset||i>=entry.offset+entry.allocation||(ready&&!stored);
            if(guard){require(pixel.every((v,c)=>v===sentinel[c]),`${entry.name}: guard texel ${i} modified.`);continue;}
            if(!stored)continue;
            if(entry.half){
                for(let pair=0;pair<2;pair++){
                    const expected=entry.packedPixels[i-entry.offset][pair],actual=halfPixels[pair];texelsChecked++;
                    require(actual.every(Number.isFinite),`${entry.name}: finite half pair ${i}/${pair}.`);
                    const err=Math.max(...actual.map((v,c)=>Math.abs(v-expected[c])/Math.max(2**-14,Math.abs(expected[c]))));
                    require(err<=(entry.format===1?0.004:0.00049),`${entry.name}: half quantization ${i}/${pair} error=${err}.`);
                    if(entry.format===0)require(actual.every((v,c)=>Object.is(v,nearestHalf(expected[c]))||(expected[c]===0&&v===0)),`${entry.name}: round-nearest-even differs ${i}/${pair}.`);
                    if(entry.name==='half-negative-subnormal-ties'&&pair===0)require(Object.is(actual[2],-0),`${entry.name}: explicit source negative zero must retain sign.`);
                    if(expected.every(x=>x===0))require(actual.every(x=>x===0),`${entry.name}: row tail padding must be zero.`);
                }
                continue;
            }
            texelsChecked++;const expected=entry.expectedTexels[i-entry.offset];
            require(pixel.every(Number.isFinite),`${entry.name}: published nonfinite texel ${i}.`);
            const rgbError=Math.max(...pixel.slice(0,3).map((v,c)=>Math.abs(v-expected[c])));
            if(entry.format===0){maxFloatError=Math.max(maxFloatError,rgbError);require(pixel.every((v,c)=>v===expected[c]),`${entry.name}: float32 Load did not preserve source texel ${i}.`);}
            else{maxSrgbError=Math.max(maxSrgbError,rgbError);require(rgbError<2e-4,`${entry.name}: sRGB decode error=${rgbError} texel ${i}.`);require(Math.abs(pixel[3]-expected[3])<1e-7,`${entry.name}: alpha was gamma converted.`);}
        }
    }
    require(offset===binary.length,'Output trailing bytes.');
    const result={status:'passed',count:fixture.count,checks,readyCount,notReadyCount,texelsChecked,maxFloatError,maxSrgbError,
        scope:'Actual runtime Begin/CopyMip/Finish DXIL with real multi-mip D3D12 Texture2D float32 and sRGB8 SRVs, explicit reduced views, UAV barriers and fence readback on WARP. Not Unity importer/streaming, reserved tiled-resource misses, DXR or physical GPU.'};
    fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('Unknown mode');
