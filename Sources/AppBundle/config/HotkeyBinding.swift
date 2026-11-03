import Common

struct HotkeyBinding: Equatable, Sendable {
    let modifiers: HotkeyModifiers
    let key: HotkeyKey
    let commands: Shell<any Command>
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(_ modifiers: HotkeyModifiers, _ key: HotkeyKey, _ commands: Shell<any Command>, descriptionWithKeyNotation: String) {
        self.modifiers = modifiers
        self.key = key
        self.commands = commands
        self.descriptionWithKeyCode = modifiers.isEmpty
            ? key.toString()
            : modifiers.toString() + "-" + key.toString()
        self.descriptionWithKeyNotation = descriptionWithKeyNotation
    }

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers &&
            lhs.key == rhs.key &&
            lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode &&
            lhs.commands.strictEquals(rhs.commands)
    }
}

func parseBindings(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext, _ mapping: KeyNotationResolver) -> [String: HotkeyBinding] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (binding, rawCommand): (String, OrderedJson) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace, mapping)
            .map { modifiers, key -> HotkeyBinding in
                let commands = parseShellOfCommandsForConfig(rawCommand, backtrace, &c)
                return HotkeyBinding(modifiers, key, commands, descriptionWithKeyNotation: binding)
            }
            .getOrNil(appendErrorTo: &c.errors)
        if let binding {
            if result.keys.contains(binding.descriptionWithKeyCode) {
                c.errors.append(.init(backtrace, "'\(binding.descriptionWithKeyCode)' Binding redeclaration"))
            }
            result[binding.descriptionWithKeyCode] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: ConfigBacktrace, _ mapping: KeyNotationResolver) -> ResOrConfigParseDiagnostic<(HotkeyModifiers, HotkeyKey)> {
    // 'alt--' binds the key that types '-', which is also the separator
    let (rawModifiers, keyNotation): ([Substring], String?) = if raw == "-" {
        ([], "-")
    } else if raw.hasSuffix("--") {
        (raw.dropLast(2).split(separator: "-"), "-")
    } else {
        (Array(raw.split(separator: "-").dropLast()), raw.split(separator: "-").last.map(String.init))
    }
    var modifiers = HotkeyModifiers.none
    for token in rawModifiers where !modifiers.add(token: String(token)) {
        return .failure(.init(backtrace, "Can't parse modifiers in '\(raw)' binding"))
    }
    guard let key = keyNotation.flatMap(mapping.resolve) else {
        return .failure(.init(backtrace, "Can't parse the key in '\(raw)' binding"))
    }
    return .success((modifiers, key))
}

/// The key of a binding
enum HotkeyKey: Hashable, Sendable {
    /// A physical key, regardless of the keyboard layout
    case physical(Key)
    /// The key that types the character without modifiers in the active keyboard layout. If no key types it, the
    /// binding can't be triggered
    case character(Character)

    func toString() -> String {
        switch self {
            case .physical(let key): key.toString()
            case .character(let character): String(character)
        }
    }
}
