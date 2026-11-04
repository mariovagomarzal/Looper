@testable import AppBundle
import Common
import XCTest

@MainActor
final class WheelTest: XCTestCase {
    func testParseWheelStyle() {
        let result = parseConfig(
            """
            wheel.corner-radius = 60
            wheel.thickness = 30
            wheel.accent-color = ['#ff0000', '#0000FF']
            wheel.haptics = false
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.wheel.profiles["default"]?.style, WheelStyleConfig(
            cornerRadius: 60,
            thickness: 30,
            accentColor: .custom(RgbColor(red: 1, green: 0, blue: 0), gradientEnd: RgbColor(red: 0, green: 0, blue: 1)),
            haptics: false,
        ))

        assertEquals(parseConfig("wheel.accent-color = 'wallpaper'").config.wheel.profiles["default"]?.style.accentColor, .wallpaper)
        assertEquals(parseConfig("wheel.accent-color = '#00ff00'").config.wheel.profiles["default"]?.style.accentColor, .custom(RgbColor(red: 0, green: 1, blue: 0), gradientEnd: nil))
    }

    func testDefaults() {
        let wheel = parseConfig("").config.wheel
        assertEquals(Array(wheel.profiles.keys), ["default"])
        assertEquals(wheel.profiles["default"]?.style, WheelStyleConfig())
        XCTAssertTrue(wheel.profiles["default"]?.actions.isEmpty == true)
        assertEquals(wheel.triggers, [WheelTriggerBinding(chord: WheelChord(fn: true), profile: "default")])
    }

    func testParseWheelStyleErrors() {
        let result = parseConfig(
            """
            wheel.corner-radius = 101
            wheel.thickness = 5
            wheel.accent-color = 'blue'
            """,
        )
        assertEquals(result.strErrors.sorted(), [
            "[ERROR] wheel.accent-color: Expected 'system', 'wallpaper', a '#RRGGBB' color, or an array of two '#RRGGBB' colors for a gradient",
            "[ERROR] wheel.corner-radius: Must be in [0, 100] range",
            "[ERROR] wheel.thickness: Must be in [10, 60] range",
        ])
    }

    func testProfilesInheritStyle() {
        let result = parseConfig(
            """
            wheel.thickness = 30

            [wheel.profiles.default]
            corner-radius = 50

            [wheel.profiles.workspaces]
            accent-color = '#e8a33d'

            [wheel.profiles.thin]
            extends = 'workspaces'
            thickness = 12
            """,
        )
        assertEquals(result.errors, [])
        let profiles = result.config.wheel.profiles
        let orange = WheelAccentColor.custom(RgbColor(hex: "#e8a33d")!, gradientEnd: nil)
        assertEquals(profiles["default"]?.style, WheelStyleConfig(cornerRadius: 50, thickness: 30))
        // Without 'extends', a profile still starts from the style of 'default'
        assertEquals(profiles["workspaces"]?.style, WheelStyleConfig(cornerRadius: 50, thickness: 30, accentColor: orange))
        assertEquals(profiles["thin"]?.style, WheelStyleConfig(cornerRadius: 50, thickness: 12, accentColor: orange))
    }

    func testProfilesInheritActionsOnlyWithExtends() {
        let result = parseConfig(
            """
            [wheel.profiles.default.actions]
            left = 'focus left'
            right = { release = 'focus right', left-click = 'move right' }
            center = 'fullscreen'

            [wheel.profiles.floating]
            extends = 'default'
            [wheel.profiles.floating.actions]
            right = 'layout tiling' # Overrides the release action only
            center = ''             # Unbinds the inherited action

            [wheel.profiles.workspaces.actions]
            up = 'workspace next'
            """,
        )
        assertEquals(result.errors, [])
        let profiles = result.config.wheel.profiles
        func action(_ profile: String, _ slot: WheelSlot, _ finish: WheelFinish) -> String? {
            profiles[profile]?.action(slot, finish).map { String(describing: $0) }
        }
        let focusLeft = String(describing: parseCommand("focus left").cmdOrNil!)
        XCTAssertNotNil(action("default", .left, .release))
        assertEquals(action("floating", .left, .release), action("default", .left, .release))
        XCTAssertTrue(action("floating", .left, .release)?.contains("focus") == true, focusLeft)
        assertEquals(action("floating", .right, .leftClick), action("default", .right, .leftClick))
        XCTAssertNotEqual(action("floating", .right, .release), action("default", .right, .release))
        if case .empty? = profiles["floating"]?.action(.center, .release) {} else { XCTFail("center must be unbound") }
        XCTAssertNil(action("default", .left, .rightClick))
        // Without 'extends', actions start empty
        XCTAssertNil(action("workspaces", .left, .release))
        XCTAssertNotNil(action("workspaces", .up, .release))
    }

    func testProfileErrors() {
        let result = parseConfig(
            """
            [wheel.profiles.default]
            extends = 'a'

            [wheel.profiles.a]
            extends = 'b'

            [wheel.profiles.b]
            extends = 'a'

            [wheel.profiles.c]
            extends = 'unknown'

            [wheel.profiles.c.actions]
            sideways = 'focus left'
            left = { double-click = 'focus left' }

            [wheel.triggers]
            fn = 'unknown'
            fn-shift = 'c'
            shift-fn = 'c'
            fn-foo = 'c'
            """,
        )
        let errors = result.strErrors.sorted()
        assertEquals(errors.count, 8, additionalMsg: errors.joined(separator: "\n"))
        XCTAssertTrue(errors.contains("[ERROR] wheel.profiles.default.extends: The default profile can't extend other profiles"))
        XCTAssertTrue(errors.contains("[ERROR] wheel.profiles.c.extends: Unknown wheel profile 'unknown'"))
        XCTAssertTrue(errors.contains { $0.contains("extend each other in a cycle") })
        XCTAssertTrue(errors.contains { $0.hasPrefix("[ERROR] wheel.profiles.c.actions.sideways: Unknown wheel slot") })
        XCTAssertTrue(errors.contains { $0.hasPrefix("[ERROR] wheel.profiles.c.actions.left.double-click: Unknown key. Possible values: release, left-click, right-click, other-click, preview, icon") })
        XCTAssertTrue(errors.contains("[ERROR] wheel.triggers.fn: Unknown wheel profile 'unknown'"))
        XCTAssertTrue(errors.contains("[ERROR] wheel.triggers.shift-fn: 'fn-shift' is declared twice"))
        XCTAssertTrue(errors.contains { $0.hasPrefix("[ERROR] wheel.triggers.fn-foo: Can't parse 'fn-foo'") })
    }

    func testParseTriggers() {
        let result = parseConfig(
            """
            [wheel.profiles.workspaces]
            [wheel.triggers]
            fn = 'default'
            fn-shift = 'workspaces'
            lalt-ralt = 'workspaces'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.wheel.triggers, [
            WheelTriggerBinding(chord: WheelChord(fn: true), profile: "default"),
            WheelTriggerBinding(chord: WheelChord(fn: true, modifiers: HotkeyModifiers([.shift: .either])), profile: "workspaces"),
            WheelTriggerBinding(chord: WheelChord(modifiers: HotkeyModifiers([.alt: .both])), profile: "workspaces"),
        ])
        // An explicitly empty table disables the triggers
        XCTAssertTrue(parseConfig("wheel.triggers = {}").config.wheel.triggers.isEmpty)
    }

