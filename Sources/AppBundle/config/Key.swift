import Carbon.HIToolbox

/// A physical key, identified by its virtual key code (the position of the key on an ANSI keyboard)
enum Key: CaseIterable, Hashable, Sendable {
    case a
    case b
    case c
    case d
    case e
    case f
    case g
    case h
    case i
    case j
    case k
    case l
    case m
    case n
    case o
    case p
    case q
    case r
    case s
    case t
    case u
    case v
    case w
    case x
    case y
    case z
    case zero
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine
    case period
    case quote
    case rightBracket
    case semicolon
    case slash
    case backslash
    case comma
    case equal
    case grave
    case leftBracket
    case minus
    case section
    case space
    case tab
    case `return`
    case pageUp
    case pageDown
    case home
    case end
    case upArrow
    case rightArrow
    case downArrow
    case leftArrow
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12
    case f13
    case f14
    case f15
    case f16
    case f17
    case f18
    case f19
    case f20
    case keypad0
    case keypad1
    case keypad2
    case keypad3
    case keypad4
    case keypad5
    case keypad6
    case keypad7
    case keypad8
    case keypad9
    case keypadClear
    case keypadDecimal
    case keypadDivide
    case keypadEnter
    case keypadEquals
    case keypadMinus
    case keypadMultiply
    case keypadPlus
    case escape
    case delete
    case forwardDelete

    var keyCode: UInt16 {
        switch self {
            case .a: UInt16(kVK_ANSI_A)
            case .b: UInt16(kVK_ANSI_B)
            case .c: UInt16(kVK_ANSI_C)
            case .d: UInt16(kVK_ANSI_D)
            case .e: UInt16(kVK_ANSI_E)
            case .f: UInt16(kVK_ANSI_F)
            case .g: UInt16(kVK_ANSI_G)
            case .h: UInt16(kVK_ANSI_H)
            case .i: UInt16(kVK_ANSI_I)
            case .j: UInt16(kVK_ANSI_J)
            case .k: UInt16(kVK_ANSI_K)
            case .l: UInt16(kVK_ANSI_L)
            case .m: UInt16(kVK_ANSI_M)
            case .n: UInt16(kVK_ANSI_N)
            case .o: UInt16(kVK_ANSI_O)
            case .p: UInt16(kVK_ANSI_P)
            case .q: UInt16(kVK_ANSI_Q)
            case .r: UInt16(kVK_ANSI_R)
            case .s: UInt16(kVK_ANSI_S)
            case .t: UInt16(kVK_ANSI_T)
            case .u: UInt16(kVK_ANSI_U)
            case .v: UInt16(kVK_ANSI_V)
            case .w: UInt16(kVK_ANSI_W)
            case .x: UInt16(kVK_ANSI_X)
            case .y: UInt16(kVK_ANSI_Y)
            case .z: UInt16(kVK_ANSI_Z)
            case .zero: UInt16(kVK_ANSI_0)
            case .one: UInt16(kVK_ANSI_1)
            case .two: UInt16(kVK_ANSI_2)
            case .three: UInt16(kVK_ANSI_3)
            case .four: UInt16(kVK_ANSI_4)
            case .five: UInt16(kVK_ANSI_5)
            case .six: UInt16(kVK_ANSI_6)
            case .seven: UInt16(kVK_ANSI_7)
            case .eight: UInt16(kVK_ANSI_8)
            case .nine: UInt16(kVK_ANSI_9)
            case .period: UInt16(kVK_ANSI_Period)
            case .quote: UInt16(kVK_ANSI_Quote)
            case .rightBracket: UInt16(kVK_ANSI_RightBracket)
            case .semicolon: UInt16(kVK_ANSI_Semicolon)
            case .slash: UInt16(kVK_ANSI_Slash)
            case .backslash: UInt16(kVK_ANSI_Backslash)
            case .comma: UInt16(kVK_ANSI_Comma)
            case .equal: UInt16(kVK_ANSI_Equal)
            case .grave: UInt16(kVK_ANSI_Grave)
            case .leftBracket: UInt16(kVK_ANSI_LeftBracket)
            case .minus: UInt16(kVK_ANSI_Minus)
            case .section: UInt16(kVK_ISO_Section)
            case .space: UInt16(kVK_Space)
            case .tab: UInt16(kVK_Tab)
            case .return: UInt16(kVK_Return)
            case .pageUp: UInt16(kVK_PageUp)
            case .pageDown: UInt16(kVK_PageDown)
            case .home: UInt16(kVK_Home)
            case .end: UInt16(kVK_End)
            case .upArrow: UInt16(kVK_UpArrow)
            case .rightArrow: UInt16(kVK_RightArrow)
            case .downArrow: UInt16(kVK_DownArrow)
            case .leftArrow: UInt16(kVK_LeftArrow)
            case .f1: UInt16(kVK_F1)
            case .f2: UInt16(kVK_F2)
            case .f3: UInt16(kVK_F3)
            case .f4: UInt16(kVK_F4)
            case .f5: UInt16(kVK_F5)
            case .f6: UInt16(kVK_F6)
            case .f7: UInt16(kVK_F7)
            case .f8: UInt16(kVK_F8)
            case .f9: UInt16(kVK_F9)
            case .f10: UInt16(kVK_F10)
            case .f11: UInt16(kVK_F11)
            case .f12: UInt16(kVK_F12)
            case .f13: UInt16(kVK_F13)
            case .f14: UInt16(kVK_F14)
            case .f15: UInt16(kVK_F15)
            case .f16: UInt16(kVK_F16)
            case .f17: UInt16(kVK_F17)
            case .f18: UInt16(kVK_F18)
            case .f19: UInt16(kVK_F19)
            case .f20: UInt16(kVK_F20)
            case .keypad0: UInt16(kVK_ANSI_Keypad0)
            case .keypad1: UInt16(kVK_ANSI_Keypad1)
            case .keypad2: UInt16(kVK_ANSI_Keypad2)
            case .keypad3: UInt16(kVK_ANSI_Keypad3)
            case .keypad4: UInt16(kVK_ANSI_Keypad4)
            case .keypad5: UInt16(kVK_ANSI_Keypad5)
            case .keypad6: UInt16(kVK_ANSI_Keypad6)
            case .keypad7: UInt16(kVK_ANSI_Keypad7)
            case .keypad8: UInt16(kVK_ANSI_Keypad8)
            case .keypad9: UInt16(kVK_ANSI_Keypad9)
            case .keypadClear: UInt16(kVK_ANSI_KeypadClear)
            case .keypadDecimal: UInt16(kVK_ANSI_KeypadDecimal)
            case .keypadDivide: UInt16(kVK_ANSI_KeypadDivide)
            case .keypadEnter: UInt16(kVK_ANSI_KeypadEnter)
            case .keypadEquals: UInt16(kVK_ANSI_KeypadEquals)
            case .keypadMinus: UInt16(kVK_ANSI_KeypadMinus)
            case .keypadMultiply: UInt16(kVK_ANSI_KeypadMultiply)
            case .keypadPlus: UInt16(kVK_ANSI_KeypadPlus)
            case .escape: UInt16(kVK_Escape)
            case .delete: UInt16(kVK_Delete)
            case .forwardDelete: UInt16(kVK_ForwardDelete)
        }
    }

    init?(keyCode: UInt16) {
        guard let key = keyCodeToKey[keyCode] else { return nil }
        self = key
    }
}

private let keyCodeToKey: [UInt16: Key] = Dictionary(uniqueKeysWithValues: Key.allCases.map { ($0.keyCode, $0) })
