@testable import AppBundle
import Common
import XCTest

@MainActor
final class WheelTest: XCTestCase {
    func testParseWheelConfig() {
        let result = parseConfig(
            """
            wheel.corner-radius = 60
            wheel.thickness = 30
            wheel.accent-color = ['#ff0000', '#0000FF']
            wheel.haptics = false
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.wheel, WheelConfig(
            cornerRadius: 60,
            thickness: 30,
            accentColor: .custom(RgbColor(red: 1, green: 0, blue: 0), gradientEnd: RgbColor(red: 0, green: 0, blue: 1)),
            haptics: false,
        ))

        assertEquals(parseConfig("wheel.accent-color = 'wallpaper'").config.wheel.accentColor, .wallpaper)
        assertEquals(parseConfig("wheel.accent-color = '#00ff00'").config.wheel.accentColor, .custom(RgbColor(red: 0, green: 1, blue: 0), gradientEnd: nil))
        assertEquals(parseConfig("").config.wheel, WheelConfig())
    }

    func testParseWheelConfigErrors() {
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
            "[ERROR] wheel.thickness: Must be in [10, 35] range",
        ])
    }

    func testSelectionZones() {
        let thickness: CGFloat = 22 // The ring starts 50 - 22 = 28 points away from the center
        assertEquals(WheelSelection(offset: CGVector(dx: 5, dy: 5), thickness: thickness), .none)
        assertEquals(WheelSelection(offset: CGVector(dx: 20, dy: 0), thickness: thickness), .center)
        assertEquals(WheelSelection(offset: CGVector(dx: 40, dy: 0), thickness: thickness), .direction(.east))
        assertEquals(WheelSelection(offset: CGVector(dx: 0, dy: 40), thickness: thickness), .direction(.north))
        assertEquals(WheelSelection(offset: CGVector(dx: -30, dy: -30), thickness: thickness), .direction(.southWest))
        assertEquals(WheelSelection(offset: CGVector(dx: -40, dy: 5), thickness: thickness), .direction(.west))
        // A thicker ring makes the center zone smaller
        assertEquals(WheelSelection(offset: CGVector(dx: 20, dy: 0), thickness: 35), .direction(.east))
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
        var pointer = WheelPointer(origin: CGPoint(x: 500, y: 500))
        // Far away and back: the offset always matches the visible pointer
        assertEquals(pointer.move(to: CGPoint(x: 800, y: 500), eventDelta: CGVector(dx: 300, dy: 0)), CGVector(dx: 300, dy: 0))
        assertEquals(pointer.move(to: CGPoint(x: 700, y: 500), eventDelta: CGVector(dx: -100, dy: 0)), CGVector(dx: 200, dy: 0))
    }

    func testPointerOvershootsScreenEdges() {
        // The wheel opened 10 points away from the left edge of the screen
        var pointer = WheelPointer(origin: CGPoint(x: 10, y: 500))
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 500), eventDelta: CGVector(dx: -10, dy: 0)), CGVector(dx: -10, dy: 0))
        // Pinned against the edge, the reported movement still counts
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 500), eventDelta: CGVector(dx: -30, dy: 0)), CGVector(dx: -40, dy: 0))
        // Moving vertically along the edge keeps the overshoot
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 520), eventDelta: CGVector(dx: 0, dy: 20)), CGVector(dx: -40, dy: 20))
        // Leaving the edge drops it
        assertEquals(pointer.move(to: CGPoint(x: 5, y: 520), eventDelta: CGVector(dx: 5, dy: 0)), CGVector(dx: -5, dy: 20))
        // The overshoot is bounded
        _ = pointer.move(to: CGPoint(x: 0, y: 520), eventDelta: CGVector(dx: -5, dy: 0))
        assertEquals(pointer.move(to: CGPoint(x: 0, y: 520), eventDelta: CGVector(dx: -1000, dy: 0)), CGVector(dx: -10 - WheelPointer.maxOvershoot, dy: 20))
    }
}
