import CoreGraphics
import Foundation

enum LightToneEstimator {
    /// Suggests exposure and gamma to center midtones for comparison viewing.
    static func estimate(from cgImage: CGImage) -> (exposureEV: Double, gamma: Double)? {
        let histogram = HistogramComputer.compute(from: cgImage)
        guard histogram.totalSamples > 0 else {
            return nil
        }

        let median = histogram.medianLuma
        let targetMedian = 128.0
        let exposureEV = clamp((targetMedian - Double(median)) / 64.0 * 0.75, lower: -2, upper: 2)

        var gamma = 1.0
        if histogram.hasHighlightClipping {
            gamma = 0.92
        } else if histogram.hasShadowClipping {
            gamma = 1.08
        }

        return (exposureEV, gamma)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

extension ImageHistogram {
    var medianLuma: Int {
        guard totalSamples > 0 else {
            return 128
        }

        let target = totalSamples / 2
        var cumulative = 0
        for (index, count) in luma.enumerated() {
            cumulative += count
            if cumulative >= target {
                return index
            }
        }

        return 128
    }
}
