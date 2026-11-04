import AppKit
import Common
import Foundation

/// macOS runs a downloaded app that wasn't moved from a temporary read-only copy (App Translocation). The permissions
/// of that copy don't work, so the app has to be moved first
func isTranslocated(bundlePath: String) -> Bool {
    bundlePath.contains("/AppTranslocation/")
}

@MainActor var isAppTranslocated: Bool { isTranslocated(bundlePath: Bundle.main.bundlePath) }

@MainActor func showTranslocationMessage(problem: String? = nil) {
    let canMove = originalAppUrl() != nil
    let howToMove = canMove
        ? "Move \(looperAppName) to the Applications folder to use it."
        : "Quit \(looperAppName), move it to the Applications folder with the Finder and open it again."
    let explanation = """
        macOS is running \(looperAppName) from a temporary copy, because it hasn't been moved since it was downloaded. \
        The Accessibility permission doesn't work there, so \(looperAppName) won't start.
        """
    MessageModel.shared.message = Message(content: .installNotice(
        title: "Move \(looperAppName) to Applications",
        body: [problem, explanation, howToMove].compactMap(\.self).joined(separator: "\n\n"),
        canMove: canMove,
    ))
}

/// Where the translocated app really is. The function isn't public API, so it's resolved at runtime
private func originalAppUrl() -> URL? {
    typealias CreateOriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
    guard let handle = unsafe dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
          let symbol = unsafe dlsym(handle, "SecTranslocateCreateOriginalPathForURL")
    else { return nil }
    let createOriginalPath = unsafe unsafeBitCast(symbol, to: CreateOriginalPath.self)
    let original = unsafe createOriginalPath(Bundle.main.bundleURL as CFURL, nil)?.takeRetainedValue() as URL?
    guard let original, !isTranslocated(bundlePath: original.path) else { return nil }
    return original
}

/// Moves the app to /Applications, replacing an older copy, and relaunches it from there
@MainActor func moveToApplicationsAndRelaunch() {
    do {
        guard let source = originalAppUrl() else { throw CocoaError(.fileNoSuchFile) }
        let destination = URL(filePath: "/Applications").appending(component: source.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try unsafe FileManager.default.trashItem(at: destination, resultingItemURL: nil)
        }
        try FileManager.default.moveItem(at: source, to: destination)
        // Unlike moving it with the Finder, this doesn't stop macOS from translocating it again
        let unquarantine = try Process.run(URL(filePath: "/usr/bin/xattr"), arguments: ["-dr", "com.apple.quarantine", destination.path])
        unquarantine.waitUntilExit()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, error in
            Task.startUnstructured { @MainActor in
                if let error {
                    showTranslocationMessage(problem: "\(looperAppName) was moved, but it can't be opened: \(error.localizedDescription)")
                } else {
                    terminationHandler?.beforeTermination()
                    terminateApp()
                }
            }
        }
    } catch {
        showTranslocationMessage(problem: "\(looperAppName) can't be moved: \(error.localizedDescription)")
    }
}
