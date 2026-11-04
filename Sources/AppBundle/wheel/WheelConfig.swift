import Common

// MARK: - Resolved config

/// Wheel profiles with their inheritance already resolved, and the modifier chords that open them
struct WheelConfig: Sendable {
    /// There is always a 'default' profile
    var profiles: [String: WheelProfile] = [defaultWheelProfile: WheelProfile()]
    var triggers: [WheelTriggerBinding] = [WheelTriggerBinding(chord: WheelChord(fn: true), profile: defaultWheelProfile)]
    /// Variants of every profile in config order: the profiles that extend it with an 'if' condition
    var variants: [String: [String]] = [:]
    /// Milliseconds that a profile switch caused by releasing a modifier waits, in case the remaining modifiers are
    /// released too. Fingers never release several keys at once
    var releaseDelay: Int = 150

    static let releaseDelayRange = 0 ... 1000

    /// `profileOrder` lists profiles in the order they appear in the config file
    mutating func orderVariants(by profileOrder: [String]) {
        let position = Dictionary(profileOrder.enumerated().map { ($1, $0) }) { first, _ in first }
        variants = variants.mapValues { names in
            names.sorted { (position[$0] ?? Int.max) < (position[$1] ?? Int.max) }
        }
    }
}

let defaultWheelProfile = "default"

struct WheelProfile: Sendable {
    var style = WheelStyleConfig()
    /// Unbound (slot, finish) pairs do nothing
    var actions: [WheelSlot: [WheelFinish: Shell<any Command>]] = [:]
    /// Per slot overrides of `style.preview`
    var previews: [WheelSlot: WheelPreviewMode] = [:]
    /// SF Symbols set per slot. An empty name hides the icon
    var icons: [WheelSlot: String] = [:]

    func preview(_ slot: WheelSlot) -> WheelPreviewMode { previews[slot] ?? style.preview }

    /// The SF Symbol for the release action of the slot: the one set in the config, or one derived from the action
    func icon(_ slot: WheelSlot) -> String? {
        guard style.icons else { return nil }
        if let icon = icons[slot] { return icon.isEmpty ? nil : icon }
        return action(slot, .release).flatMap(wheelAutoIcon)
    }
    /// Makes the profile a variant of the profile it extends: it replaces that profile when the wheel opens and the
    /// condition succeeds. Evaluated like 'test' commands, in the context of the focused window
    var condition: Shell<any Command>? = nil

    func action(_ slot: WheelSlot, _ finish: WheelFinish) -> Shell<any Command>? {
        actions[slot]?[finish]
    }
}

struct WheelStyleConfig: Equatable, Sendable {
    /// Percentage of the maximum corner radius: 0 is a square, 100 is a circle
    var cornerRadius: Int = 100
    /// Diameter in points
    var size: Int = 100
    /// Points. Bounded so that the center zone stays reachable
    var thickness: Int = 22
    var accentColor: WheelAccentColor = .system
    /// Trackpad haptic feedback when the selection changes
    var haptics: Bool = true
    /// Which windows the preview of the selected action outlines
    var preview: WheelPreviewMode = .target
    /// Points
    var previewCornerRadius: Int = 10
    /// Points. 0 draws no border
    var previewBorderWidth: Int = 2
    /// An icon for the release action of the selection in the center of the wheel
    var icons: Bool = true

    static let cornerRadiusRange = 0 ... 100
    static let sizeRange = 60 ... 240
    static let thicknessRange = 10 ... 60
    /// The hole of the ring keeps at least this radius, so that the center zone stays reachable past the dead zone
    static let minHoleRadius = 15

    var maxThickness: Int { size / 2 - Self.minHoleRadius }
    static let previewCornerRadiusRange = 0 ... 40
    static let previewBorderWidthRange = 0 ... 10

    func applying(_ overrides: WheelStyleOverrides) -> WheelStyleConfig {
        WheelStyleConfig(
            cornerRadius: overrides.cornerRadius ?? cornerRadius,
            size: overrides.size ?? size,
            thickness: overrides.thickness ?? thickness,
            accentColor: overrides.accentColor ?? accentColor,
            haptics: overrides.haptics ?? haptics,
            preview: overrides.preview ?? preview,
            previewCornerRadius: overrides.previewCornerRadius ?? previewCornerRadius,
            previewBorderWidth: overrides.previewBorderWidth ?? previewBorderWidth,
            icons: overrides.icons ?? icons,
        )
    }
}

