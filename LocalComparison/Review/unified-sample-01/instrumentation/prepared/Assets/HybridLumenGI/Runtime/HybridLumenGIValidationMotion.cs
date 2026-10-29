using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Fixed logical-frame motion; driven only by ValidationSequence.</summary>
    [AddComponentMenu("")]
    public sealed class HybridLumenGIValidationMotion : MonoBehaviour
    {
        [SerializeField] private Vector3 localOffset = new Vector3(2.2f, 0f, 0f);
        private Vector3 origin;
        private bool hasOrigin;

        public static float TravelAtFrame(int frame)
        {
            if (frame < 120 || frame >= 240) return 0f;
            if (frame < 180) return (frame - 120) / 59f;
            if (frame < 210) return 1f;
            return 1f - (frame - 210) / 29f;
        }

        public void ApplyFrame(int frame)
        {
            if (!hasOrigin) { origin = transform.localPosition; hasOrigin = true; }
            transform.localPosition = origin + localOffset * TravelAtFrame(frame);
        }

        public void Restore()
        {
            if (hasOrigin) transform.localPosition = origin;
        }

        private void OnDisable() => Restore();
    }
}
