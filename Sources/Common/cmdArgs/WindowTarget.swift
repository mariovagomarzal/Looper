/// The value of `--window-id`: a window ID, or a window described by its role
public enum WindowTarget: Equatable, Sendable, CustomStringConvertible {
    case id(OpaqueWindowId)
    /// The focused window
    case focused
    /// The window under the mouse pointer when the command runs
    case pointer
    /// The window that was under the mouse pointer when the wheel opened. Only valid in wheel actions and conditions
    case wheel

    public var description: String {
        switch self {
            case .id(let id): id.description
            case .focused: "focused"
            case .pointer: "pointer"
            case .wheel: "wheel"
        }
    }
}

func parseWindowTarget(_ str: String) -> ResOrStr<WindowTarget> {
    switch str {
        case "focused": .success(.focused)
        case "pointer": .success(.pointer)
        case "wheel": .success(.wheel)
        default: parseWindowId(str).map(WindowTarget.id).mapError { _ in "Can't convert '\(str)' to window ID. Expected a number, 'focused', 'pointer' or 'wheel'" }
    }
}
