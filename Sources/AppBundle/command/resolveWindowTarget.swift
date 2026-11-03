import AppKit
import Common

extension WindowTarget {
    /// The window that `--window-id` refers to. Reports an error if there is none
    @MainActor func resolveOrReportError(_ env: CmdEnv, _ io: CmdIo) -> Window? {
        switch self {
            case .id(let windowId):
                if let window = Window.get(byId: windowId) { return window }
                io.err("Invalid <window-id> \(windowId) passed to --window-id")
                return nil
            case .focused:
                if let window = globalFocus.windowOrNil { return window }
                io.err(noWindowIsFocused)
                return nil
            case .pointer:
                if let window = windowUnderPointer() { return window }
                io.err("There is no window under the mouse pointer")
                return nil
            case .wheel:
                guard let wheel = env.wheel else {
                    io.err("'--window-id wheel' is only valid in wheel actions and conditions")
                    return nil
                }
                if let windowId = wheel.windowId, let window = Window.get(byId: windowId) { return window }
                io.err("There was no window under the mouse pointer when the wheel opened")
                return nil
        }
    }
}

/// The managed window under the mouse pointer, if it's the topmost window there. Synchronous: it reads the window
/// list of the window server instead of asking every app for its window frames
@MainActor func windowUnderPointer() -> Window? {
    guard let primaryScreen = NSScreen.screens.first,
          let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    else { return nil }
    let mouse = NSEvent.mouseLocation
    // The window server uses top-left origin coordinates relative to the primary screen
    let point = CGPoint(x: mouse.x, y: primaryScreen.frame.height - mouse.y)
    // Front to back. The first regular window (layer 0) under the pointer is the one the user sees
    for info in windows {
        guard (info[kCGWindowLayer as String] as? Int) == 0,
              let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
              bounds.contains(point),
              let nativeWindowId = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        else { continue }
        return MacWindow.allWindows.first { $0.macApp.nativeWindowId(of: $0.windowId) == nativeWindowId }
    }
    return nil
}