    func testTapMachineHoldSwitchAndRelease() {
        let triggers = [
            WheelTriggerBinding(chord: WheelChord(fn: true), profile: "default"),
            WheelTriggerBinding(chord: WheelChord(fn: true, modifiers: HotkeyModifiers([.shift: .either])), profile: "workspaces"),
        ]
        let shift = PressedModifiers(left: [.shift])
        var machine = WheelTapMachine()
        // shift alone matches no trigger
        assertNil(machine.modifiersChanged(fnDown: false, shift, triggers, enabled: true))
        _ = machine.modifiersChanged(fnDown: false, PressedModifiers(), triggers, enabled: true)
        assertEquals(machine.modifiersChanged(fnDown: true, PressedModifiers(), triggers, enabled: true), .open("default"))
        assertEquals(machine.modifiersChanged(fnDown: true, shift, triggers, enabled: true), .open("workspaces"))
        assertEquals(machine.modifiersChanged(fnDown: true, PressedModifiers(), triggers, enabled: true), .open("default"))
        // Modifiers that match no trigger keep the profile
        assertNil(machine.modifiersChanged(fnDown: true, PressedModifiers(left: [.cmd]), triggers, enabled: true))
        assertEquals(machine.modifiersChanged(fnDown: false, PressedModifiers(), triggers, enabled: true), .finish(.release))
        assertEquals(machine.session, .idle)
        // Disabled Looper never opens the wheel
        assertNil(machine.modifiersChanged(fnDown: true, PressedModifiers(), triggers, enabled: false))
    }

