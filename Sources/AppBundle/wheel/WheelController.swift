import AppKit
import Common
import os
import SwiftUI

/// Diagnostics of wheel gestures. Read them with:
/// `log show --last 5m --style compact --predicate 'subsystem == "com.mariovagomarzal.looper.debug" AND category == "wheel"'`
let wheelLog = Logger(subsystem: looperAppId, category: "wheel")

/// Shows the wheel under the mouse pointer, tracks the direction the pointer moves to, and runs the action of the
/// active profile bound to the selection and to the way the gesture finished.
@MainActor
final class WheelController {
    static let shared = WheelController()

    private let model = WheelModel()
    private lazy var panel: WheelPanel = WheelPanel(model: model)
    private var pointer = WheelPointer(origin: .zero)
    private var lastOffset: CGVector = .zero
    private var mouseMonitor: Any? = nil
    private var orderOutTask: Task<(), Never>? = nil
    /// Bumped by every open request and every finished gesture, so that a request whose variant resolved too late is
    /// dropped
    private var openRequest = 0
    /// The window under the pointer when the gesture started (`--window-id wheel`)
    private var gestureWindowId: OpaqueWindowId? = nil

    /// The environment of the actions and conditions of the current gesture
    private var gestureEnv: CmdEnv { CmdEnv.defaultEnv.withWheel(WheelGestureEnv(windowId: gestureWindowId)) }

    private init() {}

    private(set) var isOpen = false
    private(set) var profileName = defaultWheelProfile

    private var profile: WheelProfile { config.wheel.profiles[profileName] ?? WheelProfile() }

    /// Creates and lays out the panel ahead of time. Otherwise the first layout happens inside the appearance
    /// animation, and the wheel animates in from a corner the first time it opens
    func prepare() {
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    /// Opens the wheel with the profile, or switches the open wheel to it. If the profile has variants, the one whose
    /// condition matches the focused window is used instead
    func request(profile base: String) {
        openRequest += 1
        let request = openRequest
        if !isOpen {
            // A new gesture. Captured before the pointer moves away
            gestureWindowId = windowUnderPointer()?.windowId
        }
        guard config.wheel.variants[base]?.isEmpty == false else {
            open(profile: base)
            return
        }
        Task.startUnstructured { @MainActor in
            let profile = await resolveWheelVariant(base, WheelController.shared.gestureEnv)
            // The gesture may have finished, or another profile may have been requested, while conditions ran
            guard WheelController.shared.openRequest == request else { return }
            WheelController.shared.open(profile: profile)
        }
    }

    private func open(profile name: String) {
        if isOpen {
            switchProfile(to: name)
            return
        }
        isOpen = true
        profileName = name
        orderOutTask?.cancel()
        orderOutTask = nil

        let origin = NSEvent.mouseLocation
        pointer = WheelPointer(origin: origin)
        lastOffset = .zero
        model.style = style(of: profile, at: origin)
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
        wheelLog.notice("opened: \(name, privacy: .public)")
    }

    private func switchProfile(to name: String) {
        guard name != profileName else { return }
        profileName = name
        let newStyle = style(of: profile, at: pointer.origin)
        withAnimation(.smooth(duration: 0.25)) { model.style = newStyle }
        // A thicker or thinner ring moves the boundary between the center and the directions
        _ = model.select(WheelSelection(offset: lastOffset, thickness: newStyle.thickness))
        wheelLog.notice("switched: \(name, privacy: .public)")
    }

    private func style(of profile: WheelProfile, at point: CGPoint) -> WheelStyle {
        let name = profileName
        let colors = WheelAccentResolver.shared.colors(for: profile.style.accentColor, at: point) { @MainActor colors in
            // The wallpaper colors arrived. Apply them unless the profile changed meanwhile
            let controller = WheelController.shared
            guard controller.profileName == name else { return }
            withAnimation(.easeOut(duration: 0.2)) { controller.model.style.colors = colors }
        }
        return WheelStyle(profile.style, colors: colors)
    }

    /// Finishes the gesture with the current selection
    func commit(_ finish: WheelFinish) {
        openRequest += 1
        guard isOpen else { return }
        let selection = model.selection
        let profileName = profileName
        let action = selection.slot.flatMap { profile.action($0, finish) }
        let env = gestureEnv
        close()
        guard let slot = selection.slot else {
            wheelLog.notice("cancelled: \(finish.rawValue, privacy: .public) with no selection")
            return
        }
        guard let action, !action.isEmpty else {
            wheelLog.notice("nothing bound: \(profileName, privacy: .public) \(slot.rawValue, privacy: .public) \(finish.rawValue, privacy: .public)")
            return
        }
        wheelLog.notice("action: \(profileName, privacy: .public) \(slot.rawValue, privacy: .public) \(finish.rawValue, privacy: .public)")
        Task.startUnstructured { @MainActor in
            try await runLightSession(.wheelAction, .checkServerIsEnabledOrDie()) { () throws in
                _ = await action.run(env, .emptyStdin)
            }
        }
    }

    /// Closes the wheel without doing anything
    func cancel(_ reason: String) {
        openRequest += 1
        guard isOpen else { return }
        close()
        wheelLog.notice("cancelled: \(reason, privacy: .public)")
    }

    private func close() {
        isOpen = false
        wheelDidClose()
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
        lastOffset = pointer.move(to: NSEvent.mouseLocation, eventDelta: CGVector(dx: event.deltaX, dy: -event.deltaY))
        let selection = WheelSelection(offset: lastOffset, thickness: model.style.thickness)
        if model.select(selection), selection != .none, profile.style.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

/// The variant of the profile to open: the first variant (in config order) whose condition succeeds, recursively.
/// Like any command, conditions check the focused window unless they pass '--window-id'. Conditions that fail to
/// evaluate (e.g. window variables without a focused window) don't match
@MainActor func resolveWheelVariant(_ base: String, _ env: CmdEnv) async -> String {
    var current = base
    var visited: Set<String> = [base]
    search: while true {
        for variant in config.wheel.variants[current] ?? [] where !visited.contains(variant) {
            guard let condition = config.wheel.profiles[variant]?.condition else { continue }
            let result = await condition.run(env, .emptyStdin)
            switch result.exitCode.rawValue {
                case 0:
                    visited.insert(variant)
                    current = variant
                    continue search
                case 1:
                    continue
                default:
                    wheelLog.error("condition of \(variant, privacy: .public) failed: \(result.stderr.joined(separator: " "), privacy: .public)")
            }
        }
        return current
    }
}

extension Shell {
    fileprivate var isEmpty: Bool {
        if case .empty = self { true } else { false }
    }
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
