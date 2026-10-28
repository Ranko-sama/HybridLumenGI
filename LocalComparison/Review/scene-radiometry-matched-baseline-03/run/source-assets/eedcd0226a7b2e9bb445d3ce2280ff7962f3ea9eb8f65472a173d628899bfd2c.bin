using System;

namespace HybridLumenGI
{
    /// <summary>
    /// Per-camera, allocation-free feedback for three scheduling quotas. Input milliseconds
    /// must be a valid GPU measurement of the agreed GI scopes, never CPU elapsed time or a
    /// work-count estimate. The caller validates measurement provenance and generation.
    /// This heuristic cannot enforce a total-frame GPU deadline or reclaim submitted work.
    /// </summary>
    public sealed class HybridLumenGIGpuBudgetController
    {
        public const double DefaultMinWorkFraction = 0.125;
        public const int MissingMeasurementFrames = 16;
        public const int MinimumValidSamples = 8;
        public const int AdjustmentIntervalFrames = 16;
        // The current timing wrapper observes eight stable frames with three-frame delay.
        // This is settling time, not proof of a particular GPU query's submission identity.
        public const int MeasurementSettlingFrames = 11;
        public const int MinimumOverBudgetSamples = 3;
        public const double SmoothingWeight = 0.2;
        public const double DeadbandFraction = 0.1;
        public const double MaximumDecreaseFraction = 0.25;
        public const double MaximumIncreaseFraction = 0.1;

        public readonly struct Configuration : IEquatable<Configuration>
        {
            public readonly bool Enabled;
            public readonly double TargetMs;
            public readonly double MinWorkFraction;
            public readonly int MaxCachePatches;
            public readonly int MaxSurfaceCaptures;
            public readonly int MaxGlobalBricks;

            public Configuration(bool enabled, double targetMs, double minWorkFraction,
                int maxCachePatches, int maxSurfaceCaptures, int maxGlobalBricks)
            {
                Enabled = enabled;
                TargetMs = Finite(targetMs) && targetMs > 0.0 ? targetMs : 0.0;
                MinWorkFraction = Finite(minWorkFraction)
                    ? Clamp(minWorkFraction, 0.01, 1.0) : DefaultMinWorkFraction;
                MaxCachePatches = Math.Max(0, maxCachePatches);
                MaxSurfaceCaptures = Math.Max(0, maxSurfaceCaptures);
                MaxGlobalBricks = Math.Max(0, maxGlobalBricks);
            }

            public bool Equals(Configuration other)
            {
                return Enabled == other.Enabled && TargetMs == other.TargetMs &&
                    MinWorkFraction == other.MinWorkFraction && MaxCachePatches == other.MaxCachePatches &&
                    MaxSurfaceCaptures == other.MaxSurfaceCaptures && MaxGlobalBricks == other.MaxGlobalBricks;
            }

            public override bool Equals(object other) { return other is Configuration value && Equals(value); }
            public override int GetHashCode()
            {
                unchecked
                {
                    int hash = Enabled ? 1 : 0;
                    hash = hash * 397 ^ TargetMs.GetHashCode();
                    hash = hash * 397 ^ MinWorkFraction.GetHashCode();
                    hash = hash * 397 ^ MaxCachePatches;
                    hash = hash * 397 ^ MaxSurfaceCaptures;
                    return hash * 397 ^ MaxGlobalBricks;
                }
            }
        }

        public readonly struct Budget
        {
            public readonly int CachePatches;
            public readonly int SurfaceCaptures;
            public readonly int GlobalBricks;
            public readonly double Scale;

            internal Budget(int cachePatches, int surfaceCaptures, int globalBricks, double scale)
            {
                CachePatches = cachePatches;
                SurfaceCaptures = surfaceCaptures;
                GlobalBricks = globalBricks;
                Scale = scale;
            }
        }

