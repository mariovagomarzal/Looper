@testable import AppBundle
import Common
import CoreGraphics
import XCTest

@MainActor
final class HotkeyTest: XCTestCase {
    private func parse(_ raw: String) -> HotkeyModifiers? {
        try? parseBinding(raw, .emptyRoot, keyNotationToKeyCode).get().0
    }

    private func binding(_ raw: String) -> HotkeyBinding {
        let (modifiers, key) = try! parseBinding(raw, .emptyRoot, keyNotationToKeyCode).get()
        return HotkeyBinding(modifiers, key, .empty, descriptionWithKeyNotation: raw)
    }

    func testParseModifiers() {
        assertEquals(parse("alt-h"), HotkeyModifiers([.alt: .either]))
        assertEquals(parse("lalt-h"), HotkeyModifiers([.alt: .left]))
        assertEquals(parse("ralt-shift-h"), HotkeyModifiers([.alt: .right, .shift: .either]))
        assertEquals(parse("lcmd-rcmd-h"), HotkeyModifiers([.cmd: .both]))
        assertEquals(parse("lctrl-rshift-h"), HotkeyModifiers([.ctrl: .left, .shift: .right]))
        assertEquals(parse("h"), HotkeyModifiers.none)
    }

    func testParseRejectsContradictingOrUnknownModifiers() {
        XCTAssertNil(parse("alt-lalt-h"))
        XCTAssertNil(parse("ralt-alt-h"))
        XCTAssertNil(parse("lopt-h"))
        XCTAssertNil(parse("lalt-unknownKey"))
    }

    func testDescription() {
        assertEquals(binding("shift-alt-h").descriptionWithKeyCode, "alt-shift-h")
        assertEquals(binding("ralt-ctrl-h").descriptionWithKeyCode, "ralt-ctrl-h")
        assertEquals(binding("rcmd-lcmd-h").descriptionWithKeyCode, "lcmd-rcmd-h")
    }

    func testPressedModifiersFromDeviceDependentFlags() {
        // Left alt: generic alt mask + NX_DEVICELALTKEYMASK
        assertEquals(PressedModifiers(CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x20)), PressedModifiers(left: [.alt]))
        // Right alt + left shift
        assertEquals(
            PressedModifiers(CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x40 | CGEventFlags.maskShift.rawValue | 0x2)),
            PressedModifiers(left: [.shift], right: [.alt]),
        )
        // Synthetic event without device dependent bits counts as the left key
        assertEquals(PressedModifiers(.maskCommand), PressedModifiers(left: [.cmd]))
        // Non modifier flags (arrows set the function and numeric pad flags) are ignored
        assertEquals(PressedModifiers([.maskSecondaryFn, .maskNumericPad]), PressedModifiers())
    }

    func testMatching() {
        let leftAlt = PressedModifiers(left: [.alt])
        let rightAlt = PressedModifiers(right: [.alt])
        let bothAlts = PressedModifiers(left: [.alt], right: [.alt])

        XCTAssertTrue(binding("alt-h").modifiers.matches(leftAlt))
        XCTAssertTrue(binding("alt-h").modifiers.matches(rightAlt))
        XCTAssertTrue(binding("alt-h").modifiers.matches(bothAlts))

        XCTAssertTrue(binding("lalt-h").modifiers.matches(leftAlt))
        XCTAssertFalse(binding("lalt-h").modifiers.matches(rightAlt))
        XCTAssertFalse(binding("lalt-h").modifiers.matches(bothAlts))

        XCTAssertTrue(binding("lalt-ralt-h").modifiers.matches(bothAlts))
        XCTAssertFalse(binding("lalt-ralt-h").modifiers.matches(leftAlt))

        // Extra modifiers prevent the match
        XCTAssertFalse(binding("alt-h").modifiers.matches(PressedModifiers(left: [.alt, .shift])))
        XCTAssertFalse(binding("h").modifiers.matches(leftAlt))
    }

    func testSidedBindingWinsOverGenericOne() {
        let generic = binding("alt-h")
        let left = binding("lalt-h")
        assertEquals(matchHotkeyBinding([generic, left], PressedModifiers(left: [.alt]))?.descriptionWithKeyNotation, "lalt-h")
        assertEquals(matchHotkeyBinding([generic, left], PressedModifiers(right: [.alt]))?.descriptionWithKeyNotation, "alt-h")
        XCTAssertNil(matchHotkeyBinding([left], PressedModifiers(right: [.alt])))
    }

    func testKeyCodesRoundTrip() {
        assertEquals(Key.allCases.count, Set(Key.allCases.map(\.keyCode)).count)
        for key in Key.allCases {
            assertEquals(Key(keyCode: key.keyCode), key)
        }
    }
}
