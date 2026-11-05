/// What the keyboard and mouse tap asks the wheel to do
enum WheelTapEffect: Equatable, Sendable {
    /// Open the wheel with the profile, or switch the open wheel to it
    case open(String)
    /// Switch to the profile after the release delay, unless the gesture finishes first. Confirm it with
    /// ``WheelTapMachine/confirmPendingSwitch(_:)``
    case switchLater(String, id: Int)
    case finish(WheelFinish)
    case cancel(String)
}

/// Decides how held modifiers, clicks and key presses drive the wheel. It runs on the tap thread, so it must stay
/// cheap and free of side effects: the returned effects are applied on the main thread.
///
/// - While idle, holding the modifiers of a trigger opens the wheel with its profile.
/// - While held open, the profile follows the trigger that matches the held modifiers (e.g. pressing shift on top of
///   fn switches from 'fn' to 'fn-shift'). Modifiers that match no trigger keep the current profile. Releasing every
///   modifier finishes the gesture.
/// - Fingers never release several keys at once. So a switch caused by releasing a modifier (e.g. shift before fn) is
///   delayed: if every modifier is released within the delay, the gesture finishes with the profile that was shown.
/// - A wheel opened by a command ('wheel open') isn't held: it's finished by a click, and cancelled by any key.
/// - A click finishes the gesture, and a key press cancels it. After that, the wheel only opens again once every
///   modifier is released.
struct WheelTapMachine: Equatable, Sendable {
    enum Session: Equatable, Sendable {
        case idle
        case held(profile: String)
        /// Opened by a command, without keys to release
        case free
        /// The gesture ended while modifiers were still held
        case awaitingRelease
    }

    private(set) var session: Session = .idle
    private var heldKeyCount = 0
    private var pendingSwitch: (profile: String, id: Int)? = nil
    private var lastSwitchId = 0

    static func == (lhs: WheelTapMachine, rhs: WheelTapMachine) -> Bool {
        lhs.session == rhs.session && lhs.heldKeyCount == rhs.heldKeyCount &&
            lhs.pendingSwitch?.profile == rhs.pendingSwitch?.profile && lhs.pendingSwitch?.id == rhs.pendingSwitch?.id
    }

    var isOpen: Bool {
        switch session {
            case .held, .free: true
            case .idle, .awaitingRelease: false
        }
    }

    /// `delaysReleases`: whether switches caused by releasing a modifier wait for the release delay
    mutating func modifiersChanged(
        fnDown: Bool,
        _ pressed: PressedModifiers,
        _ triggers: [WheelTriggerBinding],
        enabled: Bool,
        delaysReleases: Bool = false,
    ) -> WheelTapEffect? {
        let previousKeyCount = heldKeyCount
        heldKeyCount = (fnDown ? 1 : 0) + pressed.left.count + pressed.right.count
        let anyHeld = heldKeyCount > 0
        switch session {
            case .idle:
                guard enabled, let trigger = matchWheelTrigger(triggers, fnDown: fnDown, pressed) else { return nil }
                session = .held(profile: trigger.profile)
                return .open(trigger.profile)
            case .held(let profile):
                if !anyHeld {
                    // A pending switch is dropped: the gesture finishes with the profile that is shown
                    session = .idle
                    pendingSwitch = nil
                    return .finish(.release)
                }
                guard let trigger = matchWheelTrigger(triggers, fnDown: fnDown, pressed) else { return nil }
                if trigger.profile == profile {
                    pendingSwitch = nil // The modifier came back within the delay
                    return nil
                }
                if delaysReleases, heldKeyCount < previousKeyCount {
                    lastSwitchId += 1
                    pendingSwitch = (trigger.profile, lastSwitchId)
                    return .switchLater(trigger.profile, id: lastSwitchId)
                }
                pendingSwitch = nil
                session = .held(profile: trigger.profile)
                return .open(trigger.profile)
            case .free:
                return nil
            case .awaitingRelease:
                if !anyHeld { session = .idle }
                return nil
        }
    }

    /// The release delay of a ``WheelTapEffect/switchLater(_:id:)`` elapsed. Returns the switch if it's still due
    mutating func confirmPendingSwitch(_ id: Int) -> WheelTapEffect? {
        guard case .held = session, let pendingSwitch, pendingSwitch.id == id else { return nil }
        self.pendingSwitch = nil
        session = .held(profile: pendingSwitch.profile)
        return .open(pendingSwitch.profile)
    }

    /// A click that finishes the gesture is swallowed, so it never reaches the app under the pointer
    mutating func click(_ finish: WheelFinish) -> WheelTapEffect? {
        pendingSwitch = nil
        switch session {
            case .held: session = .awaitingRelease
            case .free: session = .idle
            case .idle, .awaitingRelease: return nil
        }
        return .finish(finish)
    }

    /// Returns the effect, and whether the key press must be swallowed. Keys pass through, so that shortcuts with the
    /// trigger modifiers (fn-arrow, fn-delete...) keep working. Only escape is swallowed when it closes a wheel, so that
    /// it doesn't also reach the focused app
    mutating func keyDown(isEscape: Bool) -> (effect: WheelTapEffect?, swallow: Bool) {
        pendingSwitch = nil
        switch session {
            case .held:
                session = .awaitingRelease
                return (.cancel("key pressed"), isEscape)
            case .free:
                session = .idle
                return (.cancel("key pressed"), isEscape)
            case .idle, .awaitingRelease:
                return (nil, false)
        }
    }

    /// The wheel was opened by a command
    mutating func openedByCommand() {
        if session == .idle || session == .awaitingRelease { session = .free }
    }

    /// The wheel closed, whatever the reason
    mutating func closed() {
        pendingSwitch = nil
        switch session {
            case .held: session = .awaitingRelease
            case .free: session = .idle
            case .idle, .awaitingRelease: break
        }
    }
}
