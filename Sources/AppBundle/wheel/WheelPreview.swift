import AppKit
import Common
import SwiftUI

/// An outline of where a window would end up
struct WheelPreviewItem: Equatable, Identifiable {
    enum Kind: Equatable {
        /// Where the window would be moved or resized to
        case frame
        /// The window that would get focus. Only outlined, not filled
        case focus
        /// Another window that the action moves or resizes ('all' preview mode). Faint outline
        case affected
    }

    let windowId: OpaqueWindowId
    /// Top-left origin screen coordinates, like window frames
    let rect: Rect
    let kind: Kind

    var id: OpaqueWindowId { windowId }

    static func == (lhs: WheelPreviewItem, rhs: WheelPreviewItem) -> Bool {
        lhs.windowId == rhs.windowId && lhs.kind == rhs.kind &&
            lhs.rect.topLeftCorner == rhs.rect.topLeftCorner && lhs.rect.size == rhs.rect.size
    }
}

/// What the action would do, without doing it. Empty when the action can't be previewed.
///
/// 'place', 'fullscreen' (turning it on) and 'focus' are computed directly. Commands that rearrange the tree, alone or
/// in a shell, are simulated (see `simulateWheelPreview`).
@MainActor func computeWheelPreview(_ action: Shell<any Command>, _ env: CmdEnv, _ mode: WheelPreviewMode) async -> [WheelPreviewItem] {
    guard mode != .off else { return [] }
    guard case .cmd(let command) = action else { return simulateWheelPreview(action, env, mode) ?? [] }
    // Previews never report errors: an action that would fail simply has no preview
    let io = CmdIoImpl(stdin: .emptyStdin)
    switch command {
        case let place as PlaceCommand:
            guard let (window, frame) = await place.targetFrame(env, io) else { return [] }
            return [WheelPreviewItem(windowId: window.windowId, rect: frame, kind: .frame)]
        case let fullscreen as FullscreenCommand:
            guard let target = fullscreen.args.resolveTargetOrReportError(env, io), let window = target.windowOrNil else { return [] }
            let turnsOn = switch fullscreen.args.toggle {
                case .on: true
                case .off: false
                case .toggle: !window.isFullscreen
            }
            guard turnsOn, !window.isFullscreen else { return [] }
            let monitor = target.workspace.workspaceMonitorInfo
            let rect = fullscreen.args.noOuterGaps ? monitor.visibleRect : monitor.visibleRectPaddedByOuterGaps
            return [WheelPreviewItem(windowId: window.windowId, rect: rect, kind: .frame)]
        case let focus as FocusCommand:
            guard let window = await focusTarget(focus, env, io), let rect = try? await window.getAxRect(.nonCancellable) else { return [] }
            return [WheelPreviewItem(windowId: window.windowId, rect: rect, kind: .focus)]
        default:
            return simulateWheelPreview(action, env, mode) ?? []
    }
}

/// The window that 'focus' would focus, also on another monitor
@MainActor private func focusTarget(_ focus: FocusCommand, _ env: CmdEnv, _ io: CmdIo) async -> Window? {
    func window(_ destination: FocusCommand.Destination) -> Window? {
        switch destination {
            case .window(let window): window
            case .workspace(let workspace, let raising): raising ?? workspace.toLiveFocus().windowOrNil
            case .exit: nil
        }
    }
    guard let target = focus.args.resolveTargetOrReportError(env, io) else { return nil }
    // Directions see floating windows as tiling ones, placed by their frames, like the command does
    guard case .direction = focus.args.target, focus.args.floatingAsTiling, !target.workspace.floatingWindows.isEmpty else {
        return window(focus.destination(target, env, io))
    }
    let plan = await FloatingAsTilingPlan(target.workspace)
    // The tree may have changed while the frames were read
    guard let target = focus.args.resolveTargetOrReportError(env, io) else { return nil }
    let snapshot = TreeSnapshot([target.workspace])
    defer { snapshot.restore() }
    makeFloatingWindowsSeenAsTiling(plan)
    return window(focus.destination(target, env, io))
}

/// Draws the preview outlines above every window and below the wheel. One transparent panel per screen, so that the
/// outlines can slide between positions with SwiftUI animations
@MainActor
final class WheelPreviewOverlay {
    private var panels: [CGDirectDisplayID: (panel: WheelPreviewPanel, model: WheelPreviewModel)] = [:]
    private var orderOutTask: Task<(), Never>? = nil

