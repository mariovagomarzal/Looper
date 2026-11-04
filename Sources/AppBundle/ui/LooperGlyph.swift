import SwiftUI

/// Looper's one-color glyph (resources/brand/glyph.svg): the ring of the wheel with its top sector selected and, in the
/// center, the three window buttons of macOS, or a pause sign
struct LooperGlyph: View {
    var isPaused: Bool = false

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            // The glyph is drawn on a 640 unit square
            let unit = side / 640
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let ring = Path { $0.addArc(center: center, radius: 250 * unit, startAngle: .zero, endAngle: .degrees(360), clockwise: false) }
            let stroke = StrokeStyle(lineWidth: 90 * unit)
            context.opacity = 0.35
            context.stroke(ring, with: .foreground, style: stroke)
            context.opacity = 1
            let sector = Path { $0.addArc(center: center, radius: 250 * unit, startAngle: .degrees(-112.5), endAngle: .degrees(-67.5), clockwise: false) }
            context.stroke(sector, with: .foreground, style: stroke)
            if isPaused {
                for dx in [-47.5, 47.5] {
                    let bar = CGRect(x: center.x + (dx - 22.5) * unit, y: center.y - 90 * unit, width: 45 * unit, height: 180 * unit)
                    context.fill(Path(roundedRect: bar, cornerRadius: 20 * unit), with: .foreground)
                }
            } else {
                for dx in [-118.0, 0, 118] {
                    let dot = CGRect(x: center.x + (dx - 46) * unit, y: center.y - 46 * unit, width: 92 * unit, height: 92 * unit)
                    context.fill(Path(ellipseIn: dot), with: .foreground)
                }
            }
        }
    }
}
