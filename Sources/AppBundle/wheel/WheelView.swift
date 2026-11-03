// The wheel's design and interaction are modeled on the radial menu of Loop (https://github.com/MrKai77/Loop) by
// Kai Azim. This implementation is written from scratch and shares no code with Loop.

import SwiftUI

enum WheelMetrics {
    static let diameter: CGFloat = 100
    /// Room around the wheel for the shadow and the appearance scale effect
    static let margin: CGFloat = 40
    static var panelSize: CGFloat { diameter + 2 * margin }
    /// Pointer offsets shorter than this select nothing
    static let deadZoneRadius: CGFloat = 10
    /// Scale of the wheel while the center is selected
    static let centerScale: CGFloat = 0.85
}

/// One of the eight directions the wheel can point to
enum WheelDirection: Int, CaseIterable, Sendable, CustomStringConvertible {
    case east, northEast, north, northWest, west, southWest, south, southEast

    /// Counterclockwise from east, like in math
    var degrees: Double { Double(rawValue) * 45 }

    /// `dx` grows to the right and `dy` grows upwards (AppKit screen coordinates)
    init(dx: CGFloat, dy: CGFloat) {
        let degrees = atan2(dy, dx) * 180 / .pi
        let index = Int((degrees / 45).rounded()) % 8
        self = WheelDirection(rawValue: (index + 8) % 8) ?? .east
    }

    var slot: WheelSlot {
        switch self {
            case .east: .right
            case .northEast: .upRight
            case .north: .up
            case .northWest: .upLeft
            case .west: .left
            case .southWest: .downLeft
            case .south: .down
            case .southEast: .downRight
        }
    }

    var description: String { slot.rawValue }
}

enum WheelSelection: Equatable, Sendable, CustomStringConvertible {
    case none
    /// Between the dead zone and the inner edge of the ring
    case center
    case direction(WheelDirection)

    /// `offset` is the pointer offset from where the wheel opened, in AppKit screen coordinates
    init(offset: CGVector, thickness: CGFloat) {
        let distance = hypot(offset.dx, offset.dy)
        self = if distance < WheelMetrics.deadZoneRadius {
            .none
        } else if distance < WheelMetrics.diameter / 2 - thickness {
            .center
        } else {
            .direction(WheelDirection(dx: offset.dx, dy: offset.dy))
        }
    }

    var direction: WheelDirection? {
        if case .direction(let direction) = self { direction } else { nil }
    }

    var slot: WheelSlot? {
        switch self {
            case .none: nil
            case .center: .center
            case .direction(let direction): direction.slot
        }
    }

    var description: String {
        switch self {
            case .none: "none"
            case .center: "center"
            case .direction(let direction): direction.description
        }
    }
}

struct WheelStyle: Equatable {
    /// 0 is a square, 1 is a circle
    var cornerFraction: CGFloat
    var thickness: CGFloat
    var colors: WheelColors

    @MainActor init(_ config: WheelStyleConfig, colors: WheelColors) {
        cornerFraction = CGFloat(config.cornerRadius) / 100
        thickness = CGFloat(config.thickness)
        self.colors = colors
    }
}

@MainActor @Observable
final class WheelModel {
    var isShown = false
    var isShadowShown = false
    var style = WheelStyle(WheelStyleConfig(), colors: .system)
    private(set) var selection: WheelSelection = .none
    /// Angle of the selector in SwiftUI degrees (clockwise from east). It accumulates turns, so that animations always
    /// take the short way around
    private(set) var selectorAngle: Double = 0

    /// Returns true if the selection changed
    func select(_ newSelection: WheelSelection) -> Bool {
        guard newSelection != selection else { return false }
        let oldSelection = selection
        if let direction = newSelection.direction {
            let target = -direction.degrees
            var delta = (target - selectorAngle).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            if oldSelection.direction != nil {
                // Between directions the selector stays visible and slides along the ring: fast start, soft landing
                withAnimation(.spring(response: 0.16, dampingFraction: 0.86)) { selectorAngle += delta }
            } else {
                // Coming from the middle, the selector appears right at the new angle instead of spinning
                selectorAngle += delta
            }
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { selection = newSelection }
        return true
    }

    func reset() {
        selection = .none
    }
}

struct WheelView: View {
    let model: WheelModel

    var body: some View {
        ZStack {
            if model.isShown {
                wheel
                    .transition(.scale(scale: 1.2).combined(with: unsafe .opacity))
            }
        }
        .frame(width: WheelMetrics.diameter, height: WheelMetrics.diameter)
        .shadow(color: .black.opacity(model.isShadowShown ? 0.22 : 0), radius: 12, y: 2)
        .scaleEffect(model.selection == .center ? WheelMetrics.centerScale : 1)
        .frame(width: WheelMetrics.panelSize, height: WheelMetrics.panelSize)
    }

    private var wheel: some View {
        let ring = WheelRing(cornerFraction: model.style.cornerFraction, thickness: model.style.thickness)
        let gradient = LinearGradient(
            colors: [model.style.colors.start, model.style.colors.end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
        return ZStack {
            // Glass body of the ring
            Color.clear
                .glassEffect(.regular.tint(model.style.colors.start.opacity(0.04)), in: ring)

            // Selection: a sector of the ring for directions, the whole ring for the center
            ZStack {
                gradient
                    .clipShape(WheelSector(angle: model.selectorAngle, span: 45))
                    .opacity(model.selection.direction != nil ? 1 : 0)
                gradient
                    .opacity(model.selection == .center ? 1 : 0)
            }
            .clipShape(ring)

            // Hairline that separates the ring from busy backgrounds
            ring.stroke(.white.opacity(0.18), lineWidth: 0.5)
        }
    }
}

/// A ring with rounded corners: a circle at `cornerFraction` 1, a square at 0
struct WheelRing: Shape {
    var cornerFraction: CGFloat
    var thickness: CGFloat

    // Switching to a profile with another shape morphs the ring
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerFraction, thickness) }
        set {
            cornerFraction = newValue.first
            thickness = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let outerRect = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        let outerRadius = side / 2 * min(max(cornerFraction, 0), 1)
        let innerRadius = max(outerRadius - thickness, 0)
        // Continuous corners look smoother, but only circular ones make a perfect circle
        let style: RoundedCornerStyle = cornerFraction >= 1 ? .circular : .continuous
        let outer = Path(roundedRect: outerRect, cornerRadius: outerRadius, style: style)
        let inner = Path(roundedRect: outerRect.insetBy(dx: thickness, dy: thickness), cornerRadius: innerRadius, style: style)
        return outer.subtracting(inner)
    }
}

/// A pie slice centered on `angle` (SwiftUI degrees), reaching past the bounds so that it covers the whole ring
struct WheelSector: Shape {
    var angle: Double
    let span: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: max(rect.width, rect.height),
            startAngle: .degrees(angle - span / 2),
            endAngle: .degrees(angle + span / 2),
            clockwise: false,
        )
        path.closeSubpath()
        return path
    }
}
