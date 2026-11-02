using System;

namespace HybridLumenGI
{
    /// <summary>
    /// Exact logical allocation budget for per-camera capture/history textures and identity
    /// candidate/object buffers. Excludes drivers, RTAS, world caches and private CPU snapshots.
    /// Identity is optional: its inability to fit never suppresses an affordable baseline GI.
    /// </summary>
    public static class HybridLumenGIScreenBudget
    {
        public readonly struct Result
        {
            public readonly bool Fits, IdentityEnabled, IdentityBudgetFallback;
            public readonly int Width, Height, FullPixelBytes, LowPixelBytes, IdentityRowCapacity;
            public readonly long IdentityBufferBytes, EstimatedBytes;
            internal Result(bool fits, bool identity, bool fallback, int width, int height,
                int fullBytes, int lowBytes, int rows, long identityBuffers, long total)
            {
                Fits = fits; IdentityEnabled = identity; IdentityBudgetFallback = fallback;
                Width = width; Height = height; FullPixelBytes = fullBytes; LowPixelBytes = lowBytes;
                IdentityRowCapacity = rows; IdentityBufferBytes = identityBuffers; EstimatedBytes = total;
            }
        }

        /// <summary>Plans for the maximum supported filter count when the caller does not supply it.</summary>
        public static Result Plan(int fullWidth, int fullHeight, float resolutionScale, long budgetBytes,
            bool replaceNative, bool identityRequested, int receiverCapacity)
            => Plan(fullWidth, fullHeight, resolutionScale, budgetBytes, replaceNative, identityRequested, receiverCapacity, 4);

        /// <summary>
        /// The longest GI dimension is an integer no larger than the requested scale (clamped
        /// to 1/4..1). The other dimension follows that ratio, rounded down, with the same
        /// minimum dimensions max(1,floor(full/8)) as the 1/8 quality floor. Binary search
        /// selects the largest affordable longest dimension; all byte comparisons use long.
        /// Screen coordinate helpers support dimensions up to 16384. A zero-row identity
        /// snapshot still needs one 80-byte dummy object row; capacity reserves up to 16384.
        /// </summary>
        public static Result Plan(int fullWidth, int fullHeight, float resolutionScale, long budgetBytes,
            bool replaceNative, bool identityRequested, int receiverCapacity, int filterIterations)
            => Plan(fullWidth, fullHeight, resolutionScale, budgetBytes, replaceNative, identityRequested, receiverCapacity, filterIterations, false);

        internal static Result Plan(int fullWidth, int fullHeight, float resolutionScale, long budgetBytes,
            bool replaceNative, bool identityRequested, int receiverCapacity, int filterIterations, bool staticShadowmask)
        {
            if (fullWidth < 1 || fullHeight < 1 || fullWidth > 16384 || fullHeight > 16384 ||
                budgetBytes < 0 || float.IsNaN(resolutionScale) || float.IsInfinity(resolutionScale)) return default;
            double scale = Math.Max(.25, Math.Min(1, (double)resolutionScale));
            filterIterations = Math.Max(0, Math.Min(4, filterIterations));
            int workingBytes = filterIterations >= 2 ? 16 : 8;
            if (identityRequested)
            {
                Result identity = Fit(fullWidth, fullHeight, scale, budgetBytes, replaceNative, true, false, receiverCapacity, workingBytes, staticShadowmask);
                if (identity.Fits) return identity;
            }
            return Fit(fullWidth, fullHeight, scale, budgetBytes, replaceNative, false, identityRequested, 0, workingBytes, staticShadowmask);
        }

        private static Result Fit(int fullWidth, int fullHeight, double scale, long budgetBytes,
            bool replaceNative, bool identity, bool fallback, int receiverCapacity, int workingBytes, bool staticShadowmask)
        {
            long fullPixels = (long)fullWidth * fullHeight;
            // With baked visibility the uint2 receiver policy becomes uint4. Layer masks remain full width.
            int fullBytes = (replaceNative ? 36 : 24) + (identity ? 4 : 0) + (staticShadowmask ? 8 : 0);
            // History pairs: radiance (16), geometry (32), material (8), moments (32).
            // Spatial filtering reuses raw. A second half-float target is needed from pass two.
            int lowBytes = 88 + workingBytes + (identity ? 32 : 0);
            int rows = identity ? Math.Max(1, Math.Min(16384, receiverCapacity)) : 0;
            long identityBuffers = identity ? fullPixels * 12 + rows * 80L : 0;
            long fixedBytes = fullPixels * fullBytes + identityBuffers;
            int minWidth = Math.Max(1, fullWidth / 8), minHeight = Math.Max(1, fullHeight / 8);
            long minimumBytes = fixedBytes + (long)minWidth * minHeight * lowBytes;
            if (minimumBytes > budgetBytes)
                return new Result(false, identity, fallback, 0, 0, fullBytes, lowBytes, rows, identityBuffers, minimumBytes);

            int longest = Math.Max(fullWidth, fullHeight);
            int low = Math.Max(minWidth, minHeight);
            int high = Math.Max(1, (int)Math.Floor(longest * scale));
            while (low < high)
            {
                int middle = low + (high - low + 1) / 2;
                Dimensions(fullWidth, fullHeight, longest, middle, minWidth, minHeight, out int width, out int height);
                long bytes = fixedBytes + (long)width * height * lowBytes;
                if (bytes <= budgetBytes) low = middle; else high = middle - 1;
            }
            Dimensions(fullWidth, fullHeight, longest, low, minWidth, minHeight, out int w, out int h);
            return new Result(true, identity, fallback, w, h, fullBytes, lowBytes, rows, identityBuffers,
                fixedBytes + (long)w * h * lowBytes);
        }

        private static void Dimensions(int fullWidth, int fullHeight, int longest, int extent,
            int minWidth, int minHeight, out int width, out int height)
        {
            width = Math.Max(minWidth, (int)((long)fullWidth * extent / longest));
            height = Math.Max(minHeight, (int)((long)fullHeight * extent / longest));
        }
    }
}