    func testTapMachineClickAndKeys() {
        let triggers = [WheelTriggerBinding(chord: WheelChord(fn: true), profile: "default")]
        var machine = WheelTapMachine()
        _ = machine.modifiersChanged(fnDown: true, PressedModifiers(), triggers, enabled: true)
        assertEquals(machine.click(.rightClick), .finish(.rightClick))
        // fn is still held, but the wheel doesn't open again until it's released
        assertNil(machine.modifiersChanged(fnDown: true, PressedModifiers(left: [.shift]), triggers, enabled: true))
        assertNil(machine.click(.leftClick))
        _ = machine.modifiersChanged(fnDown: false, PressedModifiers(), triggers, enabled: true)
        assertEquals(machine.session, .idle)

        // A key cancels a held wheel and passes through
        _ = machine.modifiersChanged(fnDown: true, PressedModifiers(), triggers, enabled: true)
        let key = machine.keyDown(isEscape: false)
        assertEquals(key.effect, .cancel("key pressed"))
        assertEquals(key.swallow, false)
        assertEquals(machine.session, .awaitingRelease)
    }

    func testTapMachineOpenedByCommand() {
        var machine = WheelTapMachine()
        machine.openedByCommand()
        XCTAssertTrue(machine.isOpen)
        // Modifiers don't finish a wheel that isn't held
        assertNil(machine.modifiersChanged(fnDown: false, PressedModifiers(), [], enabled: true))
        let escape = machine.keyDown(isEscape: true)
        assertEquals(escape.effect, .cancel("key pressed"))
        assertEquals(escape.swallow, true)
        assertEquals(machine.session, .idle)

        machine.openedByCommand()
        assertEquals(machine.click(.leftClick), .finish(.leftClick))
        assertEquals(machine.session, .idle)

        machine.openedByCommand()
        machine.closed() // 'wheel cancel'
        assertEquals(machine.session, .idle)
    }

    func testParseWheelCommand() {
        testParseSingleCommandSucc("wheel open", WheelCmdArgs(rawArgs: []).with(\.action, .initialized(.open(profile: nil))))
        testParseSingleCommandSucc("wheel open workspaces", WheelCmdArgs(rawArgs: []).with(\.action, .initialized(.open(profile: "workspaces"))))
        testParseSingleCommandSucc("wheel cancel", WheelCmdArgs(rawArgs: []).with(\.action, .initialized(.cancel)))
        XCTAssertNotNil(parseCommand("wheel spin").errorOrNil)
    }

    func testSelectionZones() {
        let thickness: CGFloat = 22 // The ring starts 50 - 22 = 28 points away from the center
        assertEquals(WheelSelection(offset: CGVector(dx: 5, dy: 5), diameter: 100, thickness: thickness), .none)
        assertEquals(WheelSelection(offset: CGVector(dx: 20, dy: 0), diameter: 100, thickness: thickness), .center)
        assertEquals(WheelSelection(offset: CGVector(dx: 40, dy: 0), diameter: 100, thickness: thickness), .direction(.east))
        assertEquals(WheelSelection(offset: CGVector(dx: 0, dy: 40), diameter: 100, thickness: thickness), .direction(.north))
        assertEquals(WheelSelection(offset: CGVector(dx: -30, dy: -30), diameter: 100, thickness: thickness), .direction(.southWest))
        assertEquals(WheelSelection(offset: CGVector(dx: -40, dy: 5), diameter: 100, thickness: thickness), .direction(.west))
        // A bigger wheel makes the center zone bigger
        assertEquals(WheelSelection(offset: CGVector(dx: 40, dy: 0), diameter: 160, thickness: thickness), .center)
        // A thicker ring makes the center zone smaller
        assertEquals(WheelSelection(offset: CGVector(dx: 20, dy: 0), diameter: 100, thickness: 35), .direction(.east))
    }

