@testable import AppBundle
import Common
import ServiceManagement
import XCTest

final class InstallFeedbackTest: XCTestCase {
    func testStartAtLoginStep() {
        assertEquals(startAtLoginStep(isWanted: true, .notRegistered), .register)
        assertEquals(startAtLoginStep(isWanted: true, .notFound), .register)
        assertEquals(startAtLoginStep(isWanted: true, .enabled), .nothing)
        assertEquals(startAtLoginStep(isWanted: true, .requiresApproval), .reportDisabledInSettings)
        // Removing a login item that doesn't exist is an error, not something to report
        assertEquals(startAtLoginStep(isWanted: false, .notRegistered), .nothing)
        assertEquals(startAtLoginStep(isWanted: false, .notFound), .nothing)
        assertEquals(startAtLoginStep(isWanted: false, .enabled), .unregister)
        assertEquals(startAtLoginStep(isWanted: false, .requiresApproval), .unregister)
    }

    func testConfigDiagnostics() {
        let error = ConfigParseDiagnostic(.rootKey("gaps"), "Bad value")
        let warning = ConfigParseDiagnostic(.emptyRoot, "Outdated")
        let diagnostics = ConfigDiagnostics(path: "~/.looper.toml", errors: [error, error], warnings: [warning])
        assertEquals(diagnostics.summary, "2 errors, 1 warning")
        assertTrue(diagnostics.containsWarnings)
        assertEquals(diagnostics.items.last?.key, "")
        assertEquals(diagnostics.plainText, "~/.looper.toml\n\n[ERROR] gaps: Bad value\n\n[ERROR] gaps: Bad value\n\n[WARNING] Outdated")
        assertEquals(ConfigDiagnostics(path: "", errors: [], warnings: [warning]).summary, "1 warning")
    }

    func testTranslocation() {
        assertTrue(isTranslocated(bundlePath: "/private/var/folders/9q/66/T/AppTranslocation/2E3A/d/Looper.app"))
        assertFalse(isTranslocated(bundlePath: "/Applications/Looper.app"))
        assertFalse(isTranslocated(bundlePath: "/Users/someone/Downloads/Looper-v0.1.0/Looper.app"))
    }
}
