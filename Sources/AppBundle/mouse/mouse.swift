import AppKit
import Common

@MainActor var currentlyManipulatedWithMouseWindowId: OpaqueWindowId? = nil
var isLeftMouseButtonDown: Bool { NSEvent.pressedMouseButtons == 1 }

@MainActor
func isManipulatedWithMouse(_ window: Window) async throws -> Bool {
    try await (!window.isHiddenInCorner && // Don't allow to resize/move windows of hidden workspaces
        isLeftMouseButtonDown &&
        hasPointerMovedSinceLeftMouseDown &&
        (currentlyManipulatedWithMouseWindowId == nil || window.windowId == currentlyManipulatedWithMouseWindowId))
        .andAsync { @Sendable @MainActor in try await getNativeFocusedWindow(.cancellable) == window }
}

/// Where the left button went down. See ``hasPointerMovedSinceLeftMouseDown``
@MainActor var leftMouseDownLocation: CGPoint? = nil

/// A click on a window focuses it while the button is still down, and the layout may then move the window (e.g. a
/// window that comes forward in an accordion). That is not a drag: the user drags only once the pointer moves
@MainActor private var hasPointerMovedSinceLeftMouseDown: Bool {
    guard let start = leftMouseDownLocation else { return true }
    let current = mouseLocation
    return abs(current.x - start.x) > 5 || abs(current.y - start.y) > 5
}

/// Same motivation as in monitorFrameNormalized
var mouseLocation: CGPoint { NSEvent.mouseLocation.withYAxisFlipped }
