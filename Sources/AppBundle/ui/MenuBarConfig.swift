import Common

// What the menu bar shows, written as templates: text, variables ('%{workspace}', with filters: '%{mode|initial|upper}')
// and SF Symbols between colons (':1.square.fill:', also with variables: ':%{workspace}.square:'). '::' is a literal
// colon. A list of templates is a list of alternatives: the first one whose symbols all exist is shown.

struct MenuBarConfig: Equatable, Sendable {
    var format: MenuBarAlternatives = parseDefault("%{mode} %{workspaces}", .format)
    /// Templates of the active mode, by mode name. `anyMode` applies to the modes without their own, except the main one
    var mode: [String: MenuBarAlternatives] = [anyMode: parseDefault([":%{mode|initial}.circle:", "(%{mode|initial|upper})"], .mode)]
    /// Templates of the workspaces in each state. Workspaces in a state without a template aren't shown
    var workspace: [MenuBarWorkspaceState: MenuBarAlternatives] = [
        .focused: parseDefault([":%{workspace}.square.fill:", "[%{workspace}]"], .workspace),
        .visible: parseDefault([":%{workspace}.square:", "%{workspace}"], .workspace),
    ]
    /// Shown between the workspaces of different monitors
    var monitorSeparator: MenuBarAlternatives = parseDefault(" │ ", .separator)

    /// Templates of single workspaces, by name. They override `workspace`
    var namedWorkspace: [String: MenuBarNamedWorkspace] = [:]

    static let anyMode = "*"

    /// The template of a workspace in a state, or nil if it isn't shown
    func workspaceTemplate(_ name: String, _ state: MenuBarWorkspaceState) -> MenuBarAlternatives? {
        switch namedWorkspace[name] {
            // A plain template replaces the look in the states that show workspaces
            case .always(let template): workspace[state] == nil ? nil : template
            case .byState(let templates): templates[state] ?? workspace[state]
            case nil: workspace[state]
        }
    }
}

enum MenuBarNamedWorkspace: Equatable, Sendable {
    case always(MenuBarAlternatives)
    /// Per state, falling back to the template of the state for every workspace
    case byState([MenuBarWorkspaceState: MenuBarAlternatives])
}

enum MenuBarWorkspaceState: String, CaseIterable, Sendable {
    /// The focused workspace
    case focused
    /// Visible on another monitor
    case visible
    /// Has windows, but isn't visible
    case occupied
    case empty
}

enum MenuBarVariable: String, CaseIterable, Sendable {
    case mode, workspaces
    case appName = "app-name"
    case workspace, monitor
}

/// Where a template is used, which decides its variables
enum MenuBarContext: Sendable {
    case format, mode, workspace, separator

    var variables: [MenuBarVariable] {
        switch self {
            case .format: [.mode, .workspaces, .appName]
            case .mode: [.mode]
            case .workspace: [.workspace, .monitor]
            case .separator: []
        }
    }

    /// Variables drawn with their own templates, which may contain symbols, so they can't be filtered
    var drawnVariables: [MenuBarVariable] {
        self == .format ? [.mode, .workspaces] : []
    }
}

enum MenuBarFilter: String, CaseIterable, Sendable {
    case upper, lower, capitalize
    /// The first character
    case initial

    func apply(_ value: String) -> String {
        switch self {
            case .upper: value.uppercased()
            case .lower: value.lowercased()
            case .capitalize: value.prefix(1).uppercased() + value.dropFirst()
            case .initial: value.first.map(String.init) ?? ""
        }
    }
}

enum MenuBarToken: Equatable, Sendable {
    case text(String)
    case variable(MenuBarVariable, [MenuBarFilter])
    /// The name of an SF Symbol, which may contain variables
    case symbol([MenuBarToken])
}

typealias MenuBarTemplate = [MenuBarToken]
typealias MenuBarAlternatives = [MenuBarTemplate]

/// What the menu bar draws, left to right
enum MenuBarSegment: Equatable, Sendable {
    case text(String)
    case symbol(String)
}

// MARK: - Parsing

private struct MenuBarDraft: Withable, Sendable {
    var config = MenuBarConfig()
}

