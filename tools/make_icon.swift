// Draws the app icon (design C: silver grid, clay star, clay circular arrow)
// and saves it as the PNG sizes macOS needs, into the folder given as argument.
// build.sh then turns that folder into AppIcon.icns with Apple's `iconutil`.
//
// This runs only at build time. The finished app never runs it.
// Numbers are the same as the approved design (a 1024 x 1024 grid, y going down).

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let clay = rgb(0xd97757)
let center = CGPoint(x: 512, y: 512)

// Star rays: end points of the original drawing, around the centre.
let rays: [CGPoint] = [(717, 512), (655, 419), (613, 322), (496, 333), (392, 340), (366, 435),
                       (313, 529), (365, 615), (414, 704), (518, 682), (630, 680), (677, 596)]
    .map { CGPoint(x: $0.0, y: $0.1) }

/// Draws the icon at `pixels` x `pixels`. `points` is the size macOS shows it at:
/// at 16 and 32 points the lines get a little thicker so they stay visible.
func drawIcon(pixels: Int, points: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip so y goes down like the design, then use the 1024 grid.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: -CGFloat(pixels) / 1024)
    let boost: CGFloat = points <= 16 ? 1.8 : (points <= 32 ? 1.4 : 1.0)

    let square = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: square, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Soft shadow under the rounded square.
    ctx.addPath(CGPath(roundedRect: square.offsetBy(dx: 0, dy: 14), cornerWidth: 185,
                       cornerHeight: 185, transform: nil))
    ctx.setFillColor(rgb(0x000000, 0.20))
    ctx.fillPath()

    // Silver background, light at the top, darker at the bottom.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [rgb(0xfbfbfc), rgb(0xcfd2d8)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924),
                           options: [])
    // Fine grid, squares of 109. Left out at the small sizes, where it would only be noise.
    if points > 32 {
        ctx.setStrokeColor(rgb(0x000000, 0.07))
        ctx.setLineWidth(3)
        var v: CGFloat = 100
        while v <= 924 {
            ctx.move(to: CGPoint(x: v, y: 100)); ctx.addLine(to: CGPoint(x: v, y: 924))
            ctx.move(to: CGPoint(x: 100, y: v)); ctx.addLine(to: CGPoint(x: 924, y: v))
            v += 109
        }
        ctx.strokePath()
    }
    ctx.restoreGState()

    // Thin edge.
    ctx.addPath(CGPath(roundedRect: square.insetBy(dx: 2, dy: 2), cornerWidth: 183,
                       cornerHeight: 183, transform: nil))
    ctx.setStrokeColor(rgb(0x000000, 0.10))
    ctx.setLineWidth(4)
    ctx.strokePath()

    ctx.setStrokeColor(clay)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Star: 60% of the original, then 130% with the arrow = 78% around the centre.
    let starScale: CGFloat = 0.6 * 1.3
    ctx.setLineWidth(46 * starScale * boost)
    for end in rays {
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: 512 + (end.x - 512) * starScale, y: 512 + (end.y - 512) * starScale))
    }
    ctx.strokePath()

    // Circular arrow: radius 215 x 1.3, turned 180°. Open at the bottom-left,
    // the arrowhead at the bottom pointing left.
    let radius: CGFloat = 215 * 1.3
    ctx.setLineWidth(28 * 1.3 * boost)
    let steps = 120
    for i in 0...steps {
        let degrees = 90 - 290 * Double(i) / Double(steps)       // from the bottom, around, to 160°
        let a = degrees * .pi / 180
        let p = CGPoint(x: 512 + radius * CGFloat(cos(a)), y: 512 + radius * CGFloat(sin(a)))
        if i == 0 { ctx.move(to: p) } else { ctx.addLine(to: p) }
    }
    ctx.strokePath()
    ctx.move(to: CGPoint(x: 580.9, y: 842.2))
    ctx.addLine(to: CGPoint(x: 505.5, y: 791.5))
    ctx.addLine(to: CGPoint(x: 561.4, y: 720.0))
    ctx.strokePath()

    return ctx.makeImage()!
}

func save(_ image: CGImage, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

for points in [16, 32, 128, 256, 512] {
    save(drawIcon(pixels: points, points: points), "icon_\(points)x\(points).png")
    save(drawIcon(pixels: points * 2, points: points), "icon_\(points)x\(points)@2x.png")
}
