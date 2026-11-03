import AppKit
import Carbon.HIToolbox
import Common
import Synchronization

// Hotkeys are captured with a CGEventTap instead of Carbon's RegisterEventHotKey, because Carbon can't tell the left
// and the right modifier keys apart. The tap runs on its own thread, so that typing never waits for the main thread.

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode_nonCancellable(_ targetMode: String?) async {
    let oldMode = activeMode
    activeMode = targetMode
    syncHotkeyTapBindings()
    startHotkeyEventTapIfNeeded()
    if oldMode != targetMode {
        broadcastEvent(.modeChanged(mode: targetMode))
        _ = await config.onModeChanged.run(.defaultEnv, .emptyStdin)
    }
}

/// Resolves the bindings of the active mode to key codes with the active keyboard layout
@MainActor private func syncHotkeyTapBindings() {
    let mode = activeMode
    let bindings = mode.flatMap { config.modes[$0] }?.bindings.values ?? [:].values
    let layout = currentKeyboardLayout
    var bindingsByKeyCode: [UInt16: [HotkeyBinding]] = [:]
    for binding in bindings {
        // Characters that no key types without modifiers can't be triggered
        guard let keyCode = layout.keyCode(for: binding.key) else { continue }
        bindingsByKeyCode[keyCode, default: []].append(binding)
    }
    hotkeyTapState.withLock { state in
        state.mode = mode
        state.bindingsByKeyCode = bindingsByKeyCode
    }
}

/// The binding to run for a key press. Bindings with sided modifiers (`lalt`) win over generic ones (`alt`)
func matchHotkeyBinding(_ candidates: [HotkeyBinding], _ pressed: PressedModifiers) -> HotkeyBinding? {
    candidates
        .filter { $0.modifiers.matches(pressed) }
        .max { $0.modifiers.specificity < $1.modifiers.specificity }
}

private struct HotkeyTapState: Sendable {
    var mode: String? = nil
    var bindingsByKeyCode: [UInt16: [HotkeyBinding]] = [:]
    /// Key ups of swallowed key downs are swallowed too, so that apps never see half of a key press
    var swallowedKeyUps: Set<UInt16> = []
}

private let hotkeyTapState = Mutex(HotkeyTapState())

@MainActor private var isHotkeyTapStarted = false

@MainActor private func startHotkeyEventTapIfNeeded() {
    if isUnitTest || isHotkeyTapStarted { return }
    isHotkeyTapStarted = true
    DistributedNotificationCenter.default().addObserver(
        forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
        object: nil,
        queue: .main,
    ) { _ in
        MainActor.assumeIsolated {
            if refreshKeyboardLayout() { syncHotkeyTapBindings() }
        }
    }
    let thread = Thread { runHotkeyEventTap() }
    thread.name = "looper-hotkeys"
    thread.qualityOfService = .userInteractive
    thread.start()
}

/// Only accessed from the hotkey tap thread
nonisolated(unsafe) private var hotkeyTap: CFMachPort? = nil

private func runHotkeyEventTap() {
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
    while true {
        // Creation fails until the Accessibility permission is granted
        if let tap = unsafe CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyTapCallback,
            userInfo: nil,
        ) {
            unsafe hotkeyTap = tap
            let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
            return
        }
        Thread.sleep(forTimeInterval: 1)
    }
}

private func hotkeyTapCallback(
    _: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _: UnsafeMutableRawPointer?,
) -> Unmanaged<CGEvent>? {
    let swallow: Bool
    switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = unsafe hotkeyTap { CGEvent.tapEnable(tap: tap, enable: true) }
            swallow = false
        case .keyDown:
            swallow = handleKeyDown(event)
        case .keyUp:
            let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            swallow = hotkeyTapState.withLock { $0.swallowedKeyUps.remove(keyCode) != nil }
        default:
            swallow = false
    }
    return swallow ? nil : unsafe Unmanaged.passUnretained(event)
}

private func handleKeyDown(_ event: CGEvent) -> Bool {
    let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
    let pressed = PressedModifiers(event.flags)
    let match: (mode: String, binding: HotkeyBinding)? = hotkeyTapState.withLock { state in
        guard let mode = state.mode, let binding = matchHotkeyBinding(state.bindingsByKeyCode[keyCode] ?? [], pressed) else { return nil }
        state.swallowedKeyUps.insert(keyCode)
        return (mode, binding)
    }
    guard let match else { return false }
    // Holding the keys runs the binding once, like Carbon hotkeys did
    if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
        Task.startUnstructured { @MainActor in
            try await triggerHotkeyBinding(match.binding, mode: match.mode)
        }
    }
    return true
}

@MainActor private func triggerHotkeyBinding(_ binding: HotkeyBinding, mode: String) async throws {
    guard activeMode == mode else { return } // The mode changed since the key press
    broadcastEvent(.bindingTriggered(mode: mode, binding: binding.descriptionWithKeyNotation))
    try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie()) { () throws in
        _ = await config.modes[mode]?.bindings[binding.descriptionWithKeyCode]?.commands
            .run(.defaultEnv, .emptyStdin)
    }
}
