import Common
import Foundation

/// macOS runs a downloaded app that wasn't moved from a temporary read-only copy (App Translocation). The permissions
/// of that copy don't work, so the app has to be moved first
func isTranslocated(bundlePath: String) -> Bool {
    bundlePath.contains("/AppTranslocation/")
}

@MainActor var isAppTranslocated: Bool { isTranslocated(bundlePath: Bundle.main.bundlePath) }

@MainActor func showTranslocationMessage() {
    MessageModel.shared.message = Message(
        type: .installation,
        description: "Move \(looperAppName) to Applications",
        body: """
            macOS is running \(looperAppName) from a temporary copy, because it hasn't been moved since it was downloaded. \
            The Accessibility permission doesn't work there, so \(looperAppName) won't start.

            Quit \(looperAppName), move it to the Applications folder with the Finder and open it again.
            """,
        containsWarnings: false,
    )
}
