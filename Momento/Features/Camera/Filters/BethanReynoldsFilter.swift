//
//  BethanReynoldsFilter.swift
//  Momento
//
//  Bethan Reynolds film emulation filter
//  Warm, dreamy film aesthetic
//
//  Characteristics:
//  - Warm golden tones
//  - Rich, saturated colors
//  - Blue-tinted shadows
//  - Lifted blacks (no pure black)
//  - Fine grain texture
//  - Slight vignette
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies Bethan Reynolds film aesthetic to images
class BethanReynoldsFilter {

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Filter Parameters (tweak these!)

    /// Warmth adjustment (0 = neutral, positive = warmer)
    var warmth: Float = 0.15  // Golden/amber cast

    /// Color saturation boost (0 = no change, negative = muted)
    var saturationBoost: Float = 0.05  // Muted, not punchy - dispo style

    /// How much to lift the blacks (0 = pure black, 0.2 = very faded)
    var blackLift: Float = 0.18  // Hazy faded shadows - key to film look

    /// Contrast reduction (0 = normal, negative = softer)
    var contrastAdjust: Float = -0.15  // Dreamy, soft - not crisp digital

    /// Grain intensity (0 = none, 0.2 = visible grain)
    var grainIntensity: Float = 0.20  // Visible grain - part of the charm

    /// Vignette intensity (0 = none, 0.5 = noticeable darkening)
    var vignetteIntensity: Float = 0.5  // Slight edge darkening

    /// Vignette radius (how far from center the darkening starts)
    var vignetteRadius: Float = 1.2

    // MARK: - Apply Filter

    /// Apply filter to an image
    /// - Parameter image: Original UIImage
    /// - Returns: Filtered UIImage
    func apply(to image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            return image
        }

        var output = ciImage

        // Step 1: Color adjustments (warmth, saturation, contrast)
        output = applyColorAdjustments(to: output)

        // Step 2: Lift blacks and add blue to shadows
        output = applyToneCurve(to: output)

        // Step 3: Add film grain
        output = applyGrain(to: output, size: image.size)

        // Step 4: Add vignette
        output = applyVignette(to: output, size: image.size)

        // Render final image
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Filter Components

    private func applyColorAdjustments(to image: CIImage) -> CIImage {
        // Temperature & Tint (warmth)
        let tempAndTint = CIFilter.temperatureAndTint()
        tempAndTint.inputImage = image
        // Neutral is 6500K, higher = warmer
        tempAndTint.neutral = CIVector(x: 6500 + CGFloat(warmth * 1000), y: 0)
        tempAndTint.targetNeutral = CIVector(x: 6500, y: 0)

        guard let tempOutput = tempAndTint.outputImage else { return image }

        // Saturation & Contrast
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = tempOutput
        colorControls.saturation = 1.0 + saturationBoost
        colorControls.contrast = 1.0 + contrastAdjust
        colorControls.brightness = 0.02 // Slight brightness boost

        return colorControls.outputImage ?? tempOutput
    }

    private func applyToneCurve(to image: CIImage) -> CIImage {
        // Lift blacks and add slight S-curve
        let toneCurve = CIFilter.toneCurve()
        toneCurve.inputImage = image

        // Lift the black point (shadows don't go to pure black)
        toneCurve.point0 = CGPoint(x: 0.0, y: CGFloat(blackLift))
        toneCurve.point1 = CGPoint(x: 0.25, y: 0.22) // Slightly lifted shadows
        toneCurve.point2 = CGPoint(x: 0.5, y: 0.5)   // Midtones neutral
        toneCurve.point3 = CGPoint(x: 0.75, y: 0.77) // Slightly compressed highlights
        toneCurve.point4 = CGPoint(x: 1.0, y: 0.98)  // Soft highlight rolloff

        guard let curveOutput = toneCurve.outputImage else { return image }

        // Add blue tint to shadows
        // We'll use a color matrix to shift shadows toward blue
        let shadowTint = CIFilter.colorMatrix()
        shadowTint.inputImage = curveOutput
        // Slight blue boost in shadows
        shadowTint.rVector = CIVector(x: 1.0, y: 0, z: 0, w: 0)
        shadowTint.gVector = CIVector(x: 0, y: 1.0, z: 0, w: 0)
        shadowTint.bVector = CIVector(x: 0.02, y: 0.02, z: 1.02, w: 0) // Slight blue boost
        shadowTint.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        shadowTint.biasVector = CIVector(x: 0, y: 0, z: 0.01, w: 0) // Blue bias

        return shadowTint.outputImage ?? curveOutput
    }

    private func applyGrain(to image: CIImage, size: CGSize) -> CIImage {
        guard grainIntensity > 0 else { return image }

        // Create noise
        let noiseFilter = CIFilter.randomGenerator()
        guard let noise = noiseFilter.outputImage else { return image }

        // Scale and crop noise to image size
        let scaledNoise = noise
            .transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
            .cropped(to: image.extent)

        // Convert to grayscale and reduce intensity
        let grayscale = CIFilter.colorMatrix()
        grayscale.inputImage = scaledNoise
        grayscale.rVector = CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0)
        grayscale.gVector = CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0)
        grayscale.bVector = CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0)
        grayscale.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(grainIntensity))

        guard let grainTexture = grayscale.outputImage else { return image }

        // Blend grain with image
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = grainTexture
        blend.backgroundImage = image

        return blend.outputImage ?? image
    }

    private func applyVignette(to image: CIImage, size: CGSize) -> CIImage {
        guard vignetteIntensity > 0 else { return image }

        let vignette = CIFilter.vignette()
        vignette.inputImage = image
        vignette.intensity = vignetteIntensity
        vignette.radius = vignetteRadius

        return vignette.outputImage ?? image
    }
}

// MARK: - Preview Helper

#if DEBUG
extension BethanReynoldsFilter {
    /// Quick test of the filter
    static func testFilter() {
        let filter = BethanReynoldsFilter()
        print("Bethan Reynolds Filter initialized")
        print("   Warmth: \(filter.warmth)")
        print("   Saturation: \(filter.saturationBoost)")
        print("   Black Lift: \(filter.blackLift)")
        print("   Grain: \(filter.grainIntensity)")
        print("   Vignette: \(filter.vignetteIntensity)")
    }
}
#endif
