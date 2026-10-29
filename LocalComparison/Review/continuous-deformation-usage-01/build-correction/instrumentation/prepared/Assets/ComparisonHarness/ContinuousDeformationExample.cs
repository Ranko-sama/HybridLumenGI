// Ordinary single-object example. The existing deformation component owns GI snapshots.
using System;
using UnityEngine;
using HybridLumenGI;

public sealed class ContinuousDeformationExample : MonoBehaviour
{
    public Renderer SourceRenderer { get; private set; }
    public HybridLumenGIDeformedMesh Deformation { get; private set; }
    public Mesh OriginalMesh { get; private set; }
    public Mesh ProducerMesh { get; private set; }
    public float Shear { get; private set; }
    public double MotionTime { get; private set; }
    public bool Running { get; private set; }

    MeshFilter filter;
    Vector3[] originalPositions,originalNormals,positions,normals;
    Vector4[] originalTangents,tangents;
    bool keyboardInput,initialized,sourceBound,shutdownRegistered,closed;

    static void Require(bool value,string reason)
    {if(!value)throw new InvalidOperationException(reason);}
    static bool Finite(float value)=>!float.IsNaN(value)&&!float.IsInfinity(value);
    static bool Finite(Vector3 value)=>Finite(value.x)&&Finite(value.y)&&Finite(value.z);

    public static ContinuousDeformationExample Create(ComparisonCapture capture,bool keyboardInput)
    {
        if(!capture)throw new ArgumentNullException(nameof(capture));
        Require(!capture.GetComponent<ContinuousDeformationExample>(),"Continuous deformation example already exists.");
        var example=capture.gameObject.AddComponent<ContinuousDeformationExample>();
        try{example.Initialize(capture,keyboardInput);return example;}
        catch
        {
            try{example.Close();}catch(Exception cleanup){Debug.LogException(cleanup,example);}
            UnityEngine.Object.Destroy(example);
            throw;
        }
    }

    void Initialize(ComparisonCapture capture,bool useKeyboard)
    {
        Require(!HybridLumenGIResourceRetirement.AdmissionClosed,"Geometry admission is closed.");
        var probe=capture.GetComponent<RuntimeAuditProbe>();
        Require(probe&&ReferenceEquals(probe.capture,capture)&&!probe.enabled,
            "The matching Functional audit probe must be present and disabled.");
        var deformation=probe.deformation;
        var renderer=deformation?deformation.GetComponent<Renderer>():null;
        var meshFilter=deformation?deformation.GetComponent<MeshFilter>():null;
        var proxy=deformation?deformation.GetComponent<HybridLumenGIProxy>():null;
        Require(deformation&&deformation.isActiveAndEnabled&&renderer&&meshFilter&&proxy&&
            renderer.name=="Audit deforming occluder"&&ReferenceEquals(proxy.SourceRenderer,renderer),
            "The existing Functional deformation target is missing or changed.");
        var original=meshFilter.sharedMesh;
        Require(original&&original.isReadable&&original.vertexCount==24&&original.subMeshCount==1&&
            original.GetTopology(0)==MeshTopology.Triangles&&original.GetIndexCount(0)==36,
            "The existing readable 24-vertex cube source is required.");
        var sourcePositions=original.vertices;
        var sourceNormals=original.normals;
        var sourceTangents=original.tangents;
        var sourceUv=original.uv;
        Require(sourcePositions.Length==24&&sourceNormals.Length==24&&sourceTangents.Length==24&&sourceUv.Length==24,
            "The source position/normal/tangent/UV streams are incomplete.");
        for(int i=0;i<sourcePositions.Length;i++)
        {
            var t=sourceTangents[i];var tangent=new Vector3(t.x,t.y,t.z);
            Require(Finite(sourcePositions[i])&&Finite(sourceNormals[i])&&sourceNormals[i].sqrMagnitude>1e-12f&&
                Finite(tangent)&&tangent.sqrMagnitude>1e-12f&&Finite(t.w)&&Mathf.Abs(t.w)==1&&
                Finite(sourceUv[i].x)&&Finite(sourceUv[i].y),"The source contains invalid geometry streams.");
        }
        SourceRenderer=renderer;Deformation=deformation;filter=meshFilter;OriginalMesh=original;
        originalPositions=sourcePositions;originalNormals=sourceNormals;originalTangents=sourceTangents;
        positions=new Vector3[24];normals=new Vector3[24];tangents=new Vector4[24];
        keyboardInput=useKeyboard;
        ProducerMesh=UnityEngine.Object.Instantiate(original);
        ProducerMesh.name="HLGI continuous deformation producer";
        ProducerMesh.hideFlags=HideFlags.HideAndDontSave;
        // Set before assignment so a partially failed bind is also withdrawn by Close.
        sourceBound=true;filter.sharedMesh=ProducerMesh;
        HybridLumenGIResourceRetirement.RegisterShutdownOwner(Close);shutdownRegistered=true;
        Deformation.RequestCoalescedCapture(ProducerMesh);
        initialized=true; // The clone starts unchanged and paused at t=0, k=0.
    }

