import Common

/// A trackpad gesture that can be bound to commands, like a key
enum TrackpadGesture: Hashable, Sendable {
    enum Direction: String, CaseIterable, Sendable {
        case left, right, up, down
    }

    /// Fingers that move together in one direction
    case swipe(fingers: Int, Direction)
    /// Fingers that touch the trackpad briefly without moving
    case tap(fingers: Int)

    static let fingerCounts = 3 ... 4

    func toString() -> String {
        switch self {
            case .swipe(let fingers, let direction): "swipe-\(fingers)-\(direction.rawValue)"
            case .tap(let fingers): "tap-\(fingers)"
        }
    }
}

struct GestureBinding: Equatable, Sendable {
    let modifiers: HotkeyModifiers
    let gesture: TrackpadGesture
    let commands: Shell<any Command>
    /// Canonical form, e.g. 'alt-swipe-3-left'. Bindings are keyed by it
    let description: String
    /// As written in the config
    let descriptionAsWritten: String

    init(_ modifiers: HotkeyModifiers, _ gesture: TrackpadGesture, _ commands: Shell<any Command>, descriptionAsWritten: String) {
        self.modifiers = modifiers
        self.gesture = gesture
        self.commands = commands
        self.description = modifiers.isEmpty ? gesture.toString() : modifiers.toString() + "-" + gesture.toString()
        self.descriptionAsWritten = descriptionAsWritten
    }

    static func == (lhs: GestureBinding, rhs: GestureBinding) -> Bool {
        lhs.modifiers == rhs.modifiers && lhs.gesture == rhs.gesture && lhs.commands.strictEquals(rhs.commands)
    }
}

func parseGestureBindings(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: GestureBinding] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: GestureBinding] = [:]
    for (rawGesture, rawCommand): (String, OrderedJson) in rawTable {
        let backtrace = backtrace + .key(rawGesture)
        let binding = parseGestureBinding(rawGesture, backtrace)
            .map { modifiers, gesture in
                GestureBinding(modifiers, gesture, parseShellOfCommandsForConfig(rawCommand, backtrace, &c), descriptionAsWritten: rawGesture)
            }
            .getOrNil(appendErrorTo: &c.errors)
        guard let binding else { continue }
        if result.keys.contains(binding.description) {
            c.errors.append(.init(backtrace, "'\(binding.description)' gesture redeclaration"))
        }
        result[binding.description] = binding
    }
    return result
}

/// '[modifiers-]swipe-<fingers>-<direction>' or '[modifiers-]tap-<fingers>'
func parseGestureBinding(_ raw: String, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<(HotkeyModifiers, TrackpadGesture)> {
    let tokens = raw.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
    guard let kindIndex = tokens.firstIndex(where: { $0 == "swipe" || $0 == "tap" }) else {
        return .failure(.init(backtrace, "Can't parse '\(raw)' gesture. Expected '[modifiers-]swipe-<fingers>-<direction>' or '[modifiers-]tap-<fingers>'"))
    }
    var modifiers = HotkeyModifiers.none
    for token in tokens[..<kindIndex] where !modifiers.add(token: token) {
        return .failure(.init(backtrace, "Can't parse modifiers in '\(raw)' gesture"))
    }
    let rest = tokens[(kindIndex + 1)...]
    let fingersError = ConfigParseDiagnostic(backtrace, "The number of fingers in '\(raw)' gesture must be 3 or 4")
    guard let fingers = rest.first.flatMap({ Int($0) }) else { return .failure(fingersError) }
    guard TrackpadGesture.fingerCounts.contains(fingers) else { return .failure(fingersError) }
    switch tokens[kindIndex] {
        case "swipe":
            guard rest.count == 2, let direction = TrackpadGesture.Direction(rawValue: rest.last!) else {
                return .failure(.init(backtrace, "Can't parse the direction in '\(raw)' gesture. Possible values: (left|right|up|down)"))
            }
            return .success((modifiers, .swipe(fingers: fingers, direction)))
        default:
            guard rest.count == 1 else { return .failure(.init(backtrace, "Can't parse '\(raw)' gesture. Taps have no direction")) }
            return .success((modifiers, .tap(fingers: fingers)))
    }
}

/// The binding to run for a gesture. Bindings with sided modifiers (`lalt`) win over generic ones (`alt`)
func matchGestureBinding(_ bindings: some Sequence<GestureBinding>, _ gesture: TrackpadGesture, _ pressed: PressedModifiers) -> GestureBinding? {
    bindings
        .filter { $0.gesture == gesture && $0.modifiers.matches(pressed) }
        .max { $0.modifiers.specificity < $1.modifiers.specificity }
}

/// A finger on the trackpad. Coordinates are normalized to 0...1, with y growing upwards
struct TrackpadTouch: Sendable {
    let x: Double
    let y: Double
}

/// Turns the touches of every trackpad frame into gestures. Every gesture fires once, until all the fingers lift
struct TrackpadGestureRecognizer: Sendable {
    /// How far the fingers must move for a swipe, as a fraction of the trackpad
    var swipeDistance: Double = 0.15
    /// Longest touch that is still a tap, in seconds
    var tapDuration: Double = 0.3
    /// Fingers of a tap may move this much, as a fraction of the trackpad
    var tapSlop: Double = 0.03

    private var start: Double? = nil
    private var maxFingers = 0
    private var fired = false
    private var moved = false
    /// Where the fingers were when their number last changed. Fingers land and lift one by one, so movements are
    /// measured from there
    private var origin: (fingers: Int, x: Double, y: Double)? = nil

    init() {}

    init(swipeDistance: Double) { self.swipeDistance = swipeDistance }

    mutating func frame(_ touches: [TrackpadTouch], timestamp: Double) -> TrackpadGesture? {
        if touches.isEmpty {
            defer { reset() }
            guard let start, !fired, !moved, TrackpadGesture.fingerCounts.contains(maxFingers), timestamp - start <= tapDuration else { return nil }
            return .tap(fingers: maxFingers)
        }
        if start == nil { start = timestamp }
        maxFingers = max(maxFingers, touches.count)
        let x = touches.map(\.x).reduce(0, +) / Double(touches.count)
        let y = touches.map(\.y).reduce(0, +) / Double(touches.count)
        guard let origin, origin.fingers == touches.count else {
            origin = (touches.count, x, y)
            return nil
        }
        let (dx, dy) = (x - origin.x, y - origin.y)
        let distance = max(abs(dx), abs(dy))
        if distance > tapSlop { moved = true }
        // Swipes with all the fingers of the gesture only, not while some of them lift
        guard !fired, touches.count == maxFingers, TrackpadGesture.fingerCounts.contains(touches.count), distance >= swipeDistance else { return nil }
        fired = true
        let direction: TrackpadGesture.Direction = abs(dx) >= abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .up : .down)
        return .swipe(fingers: touches.count, direction)
    }

    private mutating func reset() {
        start = nil
        maxFingers = 0
        fired = false
        moved = false
        origin = nil
    }
}
