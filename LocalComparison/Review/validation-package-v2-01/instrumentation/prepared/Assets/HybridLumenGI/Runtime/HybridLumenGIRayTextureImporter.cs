using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Records an exact original-texel capture. The producer, copy and all consumers must
    /// execute in order on the same graphics queue (or have explicit cross-queue waits).
    /// The GPU validates the bound source view and alone publishes ready. This class
    /// does not equate command recording, updateCount or CPU snapshots with GPU completion.
    /// </summary>
    public sealed class HybridLumenGIRayTextureImporter
    {
        private static readonly int SourceId=Shader.PropertyToID("_HLGI_RayTextureSource");
        private static readonly int MetadataId=Shader.PropertyToID("_HLGI_RayTextureCopyMetadata");
        private static readonly int TexelsId=Shader.PropertyToID("_HLGI_RayTextureCopyTexels");
        private static readonly int IndexId=Shader.PropertyToID("_HLGI_CopyTextureIndex");
        private static readonly int GenerationId=Shader.PropertyToID("_HLGI_CopyTextureGeneration");
        private static readonly int MipId=Shader.PropertyToID("_HLGI_CopyTextureMip");
        private static readonly int CapacityId=Shader.PropertyToID("_HLGI_CopyTextureCapacity");
        private static readonly int RangeStartId=Shader.PropertyToID("_HLGI_CopyRangeStart");
        private static readonly int RangeCountId=Shader.PropertyToID("_HLGI_CopyRangeCount");
        private ComputeShader shader;
        private int begin=-1,copy=-1,finish=-1,range=-1;
        public string LastRejection { get; private set; }
        public int RecordedTextures { get; private set; }
        public int RecordedDispatches { get; private set; }

        public HybridLumenGIRayTextureImporter(ComputeShader shader=null) { this.shader=shader; }

        /// <summary>
        /// Reads the source once more immediately before recording. A changed observation
        /// is rejected; material values still come from the earlier immutable snapshot.
        /// This detects CPU-visible changes only. Producers of native/GPU-written textures
        /// must provide the actual dependency, even when updateCount is unchanged.
        /// </summary>
        public static bool SourceStillMatches(HybridLumenGIFrozenTextureView v)
        {
            Texture t=v.Texture;
            if(t==null || (t is not Texture2D && t is not RenderTexture) ||
                t.width!=v.Width || t.height!=v.Height || (int)t.dimension!=v.Dimension ||
                (int)t.graphicsFormat!=v.GraphicsFormat || t.mipmapCount!=v.MipmapCount ||
                (int)t.filterMode!=v.FilterMode || (int)t.wrapModeU!=v.WrapModeU ||
                (int)t.wrapModeV!=v.WrapModeV || (int)t.wrapModeW!=v.WrapModeW ||
                t.anisoLevel!=v.AnisoLevel || BitConverter.SingleToInt32Bits(t.mipMapBias)!=BitConverter.SingleToInt32Bits(v.MipMapBias) ||
                t.updateCount!=v.UpdateCount || t.isDataSRGB!=v.IsDataSRGB) return false;
            if(t is Texture2D texture)
                return v.HasTexture2DMipState && !v.IsRenderTexture && !texture.vtOnly &&
                    texture.streamingMipmaps==v.StreamingMipmaps && texture.activeMipmapLimit==v.ActiveMipmapLimit &&
                    texture.loadedMipmapLevel==v.LoadedMipmapLevel && texture.loadingMipmapLevel==v.LoadingMipmapLevel;
            var rt=(RenderTexture)t;
            return v.IsRenderTexture && !v.HasTexture2DMipState && rt.IsCreated() && rt.antiAliasing==1 &&
                rt.volumeDepth==1 && (rt.memorylessMode&RenderTextureMemoryless.Color)==0;
        }

        /// <summary>
        /// Compatible with RayTexturePool.RecordUploads. Unsupported/stale sources retain
        /// the batch's initialized ready=0 descriptor. A command API exception propagates
        /// to the pool, which quarantines any buffers possibly referenced by that command.
        /// </summary>
        public void Record(CommandBuffer command,HybridLumenGIRayTexturePool.Upload upload,
            GraphicsBuffer metadata,GraphicsBuffer texels)
        {
            LastRejection=null;
            if(command==null || metadata==null || texels==null) throw new ArgumentNullException("Texture copy resources");
            if(!SystemInfo.supportsComputeShaders || SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Direct3D12)
            { LastRejection="The original-texel importer currently requires DX12 compute.";return; }
            var view=upload.View;var layout=upload.Layout;
            var format=(GraphicsFormat)view.GraphicsFormat;
            // Imported RGB24 assets retain their logical RGB format in Unity,
            // although DX12 binds them through a supported RGBA backing texture.
            // Test that exact expansion; the GPU copy still validates the bound
            // dimensions, mapped texels and completed chain before publishing.
            var samplingFormat=format==GraphicsFormat.R8G8B8_SRGB?GraphicsFormat.R8G8B8A8_SRGB:
                format==GraphicsFormat.R8G8B8_UNorm?GraphicsFormat.R8G8B8A8_UNorm:format;
            if(view.Dimension!=2 || !SourceStillMatches(view) ||
                !SystemInfo.IsFormatSupported(samplingFormat,GraphicsFormatUsage.Sample))
            { LastRejection="Source changed, is unavailable, or cannot be sampled as a 2D color texture.";return; }
            if(layout.FirstMip!=0 || layout.Width!=view.Width || layout.Height!=view.Height || layout.MipCount!=view.MipmapCount ||
                !layout.Fits(upload.TexelOffset,texels.count) || metadata.stride!=64 || texels.stride!=16 ||
                upload.MetadataIndex<0 || upload.MetadataIndex>=metadata.count || upload.Generation==0)
                throw new InvalidOperationException("Texture copy allocation does not match its frozen source.");
            if(shader==null) shader=Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGIRayTextureCopy");
            if(shader==null) { LastRejection="Original-texel copy shader is unavailable.";return; }
            if(begin<0)
            {
                // Assign only after all lookups succeed. A partial kernel lookup cannot
                // leave later calls using a mixture of valid and invalid kernel indices.
                int a=shader.FindKernel("CSBeginRayTextureCopy"),b=shader.FindKernel("CSCopyRayTextureMip"),c=shader.FindKernel("CSFinishRayTextureCopy");
                if(a<0 || b<0 || c<0) throw new InvalidOperationException("Texture copy kernels unavailable.");
                begin=a;copy=b;finish=c;
            }
            command.SetComputeIntParam(shader,IndexId,upload.MetadataIndex);
            command.SetComputeIntParam(shader,GenerationId,unchecked((int)upload.Generation));
            command.SetComputeIntParam(shader,CapacityId,layout.StorageElementCount);
            if(upload.Progressive)
            {
                if(upload.RangeStart<0||upload.RangeCount<=0||upload.RangeStart>layout.StorageElementCount-upload.RangeCount)
                    throw new InvalidOperationException("Progressive range exceeds its reserved page.");
                if(range<0){int found=shader.FindKernel("CSCopyRayTextureRange");if(found<0)throw new InvalidOperationException("Range copy kernel unavailable.");range=found;}
                if(upload.Begin){Bind(command,begin,view.Texture,metadata,texels);command.DispatchCompute(shader,begin,1,1,1);RecordedDispatches++;}
                Bind(command,range,view.Texture,metadata,texels);
                for(int copied=0;copied<upload.RangeCount;)
                {
                    int count=Math.Min(65535*64,upload.RangeCount-copied);
                    command.SetComputeIntParam(shader,RangeStartId,upload.RangeStart+copied);
                    command.SetComputeIntParam(shader,RangeCountId,count);
                    command.DispatchCompute(shader,range,(count+63)/64,1,1);RecordedDispatches++;copied+=count;
                }
                if(upload.Finish){Bind(command,finish,view.Texture,metadata,texels);command.DispatchCompute(shader,finish,1,1,1);RecordedDispatches++;RecordedTextures++;}
                return;
            }
            Bind(command,begin,view.Texture,metadata,texels);
            command.DispatchCompute(shader,begin,1,1,1);RecordedDispatches++;
            Bind(command,copy,view.Texture,metadata,texels);
            for(int mip=0;mip<layout.MipCount;mip++)
            {
                layout.TryGetMip(mip,out _,out int width,out int height);
                command.SetComputeIntParam(shader,MipId,mip);
                command.DispatchCompute(shader,copy,(width+7)/8,(height+7)/8,1);RecordedDispatches++;
            }
            Bind(command,finish,view.Texture,metadata,texels);
            command.DispatchCompute(shader,finish,1,1,1);RecordedDispatches++;
            RecordedTextures++;
        }

        private void Bind(CommandBuffer command,int kernel,Texture source,GraphicsBuffer metadata,GraphicsBuffer texels)
        {
            command.SetComputeTextureParam(shader,kernel,SourceId,source);
            command.SetComputeBufferParam(shader,kernel,MetadataId,metadata);
            command.SetComputeBufferParam(shader,kernel,TexelsId,texels);
        }
    }
}
