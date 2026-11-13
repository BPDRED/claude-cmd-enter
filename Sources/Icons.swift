// The small drawings used in the menu bar and the menu.
// All numbers are on a 24 x 24 grid (y going down), the same as the approved
// design, and are scaled to the size asked for. Everything is drawn in code:
// no image files, so the app stays tiny.

import AppKit

enum Icons {
    enum Inner { case star, command }

    /// The circular arrow with the star (menu bar) or the ⌘ (menu row) inside.
    /// `warning` adds the small "!" error sign in the centre of the star.
    /// `bold` (menu rows) draws the arrow about twice as thick, to match the
    /// weight of the other menu icons; the menu bar keeps the fine lines.
    /// It is a template image: macOS paints it black or white to match the menu bar.
    static func glyph(_ inner: Inner, warning: Bool = false, size: CGFloat = 18,
                      bold: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: size / 24, y: size / 24)
            ctx.setFillColor(.black)
            ctx.setStrokeColor(.black)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let weight: CGFloat = bold ? 1.8 : 1.0
            drawArrow(ctx, weight: weight)
            switch inner {
            case .star: drawStar(ctx)
            case .command: drawCommand(ctx, lineWidth: 0.86 * weight)
            }
            if warning { drawWarning(ctx) }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The return arrow for the "Enter to send" row.
    static func enterArrow(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: size / 24, y: size / 24)
            ctx.setStrokeColor(.black)
            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: 19, y: 5))
            ctx.addArc(tangent1End: CGPoint(x: 19, y: 15), tangent2End: CGPoint(x: 5, y: 15), radius: 3)
            ctx.addLine(to: CGPoint(x: 5, y: 15))
            ctx.move(to: CGPoint(x: 9, y: 11))
            ctx.addLine(to: CGPoint(x: 5, y: 15))
            ctx.addLine(to: CGPoint(x: 9, y: 19))
            ctx.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// One of Apple's built-in symbols (gear, power, accessibility).
    static func symbol(_ name: String, size: CGFloat = 15) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    // MARK: - Parts of the glyph

    /// A true circle around the centre, open at the bottom-left. It starts thin
    /// (0.75) at its tail and grows to 30% thicker (0.975) at the arrowhead.
    /// `weight` multiplies all of these (1.8 in the menu rows).
    private static func drawArrow(_ ctx: CGContext, weight: CGFloat) {
        let r: CGFloat = 8.5
        let steps = 60
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a = (160 + 290 * t) * .pi / 180        // clockwise, from the tail to the head
            let w = (0.75 + 0.225 * t) * weight
            outer.append(CGPoint(x: 12 + (r + w / 2) * cos(a), y: 12 + (r + w / 2) * sin(a)))
            inner.append(CGPoint(x: 12 + (r - w / 2) * cos(a), y: 12 + (r - w / 2) * sin(a)))
        }
        ctx.addLines(between: outer + inner.reversed())
        ctx.closePath()
        ctx.fillPath()
        // Round start of the tail.
        let tail = 160 * CGFloat.pi / 180
        let cap = 0.375 * weight
        ctx.fillEllipse(in: CGRect(x: 12 + r * cos(tail) - cap, y: 12 + r * sin(tail) - cap,
                                   width: cap * 2, height: cap * 2))
        // Arrowhead at the bottom, pointing left.
        ctx.setLineWidth(0.975 * weight)
        ctx.move(to: CGPoint(x: 13.8, y: 22.4))
        ctx.addLine(to: CGPoint(x: 11.8, y: 20.5))
        ctx.addLine(to: CGPoint(x: 13.8, y: 18.6))
        ctx.strokePath()
    }

    /// The star from the app icon, 12% bigger, lines 0.86 thick.
    private static func drawStar(_ ctx: CGContext) {
        let ends: [(CGFloat, CGFloat)] = [(4.77, 0), (3.32, -2.15), (2.35, -4.41), (-0.36, -4.17),
                                          (-2.80, -4.00), (-3.39, -1.80), (-4.63, 0.41), (-3.43, 2.40),
                                          (-2.27, 4.46), (0.14, 3.95), (2.73, 3.91), (3.83, 1.95)]
        ctx.setLineWidth(0.86)
        for (dx, dy) in ends {
            ctx.move(to: CGPoint(x: 12, y: 12))
            ctx.addLine(to: CGPoint(x: 12 + dx * 1.12, y: 12 + dy * 1.12))
        }
        ctx.strokePath()
    }

    /// The ⌘ key, drawn with the same line thickness as the arrow, in the centre.
    /// Built like the real symbol: a square in the middle, with a loop (3/4 of a
    /// circle) at each corner. Drawn on a 0-24 grid, then scaled to 50%.
    private static func drawCommand(_ ctx: CGContext, lineWidth: CGFloat) {
        let s: CGFloat = 0.5
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: 12 + (x - 12) * s, y: 12 + (y - 12) * s)
        }
        // The four sides of the square, each running on into two loops.
        ctx.move(to: p(9, 6));  ctx.addLine(to: p(9, 18))
        ctx.move(to: p(15, 6)); ctx.addLine(to: p(15, 18))
        ctx.move(to: p(6, 9));  ctx.addLine(to: p(18, 9))
        ctx.move(to: p(6, 15)); ctx.addLine(to: p(18, 15))
        // The four loops: corner centre, and where the 3/4 circle starts (degrees, y down).
        let loops: [(CGFloat, CGFloat, CGFloat)] = [(6, 6, 90), (18, 6, 180), (18, 18, 270), (6, 18, 0)]
        for (cx, cy, start) in loops {
            let points = (0...36).map { i -> CGPoint in
                let a = (start + 270 * CGFloat(i) / 36) * .pi / 180
                return p(cx + 3 * cos(a), cy + 3 * sin(a))
            }
            ctx.addLines(between: points)
        }
        ctx.setLineWidth(lineWidth)
        ctx.strokePath()
    }

    /// Small error sign in the centre of the star: a filled circle with a "!"
    /// cut out of it. No gap ring around it, so the star's rays are not cut.
    private static func drawWarning(_ ctx: CGContext) {
        ctx.fillEllipse(in: CGRect(x: 12 - 3.38, y: 12 - 3.38, width: 6.76, height: 6.76))
        ctx.setBlendMode(.clear)
        ctx.setLineWidth(1.04)
        ctx.move(to: CGPoint(x: 12, y: 10.05))
        ctx.addLine(to: CGPoint(x: 12, y: 12.65))
        ctx.strokePath()
        ctx.fillEllipse(in: CGRect(x: 12 - 0.585, y: 14.145 - 0.585, width: 1.17, height: 1.17))
        ctx.setBlendMode(.normal)
    }
}
