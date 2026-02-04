import UIKit

/// Renders a "momento" text watermark onto photos at download time.
/// Watermark is only applied to free event downloads — premium events get clean photos.
enum WatermarkRenderer {

    // MARK: - Configuration

    /// Change this to .white for white watermark, or use any custom colour
    static let watermarkColor = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.7) // Dispo-style orange, 70% opacity
    static let shadowColor = UIColor.black.withAlphaComponent(0.5)

    // MARK: - Public

    /// Applies the "momento" watermark to the bottom-right corner of the image.
    /// Returns a new image with the watermark composited. Original is not modified.
    static func apply(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            // Draw the original photo
            image.draw(at: .zero)

            // Calculate font size — ~4.5% of image width
            let fontSize = image.size.width * 0.045
            let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)

            let text = "momento"

            // Shadow attributes — drawn first, offset slightly down-right
            let shadowOffset = fontSize * 0.06
            let shadowAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: shadowColor
            ]

            // Main text attributes
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: watermarkColor
            ]

            let textSize = (text as NSString).size(withAttributes: textAttributes)

            // Position: bottom-right with padding
            let padding = image.size.width * 0.03
            let x = image.size.width - textSize.width - padding
            let y = image.size.height - textSize.height - padding

            let textRect = CGRect(x: x, y: y, width: textSize.width, height: textSize.height)
            let shadowRect = textRect.offsetBy(dx: shadowOffset, dy: shadowOffset)

            // Draw shadow first, then text on top
            (text as NSString).draw(in: shadowRect, withAttributes: shadowAttributes)
            (text as NSString).draw(in: textRect, withAttributes: textAttributes)
        }
    }
}