    func testVibrantAccent() {
        let gray = RgbColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertNil(vibrantAccent(of: Array(repeating: gray, count: 100)))

        // Mostly gray, with a little vivid orange and a lot of dull blue: the vivid color wins
        let orange = RgbColor(red: 1, green: 0.5, blue: 0)
        let dullBlue = RgbColor(red: 0.3, green: 0.31, blue: 0.38)
        let pixels = Array(repeating: gray, count: 500) + Array(repeating: orange, count: 100) + Array(repeating: dullBlue, count: 200)
        let accent = vibrantAccent(of: pixels)
        XCTAssertNotNil(accent)
        let hue = accent?.hsb.hue ?? -1
        XCTAssertTrue(abs(hue - orange.hsb.hue) < 0.03, "hue \(hue)")
    }

    func testPointerFollowsVisibleLocation() {
        var pointer = WheelPointer(origin: CGPoint(x: 500, y: 500), maxOvershoot: 100)
        // Far away and back: the offset always matches the visible pointer
        assertEquals(pointer.move(to: CGPoint(x: 800, y: 500), eventDelta: CGVector(dx: 300, dy: 0)), CGVector(dx: 300, dy: 0))
        assertEquals(pointer.move(to: CGPoint(x: 700, y: 500), eventDelta: CGVector(dx: -100, dy: 0)), CGVector(dx: 200, dy: 0))
    }

