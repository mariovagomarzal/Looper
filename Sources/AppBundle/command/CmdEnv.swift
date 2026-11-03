import Common

struct WheelGestureEnv {
    /// The window that was under the mouse pointer when the wheel opened (`--window-id wheel`)
    let windowId: OpaqueWindowId?
}

struct CmdEnv {
    var windowId: OpaqueWindowId? = nil
    var workspaceName: String? = nil
    /// Set while running the actions and conditions of a wheel gesture
    var wheel: WheelGestureEnv? = nil

    static let defaultEnv: CmdEnv = .init()

    consuming func withWheel(_ wheel: WheelGestureEnv) -> CmdEnv {
        self.wheel = wheel
        return self
    }

    consuming func withFocus(_ focus: LiveFocus) -> Self {
        return switch focus.asLeaf {
            case .window(let wd): withWindowId(wd.windowId)
            case .emptyWorkspace(let ws): withWorkspaceName(ws.name)
        }
    }

    consuming func withWindowId(_ windowId: OpaqueWindowId) -> CmdEnv {
        self.windowId = windowId
        self.workspaceName = nil
        return self
    }

    consuming func withWorkspaceName(_ workspaceName: String) -> CmdEnv {
        self.windowId = nil
        self.workspaceName = workspaceName
        return self
    }

    var asMap: [String: String] {
        var result = [String: String]()
        if let windowId {
            result[LOOPER_WINDOW_ID] = windowId.description
        }
        if let workspaceName {
            result[LOOPER_WORKSPACE] = workspaceName.description
        }
        return result
    }
}
