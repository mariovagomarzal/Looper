import AppKit
import Common

/// Identifier of a native macOS Space (Mission Control desktop)
typealias NativeSpaceId = UInt64

/// Read-only view of native macOS Spaces.
///
/// Every (monitor, native Space) pair owns an independent set of workspaces. See ``WorkspacesContainer``.
/// Looper never moves windows between Spaces. It only reads which Space is active on every display and which Space
/// every window belongs to. Both are read with private SkyLight functions that don't require disabling SIP.
///
/// When the functions are unavailable (unit tests, or a future macOS removes them), the snapshot is `nil`, and Looper
/// falls back to a single set of workspaces per monitor.
struct NativeSpacesSnapshot: Equatable, Sendable {
    struct Display: Equatable, Sendable {
        /// Display UUID, or "Main" when a single set of Spaces spans all displays
        let id: String
        let currentSpace: NativeSpaceId
        /// User desktops in Mission Control order. Native fullscreen Spaces are excluded
        let userSpaces: [NativeSpaceId]
    }

    let displays: [Display]

    /// "Displays have separate Spaces" is turned off in System Settings
    var spacesSpanAllDisplays: Bool { displays.count == 1 && displays.first?.id == spanningDisplayId }

    func currentSpace(of monitor: MonitorInfo) -> NativeSpaceId? {
        display(of: monitor)?.currentSpace
    }

    func display(of monitor: MonitorInfo) -> Display? {
        if spacesSpanAllDisplays { return displays.first }
        return monitor.displayUuid.flatMap { uuid in displays.first { $0.id.caseInsensitiveCompare(uuid) == .orderedSame } }
    }

    func display(ofSpace space: NativeSpaceId) -> Display? {
        displays.first { $0.userSpaces.contains(space) }
    }

    func isUserSpace(_ space: NativeSpaceId) -> Bool { display(ofSpace: space) != nil }

    /// The Space is currently shown on some display
    func isActive(_ space: NativeSpaceId) -> Bool { displays.contains { $0.currentSpace == space } }
}

private let spanningDisplayId = "Main"

@MainActor private var _nativeSpaces: NativeSpacesSnapshot? = readNativeSpaces()

/// The last snapshot read with ``refreshNativeSpaces()``
@MainActor var nativeSpaces: NativeSpacesSnapshot? { _nativeSpaces }

/// Set when the active Space of some display changed. Consumed by ``moveFocusToActiveSpaceIfNeeded()``
@MainActor private var activeSpacesChanged = false

/// Should be called at the beginning of every refresh session
@MainActor func refreshNativeSpaces() {
    let new = readNativeSpaces()
    if new?.displays.map(\.currentSpace) != _nativeSpaces?.displays.map(\.currentSpace) {
        activeSpacesChanged = true
    }
    _nativeSpaces = new
}

/// When the user switches to another native Space, focus follows to the visible workspace of the new Space, unless
/// macOS already focused a window there.
@MainActor func moveFocusToActiveSpaceIfNeeded() {
    if !activeSpacesChanged { return }
    activeSpacesChanged = false
    let focus = globalFocus
    guard let container = focus.workspace.workspacesContainer, !container.isActive else { return }
    let target = container.monitor.activeWorkspacesContainer.visibleWorkspace
    _ = target.focusWorkspace()
}

/// The user Space that the window belongs to. nil if unknown, or if the window belongs to a native fullscreen Space,
/// or to several Spaces ("Assign To: All Desktops")
@MainActor func nativeSpace(ofWindow nativeWindowId: UInt32) -> NativeSpaceId? {
    guard let snapshot = nativeSpaces, let api = SkyLight.shared else { return nil }
    let spaces = api.spaces(forWindow: nativeWindowId)
    guard let space = spaces.singleOrNil(), snapshot.isUserSpace(space) else { return nil }
    return space
}

/// Unit tests can't read real Spaces. They simulate them with this snapshot
@MainActor var nativeSpacesForTests: NativeSpacesSnapshot? = nil

@MainActor private func readNativeSpaces() -> NativeSpacesSnapshot? {
    if isUnitTest { return nativeSpacesForTests }
    return SkyLight.shared?.managedDisplaySpaces()
}

/// Private SkyLight functions resolved at runtime, so that Looper keeps working (without native Spaces support) if a
/// future macOS removes them
private final class SkyLight: Sendable {
    private typealias MainConnectionId = @convention(c) () -> Int32
    private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopySpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?

    private let connection: Int32
    private let copyManagedDisplaySpaces: @Sendable (Int32) -> CFArray?
    private let copySpacesForWindows: @Sendable (Int32, Int32, CFArray) -> CFArray?

    static let shared: SkyLight? = SkyLight()

    private init?() {
        guard let handle = unsafe dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let mainConnectionIdSym = unsafe dlsym(handle, "SLSMainConnectionID"),
              let copyManagedDisplaySpacesSym = unsafe dlsym(handle, "SLSCopyManagedDisplaySpaces"),
              let copySpacesForWindowsSym = unsafe dlsym(handle, "SLSCopySpacesForWindows")
        else { return nil }
        let mainConnectionId = unsafe unsafeBitCast(mainConnectionIdSym, to: MainConnectionId.self)
        let copyManagedDisplaySpaces = unsafe unsafeBitCast(copyManagedDisplaySpacesSym, to: CopyManagedDisplaySpaces.self)
        let copySpacesForWindows = unsafe unsafeBitCast(copySpacesForWindowsSym, to: CopySpacesForWindows.self)
        self.connection = mainConnectionId()
        self.copyManagedDisplaySpaces = { cid in unsafe copyManagedDisplaySpaces(cid)?.takeRetainedValue() }
        self.copySpacesForWindows = { cid, mask, windows in unsafe copySpacesForWindows(cid, mask, windows)?.takeRetainedValue() }
    }

    func managedDisplaySpaces() -> NativeSpacesSnapshot? {
        guard let raw = copyManagedDisplaySpaces(connection) as? [[String: Any]] else { return nil }
        let displays: [NativeSpacesSnapshot.Display] = raw.compactMap { display in
            guard let id = display["Display Identifier"] as? String,
                  let current = (display["Current Space"] as? [String: Any]).flatMap(spaceId)
            else { return nil }
            let spaces = (display["Spaces"] as? [[String: Any]]) ?? []
            let userSpaces = spaces.filter { ($0["type"] as? Int) == userSpaceType }.compactMap(spaceId)
            return NativeSpacesSnapshot.Display(id: id, currentSpace: current, userSpaces: userSpaces)
        }
        return displays.isEmpty ? nil : NativeSpacesSnapshot(displays: displays)
    }

    func spaces(forWindow nativeWindowId: UInt32) -> [NativeSpaceId] {
        let windows = [NSNumber(value: nativeWindowId)] as CFArray
        let result = copySpacesForWindows(connection, allSpacesMask, windows) as? [NSNumber]
        return result?.map(\.uint64Value) ?? []
    }
}

private let userSpaceType = 0
private let allSpacesMask: Int32 = 0x7

private func spaceId(_ dict: [String: Any]) -> NativeSpaceId? {
    (dict["id64"] as? NSNumber)?.uint64Value ?? (dict["ManagedSpaceID"] as? NSNumber)?.uint64Value
}
