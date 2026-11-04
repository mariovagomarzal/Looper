import AppKit
import Common
import os
import Synchronization

// Trackpad gestures are read from the private MultitouchSupport framework, which reports every finger on every frame.
// Public APIs only deliver gestures to the app under the pointer. The framework is read only, needs no permission and
// is resolved at runtime, so Looper keeps working (without gestures) if a future macOS removes it.
//
// macOS gestures can't be blocked: a gesture that macOS also uses (e.g. swiping with 3 fingers between Spaces) runs
// both actions, so those must be turned off in System Settings.

let gesturesLog = Logger(subsystem: looperAppId, category: "gestures")

private struct GestureState: Sendable {
    var mode: String? = nil
    var bindings: [GestureBinding] = []
    var swipeDistance = 0.15
    /// One recognizer per trackpad, keyed by device address
    var recognizers: [Int: TrackpadGestureRecognizer] = [:]
    /// Most fingers on each trackpad since they last all lifted
    var touchingFingers: [Int: Int] = [:]
    /// Finger counts that the active mode swipes with
    var swipeFingers: Set<Int> = []
}

private let gestureState = Mutex(GestureState())

/// Resolves the gestures of the active mode. Reads the trackpads only while some mode binds gestures
@MainActor func syncGestureBindings() {
    let mode = activeMode
    let bindings = Array(mode.flatMap { config.modes[$0] }?.gestures.values ?? [:].values)
    let swipeDistance = Double(config.gestureSwipeDistance) / 100
    gestureState.withLock { state in
        state.mode = mode
        state.bindings = bindings
        state.swipeFingers = bindings.compactMap { binding in
            if case .swipe(let fingers, _) = binding.gesture { fingers } else { nil }
        }.toSet()
        if state.swipeDistance != swipeDistance {
            state.swipeDistance = swipeDistance
            state.recognizers = [:]
        }
    }
    if config.modes.values.contains(where: { !$0.gestures.isEmpty }) {
        Multitouch.shared?.start()
    } else {
        Multitouch.shared?.stop()
    }
}

/// Called on the thread of the framework for every frame of every trackpad
private func handleFrame(device: Int, _ touches: [TrackpadTouch], timestamp: Double) {
    let recognized: (gesture: TrackpadGesture, mode: String, bindings: [GestureBinding])? = gestureState.withLock { state in
        state.touchingFingers[device] = touches.isEmpty ? nil : max(state.touchingFingers[device] ?? 0, touches.count)
        var recognizer = state.recognizers[device] ?? TrackpadGestureRecognizer(swipeDistance: state.swipeDistance)
        let gesture = recognizer.frame(touches, timestamp: timestamp)
        state.recognizers[device] = recognizer
        guard let gesture, let mode = state.mode else { return nil }
        return (gesture, mode, state.bindings)
    }
    guard let recognized else { return }
    // Read outside of the gesture lock: the hotkey tap takes its own lock first and then the gesture one
    let pressed = currentPressedModifiers()
    gesturesLog.notice("\(recognized.gesture.toString(), privacy: .public) with modifiers '\(String(describing: pressed), privacy: .public)'")
    guard let binding = matchGestureBinding(recognized.bindings, recognized.gesture, pressed) else { return }
    let match = (mode: recognized.mode, binding: binding)
    Task.startUnstructured { @MainActor in
        try await triggerGestureBinding(match.binding, mode: match.mode)
    }
}

/// Fingers on some trackpad make a swipe that the active mode binds. macOS turns finger movements that no macOS
/// gesture uses into scroll events, which the hotkey tap then keeps from the app under the pointer
func isBoundTrackpadSwipeInProgress() -> Bool {
    gestureState.withLock { state in
        state.touchingFingers.values.contains { state.swipeFingers.contains($0) }
    }
}

@MainActor private func triggerGestureBinding(_ binding: GestureBinding, mode: String) async throws {
    guard activeMode == mode else { return } // The mode changed since the gesture
    broadcastEvent(.bindingTriggered(mode: mode, binding: binding.descriptionAsWritten))
    try await runLightSession(.gestureBinding, .checkServerIsEnabledOrDie()) { () throws in
        _ = await config.modes[mode]?.gestures[binding.description]?.commands.run(.defaultEnv, .emptyStdin)
    }
}

