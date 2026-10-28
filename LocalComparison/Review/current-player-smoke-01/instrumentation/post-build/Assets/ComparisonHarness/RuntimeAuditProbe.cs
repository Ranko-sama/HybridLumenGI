using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;

[DefaultExecutionOrder(-400)]
public sealed class RuntimeAuditProbe : MonoBehaviour
{
    public ComparisonCapture capture;public HybridLumenGIDeformedMesh deformation;public Renderer mutableRenderer;public Material emitter;
    Mesh dynamicMesh;Vector3[] initial;int lastFrame=-1;StreamWriter writer;
    static object Field(object o,string n)=>o.GetType().GetField(n,BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public)?.GetValue(o);
    [Serializable] class Row
    {
        public int frame,publishedFrame,geometryRevision,areaTriangles,materialSources,emissiveSources,validIdentityPixels;
        public bool hasSnapshot,emissionEnabled,inlineRT;public string deformationStatus,areaReason,momentsFormat0,momentsFormat1;
        public float geometryX,historyFraction,historyMaximum;public long deformationReservedBytes;
    }
    void Start()
    {
        dynamicMesh=Instantiate(deformation.GetComponent<MeshFilter>().sharedMesh);initial=dynamicMesh.vertices;
        deformation.GetComponent<MeshFilter>().sharedMesh=dynamicMesh;deformation.RequestCapture(dynamicMesh);
        RenderPipelineManager.endCameraRendering+=Rendered;
    }
    void Update()
    {
        int f=(int)Field(capture,"logicalFrame");if(f==lastFrame)return;lastFrame=f;
        if(f>=60&&f<100)capture.camera.transform.position+=new Vector3(.35f*Mathf.Sin((f-60)*.12f),0,0);
        if(f==120||f==210)
        {
            var vertices=(Vector3[])initial.Clone();if(f==120)for(int i=0;i<vertices.Length;i++)if(vertices[i].y>0)vertices[i].x+=.8f;
            dynamicMesh.vertices=vertices;dynamicMesh.RecalculateBounds();dynamicMesh.RecalculateNormals();deformation.RequestCapture(dynamicMesh);
        }
        if(f==150||f==210)
        {
            var block=new MaterialPropertyBlock();if(f==150)block.SetColor("_BaseColor",Color.blue);
            mutableRenderer.SetPropertyBlock(block,0);mutableRenderer.GetComponent<HybridLumenGIProxy>().MarkDirty();
        }
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=capture.camera)return;
        int f=(int)Field(capture,"logicalFrame");string directory=(string)Field(capture,"directory");if(string.IsNullOrEmpty(directory))return;
        if(writer==null)writer=new StreamWriter(Path.Combine(directory,"functional.jsonl")){AutoFlush=true};
        var row=new Row {frame=f,publishedFrame=deformation.PublishedFrame,hasSnapshot=HybridLumenGIDeformedMesh.HasSnapshot(deformation.GetComponent<Renderer>()),
            geometryRevision=deformation.GetComponent<HybridLumenGIProxy>().GeometryContentRevision,deformationStatus=deformation.Status,
            deformationReservedBytes=HybridLumenGIDeformedMesh.ReservedBytes,emissionEnabled=emitter.IsKeywordEnabled("_EMISSION"),inlineRT=SystemInfo.supportsInlineRayTracing};
        var mesh=HybridLumenGIDeformedMesh.GetSourceMesh(deformation.GetComponent<Renderer>());if(mesh)row.geometryX=mesh.vertices[0].x;
        var pass=Field(capture.feature,"pass");var cameras=pass!=null?Field(pass,"cameras") as IDictionary:null;
        if(cameras!=null)foreach(var state in cameras.Values)
        {
            if(!ReferenceEquals(Field(state,"camera"),camera))continue;
            if(Array.IndexOf(Environment.GetCommandLineArgs(),"-auditDenoiseReadback")>=0 &&
                (f==119||f==149||f==179||f==209||f==239||f==419))
            {
                int currentRead=(int)Field(state,"readIndex");
                foreach(string field in new[]{"history","moments","geometry","material"})
                {
                    var texture=((RTHandle[])Field(state,field))[currentRead].rt;
                    var request=AsyncGPUReadback.Request(texture,0,TextureFormat.RGBAFloat);request.WaitForCompletion();
                    if(request.hasError)throw new Exception("Denoise readback failed: "+field);
                    File.WriteAllBytes(Path.Combine(directory,"denoise-"+f.ToString("D4")+"-"+field+".rgba32f"),request.GetData<byte>().ToArray());
                    File.WriteAllText(Path.Combine(directory,"denoise-size.txt"),texture.width+" "+texture.height);
                }
            }
            if(f==30||f==119||f==179||f==239||f==419||f==719)
            {
                var backend=(HybridLumenGIHardwareBackend)Field(state,((HybridLumenGIRendererFeature)capture.feature).GetDiagnostics()[0].hardwareBackend?"hardware":"softwareGeometry");
                if(backend.TryCaptureHitMaterialSources((HybridLumenGIScene)Field(state,"scene"),out var sources,out var reason))
                {
                    row.materialSources=sources.Length;foreach(var source in sources)if(source.Snapshot.HitMaterial.IsKeywordEnabled("_EMISSION"))row.emissiveSources++;
                    if(HybridLumenGIAreaEmission.TryBuild(sources,backend,1,16384,out var layout,out reason))row.areaTriangles=layout.Count;
                }
                row.areaReason=reason;
                int read=(int)Field(state,"readIndex");var moments=(RTHandle[])Field(state,"moments");
                if(moments[read]?.rt!=null)
                {
                    var req=AsyncGPUReadback.Request(moments[read].rt,0,TextureFormat.RGBAFloat);req.WaitForCompletion();
                    if(req.hasError)throw new Exception("History readback failed");var data=req.GetData<float>();int valid=0;
                    for(int i=2;i<data.Length;i+=4){if(data[i]>1)valid++;row.historyMaximum=Mathf.Max(row.historyMaximum,data[i]);}
                    row.historyFraction=(float)valid/(data.Length/4);
                }
                row.momentsFormat0=moments[0].rt.graphicsFormat.ToString();row.momentsFormat1=moments[1].rt.graphicsFormat.ToString();
                var identity=(RTHandle[])Field(state,"receiverIdentity");
                if(identity[read]?.rt!=null)
                {
                    // UInt4 textures support Load/UAV here, but Unity rejects
                    // direct ReadPixels. Reduce with Load and read a buffer.
                    var shader=Resources.Load<ComputeShader>("RuntimeAuditReadback");
                    using(var counts=new ComputeBuffer(1,4))
                    {
                        counts.SetData(new uint[1]);int kernel=shader.FindKernel("CountIdentity");
                        var texture=identity[read].rt;shader.SetInts("_Size",texture.width,texture.height);
                        shader.SetTexture(kernel,"_Identity",texture);shader.SetBuffer(kernel,"_Counts",counts);
                        shader.Dispatch(kernel,(texture.width+7)/8,(texture.height+7)/8,1);
                        var req=AsyncGPUReadback.Request(counts);req.WaitForCompletion();if(req.hasError)throw new Exception("Identity buffer readback failed");
                        row.validIdentityPixels=(int)req.GetData<uint>()[0];
                    }
                }
                if(f==119)
                {
                    var debug=new System.Text.StringBuilder();
                    var arenas=(IEnumerable)typeof(HybridLumenGIRayTexturePool).GetField("Allocations",BindingFlags.Static|BindingFlags.NonPublic).GetValue(null);
                    foreach(var arena in arenas)
                    {
                        debug.AppendLine("arena readers="+Field(arena,"Readers")+" established="+Field(arena,"Established"));
                        foreach(var page in (IEnumerable)Field(arena,"Pages"))if(page!=null)
                        {
                            foreach(var name in new[]{"Readers","Reusable","Ready","ReadbackPending","ReadbackStarted","MetadataInitialized","UploadComplete","UploadedElements"})debug.Append(name+"="+Field(page,name)+" ");
                            debug.AppendLine();
                        }
                    }
                    var leases=(IEnumerable)typeof(HybridLumenGIRayTexturePool).GetField("Resident",BindingFlags.Static|BindingFlags.NonPublic).GetValue(null);
                    foreach(HybridLumenGIRayTexturePool.Lease lease in leases)debug.AppendLine("lease="+lease.State);
                    File.WriteAllText(Path.Combine(directory,"texture-pool-state.txt"),debug.ToString());
                    var surface=(HybridLumenGISurfaceCache)Field(state,"surfaceCache");
                    foreach(var pair in new[]{("diffuse",surface.DiffuseAtlas),("position",surface.PositionAtlas),("normal",surface.NormalAtlas),("emission",surface.EmissionAtlas)})
                    {
                        var req=AsyncGPUReadback.Request(pair.Item2.rt,0,TextureFormat.RGBAFloat);req.WaitForCompletion();if(req.hasError)throw new Exception("Atlas readback failed");
                        File.WriteAllBytes(Path.Combine(directory,"atlas-"+pair.Item1+".rgba32f"),req.GetData<byte>().ToArray());
                    }
                    File.WriteAllText(Path.Combine(directory,"atlas-size.txt"),surface.AtlasWidth+" "+surface.AtlasHeight);
                }
            }
        }
        writer.WriteLine(JsonUtility.ToJson(row));
    }
    void OnDestroy(){RenderPipelineManager.endCameraRendering-=Rendered;writer?.Dispose();}
}