    func testPointerOvershootsScreenEdges() {
        // The wheel opened 10 points away from the left edge of the screen
        var pointer = WheelPointer(origin: CGPoint(x: 10, y: 500), maxOvershoot: 100)
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 500), eventDelta: CGVector(dx: -10, dy: 0)), CGVector(dx: -10, dy: 0))
        // Pinned against the edge, the reported movement still counts
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 500), eventDelta: CGVector(dx: -30, dy: 0)), CGVector(dx: -40, dy: 0))
        // Moving vertically along the edge keeps the overshoot
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 520), eventDelta: CGVector(dx: 0, dy: 20)), CGVector(dx: -40, dy: 20))
        // Leaving the edge drops it
        assertEquals(pointer.move(to: CGPoint(x: 5, y: 520), eventDelta: CGVector(dx: 5, dy: 0)), CGVector(dx: -5, dy: 20))
        // The overshoot is bounded
        _ = pointer.move(to: CGPoint(x: 0, y: 520), eventDelta: CGVector(dx: -5, dy: 0))
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 520), eventDelta: CGVector(dx: -1000, dy: 0)), CGVector(dx: -110, dy: 20))
    }

    func testTapMachineDelaysSwitchesCausedByReleases() {
        let triggers = [
            WheelTriggerBinding(chord: WheelChord(fn: true), profile: "default"),
            WheelTriggerBinding(chord: WheelChord(fn: true, modifiers: HotkeyModifiers([.shift: .either])), profile: "workspaces"),
        ]
        let shift = PressedModifiers(left: [.shift])
        let none = PressedModifiers()
        var machine = WheelTapMachine()
        _ = machine.modifiersChanged(fnDown: true, none, triggers, enabled: true, delaysReleases: true)
        // Pressing a modifier switches right away
        assertEquals(machine.modifiersChanged(fnDown: true, shift, triggers, enabled: true, delaysReleases: true), .open("workspaces"))

        // Releasing shift and then fn within the delay finishes in 'workspaces'
        assertEquals(machine.modifiersChanged(fnDown: true, none, triggers, enabled: true, delaysReleases: true), .switchLater("default", id: 1))
        assertEquals(machine.modifiersChanged(fnDown: false, none, triggers, enabled: true, delaysReleases: true), .finish(.release))
        assertNil(machine.confirmPendingSwitch(1))

        // Keeping fn held past the delay switches back to 'default'
        _ = machine.modifiersChanged(fnDown: true, shift, triggers, enabled: true, delaysReleases: true)
        assertEquals(machine.modifiersChanged(fnDown: true, none, triggers, enabled: true, delaysReleases: true), .switchLater("default", id: 2))
        assertEquals(machine.confirmPendingSwitch(2), .open("default"))
        assertEquals(machine.session, .held(profile: "default"))

        // Pressing shift again within the delay cancels the switch
        assertEquals(machine.modifiersChanged(fnDown: true, shift, triggers, enabled: true, delaysReleases: true), .open("workspaces"))
        assertEquals(machine.modifiersChanged(fnDown: true, none, triggers, enabled: true, delaysReleases: true), .switchLater("default", id: 3))
        assertNil(machine.modifiersChanged(fnDown: true, shift, triggers, enabled: true, delaysReleases: true))
        assertNil(machine.confirmPendingSwitch(3))
        assertEquals(machine.session, .held(profile: "workspaces"))
    }

    func testParseReleaseDelay() {
        assertEquals(parseConfig("").config.wheel.releaseDelay, 150)
        assertEquals(parseConfig("wheel.release-delay = 0").config.wheel.releaseDelay, 0)
        assertEquals(parseConfig("wheel.release-delay = 5000").strErrors, ["[ERROR] wheel.release-delay: Must be in [0, 1000] range"])
    }

    func testParseVariants() {
        let result = parseConfig(
            """
            [wheel.profiles.floating]
            extends = 'default'
            if = 'test %{window-layout} = floating && test-not %{app-name} ~= safari'

            [wheel.profiles.plain]
            extends = 'default'

            [wheel.profiles.safari]
            extends = 'default'
            if = 'test %{app-name} ~= safari'

            [wheel.profiles.floating-firefox]
            extends = 'floating'
            if = 'test %{app-name} ~= firefox'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.wheel.variants, ["default": ["floating", "safari"], "floating": ["floating-firefox"]])
        XCTAssertNotNil(result.config.wheel.profiles["floating"]?.condition)
        XCTAssertNil(result.config.wheel.profiles["plain"]?.condition)
        // The condition isn't inherited
        XCTAssertNotNil(result.config.wheel.profiles["floating-firefox"]?.condition)
    }

    func testVariantErrors() {
        let result = parseConfig(
            """
            [wheel.profiles.default]
            if = 'true'

            [wheel.profiles.orphan]
            if = 'true'

            [wheel.profiles.broken]
            extends = 'default'
            if = 'test %{window-layout} ='
            """,
        )
        let errors = result.strErrors.sorted()
        assertEquals(errors.count, 3, additionalMsg: errors.joined(separator: "\n"))
        XCTAssertTrue(errors.contains("[ERROR] wheel.profiles.default.if: A profile with 'if' must extend the profile it replaces"))
        XCTAssertTrue(errors.contains("[ERROR] wheel.profiles.orphan.if: A profile with 'if' must extend the profile it replaces"))
        XCTAssertTrue(errors.contains { $0.hasPrefix("[ERROR] wheel.profiles.broken.if:") })
        XCTAssertTrue(result.config.wheel.variants.isEmpty)
    }

    func testResolveVariants() async {
        setUpWorkspacesForTests()
        defer { setUpWorkspacesForTests() }
        config.wheel = parseConfig(
            """
            [wheel.profiles.other-workspace]
            extends = 'default'
            if = 'test %{workspace} = b'

            [wheel.profiles.this-workspace]
            extends = 'default'
            if = 'test %{workspace} = a'

            [wheel.profiles.also-this-workspace]
            extends = 'default'
            if = 'test %{workspace} = a'

            [wheel.profiles.nested]
            extends = 'this-workspace'
            if = 'test %{workspace} = b || test-not %{workspace} = c'

            [wheel.profiles.needs-window]
            extends = 'nested'
            if = 'test %{window-layout} = floating'
            """,
        ).config.wheel
        assertTrue(Workspace.get(byName: "a").focusWorkspace())

        // The first matching variant wins, recursively. Window conditions can't match on an empty workspace
        let resolved = await resolveWheelVariant("default", .defaultEnv)
        XCTAssertEqual(resolved, "nested")
        // A variant requested by name skips its own condition
        assertEquals(await resolveWheelVariant("other-workspace", .defaultEnv), "other-workspace")
    }

    func testParsePreviewConfig() {
        let result = parseConfig(
            """
            wheel.preview = 'all'
            wheel.preview-corner-radius = 16
            wheel.preview-border-width = 0

            [wheel.profiles.default.actions]
            left = { release = 'place left-half', preview = 'off' }
            right = 'place right-half'

            [wheel.profiles.quiet]
            extends = 'default'
            preview = 'off'
            [wheel.profiles.quiet.actions]
            right = { preview = 'target' }
            """,
        )
        assertEquals(result.errors, [])
        let wheel = result.config.wheel
        assertEquals(wheel.profiles["default"]?.style.preview, .all)
        assertEquals(wheel.profiles["default"]?.style.previewCornerRadius, 16)
        assertEquals(wheel.profiles["default"]?.style.previewBorderWidth, 0)
        assertEquals(wheel.profiles["default"]?.preview(.left), .off)
        assertEquals(wheel.profiles["default"]?.preview(.right), .all)
        // Inherited per slot, and a slot table may only change the preview
        assertEquals(wheel.profiles["quiet"]?.preview(.left), .off)
        assertEquals(wheel.profiles["quiet"]?.preview(.right), .target)
        assertEquals(wheel.profiles["quiet"]?.preview(.up), .off)
        XCTAssertNotNil(wheel.profiles["quiet"]?.action(.right, .release))

        assertEquals(parseConfig("wheel.preview = 'some'").strErrors, ["[ERROR] wheel.preview: Expected 'off', 'target', 'all'"])
    }

    func testParseSize() {
        let result = parseConfig(
            """
            wheel.size = 160
            wheel.thickness = 50
            [wheel.profiles.small]
            size = 60
            """,
        )
        assertEquals(result.config.wheel.profiles["default"]?.style.size, 160)
        assertEquals(result.config.wheel.profiles["default"]?.style.thickness, 50)
        // The inherited thickness doesn't fit: it's bounded
        assertEquals(result.config.wheel.profiles["small"]?.style.thickness, 15)
        assertEquals(result.strErrors, ["[ERROR] wheel.profiles.small: The thickness (50) leaves no room for the center: a wheel of size 60 takes at most 15"])
        assertEquals(parseConfig("wheel.thickness = 40").strErrors, ["[ERROR] wheel: The thickness (40) leaves no room for the center: a wheel of size 100 takes at most 35"])
        assertEquals(parseConfig("wheel.size = 20").strErrors, ["[ERROR] wheel.size: Must be in [60, 240] range"])
    }

    func testParseIconConfig() {
        let result = parseConfig(
            """
            [wheel.profiles.default.actions]
            left = { release = 'move left', icon = 'star' }
            right = { release = 'move right', icon = '' }
            up = 'echo -- hi'
            down = 'echo -- hi && layout accordion tiles'
            down-left = { release = 'move left', icon = 'star' }

            [wheel.profiles.child]
            extends = 'default'
            [wheel.profiles.child.actions]
            down-left = 'focus left'
            up = { icon = 'heart' }

            [wheel.profiles.plain]
            icons = false
            """,
        )
        assertEquals(result.errors, [])
        let profiles = result.config.wheel.profiles
        assertEquals(profiles["default"]?.icon(.left), "star")
        assertEquals(profiles["default"]?.icon(.right), nil)
        // Commands without an icon are skipped
        assertEquals(profiles["default"]?.icon(.up), nil)
        assertEquals(profiles["default"]?.icon(.down), "rectangle.stack")
        assertEquals(profiles["default"]?.icon(.center), nil)
        // Icons are inherited, unless the profile rebinds the release action
        assertEquals(profiles["child"]?.icon(.left), "star")
        assertEquals(profiles["child"]?.icon(.downLeft), "arrow.left.circle")
        assertEquals(profiles["child"]?.icon(.up), "heart")
        assertEquals(profiles["plain"]?.icon(.left), nil)

        assertEquals(
            parseConfig("wheel.profiles.default.actions.left = { release = 'move left', icon = 'no-such-symbol' }").strErrors,
            ["[ERROR] wheel.profiles.default.actions.left.icon: Unknown SF Symbol 'no-such-symbol'"],
        )
    }

    func testAutoIconsExist() {
        let commands = [
            "move left", "move up", "swap left", "swap up", "swap dfs-next", "focus right", "focus dfs-next", "focus-back-and-forth",
            "join-with left", "layout accordion tiles", "layout v_tiles", "layout floating tiling", "layout tiling", "layout horizontal",
            "fullscreen", "macos-native-fullscreen", "macos-native-minimize", "workspace next", "workspace prev", "workspace 1",
            "workspace W", "workspace dev", "workspace-back-and-forth", "move-node-to-workspace next", "move-node-to-monitor next",
            "move-workspace-to-monitor next", "swap-workspace-with-monitor next", "focus-monitor left", "balance-sizes",
            "flatten-workspace-tree", "split vertical", "split horizontal", "resize smart +50", "resize smart -50", "resize width 500",
            "close", "close-all-windows-but-current", "exec-and-forget open .", "mode main", "reload-config", "enable toggle",
            "volume up", "move-mouse window-lazy-center",
        ] + PlacementPreset.allCases.map { "place \($0.rawValue)" } + ["place rect 0 0 50 50"]
        for command in commands {
            guard let parsed = parseCommand(command).cmdOrNil else {
                XCTFail("Can't parse '\(command)'")
                continue
            }
            guard let icon = wheelAutoIcon(parsed) else {
                XCTFail("No icon for '\(command)'")
                continue
            }
            XCTAssertTrue(isSfSymbol(icon), "'\(icon)' of '\(command)' isn't an SF Symbol")
        }
    }

    func testComputePreview() async {
        let workspace = Workspace.get(byName: "a")
        let left = TestWindow.new(id: 1, parent: workspace.rootTilingContainer, rect: Rect(topLeftX: 0, topLeftY: 0, width: 50, height: 50))
        _ = TestWindow.new(id: 2, parent: workspace.rootTilingContainer, rect: Rect(topLeftX: 50, topLeftY: 0, width: 50, height: 50))
        let floating = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 10, topLeftY: 10, width: 20, height: 20))
        assertTrue(left.focusWindow())
        let wheelEnv = CmdEnv.defaultEnv.withWheel(WheelGestureEnv(windowId: floating.windowId))
        func preview(_ command: String, _ mode: WheelPreviewMode = .target) async -> [WheelPreviewItem] {
            await computeWheelPreview(parseCommand(command).cmdOrDie, wheelEnv, mode)
        }

        let placed = await preview("place --window-id wheel maximize")
        assertEquals(placed.map(\.windowId), [3])
        assertEquals(placed.first?.kind, .frame)
        let area = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        assertEquals(placed.first.map { [$0.rect.minX, $0.rect.minY, $0.rect.width, $0.rect.height] }, [area.minX, area.minY, area.width, area.height])

        // 'place' fails on tiled windows, so it has no preview
        assertEquals(await preview("place left-half"), [])
        // Focus outlines the window that gets focus
        assertEquals(await preview("focus right").map(\.windowId), [2])
        assertEquals(await preview("focus right").first?.kind, .focus)
        // Like the command, it sees the floating window as a tiling one at its center, left of the focused one
        assertEquals(await preview("focus left").map(\.windowId), [3])
        assertEquals(await preview("focus --ignore-floating left"), []) // No window there
        // Tiling commands are simulated (see WheelSimulationTest)
        assertEquals(await preview("move right").map(\.windowId), [1])
        // Unsupported commands, shells and the 'off' mode have no preview
        assertEquals(await preview("workspace b"), [])
        assertEquals(await preview("focus right && focus left"), [])
        assertEquals(await preview("place --window-id wheel maximize", .off), [])
    }
}
