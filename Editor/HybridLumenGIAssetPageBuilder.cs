using System;
using System.Collections.Generic;
using System.IO;
using HybridLumenGI;
using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;
using Object=UnityEngine.Object;

/// <summary>Builds real local LZ4 bundles, one independently addressable resource per page.</summary>
public static class HybridLumenGIAssetPageBuilder
{
    public sealed class ExportResult
    {
        public HybridLumenGIAssetPageManifest Manifest { get; }
        public GameObject Rig { get; }
        internal ExportResult(HybridLumenGIAssetPageManifest manifest,GameObject rig)
        {Manifest=manifest;Rig=rig;}
    }
    private sealed class Page
    {
        internal Object source,copy;
        internal string id,path,bundle;
        internal HybridLumenGIAssetPageStreaming.Kind kind;
    }
    internal readonly struct ExportGeometry
    {
        internal readonly Mesh mesh;
        internal readonly HybridLumenGIMeshSdf sdf;
        internal readonly HybridLumenGISurfaceCharts charts;

        internal ExportGeometry(Mesh mesh, HybridLumenGIMeshSdf sdf, HybridLumenGISurfaceCharts charts)
        { this.mesh = mesh; this.sdf = sdf; this.charts = charts; }
    }
    [MenuItem("Tools/Hybrid Lumen GI/Export Selected Proxies As Asset Pages")]
    private static void ExportSelection()
    {
        var proxies=new HashSet<HybridLumenGIProxy>();
        foreach(GameObject selected in Selection.gameObjects)
            foreach(var proxy in selected.GetComponentsInChildren<HybridLumenGIProxy>(true))proxies.Add(proxy);
        string run=Guid.NewGuid().ToString("N");
        var result=Export(proxies,"Assets/HybridLumenGIAssetPages/"+run,"Assets/StreamingAssets/HybridLumenGIAssetPages/"+run);
        Selection.activeObject=result.Rig;
    }
    /// <summary>
    /// Builds pages in two new project-relative directories and returns an inactive rig.
    /// Source proxies and their bindings are retained; the caller decides when to replace them.
    /// Static ordinary URP Lit property-block values are exported as per-slot material assets.
    /// </summary>
    public static ExportResult Export(IEnumerable<HybridLumenGIProxy> sourceProxies,string assetDirectory,string bundleOutputDirectory)
    {
        if(sourceProxies==null)throw new ArgumentNullException(nameof(sourceProxies));
        var proxies=new HashSet<HybridLumenGIProxy>();
        foreach(var proxy in sourceProxies)
        {
            if(proxy==null)throw new ArgumentException("Source proxies cannot contain a null/destroyed entry.",nameof(sourceProxies));
            proxies.Add(proxy);
        }
        if(proxies.Count==0)throw new InvalidOperationException("Select one or more static MeshRenderer proxies to export.");
        string assetRoot=assetDirectory,output=bundleOutputDirectory;
        string assetFull=ValidateNewDirectory(assetRoot,false),outputFull=ValidateNewDirectory(output,true);
        if(IsWithin(assetFull,outputFull) || IsWithin(outputFull,assetFull))
            throw new ArgumentException("Source-asset and bundle-output directories must not overlap.");
        var sources=new Dictionary<Object,Page>();
        var effectiveMaterials=new Dictionary<Renderer,Material[]>();
        var geometries=new Dictionary<Renderer,ExportGeometry>();
        var temporarySources=new List<Object>();
        try
        {
        foreach(var proxy in proxies)
        {
            if(proxy.HLODParent!=null && !proxies.Contains(proxy.HLODParent))
                throw new InvalidOperationException("Include each selected proxy's HLOD parent in the export selection.");
            var renderer=proxy.SourceRenderer as MeshRenderer;
            ValidateStandaloneMesh(renderer);
            MeshFilter filter=renderer!=null?renderer.GetComponent<MeshFilter>():null;
            if(filter==null || filter.sharedMesh==null || renderer.sharedMaterials.Length!=filter.sharedMesh.subMeshCount)
                throw new InvalidOperationException("Every selected proxy needs a mesh and exactly one material per submesh.");
            if(geometries.ContainsKey(renderer))throw new InvalidOperationException("Two selected proxies cannot own the same streamed renderer.");
            var geometry=PrepareGeometry(proxy,temporarySources);
            geometries.Add(renderer,geometry);
            Collect(geometry.mesh,sources);Collect(geometry.sdf,sources);Collect(geometry.charts,sources);
            Material[] materials=renderer.sharedMaterials;
            for(int slot=0;slot<materials.Length;slot++)
            {
                if(materials[slot]==null)throw new InvalidOperationException("Null material slots cannot be exported.");
                if(renderer.HasPropertyBlock())materials[slot]=ExportMaterial(renderer,slot,materials[slot],temporarySources);
                Collect(materials[slot],sources);
            }
            effectiveMaterials.Add(renderer,materials);
        }
        string run=Path.GetFileName(assetRoot);
        string bundleRelative=output.Substring("Assets/StreamingAssets/".Length);
        Directory.CreateDirectory(assetRoot+"/Sources");Directory.CreateDirectory(output);AssetDatabase.Refresh();
        var builds=new List<AssetBundleBuild>();
        foreach(var page in sources.Values)
        {
            page.id=page.kind.ToString().ToLowerInvariant()+"-"+Guid.NewGuid().ToString("N");
            page.path=assetRoot+"/Sources/"+page.id+".asset";page.bundle=page.id+".hlgipage";
            page.copy=Object.Instantiate(page.source);page.copy.name=page.source.name;
            if((page.source.hideFlags & HideFlags.DontSave)!=0)page.copy.hideFlags=HideFlags.None;
            AssetDatabase.CreateAsset(page.copy,page.path);
            builds.Add(new AssetBundleBuild {assetBundleName=page.bundle,assetNames=new[]{page.path}});
        }
        // All references point to the exported identities, including subasset meshes/textures.
        // Leaving source references here would silently duplicate them into several bundles.
        foreach(var page in sources.Values)
        {
            if(page.copy is Material material)
            {
                foreach(string property in material.GetTexturePropertyNames())
                {Texture texture=material.GetTexture(property);if(texture!=null)material.SetTexture(property,(Texture)sources[texture].copy);}
            }
            else if(page.copy is HybridLumenGIMeshSdf || page.copy is HybridLumenGISurfaceCharts)
            {
                using var origin=new SerializedObject(page.source);
                using var serialized=new SerializedObject(page.copy);
                foreach(string field in new[]{"sourceMesh","captureMesh","distanceTexture"})
                {
                    var original=origin.FindProperty(field)?.objectReferenceValue;
                    if(original!=null)serialized.FindProperty(field).objectReferenceValue=sources[original].copy;
                }
                serialized.ApplyModifiedPropertiesWithoutUndo();
            }
            EditorUtility.SetDirty(page.copy);
        }
        AssetDatabase.SaveAssets();
        var target=EditorUserBuildSettings.activeBuildTarget;
        AssetBundleManifest built=BuildPipeline.BuildAssetBundles(output,builds.ToArray(),
            BuildAssetBundleOptions.ChunkBasedCompression|BuildAssetBundleOptions.StrictMode|BuildAssetBundleOptions.DeterministicAssetBundle,target);
        if(built==null)throw new InvalidOperationException("AssetBundle build failed; no scene bindings were changed.");
        var bundleToId=new Dictionary<string,string>(StringComparer.Ordinal);
        foreach(var page in sources.Values)bundleToId.Add(page.bundle,page.id);
        var definitions=new List<HybridLumenGIAssetPageStreaming.Definition>();
        foreach(var page in sources.Values)
        {
            string fullPath=Path.GetFullPath(Path.Combine(output,page.bundle));
            if(!BuildPipeline.GetCRCForAssetBundle(fullPath,out uint crc))throw new InvalidOperationException("Cannot read bundle CRC: "+page.id);
            var dependencies=new List<string>();
            foreach(string dependency in built.GetDirectDependencies(page.bundle))dependencies.Add(bundleToId[dependency]);
            // BuildAssetBundles may unload unreferenced imported objects. Managed
            // references to the temporary copies do not keep their native assets
            // alive, so reacquire the saved identity after the build.
            page.copy=AssetDatabase.LoadMainAssetAtPath(page.path);
            if(page.copy==null)throw new InvalidOperationException("Built page asset is unavailable: "+page.path);
            long bytes=DeclaredResidentBytes(page.copy);
            definitions.Add(new HybridLumenGIAssetPageStreaming.Definition {id=page.id,bundlePath=page.bundle,
                assetName=page.path.ToLowerInvariant(),kind=page.kind,crc=crc,fileBytes=new FileInfo(fullPath).Length,
                residentBytes=bytes,uploadBytes=page.copy is Mesh || page.copy is Texture?bytes:0,dependencies=dependencies.ToArray()});
        }
        var manifest=ScriptableObject.CreateInstance<HybridLumenGIAssetPageManifest>();
        manifest.SetBuiltPages(bundleRelative,target.ToString(),definitions.ToArray());
        AssetDatabase.CreateAsset(manifest,assetRoot+"/Manifest.asset");AssetDatabase.SaveAssets();AssetDatabase.Refresh();

        // Clone transform ancestry without source assets/components so parent nonuniform scale
        // and rotation remain exact. All destinations live under one inactive, independent rig.
        var rig=new GameObject("HybridLumenGI Streamed Pages "+run.Substring(0,Math.Min(8,run.Length)));rig.SetActive(false);
        Undo.RegisterCreatedObjectUndo(rig,"Create streamed GI representations");
        var driver=rig.AddComponent<HybridLumenGIAssetPageStreamer>();driver.Configure(manifest);
        var replacements=new Dictionary<HybridLumenGIProxy,HybridLumenGIProxy>();
        var transforms=new Dictionary<Transform,Transform>();
        var authoredParents=new HashSet<HybridLumenGIProxy>();
        foreach(var original in proxies)if(original.HLODParent!=null)authoredParents.Add(original.HLODParent);
        foreach(var original in proxies)
        {
            var sourceRenderer=(MeshRenderer)original.SourceRenderer;
            var geometry=geometries[sourceRenderer];
            GameObject go=CloneTransform(sourceRenderer.transform,rig.transform,transforms).gameObject;
            var filter=go.AddComponent<MeshFilter>();var renderer=go.AddComponent<MeshRenderer>();
            // Copy public rendering policy without inheriting the original static-batch mesh or
            // static-batch root: this destination owns independently streamed vertex buffers.
            renderer.shadowCastingMode=sourceRenderer.shadowCastingMode;renderer.receiveShadows=sourceRenderer.receiveShadows;
            renderer.renderingLayerMask=sourceRenderer.renderingLayerMask;renderer.motionVectorGenerationMode=sourceRenderer.motionVectorGenerationMode;
            renderer.lightProbeUsage=sourceRenderer.lightProbeUsage;renderer.reflectionProbeUsage=sourceRenderer.reflectionProbeUsage;
            renderer.lightmapIndex=sourceRenderer.lightmapIndex;renderer.lightmapScaleOffset=sourceRenderer.lightmapScaleOffset;
            renderer.allowOcclusionWhenDynamic=sourceRenderer.allowOcclusionWhenDynamic;
            if(sourceRenderer.probeAnchor!=null)renderer.probeAnchor=CloneTransform(sourceRenderer.probeAnchor,rig.transform,transforms);
            renderer.sharedMaterials=Array.Empty<Material>();renderer.enabled=false;
            var proxy=go.AddComponent<HybridLumenGIProxy>();EditorUtility.CopySerialized(original,proxy);
            proxy.SetSources(renderer,null);proxy.SetMeshSdf(null);proxy.SetSurfaceCharts(null);proxy.enabled=false;
            Material[] materials=effectiveMaterials[sourceRenderer];
            var materialIds=new string[materials.Length];
            for(int i=0;i<materialIds.Length;i++)materialIds[i]=sources[materials[i]].id;
            var binding=go.AddComponent<HybridLumenGIStreamedRepresentation>();
            binding.Configure(driver,proxy,filter,renderer,sources[geometry.mesh].id,
                geometry.sdf!=null?sources[geometry.sdf].id:null,
                geometry.charts!=null?sources[geometry.charts].id:null,materialIds,geometry.mesh.bounds);
            bool aggregate=authoredParents.Contains(original);
            if(aggregate || original.FarFieldOnly)binding.ConfigureDistances(200f,240f);
            binding.UseHlodPublicationForRendering(aggregate || original.HLODParent!=null);
            replacements.Add(original,proxy);
        }
        foreach(var pair in replacements)
            if(pair.Key.HLODParent!=null && replacements.TryGetValue(pair.Key.HLODParent,out var replacement))pair.Value.SetHLODParent(replacement);
        Debug.Log("Built "+definitions.Count+" independently loaded LZ4 asset pages in "+output+". Manifest: "+assetRoot+
            "/Manifest.asset. Inactive streamed rig created; disable originals and enable the rig to test. " +
            "Costs are admission estimates; verify actual GPU time/memory on the target Player. Export must match its build target.",manifest);
        return new ExportResult(manifest,rig);
        }
        finally
        {
            foreach(var source in temporarySources)if(source!=null)Object.DestroyImmediate(source);
        }
    }
    private static bool IsOverride(HybridLumenGIMaterialValueOrigin origin)
        => origin==HybridLumenGIMaterialValueOrigin.RendererPropertyBlock || origin==HybridLumenGIMaterialValueOrigin.MaterialPropertyBlock;
    private static Material ExportMaterial(Renderer renderer,int slot,Material source,List<Object> temporarySources)
    {
        var reader=new HybridLumenGIMaterialSource();
        if(!reader.TryCapture(renderer,slot,source,out var snapshot,out string reason))
            throw new InvalidOperationException("Cannot export static URP Lit overrides for "+renderer.name+" slot "+slot+": "+reason);
        var data=snapshot.HitMaterial;
        // Keep transient snapshots alive while BuildAssetBundles unloads imported assets.
        // Only the independently saved copy enters the page graph; the caller always disposes this one.
        Material material=Object.Instantiate(source);material.hideFlags=HideFlags.HideAndDontSave;
        temporarySources.Add(material);
        Shader shader=source.shader;
        for(int property=0;property<shader.GetPropertyCount();property++)
        {
            string name=shader.GetPropertyName(property);
            var type=shader.GetPropertyType(property);
            if(type==ShaderPropertyType.Texture)
            {
                var texture=data.GetTexture(name);
                if(IsOverride(texture.Origin))material.SetTexture(name,texture.Texture);
                continue;
            }
            if(!data.TryGetVector(name,out Vector4 value,out var origin) || !IsOverride(origin))continue;
            if(type==ShaderPropertyType.Float || type==ShaderPropertyType.Range)material.SetFloat(name,value.x);
            else if(type==ShaderPropertyType.Vector)material.SetVector(name,value);
            else if(type==ShaderPropertyType.Color)
            {
                // MPBs contain shader-space vectors; non-HDR Material colors use authoring space.
                Color color=value;
                if(QualitySettings.activeColorSpace==ColorSpace.Linear && (shader.GetPropertyFlags(property)&ShaderPropertyFlags.HDR)==0)color=color.gamma;
                material.SetColor(name,color);
            }
        }
        foreach(string texture in new[]{"_BaseMap","_DetailAlbedoMap"})
            if(data.TryGetVector(texture+"_ST",out Vector4 transform,out var origin) && IsOverride(origin))
            {
                material.SetTextureScale(texture,new Vector2(transform.x,transform.y));
                material.SetTextureOffset(texture,new Vector2(transform.z,transform.w));
            }
        // Keywords and raster state stay cloned from the source Material. The existing
        // material contract reports raster values with Material origin even if an MPB names them.
        return material;
    }
    private static bool IsWithin(string child,string parent)
        => string.Equals(child,parent,StringComparison.OrdinalIgnoreCase) ||
            child.StartsWith(parent+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase);
    internal static void ValidateStandaloneMesh(MeshRenderer renderer)
    {
        if (renderer == null) return;
        if (renderer.isPartOfStaticBatch)
            throw new InvalidOperationException($"Renderer '{renderer.name}' is part of a static batch. Export the authoring renderer before batching.");
        var stream = renderer.additionalVertexStreams;
        if (!stream) return;
        var mesh = renderer.GetComponent<MeshFilter>()?.sharedMesh;
        if (!mesh || !mesh.isReadable || !stream.isReadable || stream.vertexCount != mesh.vertexCount ||
            renderer.enlightenVertexStream || stream.vertexAttributeCount != 1 ||
            !stream.HasVertexAttribute(VertexAttribute.TexCoord0) ||
            stream.GetVertexAttributeFormat(VertexAttribute.TexCoord0) != VertexAttributeFormat.Float32 ||
            stream.GetVertexAttributeDimension(VertexAttribute.TexCoord0) != 2)
            throw new InvalidOperationException($"Renderer '{renderer.name}' uses unsupported additional vertex streams. Export requires a readable Float32 UV0 pair per source vertex and no other override.");
        foreach (var material in renderer.sharedMaterials)
            if (!material || !material.shader || material.shader.name != "Universal Render Pipeline/Lit")
                throw new InvalidOperationException($"Renderer '{renderer.name}' needs ordinary URP Lit materials to export a UV0 override.");
    }