    func show(_ items: [WheelPreviewItem], style: WheelStyleConfig, colors: WheelColors) {
        orderOutTask?.cancel()
        orderOutTask = nil
        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height
        var visibleDisplays: Set<CGDirectDisplayID> = []
        for screen in NSScreen.screens {
            guard let displayId = screen.displayId else { continue }
            // The screen frame in the top-left origin coordinates of window frames
            let screenTop = primaryHeight - screen.frame.maxY
            let local = items.compactMap { item -> WheelPreviewModel.LocalItem? in
                guard item.rect.center.x >= screen.frame.minX, item.rect.center.x < screen.frame.maxX,
                      item.rect.center.y >= screenTop, item.rect.center.y < screenTop + screen.frame.height
                else { return nil }
                let rect = CGRect(x: item.rect.minX - screen.frame.minX, y: item.rect.minY - screenTop, width: item.rect.width, height: item.rect.height)
                return WheelPreviewModel.LocalItem(id: item.windowId, rect: rect, kind: item.kind)
            }
            if local.isEmpty && panels[displayId] == nil { continue }
            let (panel, model) = panels[displayId] ?? makePanel(displayId)
            if panel.frame != screen.frame { panel.setFrame(screen.frame, display: false) }
            model.style = style
            model.colors = colors
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) { model.items = local }
            if !local.isEmpty {
                visibleDisplays.insert(displayId)
                panel.orderFrontRegardless()
            }
        }
        scheduleOrderOut(except: visibleDisplays)
    }

    func hide() {
        for (_, (_, model)) in panels {
            withAnimation(.easeOut(duration: 0.12)) { model.items = [] }
        }
        scheduleOrderOut(except: [])
    }

    /// Panels without outlines leave the screen once their outlines faded out
    private func scheduleOrderOut(except visibleDisplays: Set<CGDirectDisplayID>) {
        orderOutTask?.cancel()
        orderOutTask = Task.startUnstructured { @MainActor [panels] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            for (displayId, (panel, _)) in panels where !visibleDisplays.contains(displayId) {
                panel.orderOut(nil)
            }
        }
    }

    private func makePanel(_ displayId: CGDirectDisplayID) -> (panel: WheelPreviewPanel, model: WheelPreviewModel) {
        let model = WheelPreviewModel()
        let result = (WheelPreviewPanel(model: model), model)
        panels[displayId] = result
        return result
    }
}

@MainActor @Observable
final class WheelPreviewModel {
    struct LocalItem: Identifiable, Equatable {
        let id: OpaqueWindowId
        /// Relative to the screen, top-left origin
        let rect: CGRect
        let kind: WheelPreviewItem.Kind
    }

    var items: [LocalItem] = []
    var style = WheelStyleConfig()
    var colors = WheelColors(single: .accentColor)
}

private struct WheelPreviewView: View {
    let model: WheelPreviewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.items) { item in
                let shape = RoundedRectangle(cornerRadius: CGFloat(model.style.previewCornerRadius), style: .continuous)
                let gradient = LinearGradient(colors: [model.colors.start, model.colors.end], startPoint: .topLeading, endPoint: .bottomTrailing)
                let (fill, stroke, lineWidth): (Double, Double, CGFloat) = switch item.kind {
                    case .frame: (0.18, 0.9, CGFloat(model.style.previewBorderWidth))
                    case .focus: (0, 0.9, max(CGFloat(model.style.previewBorderWidth), 2))
                    case .affected: (0.06, 0.45, max(CGFloat(model.style.previewBorderWidth) / 2, 1))
                }
                shape
                    .fill(gradient.opacity(fill))
                    .overlay {
                        shape.strokeBorder(gradient.opacity(stroke), lineWidth: lineWidth)
                    }
                    .frame(width: item.rect.width, height: item.rect.height)
                    .offset(x: item.rect.minX, y: item.rect.minY)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private final class WheelPreviewPanel: NSPanel {
    init(model: WheelPreviewModel) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        // Above every window, below the wheel
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        contentView = panelContentView(WheelPreviewView(model: model))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

extension NSScreen {
    fileprivate var displayId: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Wraps a SwiftUI view for a panel's content view. When an NSHostingView is the content view itself, it keeps
/// updating the size limits of its window from its content. With content that animates all the time, that loops until
/// AppKit throws ("needing another Update Constraints in Window pass") and the app crashes. As a subview that just
/// follows the size of a plain container, it never touches the window
@MainActor func panelContentView<Content: View>(_ rootView: Content) -> NSView {
    let container = NSView()
    let hosting = NSHostingView(rootView: rootView)
    hosting.sizingOptions = []
    hosting.translatesAutoresizingMaskIntoConstraints = true
    hosting.autoresizingMask = [.width, .height]
    container.addSubview(hosting)
    return container
}
