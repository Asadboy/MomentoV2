// Renders 10shots brand title-card PNGs at the iPhone App Store
// screenshot sizes. Run:
//
//   swift "Docs/launch/App Store Screenshots/generate.swift"
//
// Output lands next to this script. Two variants per size:
//   title-<size>.png             — roll mark only, centred
//   title-tagline-<size>.png     — roll mark + "Your shared disposable camera"
//
// Roll-mark spec mirrors Momento/Components/BrandWordmark.swift exactly:
// bold sans "10Shots" + a row of 10 white dots. Sized proportionally so
// the lockup keeps its visual weight at any output dimension.

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

func renderTitleCard(width: Int, height: Int, outPath: String, tagline: String? = nil) {
    let w = CGFloat(width)
    let h = CGFloat(height)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return }

    // Solid black background — RGB, no alpha (matches the app icon spec
    // and what App Store Connect prefers for screenshots).
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    // Sizing locked to width so the mark scales with the canvas.
    let textSize: CGFloat = w * 0.21
    let tracking = -textSize * 0.04
    let dotSize = textSize * 0.17
    let dotGap = textSize * 0.14
    let rowSpacing = textSize * 0.28
    let taglineSize = textSize * 0.20
    let taglineGap = textSize * 0.55

    // Text setup
    let font = NSFont.systemFont(ofSize: textSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .kern: tracking,
    ]
    let attrText = NSAttributedString(string: "10Shots", attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrText)
    let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    let rowWidth = dotSize * 10 + dotGap * 9
    let blockHeight = textBounds.height + rowSpacing + dotSize

    // Centre the whole lockup vertically; CG bitmap origin is bottom-left.
    let blockBottom = (h - blockHeight) / 2

    // Dots sit at the bottom of the block.
    let rowCenterY = blockBottom + dotSize / 2
    let rowX = (w - rowWidth) / 2

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    for i in 0..<10 {
        let x = rowX + CGFloat(i) * (dotSize + dotGap)
        ctx.fillEllipse(in: CGRect(
            x: x, y: rowCenterY - dotSize / 2,
            width: dotSize, height: dotSize
        ))
    }

    // Text sits above the dot row.
    let textBottom = blockBottom + dotSize + rowSpacing
    let descent = CTFontGetDescent(font as CTFont)
    let baselineY = textBottom + descent
    let textX = (w - textBounds.width) / 2 - textBounds.minX

    ctx.textPosition = CGPoint(x: textX, y: baselineY)
    CTLineDraw(line, ctx)

    // Optional tagline below the lockup.
    if let tagline = tagline {
        let tFont = NSFont.systemFont(ofSize: taglineSize, weight: .regular)
        let tAttrs: [NSAttributedString.Key: Any] = [
            .font: tFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.35),
        ]
        let tAttr = NSAttributedString(string: tagline, attributes: tAttrs)
        let tLine = CTLineCreateWithAttributedString(tAttr)
        let tBounds = CTLineGetBoundsWithOptions(tLine, .useOpticalBounds)
        let tDescent = CTFontGetDescent(tFont as CTFont)
        let tX = (w - tBounds.width) / 2 - tBounds.minX
        let tBaseline = blockBottom - taglineGap + tDescent
        ctx.textPosition = CGPoint(x: tX, y: tBaseline)
        CTLineDraw(tLine, ctx)
    }

    guard let image = ctx.makeImage() else { return }
    let url = URL(fileURLWithPath: outPath) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(
        url, UTType.png.identifier as CFString, 1, nil
    ) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(outPath)")
}

// iPhone App Store screenshot sizes (portrait, current as of 2026):
// 6.9-inch (16/17 Pro Max class) — required if 6.7-inch isn't submitted
// 6.7-inch (15/16 Plus, 14/15/16 Pro Max) — required if 6.9-inch isn't
let here = (#filePath as NSString).deletingLastPathComponent
let sizes: [(String, Int, Int)] = [
    ("6.9-inch", 1320, 2868),
    ("6.7-inch", 1290, 2796),
]

for (label, w, h) in sizes {
    renderTitleCard(
        width: w, height: h,
        outPath: "\(here)/title-\(label).png"
    )
    renderTitleCard(
        width: w, height: h,
        outPath: "\(here)/title-tagline-\(label).png",
        tagline: "Your shared disposable camera"
    )
}