    // Callers own these temporary objects through the bundle build. Authoring assets are shared read-only.
    internal static ExportGeometry PrepareGeometry(HybridLumenGIProxy proxy, List<Object> temporarySources)
    {
        var renderer = (MeshRenderer)proxy.SourceRenderer;
        var source = renderer.GetComponent<MeshFilter>().sharedMesh;
        var sdf = proxy.MeshSdf;
        var charts = proxy.SurfaceCharts;
        var stream = renderer.additionalVertexStreams;
        if (!stream) return new ExportGeometry(source, sdf, charts);
        if ((sdf && !sdf.MatchesSource(source)) || (charts && !charts.MatchesSource(source)))
            throw new InvalidOperationException($"Renderer '{renderer.name}' has stale source bakes. Rebake the base mesh before exporting its UV0 override.");

        var uv = stream.uv;
        if (uv.Length != source.vertexCount)
            throw new InvalidOperationException($"Renderer '{renderer.name}' does not supply a UV0 value for every source vertex.");
        foreach (var value in uv)
            if (!float.IsFinite(value.x) || !float.IsFinite(value.y))
                throw new InvalidOperationException($"Renderer '{renderer.name}' has a non-finite UV0 override.");
        var mesh = KeepTemporary(Object.Instantiate(source), temporarySources);
        mesh.name = source.name + " (" + renderer.name + " UV0)";
        mesh.uv = uv;
        if (sdf)
        {
            // UV changes leave the signed distances, local bounds and triangle topology intact.
            var rebound = KeepTemporary(ScriptableObject.CreateInstance<HybridLumenGIMeshSdf>(), temporarySources);
            rebound.name = sdf.name;
            rebound.SetBakedData(mesh, sdf.DistanceTexture, sdf.LocalBounds, sdf.Resolution, sdf.Watertight);
            sdf = rebound;
        }
        if (charts)
        {
            var capture = KeepTemporary(HybridLumenGISurfaceCharts.CreateCaptureMesh(mesh, charts.Charts), temporarySources);
            var rebound = KeepTemporary(ScriptableObject.CreateInstance<HybridLumenGISurfaceCharts>(), temporarySources);
            rebound.name = charts.name;
            rebound.SetBakedData(mesh, capture, charts.Charts);
            charts = rebound;
        }
        return new ExportGeometry(mesh, sdf, charts);
    }

