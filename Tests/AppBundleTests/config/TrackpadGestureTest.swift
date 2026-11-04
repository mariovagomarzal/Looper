@testable import AppBundle
import Common
import XCTest

@MainActor
final class TrackpadGestureTest: XCTestCase {
    /// Feeds frames of `fingers` touches around (x, y) and returns the gestures recognized
    private struct Feed {
        var recognizer = TrackpadGestureRecognizer()
        var time = 0.0
        var gestures: [TrackpadGesture] = []

        mutating func touch(_ fingers: Int, at x: Double, _ y: Double, after delay: Double = 0.01) {
            time += delay
            let touches = (0 ..< fingers).map { TrackpadTouch(x: x + Double($0) * 0.05, y: y) }
            if let gesture = recognizer.frame(touches, timestamp: time) { gestures.append(gesture) }
        }

        mutating func lift(after delay: Double = 0.01) {
            time += delay
            if let gesture = recognizer.frame([], timestamp: time) { gestures.append(gesture) }
        }

        /// Moves the fingers in steps, like real frames
        mutating func slide(_ fingers: Int, from start: (Double, Double), to end: (Double, Double), steps: Int = 10) {
            for step in 0 ... steps {
                let t = Double(step) / Double(steps)
                touch(fingers, at: start.0 + (end.0 - start.0) * t, start.1 + (end.1 - start.1) * t)
            }
        }
    }

    func testSwipes() {
        for (end, direction) in [((0.2, 0.5), TrackpadGesture.Direction.left), ((0.8, 0.5), .right), ((0.5, 0.8), .up), ((0.5, 0.2), .down)] {
            var feed = Feed()
            feed.slide(3, from: (0.5, 0.5), to: end)
            feed.lift()
            assertEquals(feed.gestures, [.swipe(fingers: 3, direction)])
        }
    }

    func testSwipeFiresOnce() {
        var feed = Feed()
        feed.slide(4, from: (0.1, 0.5), to: (0.9, 0.5), steps: 30)
        feed.slide(4, from: (0.9, 0.5), to: (0.1, 0.5), steps: 30)
        feed.lift()
        assertEquals(feed.gestures, [.swipe(fingers: 4, .right)])
    }

    func testFingersThatLandOneByOne() {
        var feed = Feed()
        feed.touch(1, at: 0.5, 0.5)
        feed.touch(2, at: 0.45, 0.5)
        // Landing moves the center of the fingers, which isn't a swipe
        feed.slide(3, from: (0.3, 0.5), to: (0.32, 0.5), steps: 3)
        feed.lift()
        assertEquals(feed.gestures, [.tap(fingers: 3)])
    }

    func testTaps() {
        var feed = Feed()
        feed.touch(4, at: 0.5, 0.5)
        feed.touch(4, at: 0.51, 0.5)
        feed.lift()
        // Too long
        feed.touch(3, at: 0.5, 0.5)
        feed.touch(3, at: 0.5, 0.5, after: 0.5)
        feed.lift()
        // Moved
        feed.slide(3, from: (0.5, 0.5), to: (0.55, 0.5), steps: 3)
        feed.lift()
        assertEquals(feed.gestures, [.tap(fingers: 4)])
    }

    func testOtherFingerCountsAreIgnored() {
        var feed = Feed()
        feed.slide(2, from: (0.5, 0.2), to: (0.5, 0.8))
        feed.lift()
        feed.touch(2, at: 0.5, 0.5)
        feed.lift()
        feed.slide(5, from: (0.2, 0.5), to: (0.8, 0.5))
        feed.lift()
        assertEquals(feed.gestures, [])
    }

    func testNoSwipeWhileFingersLift() {
        var feed = Feed()
        feed.touch(4, at: 0.5, 0.5)
        // One finger lifts and the rest move: not a 3-finger swipe
        feed.slide(3, from: (0.5, 0.5), to: (0.9, 0.5))
        feed.lift()
        assertEquals(feed.gestures, [])
    }

    func testParseConfig() {
        let result = parseConfig(
            """
            gesture-swipe-distance = 20
            [mode.main.gesture]
                swipe-3-left = 'focus left'
                alt-swipe-3-left = 'move left'
                lalt-tap-4 = 'layout accordion tiles'
                swipe-5-left = 'focus left'
                swipe-3-sideways = 'focus left'
                tap-3-up = 'focus left'
                aalt-tap-3 = 'focus left'
                pinch-3 = 'focus left'
            """,
        )
        assertEquals(
            result.strErrors,
            [
                "[ERROR] mode.main.gesture.aalt-tap-3: Can't parse modifiers in 'aalt-tap-3' gesture",
                "[ERROR] mode.main.gesture.pinch-3: Can't parse 'pinch-3' gesture. Expected '[modifiers-]swipe-<fingers>-<direction>' or '[modifiers-]tap-<fingers>'",
                "[ERROR] mode.main.gesture.swipe-3-sideways: Can't parse the direction in 'swipe-3-sideways' gesture. Possible values: (left|right|up|down)",
                "[ERROR] mode.main.gesture.swipe-5-left: The number of fingers in 'swipe-5-left' gesture must be 3 or 4",
                "[ERROR] mode.main.gesture.tap-3-up: Can't parse 'tap-3-up' gesture. Taps have no direction",
            ],
        )
        assertEquals(result.config.gestureSwipeDistance, 20)
        let gestures = result.config.modes[mainModeId]?.gestures ?? [:]
        assertEquals(gestures.keys.sorted(), ["alt-swipe-3-left", "lalt-tap-4", "swipe-3-left"])
        assertEquals(gestures["lalt-tap-4"]?.gesture, .tap(fingers: 4))
        assertEquals(parseConfig("gesture-swipe-distance = 0").strErrors, ["[ERROR] gesture-swipe-distance: Must be between 1 and 100 (percent of the trackpad)"])
    }

    func testMatchModifiers() {
        let gestures = parseConfig(
            """
            [mode.main.gesture]
                swipe-3-left = 'focus left'
                alt-swipe-3-left = 'move left'
                lalt-swipe-3-left = 'swap left'
            """,
        ).config.modes[mainModeId]?.gestures.values.map { $0 } ?? []
        let left = TrackpadGesture.swipe(fingers: 3, .left)
        assertEquals(matchGestureBinding(gestures, left, PressedModifiers())?.description, "swipe-3-left")
        assertEquals(matchGestureBinding(gestures, left, PressedModifiers(right: [.alt]))?.description, "alt-swipe-3-left")
        assertEquals(matchGestureBinding(gestures, left, PressedModifiers(left: [.alt]))?.description, "lalt-swipe-3-left")
        assertNil(matchGestureBinding(gestures, left, PressedModifiers(left: [.cmd])))
        assertNil(matchGestureBinding(gestures, .swipe(fingers: 4, .left), PressedModifiers()))
    }
}
