import AppKit
import Carbon.HIToolbox
import Common

/// The characters that every physical key types without modifiers in a keyboard layout
struct KeyboardLayout: Equatable, Sendable {
    private let characterToKeyCode: [Character: UInt16]

    init(_ characterToKeyCode: [Character: UInt16]) {
        self.characterToKeyCode = characterToKeyCode
    }

    func keyCode(for key: HotkeyKey) -> UInt16? {
        switch key {
            case .physical(let key): key.keyCode
            case .character(let character): characterToKeyCode[character.lowercasedIfSingle]
        }
    }

    /// US ANSI layout. Used when the active layout can't be read (unit tests, input sources without layout data)
    static let ansi = KeyboardLayout(Dictionary(uniqueKeysWithValues: ansiCharacters.map { ($0.0, $0.1.keyCode) }))
}

private let ansiCharacters: [(Character, Key)] = [
    ("a", .a), ("b", .b), ("c", .c), ("d", .d), ("e", .e), ("f", .f), ("g", .g), ("h", .h), ("i", .i), ("j", .j),
    ("k", .k), ("l", .l), ("m", .m), ("n", .n), ("o", .o), ("p", .p), ("q", .q), ("r", .r), ("s", .s), ("t", .t),
    ("u", .u), ("v", .v), ("w", .w), ("x", .x), ("y", .y), ("z", .z),
    ("0", .zero), ("1", .one), ("2", .two), ("3", .three), ("4", .four),
    ("5", .five), ("6", .six), ("7", .seven), ("8", .eight), ("9", .nine),
    ("-", .minus), ("=", .equal), ("[", .leftBracket), ("]", .rightBracket), ("\\", .backslash),
    (";", .semicolon), ("'", .quote), (",", .comma), (".", .period), ("/", .slash), ("`", .grave), ("§", .section),
]

@MainActor private var _currentKeyboardLayout: KeyboardLayout? = nil

@MainActor var currentKeyboardLayout: KeyboardLayout {
    if let layout = _currentKeyboardLayout { return layout }
    let layout = readKeyboardLayout()
    _currentKeyboardLayout = layout
    return layout
}

/// Unit tests can't read the system layout. They simulate it with this one
@MainActor var keyboardLayoutForTests: KeyboardLayout? = nil {
    didSet { _currentKeyboardLayout = nil }
}

/// Re-reads the active layout. Returns true if it changed
@MainActor func refreshKeyboardLayout() -> Bool {
    let new = readKeyboardLayout()
    defer { _currentKeyboardLayout = new }
    return new != _currentKeyboardLayout
}

@MainActor private func readKeyboardLayout() -> KeyboardLayout {
    if isUnitTest { return keyboardLayoutForTests ?? .ansi }
    return readSystemKeyboardLayout() ?? .ansi
}

@MainActor private func readSystemKeyboardLayout() -> KeyboardLayout? {
    guard let source = unsafe TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let rawData = unsafe TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return nil }
    let data = unsafe Unmanaged<CFData>.fromOpaque(rawData).takeUnretainedValue() as Data
    let keyboardType = UInt32(LMGetKbdType())
    var result: [Character: UInt16] = [:]
    // Lower key codes first, so that the main keys win over the keypad ones
    for keyCode in Key.allCases.map(\.keyCode).sorted() {
        guard let character = translate(data, keyCode, keyboardType), result[character] == nil else { continue }
        result[character] = keyCode
    }
    return result.isEmpty ? nil : KeyboardLayout(result)
}

private func translate(_ layoutData: Data, _ keyCode: UInt16, _ keyboardType: UInt32) -> Character? {
    var deadKeyState: UInt32 = 0
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    let status = unsafe layoutData.withUnsafeBytes { buffer -> OSStatus in
        guard let layout = unsafe buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
        return unsafe UCKeyTranslate(
            layout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0, // No modifiers
            keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysMask), // Dead keys ('´') type themselves
            &deadKeyState,
            chars.count,
            &length,
            &chars,
        )
    }
    guard status == noErr, length > 0 else { return nil }
    let string = unsafe String(utf16CodeUnits: chars, count: length)
    guard string.count == 1, let character = string.first,
          !character.isWhitespace,
          !character.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else { return nil }
    return character.lowercasedIfSingle
}