        public bool FeedbackActive { get; private set; }
        /// <summary>Zero when no accepted GPU measurement remains in the current feedback epoch.</summary>
        public double SmoothedMs { get; private set; }
        public bool AtMinimumWork { get; private set; }
        /// <summary>
        /// At minimum quotas, three consecutive usable observations keep the smoothed
        /// GPU time above the upper deadband. After a scale adjustment, wait eleven
        /// frames before counting; unchanged static quotas need no additional settling.
        /// This is observed pressure, not a claim that the target is unreachable.
        /// </summary>
        public bool MinimumWorkOverBudget { get; private set; }
        /// <summary>Lifetime counters survive Reset. Missing and duplicate-frame calls are not samples.</summary>
        public ulong AcceptedSamples { get; private set; }
        public ulong RejectedSamples { get; private set; }
        public Budget CurrentBudget { get { return budget; } }

        private Configuration configuration;
        private Budget budget;
        private bool initialized;
        private ulong generation;
        private int lastFrame;
        private int epochFrame;
        private int lastValidFrame;
        private int lastAcceptedSourceFrame = -1;
        private int validSamples;
        private bool adjusted;
        private int lastAdjustmentFrame;
        private int minimumOverSamples;

        /// <summary>
        /// Invalidates feedback immediately, preserving diagnostic lifetime counters. The
        /// next Step returns static quotas and rejects its measurement, even in the same
        /// engine frame as the preceding Step. Already submitted GPU work is unaffected.
        /// </summary>
        public void Reset()
        {
            initialized = false;
            ClearFeedback();
            SetBudget(1.0);
        }

        /// <summary>
        /// Call once per engine frame with the current camera/configuration generation.
        /// validMeasurement means the timing wrapper has verified matching generation,
        /// scope count and its delayed aggregation window. If the backend returns an exact
        /// submission frame, supply measurementSourceFrame to reject stale/repeated quota
        /// measurements. Leave it at -1 for Recorder: never substitute an estimated f-3.
        /// Epoch boundaries discard the supplied measurement.
        /// Repeated frame numbers have no effect; backwards/negative frames are rejected.
        /// Missing measurements retain quotas briefly, then restore static quotas exactly.
        /// </summary>
        public Budget Step(int engineFrame, ulong currentGeneration, bool validMeasurement,
            double gpuMs, Configuration currentConfiguration, int measurementSourceFrame = -1)
        {
            if (engineFrame < 0 || (initialized && engineFrame < lastFrame))
            {
                if (validMeasurement) Reject();
                return budget;
            }

            // Config/lifecycle invalidation takes precedence over the duplicate-frame guard.
            // This is a reset to static work, not a second feedback adjustment in that frame.
            if (!initialized || generation != currentGeneration || !configuration.Equals(currentConfiguration))
            {
                configuration = currentConfiguration;
                generation = currentGeneration;
                initialized = true;
                lastFrame = engineFrame;
                epochFrame = engineFrame;
                ClearFeedback();
                SetBudget(1.0);
                if (validMeasurement) Reject();
                return budget;
            }
            if (engineFrame == lastFrame) return budget;
            lastFrame = engineFrame;

            if (!CanControl())
            {
                ClearFeedback();
                SetBudget(1.0);
                if (validMeasurement) Reject();
                return budget;
            }

            int sampleReference = validSamples > 0 ? lastValidFrame : epochFrame;
            if ((long)engineFrame - sampleReference >= MissingMeasurementFrames)
            {
                ClearFeedback();
                SetBudget(1.0);
                epochFrame = engineFrame;
            }

            bool invalidSource = measurementSourceFrame < -1 ||
                (measurementSourceFrame >= 0 &&
                 (measurementSourceFrame > engineFrame || measurementSourceFrame < epochFrame ||
                  (adjusted && measurementSourceFrame < lastAdjustmentFrame) ||
                  measurementSourceFrame <= lastAcceptedSourceFrame));
            if (!validMeasurement || !Finite(gpuMs) || gpuMs <= 0.0 || invalidSource)
            {
                minimumOverSamples = 0;
                MinimumWorkOverBudget = false;
                if (validMeasurement) Reject();
                return budget;
            }

            bool contiguous = validSamples > 0 && (long)engineFrame - lastValidFrame == 1;
            if (!contiguous) minimumOverSamples = 0;
            SmoothedMs = validSamples == 0 ? gpuMs :
                (1.0 - SmoothingWeight) * SmoothedMs + SmoothingWeight * gpuMs;
            lastValidFrame = engineFrame;
            if (measurementSourceFrame >= 0) lastAcceptedSourceFrame = measurementSourceFrame;
            if (validSamples < int.MaxValue) validSamples++;
            if (AcceptedSamples < ulong.MaxValue) AcceptedSamples++;
            FeedbackActive = true;

            double ratio = SmoothedMs / configuration.TargetMs;
            bool aboveBand = ratio > 1.0 + DeadbandFraction;
            bool belowBand = ratio < 1.0 - DeadbandFraction;
            bool canAdjust = validSamples >= MinimumValidSamples &&
                (!adjusted || (long)engineFrame - lastAdjustmentFrame >= AdjustmentIntervalFrames);
            // Once all integer quotas equal their floors, reducing an otherwise larger
            // continuous scale cannot save work. Keep settled pressure evidence intact.
            if (canAdjust && ((aboveBand && !AtMinimumWork) || belowBand))
            {
                double desired = budget.Scale / ratio;
                double next = aboveBand
                    ? Math.Max(budget.Scale * (1.0 - MaximumDecreaseFraction), desired)
                    : Math.Min(budget.Scale * (1.0 + MaximumIncreaseFraction), desired);
                next = Clamp(next, configuration.MinWorkFraction, 1.0);
                if (next != budget.Scale)
                {
                    SetBudget(next);
                    adjusted = true;
                    lastAdjustmentFrame = engineFrame;
                    minimumOverSamples = 0;
                }
            }

            bool settled = !adjusted ||
                (long)engineFrame - lastAdjustmentFrame >= MeasurementSettlingFrames;
            if (AtMinimumWork && aboveBand && settled)
            {
                if (minimumOverSamples < MinimumOverBudgetSamples) minimumOverSamples++;
            }
            else minimumOverSamples = 0;
            MinimumWorkOverBudget = minimumOverSamples >= MinimumOverBudgetSamples;
            return budget;
        }