private let menuBarParser: [String: any ParserProtocol<MenuBarDraft>] = [
    "format": Parser(\.config.format) { parseAlternatives($0, $1, .format) },
    "mode": Parser(\.config.mode, parseModeTemplates),
    "workspace": Parser(\.config.workspace) { parseWorkspaceTemplates($0, $1, &$2) ?? MenuBarConfig().workspace },
    "named-workspace": Parser(\.config.namedWorkspace, parseNamedWorkspaces),
    "monitor-separator": Parser(\.config.monitorSeparator) { parseAlternatives($0, $1, .separator) },
]

func parseMenuBar(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> MenuBarConfig {
    parseNonEmptyTable(raw, MenuBarDraft(), menuBarParser, backtrace, &c).config
}

/// A template for every mode but the main one, or a table of templates by mode name, with '*' for the rest of the modes
/// except the main one
private func parseModeTemplates(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: MenuBarAlternatives] {
    guard let table = raw.asDictOrNil else {
        return parseAlternatives(raw, backtrace, .mode).getOrNil(appendErrorTo: &c.errors).map { [MenuBarConfig.anyMode: $0] } ?? MenuBarConfig().mode
    }
    var result: [String: MenuBarAlternatives] = [:]
    for (key, value) in table {
        result[key] = parseAlternatives(value, backtrace + .key(key), .mode).getOrNil(appendErrorTo: &c.errors)
    }
    return result
}

/// A template for every state that shows workspaces, or a table of templates by state
private func parseNamedWorkspaces(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: MenuBarNamedWorkspace] {
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
        return [:]
    }
    var result: [String: MenuBarNamedWorkspace] = [:]
    for (name, value) in table {
        let backtrace = backtrace + .key(name)
        if value.asDictOrNil != nil {
            result[name] = parseWorkspaceTemplates(value, backtrace, &c).map(MenuBarNamedWorkspace.byState)
        } else {
            result[name] = parseAlternatives(value, backtrace, .workspace).getOrNil(appendErrorTo: &c.errors).map(MenuBarNamedWorkspace.always)
        }
    }
    return result
}

/// Setting the table replaces every state: the states it leaves out aren't shown
private func parseWorkspaceTemplates(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [MenuBarWorkspaceState: MenuBarAlternatives]? {
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
        return nil
    }
    var result: [MenuBarWorkspaceState: MenuBarAlternatives] = [:]
    for (key, value) in table {
        let backtrace = backtrace + .key(key)
        guard let state = MenuBarWorkspaceState(rawValue: key) else {
            c.errors.append(.init(backtrace, "Unknown workspace state. Possible values: \(MenuBarWorkspaceState.allCases.map(\.rawValue).joined(separator: ", "))"))
            continue
        }
        result[state] = parseAlternatives(value, backtrace, .workspace).getOrNil(appendErrorTo: &c.errors)
    }
    return result
}

private func parseAlternatives(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ context: MenuBarContext) -> ResOrConfigParseDiagnostic<MenuBarAlternatives> {
    let strings: [String]
    if let string = raw.asStringOrNil {
        strings = [string]
    } else if let array = raw.asArrayOrNil, !array.isEmpty, array.allSatisfy({ $0.asStringOrNil != nil }) {
        strings = array.compactMap(\.asStringOrNil)
    } else {
        return .failure(.init(backtrace, "Expected a template string or a non-empty array of template strings"))
    }
    var result: MenuBarAlternatives = []
    for string in strings {
        switch parseMenuBarTemplate(string, context) {
            case .success(let template): result.append(template)
            case .failure(let error): return .failure(.init(backtrace, error.message))
        }
    }
    return .success(result)
}

private func parseDefault(_ string: String, _ context: MenuBarContext) -> MenuBarAlternatives {
    parseDefault([string], context)
}

private func parseDefault(_ strings: [String], _ context: MenuBarContext) -> MenuBarAlternatives {
    strings.map { (try? parseMenuBarTemplate($0, context).get()) ?? [] }
}

struct MenuBarTemplateError: Error, Equatable {
    let message: String
}

