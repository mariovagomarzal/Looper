import AppKit
import Common
import os
import SwiftUI

/// How the user finished a wheel gesture. Every (selection, trigger) pair will be able to run a different action
enum WheelTrigger: String, Sendable {
    /// The trigger key was released
    case release
    case leftClick = "left-click"
    case rightClick = "right-click"
    case otherClick = "other-click"
}

/// Diagnostics of wheel gestures. Read them with:
/// `log show --last 5m --style compact --predicate 'subsystem == "com.mariovagomarzal.looper.debug" AND category == "wheel"'`
let wheelLog = Logger(subsystem: looperAppId, category: "wheel")

/// Shows the wheel under the mouse pointer and tracks the direction the pointer moves to.
/// For now it's opened by holding fn, and finished gestures are only logged.
@MainActor
final class WheelController {
    static let shared = WheelController()

    private let model = WheelModel()
    private lazy var panel: WheelPanel = WheelPanel(model: model)
    private var pointer = WheelPointer(origin: .zero)
    private var mouseMonitor: Any? = nil
    private var orderOutTask: Task<(), Never>? = nil

    private init() {}

    private(set) var isOpen = false

    /// Creates and lays out the panel ahead of time. Otherwise the first layout happens inside the appearance
    /// animation, and the wheel animates in from a corner the first time it opens
    func prepare() {
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    func open() {
        if isOpen { return }
        isOpen = true
        orderOutTask?.cancel()
        orderOutTask = nil

        let origin = NSEvent.mouseLocation
        pointer = WheelPointer(origin: origin)
        let colors = WheelAccentResolver.shared.colors(for: config.wheel.accentColor, at: origin) { @MainActor colors in
            let model = WheelController.shared.model
            withAnimation(.easeOut(duration: 0.2)) { model.style.colors = colors }
        }
        model.style = WheelStyle(config.wheel, colors: colors)
        model.reset()

        let size = WheelMetrics.panelSize
        panel.setFrameOrigin(CGPoint(x: origin.x - size / 2, y: origin.y - size / 2))
        panel.orderFrontRegardless()
        // Any pending layout must happen before the appearance animation starts
        panel.contentView?.layoutSubtreeIfNeeded()

        withAnimation(.smooth(duration: 0.16)) { model.isShown = true }
        // The shadow lands slightly after the wheel, which makes it feel like it settles onto the screen
        withAnimation(.smooth(duration: 0.12).delay(0.05)) { model.isShadowShown = true }

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged],
        ) { @MainActor event in
            WheelController.shared.pointerMoved(event)
        }
    }

    /// Finishes the gesture with the current selection
    func commit(_ trigger: WheelTrigger) {
        guard isOpen else { return }
        let selection = model.selection
        close()
        if selection == .none {
            wheelLog.notice("cancelled: \(trigger.rawValue, privacy: .public) with no selection")
        } else {
            performWheelAction(selection, trigger)
        }
    }

    /// Closes the wheel without doing anything
    func cancel(_ reason: String) {
        guard isOpen else { return }
        close()
        wheelLog.notice("cancelled: \(reason, privacy: .public)")
    }

    private func close() {
        isOpen = false
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil

        withAnimation(.smooth(duration: 0.14)) {
            model.isShown = false
            model.isShadowShown = false
        }
        orderOutTask = Task.startUnstructured { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            WheelController.shared.panel.orderOut(nil)
        }
    }

    private func pointerMoved(_ event: NSEvent) {
        guard isOpen else { return }
        let offset = pointer.move(to: NSEvent.mouseLocation, eventDelta: CGVector(dx: event.deltaX, dy: -event.deltaY))
        let selection = WheelSelection(offset: offset, thickness: model.style.thickness)
        if model.select(selection), selection != .none, config.wheel.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

/// The single entry point of wheel actions. Nothing is bound yet, so it only logs what would run
@MainActor private func performWheelAction(_ selection: WheelSelection, _ trigger: WheelTrigger) {
    wheelLog.notice("action: \(selection.description, privacy: .public) via \(trigger.rawValue, privacy: .public)")
}

/// Tracks the pointer offset from where the wheel opened.
///
/// The visible pointer location always wins, so the selection matches what the user sees. The only exception is a
/// pointer pinned against a screen edge: it can't move further, so the movement reported by the events is added as an
/// overshoot, which lets the user select directions that point off screen. The overshoot of an axis is dropped as soon
/// as the pointer moves along that axis again.
struct WheelPointer {
    let origin: CGPoint
    private var last: CGPoint
    private var overshoot: CGVector = .zero

    /// Enough to reach any direction from the edge
    static let maxOvershoot = WheelMetrics.diameter

    init(origin: CGPoint) {
        self.origin = origin
        self.last = origin
    }

    /// `eventDelta` is the movement reported by the event, with `dy` growing upwards. Returns the new offset
    mutating func move(to location: CGPoint, eventDelta: CGVector) -> CGVector {
        overshoot.dx = location.x != last.x ? 0 : clamp(overshoot.dx + eventDelta.dx)
        overshoot.dy = location.y != last.y ? 0 : clamp(overshoot.dy + eventDelta.dy)
        last = location
        return CGVector(dx: location.x - origin.x + overshoot.dx, dy: location.y - origin.y + overshoot.dy)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, -Self.maxOvershoot), Self.maxOvershoot)
    }
}

/// A transparent panel above everything that never takes focus and lets mouse events through
private final class WheelPanel: NSPanel {
    init(model: WheelModel) {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: WheelMetrics.panelSize, height: WheelMetrics.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = false // SwiftUI draws the shadow
        backgroundColor = .clear
        isOpaque = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        contentView = NSHostingView(rootView: WheelView(model: model))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Glass renders dimmed in windows that look inactive. The panel never activates, so it pretends to
    // periphery:ignore - read by AppKit through the Objective-C runtime
    @objc dynamic var hasKeyAppearance: Bool { true }
    // periphery:ignore - read by AppKit through the Objective-C runtime
    @objc dynamic var hasActiveAppearance: Bool { true }
}
