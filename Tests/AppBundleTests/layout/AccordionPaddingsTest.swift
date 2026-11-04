@testable import AppBundle
import XCTest

final class AccordionPaddingsTest: XCTestCase {
    private func paddings(count: Int, mru: Int) -> [[CGFloat]] {
        (0 ..< count).map { index in
            let (left, right) = accordionPaddings(index, count: count, mruIndex: mru, padding: 10)
            return [left, right]
        }
    }

    func testSingleChild() {
        assertEquals(paddings(count: 1, mru: 0), [[0, 0]])
    }

    func testTwoChildren() {
        assertEquals(paddings(count: 2, mru: 0), [[0, 10], [10, 0]])
        assertEquals(paddings(count: 2, mru: 1), [[0, 10], [10, 0]])
    }

    func testMostRecentInTheMiddle() {
        assertEquals(paddings(count: 5, mru: 2), [[10, 10], [0, 10], [10, 10], [10, 0], [10, 10]])
    }

    /// With the most recent child at an edge, the farther children hide behind it instead of taking the edge strip
    /// of its only neighbor (an inherited bug: which one showed there depended on the order of windows in macOS)
    func testMostRecentAtAnEdge() {
        assertEquals(paddings(count: 3, mru: 0), [[0, 10], [10, 0], [10, 10]])
        assertEquals(paddings(count: 3, mru: 2), [[10, 10], [0, 10], [10, 0]])
    }

    /// Moving the focus by one changes the place of the children whose role changes only: at most two of three, and at
    /// most four in longer accordions (the old neighbor, the old and new most recent, and the new neighbor)
    func testFewChildrenMove() {
        for count in 2 ... 6 {
            for mru in 0 ..< count - 1 {
                let moved = zip(paddings(count: count, mru: mru), paddings(count: count, mru: mru + 1)).count { $0 != $1 }
                XCTAssertLessThanOrEqual(moved, count <= 3 ? 2 : 4, "count \(count), mru \(mru)")
            }
        }
    }
}