        private bool CanControl()
        {
            return configuration.Enabled && configuration.TargetMs > 0.0 &&
                (configuration.MaxCachePatches > 0 || configuration.MaxSurfaceCaptures > 0 ||
                 configuration.MaxGlobalBricks > 0);
        }

        private void ClearFeedback()
        {
            FeedbackActive = false;
            SmoothedMs = 0.0;
            validSamples = 0;
            lastAcceptedSourceFrame = -1;
            adjusted = false;
            minimumOverSamples = 0;
            MinimumWorkOverBudget = false;
        }

        private void SetBudget(double scale)
        {
            budget = new Budget(Quota(configuration.MaxCachePatches, scale),
                Quota(configuration.MaxSurfaceCaptures, scale), Quota(configuration.MaxGlobalBricks, scale), scale);
            AtMinimumWork = (configuration.MaxCachePatches > 0 || configuration.MaxSurfaceCaptures > 0 ||
                configuration.MaxGlobalBricks > 0) &&
                budget.CachePatches == Quota(configuration.MaxCachePatches, configuration.MinWorkFraction) &&
                budget.SurfaceCaptures == Quota(configuration.MaxSurfaceCaptures, configuration.MinWorkFraction) &&
                budget.GlobalBricks == Quota(configuration.MaxGlobalBricks, configuration.MinWorkFraction);
        }

        private static int Quota(int limit, double scale)
        {
            if (limit <= 0) return 0;
            // Double multiplication avoids overflow even for int.MaxValue caps; ceil
            // preserves the configured positive floor instead of rounding small quotas to zero.
            return (int)Math.Max(1.0, Math.Min(limit, Math.Ceiling(limit * scale)));
        }

        private void Reject() { if (RejectedSamples < ulong.MaxValue) RejectedSamples++; }
        private static bool Finite(double value) { return !double.IsNaN(value) && !double.IsInfinity(value); }
        private static double Clamp(double value, double min, double max) { return Math.Max(min, Math.Min(max, value)); }
    }
}