    void RequireLiveSource()
    {
        Require(initialized&&!closed&&SourceRenderer&&Deformation&&Deformation.isActiveAndEnabled&&
            filter&&OriginalMesh&&ProducerMesh&&ReferenceEquals(filter.sharedMesh,ProducerMesh),
            "The continuous deformation source is no longer available.");
    }

    public void SetRunning(bool value)
    {
        RequireLiveSource();
        if(Running==value)return;
        Running=value;
        // Stopping freezes the producer; the last request must remain alive to catch up.
        if(!value)Deformation.RequestCoalescedCapture(ProducerMesh);
    }

    public void Advance(float seconds)
    {
        RequireLiveSource();
        if(!Finite(seconds)||seconds<0)throw new ArgumentOutOfRangeException(nameof(seconds));
        if(!Running||seconds==0)return;
        MotionTime+=(double)seconds;
        Shear=(float)(0.4*Math.Sin((2*Math.PI/4)*MotionTime));
        for(int i=0;i<originalPositions.Length;i++)
        {
            var p=originalPositions[i];positions[i]=new Vector3(p.x+Shear*p.y,p.y,p.z);
            var n=originalNormals[i];normals[i]=new Vector3(n.x,n.y-Shear*n.x,n.z).normalized;
            var t=originalTangents[i];var direction=new Vector3(t.x+Shear*t.y,t.y,t.z).normalized;
            tangents[i]=new Vector4(direction.x,direction.y,direction.z,t.w);
        }
        // UV, indices, submeshes and the object Transform remain those of the original clone.
        ProducerMesh.vertices=positions;ProducerMesh.normals=normals;ProducerMesh.tangents=tangents;
        ProducerMesh.RecalculateBounds();
        Deformation.RequestCoalescedCapture(ProducerMesh);
    }

    void Update()
    {
        if(!keyboardInput||!initialized||closed)return;
        try
        {
            if(Application.isFocused&&Input.GetKeyDown(KeyCode.Space))SetRunning(!Running);
            if(Running)Advance(Mathf.Min(Time.unscaledDeltaTime,0.05f));
        }
        catch{Running=false;throw;}
    }

    public void Close()
    {
        if(closed)return;
        closed=true;Running=false;
        if(shutdownRegistered)
        {HybridLumenGIResourceRetirement.UnregisterShutdownOwner(Close);shutdownRegistered=false;}
        Exception error=null;
        // OnDisable cancels pending work and withdraws published system-owned snapshots.
        // Never call RequestCapture here: teardown must not admit another capture.
        try{if(sourceBound&&Deformation)Deformation.enabled=false;}
        catch(Exception e){error=e;}
        try
        {
            if(filter&&ProducerMesh&&ReferenceEquals(filter.sharedMesh,ProducerMesh))filter.sharedMesh=OriginalMesh;
        }
        catch(Exception e){error=error??e;}
        // On a detach failure retain the clone instead of destroying a still-borrowed source.
        if(error==null&&ProducerMesh)
        {
            var owned=ProducerMesh;
            try{HybridLumenGIResourceRetirement.Retire(()=>UnityEngine.Object.Destroy(owned));ProducerMesh=null;}
            catch(Exception e){error=e;}
        }
        if(error!=null)throw error;
        originalPositions=originalNormals=positions=normals=null;originalTangents=tangents=null;
    }

    void OnDisable(){Close();}
    void OnDestroy(){Close();}
    void OnApplicationQuit(){Close();}
}