func parseMenuBarTemplate(_ raw: String, _ context: MenuBarContext) -> Result<MenuBarTemplate, MenuBarTemplateError> {
    let variables = context.variables
    func failure(_ message: String) -> Result<MenuBarTemplate, MenuBarTemplateError> { .failure(MenuBarTemplateError(message: message)) }
    var tokens: MenuBarTemplate = []
    var symbol: [MenuBarToken]? = nil
    var text = ""
    func flushText() {
        guard !text.isEmpty else { return }
        if symbol != nil { symbol?.append(.text(text)) } else { tokens.append(.text(text)) }
        text = ""
    }
    var rest = Substring(raw)
    while let char = rest.first {
        if rest.hasPrefix("%{") {
            guard let end = rest.firstIndex(of: "}") else { return failure("Unclosed variable in '\(raw)'") }
            let parts = rest[rest.index(rest.startIndex, offsetBy: 2) ..< end].split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            let name = parts[0]
            guard let variable = MenuBarVariable(rawValue: name), variables.contains(variable) else {
                let possible = variables.isEmpty ? "none" : variables.lazy.map { "%{\($0.rawValue)}" }.joined(separator: ", ")
                return failure("Unknown variable '%{\(name)}' in '\(raw)'. Possible values: \(possible)")
            }
            var filters: [MenuBarFilter] = []
            for filterName in parts.dropFirst() {
                guard let filter = MenuBarFilter(rawValue: filterName) else {
                    return failure("Unknown filter '\(filterName)' in '\(raw)'. Possible values: \(MenuBarFilter.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                filters.append(filter)
            }
            let isDrawn = context.drawnVariables.contains(variable)
            if isDrawn, !filters.isEmpty {
                return failure("'%{\(name)}' can't be filtered in '\(raw)': it's drawn with 'menu-bar.\(name == "mode" ? "mode" : "workspace")'")
            }
            if isDrawn, symbol != nil { return failure("'%{\(name)}' can't be part of a symbol name in '\(raw)'") }
            flushText()
            if symbol != nil { symbol?.append(.variable(variable, filters)) } else { tokens.append(.variable(variable, filters)) }
            rest = rest[rest.index(after: end)...]
        } else if rest.hasPrefix("::") {
            text.append(":")
            rest = rest.dropFirst(2)
        } else if char == ":" {
            flushText()
            if let name = symbol {
                if name.isEmpty { return failure("Empty symbol name in '\(raw)'") }
                if case .some(let constant) = constantSymbolName(name), !isSfSymbol(constant) {
                    return failure("Unknown SF Symbol '\(constant)' in '\(raw)'")
                }
                tokens.append(.symbol(name))
                symbol = nil
            } else {
                symbol = []
            }
            rest = rest.dropFirst()
        } else {
            text.append(char)
            rest = rest.dropFirst()
        }
    }
    if symbol != nil { return failure("Unclosed symbol in '\(raw)'. Write '::' for a colon") }
    flushText()
    return .success(tokens)
}

/// The name of a symbol without variables
private func constantSymbolName(_ name: [MenuBarToken]) -> String? {
    name.reduce(Optional("")) { result, token in
        if case .text(let text) = token { result.map { $0 + text } } else { nil }
    }
}

// MARK: - Rendering

struct MenuBarState: Equatable, Sendable, Withable {
    struct WorkspaceItem: Equatable, Sendable {
        let name: String
        let monitor: String
        let state: MenuBarWorkspaceState
    }

    /// The active mode
    var mode: String = mainModeId
    var appName: String? = nil
    /// Workspaces of every monitor, left to right
    var monitors: [[WorkspaceItem]] = []
}

/// Renders the menu bar. `symbolExists` is `isSfSymbol`, injectable for tests
func renderMenuBar(_ config: MenuBarConfig, _ state: MenuBarState, symbolExists: (String) -> Bool = isSfSymbol) -> [MenuBarSegment] {
    var workspaces: [MenuBarSegment] = []
    var isFirstGroup = true
    for monitor in state.monitors {
        var group: [MenuBarSegment] = []
        for item in monitor {
            guard let alternatives = config.workspaceTemplate(item.name, item.state) else { continue }
            let rendered = renderAlternatives(alternatives, symbolExists) { variable in
                switch variable {
                    case .workspace: item.name
                    case .monitor: item.monitor
                    default: ""
                }
            }
            if rendered.isEmpty { continue }
            if !group.isEmpty { group.append(.text(" ")) }
            group += rendered
        }
        if group.isEmpty { continue }
        if !isFirstGroup { workspaces += renderAlternatives(config.monitorSeparator, symbolExists) { _ in "" } }
        isFirstGroup = false
        workspaces += group
    }
    let modeTemplate = config.mode[state.mode] ?? (state.mode == mainModeId ? nil : config.mode[MenuBarConfig.anyMode])
    let mode = modeTemplate.map { renderAlternatives($0, symbolExists) { _ in state.mode } } ?? []
    return renderAlternatives(config.format, symbolExists, drawn: [.mode: mode, .workspaces: workspaces]) { variable in
        variable == .appName ? state.appName ?? "" : ""
    }
}

private func renderAlternatives(
    _ alternatives: MenuBarAlternatives,
    _ symbolExists: (String) -> Bool,
    drawn: [MenuBarVariable: [MenuBarSegment]] = [:],
    _ value: (MenuBarVariable) -> String,
) -> [MenuBarSegment] {
    let rendered = alternatives.map { render($0, drawn, value) }
    let isDrawable: ([MenuBarSegment]) -> Bool = { segments in
        segments.allSatisfy { if case .symbol(let name) = $0 { symbolExists(name) } else { true } }
    }
    // When no alternative can be drawn, the names of the missing symbols are shown instead
    let chosen = rendered.first(where: isDrawable) ?? rendered.last ?? []
    return mergeTexts(chosen.map { segment in
        if case .symbol(let name) = segment, !symbolExists(name) { .text(name) } else { segment }
    })
}

private func render(_ template: MenuBarTemplate, _ drawn: [MenuBarVariable: [MenuBarSegment]], _ value: (MenuBarVariable) -> String) -> [MenuBarSegment] {
    func filtered(_ variable: MenuBarVariable, _ filters: [MenuBarFilter]) -> String {
        filters.reduce(value(variable)) { $1.apply($0) }
    }
    var result: [MenuBarSegment] = []
    var dropLeadingSpace = false
    for (index, token) in template.enumerated() {
        switch token {
            case .text(var text):
                if dropLeadingSpace, text.first == " " { text.removeFirst() }
                dropLeadingSpace = false
                result.append(.text(text))
            case .variable(let variable, let filters):
                let text = filtered(variable, filters)
                let segments: [MenuBarSegment] = drawn[variable] ?? (text.isEmpty ? [] : [.text(text)])
                if !segments.isEmpty {
                    result += segments
                    continue
                }
                // An empty variable takes a space next to it along: the one after it, or else the one before it
                if index + 1 < template.count, case .text(let next) = template[index + 1], next.first == " " {
                    dropLeadingSpace = true
                } else if case .text(var previous) = result.last, previous.last == " " {
                    previous.removeLast()
                    result[result.count - 1] = .text(previous)
                }
            case .symbol(let name):
                let expanded = name.map { part in
                    switch part {
                        case .text(let text): text
                        case .variable(let variable, let filters): filtered(variable, filters)
                        case .symbol: ""
                    }
                }.joined()
                // SF Symbol names are lowercase, while workspace names may not be
                result.append(.symbol(expanded.lowercased()))
        }
    }
    return result.filter { $0 != .text("") }
}

private func mergeTexts(_ segments: [MenuBarSegment]) -> [MenuBarSegment] {
    var result: [MenuBarSegment] = []
    for segment in segments {
        if case .text(let text) = segment, case .text(let previous) = result.last {
            result[result.count - 1] = .text(previous + text)
        } else {
            result.append(segment)
        }
    }
    return result
}

extension [MenuBarSegment] {
    /// For accessibility and as a fallback when the image can't be drawn
    var plainText: String {
        map { segment in
            switch segment {
                case .text(let text): text
                case .symbol(let name): name
            }
        }.joined()
    }
}
