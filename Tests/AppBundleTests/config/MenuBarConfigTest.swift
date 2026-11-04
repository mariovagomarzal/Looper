@testable import AppBundle
import Common
import XCTest

@MainActor
final class MenuBarConfigTest: XCTestCase {
    private typealias Item = MenuBarState.WorkspaceItem

    private func render(_ toml: String, _ state: MenuBarState) -> [MenuBarSegment] {
        let result = parseConfig(toml)
        XCTAssertEqual(result.strErrors, [])
        return renderMenuBar(result.config.menuBar, state)
    }

    func testDefault() {
        let state = MenuBarState(monitors: [
            [Item(name: "1", monitor: "A", state: .focused), Item(name: "2", monitor: "A", state: .occupied), Item(name: "3", monitor: "A", state: .empty)],
            [Item(name: "dev", monitor: "B", state: .visible)],
        ])
        assertEquals(render("", state), [.symbol("looper"), .text(" "), .symbol("1.square.fill"), .text(" │ dev")])
        // The mode comes first, separated by a space
        assertEquals(render("", state.with(\.mode, "service")), [.symbol("looper"), .text(" "), .symbol("s.circle"), .text(" "), .symbol("1.square.fill"), .text(" │ dev")])
    }

    func testTemplates() {
        let state = MenuBarState(appName: "Ghostty", monitors: [
            [Item(name: "a", monitor: "Main", state: .focused), Item(name: "b", monitor: "Main", state: .occupied), Item(name: "c", monitor: "Main", state: .empty)],
            [Item(name: "d", monitor: "Side", state: .empty)],
        ])
        let segments = render(
            """
            menu-bar.format = '%{mode} %{workspaces}  %{app-name}::'
            menu-bar.monitor-separator = ':poweron:'
            [menu-bar.workspace]
                focused = ':%{workspace}.circle.fill:'
                occupied = '%{workspace}'
                empty = '(%{workspace}@%{monitor})'
            """,
            state,
        )
        assertEquals(segments, [.symbol("a.circle.fill"), .text(" b (c@Main)"), .symbol("poweron"), .text("(d@Side)  Ghostty:")])
    }

    func testAlternativesAndMissingSymbols() {
        let toml = "menu-bar.format = '%{workspaces}'\nmenu-bar.workspace.focused = [':%{workspace}.square.fill:', '[%{workspace}]']"
        let state = MenuBarState(monitors: [[Item(name: "Dev", monitor: "A", state: .focused)]])
        assertEquals(render(toml, state), [.text("[Dev]")])
        assertEquals(render(toml, MenuBarState(monitors: [[Item(name: "B", monitor: "A", state: .focused)]])), [.symbol("b.square.fill")])
        // Without a drawable alternative, the name of the symbol is shown
        assertEquals(render("menu-bar.format = '%{workspaces}'\nmenu-bar.workspace.focused = ':%{workspace}.square:'", state), [.text("dev.square")])
    }

    func testModes() {
        let toml = """
            menu-bar.format = '%{mode}%{workspaces}'
            menu-bar.workspace.focused = '%{workspace}'
            [menu-bar.mode]
                main = '·'
                resize = ':arrow.up.left.and.arrow.down.right:'
                '*' = '%{mode|capitalize}:: '
            [mode.main.binding]
            [mode.resize.binding]
            [mode.service.binding]
            """
        let state = MenuBarState(monitors: [[Item(name: "1", monitor: "A", state: .focused)]])
        assertEquals(render(toml, state), [.text("·1")])
        assertEquals(render(toml, state.with(\.mode, "resize")), [.symbol("arrow.up.left.and.arrow.down.right"), .text("1")])
        assertEquals(render(toml, state.with(\.mode, "service")), [.text("Service: 1")])
        // A single template applies to every mode but the main one
        let single = "menu-bar.format = '%{mode} %{workspaces}'\nmenu-bar.mode = '[%{mode|initial|upper}]'\nmenu-bar.workspace.focused = '%{workspace}'"
        assertEquals(render(single, state), [.text("1")])
        assertEquals(render(single, state.with(\.mode, "service")), [.text("[S] 1")])
    }

    func testNamedWorkspaces() {
        let toml = """
            menu-bar.format = '%{workspaces}'
            menu-bar.workspace.focused = '[%{workspace}]'
            menu-bar.workspace.occupied = '%{workspace}'
            [menu-bar.named-workspace]
                web = ':globe:'
                mail = { focused = ':envelope.fill:', empty = ':envelope:' }
                secret = ''
            """
        func items(_ states: [(String, MenuBarWorkspaceState)]) -> MenuBarState {
            MenuBarState(monitors: [states.map { Item(name: $0.0, monitor: "A", state: $0.1) }])
        }
        // A plain template applies in the states that show workspaces only
        assertEquals(render(toml, items([("web", .focused), ("1", .occupied), ("secret", .occupied)])), [.symbol("globe"), .text(" 1")])
        assertEquals(render(toml, items([("web", .empty), ("1", .focused)])), [.text("[1]")])
        // A table overrides per state, and the rest of the states use the template for every workspace
        assertEquals(render(toml, items([("mail", .focused)])), [.symbol("envelope.fill")])
        assertEquals(render(toml, items([("mail", .empty)])), [.symbol("envelope")])
        assertEquals(render(toml, items([("mail", .occupied)])), [.text("mail")])
    }

    func testEmptyVariablesTakeASpaceAlong() {
        let state = MenuBarState(monitors: [[Item(name: "1", monitor: "A", state: .focused)]])
        let workspace = "menu-bar.workspace.focused = '%{workspace}'\n"
        assertEquals(render(workspace + "menu-bar.format = '%{mode} %{workspaces} %{app-name}'", state), [.text("1")])
        assertEquals(render(workspace + "menu-bar.format = '<%{mode}>'", state), [.text("<>")])
    }

    func testErrors() {
        assertEquals(parseConfig("menu-bar.format = '%{workspace}'").strErrors, [
            "[ERROR] menu-bar.format: Unknown variable '%{workspace}' in '%{workspace}'. Possible values: %{mode}, %{workspaces}, %{app-name}",
        ])
        assertEquals(parseConfig("menu-bar.format = ':oops'").strErrors, ["[ERROR] menu-bar.format: Unclosed symbol in ':oops'. Write '::' for a colon"])
        assertEquals(parseConfig("menu-bar.format = ':no-such-symbol:'").strErrors, ["[ERROR] menu-bar.format: Unknown SF Symbol 'no-such-symbol' in ':no-such-symbol:'"])
        assertEquals(parseConfig("menu-bar.workspace.hidden = 'x'").strErrors, ["[ERROR] menu-bar.workspace.hidden: Unknown workspace state. Possible values: focused, visible, occupied, empty"])
        assertEquals(parseConfig("menu-bar.format = '%{app-name|shout}'").strErrors, [
            "[ERROR] menu-bar.format: Unknown filter 'shout' in '%{app-name|shout}'. Possible values: upper, lower, capitalize, initial",
        ])
        assertEquals(parseConfig("menu-bar.format = '%{mode|upper}'").strErrors, [
            "[ERROR] menu-bar.format: '%{mode}' can't be filtered in '%{mode|upper}': it's drawn with 'menu-bar.mode'",
        ])
        assertEquals(parseConfig("menu-bar.mode.nope = 'x'").strErrors, ["[ERROR] menu-bar.mode.nope: Unknown mode 'nope'"])
        assertEquals(parseConfig("menu-bar.monitor-separator = []").strErrors, ["[ERROR] menu-bar.monitor-separator: Expected a template string or a non-empty array of template strings"])
    }
}
