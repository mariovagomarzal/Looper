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

    func testTranslocation() {
        assertTrue(isTranslocated(bundlePath: "/private/var/folders/9q/66/T/AppTranslocation/2E3A/d/Looper.app"))
        assertFalse(isTranslocated(bundlePath: "/Applications/Looper.app"))
        assertFalse(isTranslocated(bundlePath: "/Users/someone/Downloads/Looper-v0.1.0/Looper.app"))
    }
}
