using UnityEngine; namespace HybridLumenGI { public class HybridLumenGILights {
        public struct Data : IEquatable<Data>
        {
            public Vector4 positionType, directionRange, color, spot;
            public uint cullingMask, renderingLayers, shadowRenderingLayers, flags;
            public bool Equals(Data other) => positionType.Equals(other.positionType) &&
                directionRange.Equals(other.directionRange) && color.Equals(other.color) && spot.Equals(other.spot) &&
                cullingMask == other.cullingMask && renderingLayers == other.renderingLayers &&
                shadowRenderingLayers == other.shadowRenderingLayers && flags == other.flags;
            public override bool Equals(object other) => other is Data value && Equals(value);
            public override int GetHashCode()
            {
                unchecked
                {
                    int h = positionType.GetHashCode(); h = h * 31 + directionRange.GetHashCode();
                    h = h * 31 + color.GetHashCode(); h = h * 31 + spot.GetHashCode();
                    h = h * 31 + (int)cullingMask; h = h * 31 + (int)renderingLayers;
                    h = h * 31 + (int)shadowRenderingLayers; return h * 31 + (int)flags;
                }
            }
        }
}}