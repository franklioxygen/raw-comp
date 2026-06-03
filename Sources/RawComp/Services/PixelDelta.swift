import CoreGraphics
import Foundation

enum PixelDelta {
    /// Euclidean distance in CIELAB — approximates ΔE76. Not the full ΔE2000 formula.
    static func deltaE(readoutA: PixelReadout, readoutB: PixelReadout) -> Double {
        let labA = rgbToLab(r: Double(readoutA.red), g: Double(readoutA.green), b: Double(readoutA.blue))
        let labB = rgbToLab(r: Double(readoutB.red), g: Double(readoutB.green), b: Double(readoutB.blue))
        let deltaL = labA.l - labB.l
        let deltaA = labA.a - labB.a
        let deltaB = labA.b - labB.b
        return (deltaL * deltaL + deltaA * deltaA + deltaB * deltaB).squareRoot()
    }

    private struct Lab {
        let l: Double
        let a: Double
        let b: Double
    }

    private static func rgbToLab(r: Double, g: Double, b: Double) -> Lab {
        let sr = sRGBToLinear(r / 255)
        let sg = sRGBToLinear(g / 255)
        let sb = sRGBToLinear(b / 255)

        let x = (sr * 0.4124 + sg * 0.3576 + sb * 0.1805) / 0.95047
        let y = (sr * 0.2126 + sg * 0.7152 + sb * 0.0722) / 1.00000
        let z = (sr * 0.0193 + sg * 0.1192 + sb * 0.9505) / 1.08883

        let fx = labF(x)
        let fy = labF(y)
        let fz = labF(z)

        return Lab(
            l: 116 * fy - 16,
            a: 500 * (fx - fy),
            b: 200 * (fy - fz)
        )
    }

    private static func sRGBToLinear(_ value: Double) -> Double {
        if value <= 0.04045 {
            return value / 12.92
        }
        return pow((value + 0.055) / 1.055, 2.4)
    }

    private static func labF(_ value: Double) -> Double {
        if value > 0.008856 {
            return pow(value, 1.0 / 3.0)
        }
        return (7.787 * value) + (16.0 / 116.0)
    }
}