    private static T KeepTemporary<T>(T value, List<Object> temporarySources) where T : Object
    {
        temporarySources.Add(value);
        value.hideFlags = HideFlags.HideAndDontSave;
        return value;
    }

    private static string ValidateNewDirectory(string path,bool bundles)
    {
        string prefix=bundles?"Assets/StreamingAssets/":"Assets/";
        if(string.IsNullOrEmpty(path) || !path.StartsWith(prefix,StringComparison.Ordinal) || path.IndexOf('\\')>=0)
            throw new ArgumentException("Expected a new project-relative "+prefix+"... directory.",nameof(path));
        foreach(string part in path.Split('/'))
            if(part.Length==0 || part=="." || part==".." || part.IndexOf(':')>=0 || part.IndexOfAny(Path.GetInvalidFileNameChars())>=0 ||
                part.EndsWith(".",StringComparison.Ordinal) || part.EndsWith(" ",StringComparison.Ordinal))
                throw new ArgumentException("Output path has an invalid or ambiguous segment.",nameof(path));
        string project=Path.GetFullPath(Path.Combine(Application.dataPath,".."));
        if(!string.Equals(Path.GetFullPath("."),project,StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Page export requires the Unity project working directory.");
        string full=Path.GetFullPath(Path.Combine(project,path));
        if(!full.StartsWith(Path.Combine(project,"Assets")+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("Output path escaped project Assets.",nameof(path));
        string current=project;
        foreach(string part in path.Split('/'))
        {
            current=Path.Combine(current,part);
            if(File.Exists(current))throw new IOException("Output directory ancestor is a file: "+current);
            if(!Directory.Exists(current) && File.Exists(current+".meta"))
                throw new IOException("Output directory would reuse orphaned metadata: "+current);
            if(Directory.Exists(current) && (File.GetAttributes(current)&FileAttributes.ReparsePoint)!=0)
                throw new IOException("Output directory traverses a reparse point: "+current);
        }
        if(Directory.Exists(full) || File.Exists(full) || File.Exists(full+".meta") || AssetDatabase.IsValidFolder(path) || AssetDatabase.LoadMainAssetAtPath(path)!=null)
            throw new IOException("Refusing to overwrite an existing output path or metadata: "+path);
        return full;
    }
    private static Transform CloneTransform(Transform source,Transform rig,Dictionary<Transform,Transform> clones)
    {
        if(clones.TryGetValue(source,out var existing))return existing;
        Transform parent=source.parent!=null?CloneTransform(source.parent,rig,clones):rig;
        var go=new GameObject(source.name+" (Streamed)");go.layer=source.gameObject.layer;
        go.transform.SetParent(parent,false);go.transform.localPosition=source.localPosition;
        go.transform.localRotation=source.localRotation;go.transform.localScale=source.localScale;
        Undo.RegisterCreatedObjectUndo(go,"Create streamed GI transform");clones.Add(source,go.transform);return go.transform;
    }
    private static void Collect(Object source,Dictionary<Object,Page> pages)
    {
        if(source==null || pages.ContainsKey(source))return;
        HybridLumenGIAssetPageStreaming.Kind kind;
        if(source is Mesh)kind=HybridLumenGIAssetPageStreaming.Kind.Geometry;
        else if(source is HybridLumenGIMeshSdf)kind=HybridLumenGIAssetPageStreaming.Kind.Sdf;
        else if(source is HybridLumenGISurfaceCharts)kind=HybridLumenGIAssetPageStreaming.Kind.SurfaceCharts;
        else if(source is Material)kind=HybridLumenGIAssetPageStreaming.Kind.Material;
        else if(source is Texture && !(source is RenderTexture))kind=HybridLumenGIAssetPageStreaming.Kind.Texture;
        else throw new InvalidOperationException("Unsupported authored asset for file paging: "+source.GetType().Name);
        pages.Add(source,new Page{source=source,kind=kind});
        if(source is HybridLumenGIMeshSdf sdf){Collect(sdf.SourceMesh,pages);Collect(sdf.DistanceTexture,pages);}
        if(source is HybridLumenGISurfaceCharts charts){Collect(charts.SourceMesh,pages);Collect(charts.CaptureMesh,pages);}
        if(source is Material material)foreach(string property in material.GetTexturePropertyNames())Collect(material.GetTexture(property),pages);
    }
    private static long DeclaredResidentBytes(Object value)
    {
        long bytes=Profiler.GetRuntimeMemorySizeLong(value);
        if(value is Mesh mesh)
        {
            long bufferBytes=0;
            for(int stream=0;stream<mesh.vertexBufferCount;stream++)bufferBytes=checked(bufferBytes+(long)mesh.vertexCount*mesh.GetVertexBufferStride(stream));
            long indices=0;for(int submesh=0;submesh<mesh.subMeshCount;submesh++)indices=checked(indices+mesh.GetIndexCount(submesh));
            bufferBytes=checked(bufferBytes+indices*(mesh.indexFormat==UnityEngine.Rendering.IndexFormat.UInt32?4:2));
            bytes=Math.Max(bytes,bufferBytes);
        }
        if(bytes<=0)throw new InvalidOperationException("No native residency estimate available for "+value.name+"; author an explicit measured page budget before exporting.");
        return bytes;
    }
}
