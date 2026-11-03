import CoreGraphics

/// Modifiers of a hotkey binding. Every modifier can be required on either side (`alt`), only on the left side
/// (`lalt`), only on the right side (`ralt`), or on both sides (`lalt-ralt`). Modifiers that aren't mentioned must not
/// be pressed.
struct HotkeyModifiers: Hashable, Sendable {
    enum Modifier: String, CaseIterable, Sendable {
        // The order defines the textual representation
        case alt, ctrl, cmd, shift
    }

    enum Side: Sendable {
        case either, left, right, both
    }

    private(set) var sides: [Modifier: Side] = [:]

    static let none = HotkeyModifiers()

    init() {}

    init(_ sides: [Modifier: Side]) { self.sides = sides }

    var isEmpty: Bool { sides.isEmpty }

    /// Sided modifiers win over generic ones when several bindings match the same key press
    var specificity: Int { sides.values.count { $0 != .either } }

    /// Adds a modifier token, such as `alt`, `lalt` or `ralt`. Fails on contradicting tokens like `alt-lalt`
    mutating func add(token: String) -> Bool {
        guard let (modifier, side) = parseModifierToken(token) else { return false }
        switch (sides[modifier], side) {
            case (nil, _): sides[modifier] = side
            case (let old?, let new) where old == new: break
            case (.left, .right), (.right, .left): sides[modifier] = .both
            case (.both, .left), (.both, .right): break
            default: return false
        }
        return true
    }

    func toString() -> String {
        Modifier.allCases.flatMap { modifier -> [String] in
            switch sides[modifier] {
                case nil: []
                case .either: [modifier.rawValue]
                case .left: ["l" + modifier.rawValue]
                case .right: ["r" + modifier.rawValue]
                case .both: ["l" + modifier.rawValue, "r" + modifier.rawValue]
            }
        }.joined(separator: "-")
    }

    func matches(_ pressed: PressedModifiers) -> Bool {
        Modifier.allCases.allSatisfy { modifier in
            let left = pressed.left.contains(modifier)
            let right = pressed.right.contains(modifier)
            return switch sides[modifier] {
                case nil: !left && !right
                case .either: left || right
                case .left: left && !right
                case .right: right && !left
                case .both: left && right
            }
        }
    }
}

private func parseModifierToken(_ token: String) -> (HotkeyModifiers.Modifier, HotkeyModifiers.Side)? {
    if let modifier = HotkeyModifiers.Modifier(rawValue: token) { return (modifier, .either) }
    guard let first = token.first, first == "l" || first == "r",
          let modifier = HotkeyModifiers.Modifier(rawValue: String(token.dropFirst()))
    else { return nil }
    return (modifier, first == "l" ? .left : .right)
}

/// Modifier keys that are physically pressed, read from the device dependent bits of a keyboard event
struct PressedModifiers: Equatable, Sendable {
    var left: Set<HotkeyModifiers.Modifier> = []
    var right: Set<HotkeyModifiers.Modifier> = []

    init(left: Set<HotkeyModifiers.Modifier> = [], right: Set<HotkeyModifiers.Modifier> = []) {
        self.left = left
        self.right = right
    }

    init(_ flags: CGEventFlags) {
        for modifier in HotkeyModifiers.Modifier.allCases {
            let masks = modifier.masks
            guard flags.contains(masks.generic) else { continue }
            let isLeft = flags.rawValue & masks.left != 0
            let isRight = flags.rawValue & masks.right != 0
            // Synthetic events (e.g. from remapping tools) may lack the device dependent bits
            if isLeft || !isRight { left.insert(modifier) }
            if isRight { right.insert(modifier) }
        }
    }
}

extension HotkeyModifiers.Modifier {
    /// Device dependent masks from IOKit's IOLLEvent.h (NX_DEVICE*KEYMASK)
    fileprivate var masks: (generic: CGEventFlags, left: UInt64, right: UInt64) {
        switch self {
            case .ctrl: (.maskControl, 0x0000_0001, 0x0000_2000)
            case .shift: (.maskShift, 0x0000_0002, 0x0000_0004)
            case .cmd: (.maskCommand, 0x0000_0008, 0x0000_0010)
            case .alt: (.maskAlternate, 0x0000_0020, 0x0000_0040)
        }
    }
}