/// The private MultitouchSupport functions, resolved at runtime. Devices are passed around by address
@MainActor
private final class Multitouch {
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias RegisterCallback = @convention(c) (UnsafeMutableRawPointer?, MultitouchFrameCallback) -> Void
    private typealias DeviceStart = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void
    private typealias DeviceStop = @convention(c) (UnsafeMutableRawPointer?) -> Void

    private let createList: () -> CFArray?
    private let startDevice: (Int) -> Void
    private let stopDevice: (Int) -> Void
    /// The device list owns the devices, so it's kept while they run
    private var devices: CFArray? = nil
    private var wakeObserver: (any NSObjectProtocol)? = nil

    static let shared: Multitouch? = Multitouch()

    private init?() {
        if isUnitTest { return nil }
        guard let handle = unsafe dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY),
              let createListSym = unsafe dlsym(handle, "MTDeviceCreateList"),
              let registerSym = unsafe dlsym(handle, "MTRegisterContactFrameCallback"),
              let unregisterSym = unsafe dlsym(handle, "MTUnregisterContactFrameCallback"),
              let deviceStartSym = unsafe dlsym(handle, "MTDeviceStart"),
              let deviceStopSym = unsafe dlsym(handle, "MTDeviceStop")
        else { return nil }
        let createList = unsafe unsafeBitCast(createListSym, to: CreateList.self)
        let register = unsafe unsafeBitCast(registerSym, to: RegisterCallback.self)
        let unregister = unsafe unsafeBitCast(unregisterSym, to: RegisterCallback.self)
        let deviceStart = unsafe unsafeBitCast(deviceStartSym, to: DeviceStart.self)
        let deviceStop = unsafe unsafeBitCast(deviceStopSym, to: DeviceStop.self)
        self.createList = { unsafe createList()?.takeRetainedValue() }
        self.startDevice = { address in
            let device = unsafe UnsafeMutableRawPointer(bitPattern: address)
            unsafe register(device, multitouchFrameCallback)
            unsafe deviceStart(device, 0)
        }
        self.stopDevice = { address in
            let device = unsafe UnsafeMutableRawPointer(bitPattern: address)
            unsafe unregister(device, multitouchFrameCallback)
            unsafe deviceStop(device)
        }
    }

    func start() {
        if devices != nil { return }
        guard let list = createList() else { return }
        devices = list
        for device in deviceAddresses(list) { startDevice(device) }
        gesturesLog.notice("Reading \(CFArrayGetCount(list)) multitouch devices")
        // Devices stop delivering frames after sleep, and trackpads may have been connected meanwhile
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main,
        ) { _ in
            MainActor.assumeIsolated {
                Multitouch.shared?.stop()
                Multitouch.shared?.start()
            }
        }
    }

    func stop() {
        guard let list = devices else { return }
        for device in deviceAddresses(list) { stopDevice(device) }
        devices = nil
        gestureState.withLock { $0.touchingFingers = [:] }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        gestureState.withLock { $0.recognizers = [:] }
    }

    private func deviceAddresses(_ list: CFArray) -> [Int] {
        (0 ..< CFArrayGetCount(list)).map { unsafe Int(bitPattern: CFArrayGetValueAtIndex(list, $0)) }
    }
}

/// Layout of a finger (MTTouch) in a frame of the framework, on 64-bit
private let touchStride = 96
private let touchStateOffset = 20
private let touchPositionOffset = 32
/// Fingers that are on the trackpad, not just hovering over it (make touch, touching)
private let touchingStates: ClosedRange<Int32> = 4 ... 5

private typealias MultitouchFrameCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, Int32, Double, Int32) -> Int32

private let multitouchFrameCallback: MultitouchFrameCallback = { device, touches, count, timestamp, _ in
    guard let device = unsafe device else { return 0 }
    var result: [TrackpadTouch] = []
    if let touches = unsafe touches {
        for index in 0 ..< Int(max(count, 0)) {
            let touch = unsafe touches + index * touchStride
            guard touchingStates.contains(unsafe touch.loadUnaligned(fromByteOffset: touchStateOffset, as: Int32.self)) else { continue }
            let x = unsafe touch.loadUnaligned(fromByteOffset: touchPositionOffset, as: Float.self)
            let y = unsafe touch.loadUnaligned(fromByteOffset: touchPositionOffset + 4, as: Float.self)
            result.append(TrackpadTouch(x: Double(x), y: Double(y)))
        }
    }
    handleFrame(device: Int(bitPattern: device), result, timestamp: timestamp)
    return 0
}
