import CoreGraphics
import XCTest
@testable import LyricCore
final class WindowAnchorTests: XCTestCase {
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let mini = CGSize(width: 420, height: 210)
    let full = CGSize(width: 480, height: 610)
    func testBottomLeftStaysFixedAcrossRepeatedFocusChanges() {
        var frame = CGRect(origin: CGPoint(x: 12, y: 35), size: mini)
        let anchor = WindowAnchor.nearest(to: frame, on: screen)
        XCTAssertEqual(anchor, .bottomLeft)
        for _ in 0..<10 {
            frame = anchor.resized(frame, to: full, within: screen)
            XCTAssertEqual(frame.minX, 12); XCTAssertEqual(frame.minY, 35)
            frame = anchor.resized(frame, to: mini, within: screen)
            XCTAssertEqual(frame.minX, 12); XCTAssertEqual(frame.minY, 35)
        }
    }
    func testDefaultTopLeftKeepsLeftAndTopEdges() {
        let frame = CGRect(x: 100, y: 250, width: 480, height: 610)
        let resized = WindowAnchor.topLeft.resized(frame, to: mini, within: screen)
        XCTAssertEqual(resized.minX, frame.minX); XCTAssertEqual(resized.maxY, frame.maxY)
    }
    func testOtherCornersAndSecondaryDisplay() {
        XCTAssertEqual(WindowAnchor.nearest(to: CGRect(x: 950, y: 35, width: 480, height: 610), on: screen), .bottomRight)
        XCTAssertEqual(WindowAnchor.nearest(to: CGRect(x: 950, y: 675, width: 420, height: 210), on: screen), .topRight)
        let secondary = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let frame = CGRect(x: -1910, y: 10, width: 420, height: 210)
        let expanded = WindowAnchor.bottomLeft.resized(frame, to: full, within: secondary)
        XCTAssertEqual(expanded.minX, -1910); XCTAssertEqual(expanded.minY, 10)
    }
}