/// Which windows the wheel outlines where the selected action would put them
enum WheelPreviewMode: String, CaseIterable, Equatable, Sendable {
    case off
    /// Only the window the action acts on
    case target
    /// Every window that the action moves or resizes
    case all
}

enum WheelAccentColor: Equatable, Sendable {
    /// The macOS accent color
    case system
    /// The most vibrant color of the wallpaper under the pointer
    case wallpaper
    case custom(RgbColor, gradientEnd: RgbColor?)
}

struct RgbColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    /// Parses '#RRGGBB'
    init?(hex: String) {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// Where the gesture ended
enum WheelSlot: String, CaseIterable, Sendable {
    case center, up, down, left, right
    case upLeft = "up-left", upRight = "up-right", downLeft = "down-left", downRight = "down-right"
}

/// How the gesture ended
enum WheelFinish: String, CaseIterable, Sendable {
    /// The keys that opened the wheel were released
    case release
    case leftClick = "left-click"
    case rightClick = "right-click"
    case otherClick = "other-click"
}

/// Modifier keys that open the wheel while held, like 'fn' or 'fn-shift'
struct WheelChord: Hashable, Sendable, CustomStringConvertible {
    var fn: Bool = false
    var modifiers: HotkeyModifiers = .none

    func matches(fnDown: Bool, _ pressed: PressedModifiers) -> Bool {
        fn == fnDown && modifiers.matches(pressed)
    }

    var description: String {
        let modifiers = modifiers.toString()
        return fn ? (modifiers.isEmpty ? "fn" : "fn-" + modifiers) : modifiers
    }
}

struct WheelTriggerBinding: Equatable, Sendable {
    let chord: WheelChord
    let profile: String
}

/// The trigger to follow for the modifiers that are held. Sided modifiers win over generic ones
func matchWheelTrigger(_ triggers: [WheelTriggerBinding], fnDown: Bool, _ pressed: PressedModifiers) -> WheelTriggerBinding? {
    triggers
        .filter { $0.chord.matches(fnDown: fnDown, pressed) }
        .max { $0.chord.modifiers.specificity < $1.chord.modifiers.specificity }
}

// MARK: - Parsing

/// Style keys that a profile sets. The rest are inherited
struct WheelStyleOverrides: Withable, Equatable, Sendable {
    var cornerRadius: Int? = nil
    var size: Int? = nil
    var thickness: Int? = nil
    var accentColor: WheelAccentColor? = nil
    var haptics: Bool? = nil
    var preview: WheelPreviewMode? = nil
    var previewCornerRadius: Int? = nil
    var previewBorderWidth: Int? = nil
    var icons: Bool? = nil
}

private struct WheelProfileDraft: Withable, Sendable {
    var extends: String? = nil
    var condition: Shell<any Command>? = nil
    var style = WheelStyleOverrides()
    var actions = WheelActionsDraft()
}

private struct WheelActionsDraft: Sendable {
    var actions: [WheelSlot: [WheelFinish: Shell<any Command>]] = [:]
    var previews: [WheelSlot: WheelPreviewMode] = [:]
    var icons: [WheelSlot: String] = [:]
}

private struct WheelDraft: Withable, Sendable {
    var style = WheelStyleOverrides()
    var profiles: [(name: String, draft: WheelProfileDraft)] = []
    var triggers: [WheelTriggerBinding]? = nil
    var releaseDelay: Int? = nil
}

private let profilesKey = "profiles"
private let triggersKey = "triggers"
private let extendsKey = "extends"
private let conditionKey = "if"
private let previewKey = "preview"
private let iconKey = "icon"

private let wheelParser: [String: any ParserProtocol<WheelDraft>] = [
    "corner-radius": Parser(\.style.cornerRadius, parseCornerRadius),
    "size": Parser(\.style.size) { parseIntInRange($0, $1, WheelStyleConfig.sizeRange).map(Optional.some) },
    "thickness": Parser(\.style.thickness, parseThickness),
    "accent-color": Parser(\.style.accentColor, parseOptionalAccentColor),
    "haptics": Parser(\.style.haptics, parseOptionalBool),
    "preview": Parser(\.style.preview, parseOptionalPreviewMode),
    "preview-corner-radius": Parser(\.style.previewCornerRadius) { parseIntInRange($0, $1, WheelStyleConfig.previewCornerRadiusRange).map(Optional.some) },
    "preview-border-width": Parser(\.style.previewBorderWidth) { parseIntInRange($0, $1, WheelStyleConfig.previewBorderWidthRange).map(Optional.some) },
    "icons": Parser(\.style.icons, parseOptionalBool),
    profilesKey: Parser(\.profiles, parseProfileDrafts),
    triggersKey: Parser(\.triggers) { parseTriggers($0, $1, &$2) },
    "release-delay": Parser(\.releaseDelay) { parseIntInRange($0, $1, WheelConfig.releaseDelayRange).map(Optional.some) },
]

private let profileParser: [String: any ParserProtocol<WheelProfileDraft>] = [
    "corner-radius": Parser(\.style.cornerRadius, parseCornerRadius),
    "size": Parser(\.style.size) { parseIntInRange($0, $1, WheelStyleConfig.sizeRange).map(Optional.some) },
    "thickness": Parser(\.style.thickness, parseThickness),
    "accent-color": Parser(\.style.accentColor, parseOptionalAccentColor),
    "haptics": Parser(\.style.haptics, parseOptionalBool),
    "preview": Parser(\.style.preview, parseOptionalPreviewMode),
    "preview-corner-radius": Parser(\.style.previewCornerRadius) { parseIntInRange($0, $1, WheelStyleConfig.previewCornerRadiusRange).map(Optional.some) },
    "preview-border-width": Parser(\.style.previewBorderWidth) { parseIntInRange($0, $1, WheelStyleConfig.previewBorderWidthRange).map(Optional.some) },
    "icons": Parser(\.style.icons, parseOptionalBool),
    extendsKey: Parser(\.extends) { parseString($0, $1).map(Optional.some) },
    conditionKey: Parser(\.condition, parseCondition),
    "actions": Parser(\.actions, parseActions),
]

private func parseCornerRadius(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<Int?> {
    parseIntInRange(raw, backtrace, WheelStyleConfig.cornerRadiusRange).map(Optional.some)
}

private func parseThickness(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<Int?> {
    parseIntInRange(raw, backtrace, WheelStyleConfig.thicknessRange).map(Optional.some)
}

private func parseOptionalAccentColor(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<WheelAccentColor?> {
    parseWheelAccentColor(raw, backtrace).map(Optional.some)
}

private func parseOptionalPreviewMode(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<WheelPreviewMode?> {
    parsePreviewMode(raw, backtrace).map(Optional.some)
}

private func parsePreviewMode(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<WheelPreviewMode> {
    parseString(raw, backtrace).flatMap { string in
        WheelPreviewMode(rawValue: string).toResult(.init(backtrace, "Expected \(WheelPreviewMode.allCases.lazy.map { "'\($0.rawValue)'" }.joined(separator: ", "))"))
    }
}

private func parseOptionalBool(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<Bool?> {
    parseBool(raw, backtrace).map(Optional.some)
}

func parseWheel(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> WheelConfig {
    let draft = parseNonEmptyTable(raw, WheelDraft(), wheelParser, backtrace, &c)
    return resolveWheel(draft, backtrace, &c)
}

private func parseProfileDrafts(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [(name: String, draft: WheelProfileDraft)] {
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
        return []
    }
    return table.compactMap { (name: String, value: OrderedJson) -> (name: String, draft: WheelProfileDraft)? in
        let backtrace = backtrace + .key(name)
        guard let profileTable = value.asDictOrNil else {
            c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: value.tomlType, backtrace))
            return nil
        }
        return (name, profileTable.parseTable(WheelProfileDraft(), profileParser, backtrace, &c, allowEmpty: true))
    }
}

/// Same syntax as the string form of the 'if' of on-window-detected: 'test' and 'test-not' commands joined with '&&',
/// '||' and parentheses
private func parseCondition(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> Shell<any Command>? {
    guard let rawString = parseString(raw, backtrace).getOrNil(appendErrorTo: &c.errors) else { return nil }
    return parseCommand(rawString, allowExecAndForget: false, allowEval: false).toResult().toParsedConfig(backtrace).getOrNil(appendErrorTo: &c.errors)
}

private func parseActions(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> WheelActionsDraft {
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
        return WheelActionsDraft()
    }
    var result = WheelActionsDraft()
    for (key, value) in table {
        let backtrace = backtrace + .key(key)
        guard let slot = WheelSlot(rawValue: key) else {
            c.errors.append(.init(backtrace, "Unknown wheel slot. Possible values: \(WheelSlot.allCases.map(\.rawValue).joined(separator: ", "))"))
            continue
        }
        if let finishes = value.asDictOrNil {
            // A table binds every way of finishing the gesture separately
            var slotActions: [WheelFinish: Shell<any Command>] = [:]
            for (finishKey, command) in finishes {
                let backtrace = backtrace + .key(finishKey)
                if finishKey == previewKey {
                    // Only the release action can be previewed: clicks run right away
                    result.previews[slot] = parsePreviewMode(command, backtrace).getOrNil(appendErrorTo: &c.errors)
                    continue
                }
                if finishKey == iconKey {
                    result.icons[slot] = parseIcon(command, backtrace).getOrNil(appendErrorTo: &c.errors)
                    continue
                }
                guard let finish = WheelFinish(rawValue: finishKey) else {
                    c.errors.append(.init(backtrace, "Unknown key. Possible values: \((WheelFinish.allCases.map(\.rawValue) + [previewKey, iconKey]).joined(separator: ", "))"))
                    continue
                }
                slotActions[finish] = parseShellOfCommandsForConfig(command, backtrace, &c)
            }
            result.actions[slot] = slotActions
        } else {
            // A plain command runs when the keys are released
            result.actions[slot] = [.release: parseShellOfCommandsForConfig(value, backtrace, &c)]
        }
    }
    return result
}

/// An SF Symbol name, or '' for no icon
private func parseIcon(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<String> {
    parseString(raw, backtrace).flatMap { name in
        name.isEmpty || isSfSymbol(name) ? .success(name) : .failure(.init(backtrace, "Unknown SF Symbol '\(name)'"))
    }
}

private func parseTriggers(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [WheelTriggerBinding] {
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
        return []
    }
    var result: [WheelTriggerBinding] = []
    for (rawChord, value) in table {
        let backtrace = backtrace + .key(rawChord)
        guard let chord = parseWheelChord(rawChord) else {
            c.errors.append(.init(backtrace, "Can't parse '\(rawChord)'. Expected modifiers like 'fn', 'fn-shift' or 'lalt-ralt'"))
            continue
        }
        if result.contains(where: { $0.chord == chord }) {
            c.errors.append(.init(backtrace, "'\(chord)' is declared twice"))
            continue
        }
        if let profile = parseString(value, backtrace).getOrNil(appendErrorTo: &c.errors) {
            result.append(WheelTriggerBinding(chord: chord, profile: profile))
        }
    }
    return result
}

func parseWheelChord(_ raw: String) -> WheelChord? {
    var chord = WheelChord()
    for token in raw.split(separator: "-", omittingEmptySubsequences: false) {
        if token == "fn" {
            if chord.fn { return nil }
            chord.fn = true
        } else if !chord.modifiers.add(token: String(token)) {
            return nil
        }
    }
    return chord.fn || !chord.modifiers.isEmpty ? chord : nil
}

private func parseIntInRange(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ range: ClosedRange<Int>) -> ResOrConfigParseDiagnostic<Int> {
    parseInt(raw, backtrace).flatMap { value in
        range.contains(value)
            ? .success(value)
            : .failure(.init(backtrace, "Must be in [\(range.lowerBound), \(range.upperBound)] range"))
    }
}

private func parseWheelAccentColor(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<WheelAccentColor> {
    let error = ConfigParseDiagnostic(backtrace, "Expected 'system', 'wallpaper', a '#RRGGBB' color, or an array of two '#RRGGBB' colors for a gradient")
    if let string = raw.asStringOrNil {
        return switch string {
            case "system": .success(.system)
            case "wallpaper": .success(.wallpaper)
            default: RgbColor(hex: string).map { .custom($0, gradientEnd: nil) }.toResult(error)
        }
    }
    if let array = raw.asArrayOrNil, array.count == 2,
       let start = array[0].asStringOrNil.flatMap(RgbColor.init(hex:)),
       let end = array[1].asStringOrNil.flatMap(RgbColor.init(hex:))
    {
        return .success(.custom(start, gradientEnd: end))
    }
    return .failure(error)
}

// MARK: - Inheritance

/// Keeps the center zone reachable. Returns the error if the thickness had to be reduced
private func boundThickness(_ style: inout WheelStyleConfig) -> String? {
    guard style.thickness > style.maxThickness else { return nil }
    defer { style.thickness = style.maxThickness }
    return "The thickness (\(style.thickness)) leaves no room for the center: a wheel of size \(style.size) takes at most \(style.maxThickness)"
}

/// Every profile starts from the style of 'default' (the top-level style keys plus its own table). A profile that
/// extends another one inherits its style and its actions, and overrides them key by key: style keys one by one, and
/// actions per (slot, finish) pair. An empty command ('') unbinds an inherited action. Icons describe the release action,
/// so a profile that rebinds it without setting the icon gets the automatic one.
private func resolveWheel(_ draft: WheelDraft, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> WheelConfig {
    let profilesBacktrace = backtrace + .key(profilesKey)
    var drafts: [String: WheelProfileDraft] = [defaultWheelProfile: WheelProfileDraft()]
    for (name, profile) in draft.profiles {
        drafts[name] = profile
    }
    if drafts[defaultWheelProfile]?.extends != nil {
        c.errors.append(.init(profilesBacktrace + .key(defaultWheelProfile) + .key(extendsKey), "The default profile can't extend other profiles"))
        drafts[defaultWheelProfile]?.extends = nil
    }
    for (name, profile) in drafts {
        if let parent = profile.extends, drafts[parent] == nil {
            c.errors.append(.init(profilesBacktrace + .key(name) + .key(extendsKey), "Unknown wheel profile '\(parent)'"))
            drafts[name]?.extends = nil
        }
    }
    for (name, profile) in drafts where profile.condition != nil && profile.extends == nil {
        c.errors.append(.init(profilesBacktrace + .key(name) + .key(conditionKey), "A profile with 'if' must extend the profile it replaces"))
        drafts[name]?.condition = nil
    }

    var baseStyle = WheelStyleConfig().applying(draft.style)
    if let error = boundThickness(&baseStyle) {
        c.errors.append(.init(backtrace, error))
    }
    baseStyle = baseStyle.applying(drafts[defaultWheelProfile]?.style ?? WheelStyleOverrides())
    var resolved: [String: WheelProfile] = [:]
    func resolve(_ name: String, _ visiting: [String]) -> WheelProfile {
        if let profile = resolved[name] { return profile }
        let profileDraft = drafts[name] ?? WheelProfileDraft()
        var parent: WheelProfile? = nil
        if let parentName = profileDraft.extends {
            if visiting.contains(parentName) {
                c.errors.append(.init(profilesBacktrace + .key(name) + .key(extendsKey), "Wheel profiles extend each other in a cycle: \((visiting + [name, parentName]).joined(separator: " -> "))"))
            } else {
                parent = resolve(parentName, visiting + [name])
            }
        }
        var profile = WheelProfile()
        profile.condition = profileDraft.condition
        profile.style = name == defaultWheelProfile ? baseStyle : (parent?.style ?? baseStyle).applying(profileDraft.style)
        profile.actions = parent?.actions ?? [:]
        for (slot, finishes) in profileDraft.actions.actions {
            for (finish, command) in finishes {
                profile.actions[slot, default: [:]][finish] = command
            }
        }
        profile.previews = (parent?.previews ?? [:]).merging(profileDraft.actions.previews) { $1 }
        profile.icons = parent?.icons ?? [:]
        for (slot, finishes) in profileDraft.actions.actions where finishes[.release] != nil {
            profile.icons[slot] = nil
        }
        profile.icons.merge(profileDraft.actions.icons) { $1 }
        // The style a profile inherits fits already, so only profiles that change the size or the thickness can break it
        let setsShape = profileDraft.style.size != nil || profileDraft.style.thickness != nil
        if setsShape, let error = boundThickness(&profile.style) {
            c.errors.append(.init(profilesBacktrace + .key(name), error))
        }
        resolved[name] = profile
        return profile
    }
    for name in drafts.keys {
        _ = resolve(name, [])
    }

    var result = WheelConfig()
    result.profiles = resolved
    // Sorted by name here, and by their order in the config file once the whole file is parsed (see parseConfig)
    for (name, _) in draft.profiles.sorted(by: { $0.name < $1.name }) {
        if let base = drafts[name]?.extends, drafts[name]?.condition != nil {
            result.variants[base, default: []].append(name)
        }
    }
    result.releaseDelay = draft.releaseDelay ?? result.releaseDelay
    if let triggers = draft.triggers {
        for trigger in triggers where resolved[trigger.profile] == nil {
            c.errors.append(.init(backtrace + .key(triggersKey) + .key(trigger.chord.description), "Unknown wheel profile '\(trigger.profile)'"))
        }
        result.triggers = triggers.filter { resolved[$0.profile] != nil }
    }
    return result
}
