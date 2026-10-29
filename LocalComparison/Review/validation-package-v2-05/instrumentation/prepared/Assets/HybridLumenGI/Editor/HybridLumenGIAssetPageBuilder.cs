using System;
using System.Collections.Generic;
using System.IO;
using HybridLumenGI;
using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using Object=UnityEngine.Object;

/// <summary>Builds real local LZ4 bundles, one independently addressable resource per page.</summary>
public static class HybridLumenGIAssetPageBuilder
{
    private sealed class Page
    {
        internal Object source,copy;
        internal string id,path,bundle;
        internal HybridLumenGIAssetPageStreaming.Kind kind;
    }
    [MenuItem("Tools/Hybrid Lumen GI/Export Selected Proxies As Asset Pages")]
    private static void ExportSelection()
    {
        var proxies=new HashSet<HybridLumenGIProxy>();
        foreach(GameObject selected in Selection.gameObjects)
            foreach(var proxy in selected.GetComponentsInChildren<HybridLumenGIProxy>(true))proxies.Add(proxy);
        if(proxies.Count==0)throw new InvalidOperationException("Select one or more static MeshRenderer proxies to export.");
        var sources=new Dictionary<Object,Page>();
        var renderers=new HashSet<Renderer>();
        foreach(var proxy in proxies)
        {
            if(proxy.HLODParent!=null && !proxies.Contains(proxy.HLODParent))
                throw new InvalidOperationException("Include each selected proxy's HLOD parent in the export selection.");
            var renderer=proxy.SourceRenderer as MeshRenderer;
            MeshFilter filter=renderer!=null?renderer.GetComponent<MeshFilter>():null;
            if(filter==null || filter.sharedMesh==null || renderer.sharedMaterials.Length!=filter.sharedMesh.subMeshCount)
                throw new InvalidOperationException("Every selected proxy needs a mesh and exactly one material per submesh.");
            if(!renderers.Add(renderer))throw new InvalidOperationException("Two selected proxies cannot own the same streamed renderer.");
            Collect(filter.sharedMesh,sources);Collect(proxy.MeshSdf,sources);Collect(proxy.SurfaceCharts,sources);
            foreach(var material in renderer.sharedMaterials)
            {if(material==null)throw new InvalidOperationException("Null material slots cannot be exported.");Collect(material,sources);}
        }
        string run=Guid.NewGuid().ToString("N"),assetRoot="Assets/HybridLumenGIAssetPages/"+run;
        string bundleRelative="HybridLumenGIAssetPages/"+run;
        string output="Assets/StreamingAssets/"+bundleRelative;
        Directory.CreateDirectory(assetRoot+"/Sources");Directory.CreateDirectory(output);AssetDatabase.Refresh();
        var builds=new List<AssetBundleBuild>();
        foreach(var page in sources.Values)
        {
            page.id=page.kind.ToString().ToLowerInvariant()+"-"+Guid.NewGuid().ToString("N");
            page.path=assetRoot+"/Sources/"+page.id+".asset";page.bundle=page.id+".hlgipage";
            page.copy=Object.Instantiate(page.source);page.copy.name=page.source.name;
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
                var serialized=new SerializedObject(page.copy);
                foreach(string field in new[]{"sourceMesh","captureMesh","distanceTexture"})
                {
                    var property=serialized.FindProperty(field);
                    if(property!=null && property.objectReferenceValue!=null)
                        property.objectReferenceValue=sources[property.objectReferenceValue].copy;
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
        var rig=new GameObject("HybridLumenGI Streamed Pages "+run.Substring(0,8));rig.SetActive(false);
        Undo.RegisterCreatedObjectUndo(rig,"Create streamed GI representations");
        var driver=rig.AddComponent<HybridLumenGIAssetPageStreamer>();driver.Configure(manifest);
        var replacements=new Dictionary<HybridLumenGIProxy,HybridLumenGIProxy>();
        var transforms=new Dictionary<Transform,Transform>();
        foreach(var original in proxies)
        {
            var sourceRenderer=(MeshRenderer)original.SourceRenderer;
            Mesh sourceMesh=sourceRenderer.GetComponent<MeshFilter>().sharedMesh;
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
            var materialIds=new string[sourceRenderer.sharedMaterials.Length];
            for(int i=0;i<materialIds.Length;i++)materialIds[i]=sources[sourceRenderer.sharedMaterials[i]].id;
            var binding=go.AddComponent<HybridLumenGIStreamedRepresentation>();
            binding.Configure(driver,proxy,filter,renderer,sources[sourceMesh].id,
                original.MeshSdf!=null?sources[original.MeshSdf].id:null,
                original.SurfaceCharts!=null?sources[original.SurfaceCharts].id:null,materialIds,sourceMesh.bounds);
            bool aggregate=original.FarFieldOnly;
            foreach(var candidate in proxies)aggregate|=candidate.HLODParent==original;
            if(aggregate)binding.ConfigureDistances(200f,240f);
            replacements.Add(original,proxy);
        }
        foreach(var pair in replacements)
            if(pair.Key.HLODParent!=null && replacements.TryGetValue(pair.Key.HLODParent,out var replacement))pair.Value.SetHLODParent(replacement);
        Selection.activeObject=rig;
        Debug.Log("Built "+definitions.Count+" independently loaded LZ4 asset pages in "+output+". Manifest: "+assetRoot+
            "/Manifest.asset. Inactive streamed rig created; disable originals and enable the rig to test. " +
            "Costs are admission estimates; verify actual GPU time/memory on the target Player. Export must match its build target.",manifest);
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
