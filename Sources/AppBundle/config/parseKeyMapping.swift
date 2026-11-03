import Common

private let keyMappingParser: [String: any ParserProtocol<KeyMapping>] = [
    "preset": Parser(\.preset, parsePreset),
    "key-notation-to-key-code": Parser(\.rawKeyNotationToKeyCode, parseKeyNotationToKeyCode),
]

struct KeyMapping: Withable, Equatable, Sendable {
    enum Preset: String, CaseIterable, Sendable {
        /// Single characters ('a', 'ñ', '-') follow the active keyboard layout. Key names ('semicolon') are ANSI
        /// physical positions
        case system
        /// Every key notation is an ANSI physical position
        case qwerty, dvorak, colemak
    }

    init(
        preset: Preset = .system,
        rawKeyNotationToKeyCode: [String: Key] = [:],
    ) {
        self.preset = preset
        self.rawKeyNotationToKeyCode = rawKeyNotationToKeyCode
    }

    fileprivate var preset: Preset = .system
    fileprivate var rawKeyNotationToKeyCode: [String: Key] = [:]

    func resolve() -> KeyNotationResolver {
        KeyNotationResolver(
            physical: getKeysPreset(preset) + rawKeyNotationToKeyCode,
            custom: rawKeyNotationToKeyCode,
            charactersFollowLayout: preset == .system,
        )
    }
}

struct KeyNotationResolver: Sendable {
    fileprivate let physical: [String: Key]
    fileprivate let custom: [String: Key]
    fileprivate let charactersFollowLayout: Bool

    func resolve(_ notation: String) -> HotkeyKey? {
        if let key = custom[notation] { return .physical(key) }
        if charactersFollowLayout, notation.count == 1, let character = notation.first {
            return .character(character.lowercasedIfSingle)
        }
        return physical[notation].map(HotkeyKey.physical)
    }
}

extension Character {
    var lowercasedIfSingle: Character {
        let lowercased = lowercased()
        return lowercased.count == 1 ? lowercased.first ?? self : self
    }
}

func parseKeyMapping(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> KeyMapping {
    parseNonEmptyTable(raw, KeyMapping(), keyMappingParser, backtrace, &c)
}

private func parsePreset(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<KeyMapping.Preset> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.Preset.self).toParsedConfig(backtrace) }
}

private func parseKeyNotationToKeyCode(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: Key] {
    var result: [String: Key] = [:]
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
        return result
    }
    for (key, value): (String, OrderedJson) in table {
        if isValidKeyNotation(key) {
            let backtrace = backtrace + .key(key)
            if let value = parseString(value, backtrace).getOrNil(appendErrorTo: &c.errors) {
                switch keyNotationToKeyCode[value] {
                    case let value?: result[key] = value
                    case nil: c.errors.append(.init(backtrace, "\(value.singleQuoted) is invalid key code"))
                }
            }
        } else {
            c.errors.append(.init(backtrace, "\(key.singleQuoted) is invalid key notation"))
        }
    }
    return result
}

private func isValidKeyNotation(_ str: String) -> Bool {
    str.rangeOfCharacter(from: .whitespacesAndNewlines) == nil && !str.contains("-")
}
