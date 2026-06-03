import CoreGraphics
import Foundation

enum ColorBalanceEstimator {
    /// Estimates relative temperature and tint to neutralize the center region of an image.
    static func estimate(from cgImage: CGImage) -> (temperature: Double, tint: Double)? {
        let samplePoints: [CGPoint] = [
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.42, y: 0.5),
            CGPoint(x: 0.58, y: 0.5),
            CGPoint(x: 0.5, y: 0.42),
            CGPoint(x: 0.5, y: 0.58)
        ]

        var redTotal = 0
        var greenTotal = 0
        var blueTotal = 0
        var count = 0

        for point in samplePoints {
            let readout = PixelSampler.sample(
                cgImage: cgImage,
                normalizedPoint: point,
                sampleSize: .five
            )
            guard readout != .empty else {
                continue
            }

            redTotal += readout.red
            greenTotal += readout.green
            blueTotal += readout.blue
            count += 1
        }

        guard count > 0 else {
            return nil
        }

        let red = Double(redTotal) / Double(count)
        let green = Double(greenTotal) / Double(count)
        let blue = Double(blueTotal) / Double(count)
        let neutral = (red + green + blue) / 3

        let temperature = clamp((red - blue) * 0.55, lower: -100, upper: 100)
        let tint = clamp((green - neutral) * 0.7, lower: -100, upper: 100)
        return (temperature, tint)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
