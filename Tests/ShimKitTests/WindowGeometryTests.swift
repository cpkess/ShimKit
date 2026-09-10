import XCTest
@testable import ShimKit

final class WindowGeometryTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let current = CGRect(x: 100, y: 150, width: 600, height: 400)
    func assertFrame(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.001, file: file, line: line)
    }
    func testAllLayoutsAtZeroAndNegativeOrigins() {
        let expected: [(WindowCommand, CGRect)] = [
            (.left, CGRect(x: 0, y: 0, width: 720, height: 900)),
            (.right, CGRect(x: 720, y: 0, width: 720, height: 900)),
            (.top, CGRect(x: 0, y: 0, width: 1440, height: 450)),
            (.bottom, CGRect(x: 0, y: 450, width: 1440, height: 450)),
            (.topLeft, CGRect(x: 0, y: 0, width: 720, height: 450)),
            (.topRight, CGRect(x: 720, y: 0, width: 720, height: 450)),
            (.bottomLeft, CGRect(x: 0, y: 450, width: 720, height: 450)),
            (.bottomRight, CGRect(x: 720, y: 450, width: 720, height: 450)),
            (.leftThird, CGRect(x: 0, y: 0, width: 480, height: 900)),
            (.centerThird, CGRect(x: 480, y: 0, width: 480, height: 900)),
            (.rightThird, CGRect(x: 960, y: 0, width: 480, height: 900)),
            (.leftTwoThirds, CGRect(x: 0, y: 0, width: 960, height: 900)),
            (.rightTwoThirds, CGRect(x: 480, y: 0, width: 960, height: 900)),
            (.maximize, CGRect(x: 0, y: 0, width: 1440, height: 900)),
            (.center, CGRect(x: 420, y: 250, width: 600, height: 400))
        ]
        for origin in [CGPoint.zero, CGPoint(x: -1440, y: -900), CGPoint(x: 240, y: 1080)] {
            for (command, frame) in expected {
                assertFrame(WindowGeometry.frame(for: command, visible: screen.offsetBy(dx: origin.x, dy: origin.y), current: current), frame.offsetBy(dx: origin.x, dy: origin.y))
            }
        }
    }
    func testCoordinateConversionAcrossDisplays() {
        assertFrame(WindowGeometry.accessibilityFrame(fromAppKit: CGRect(x: 0, y: 50, width: 1440, height: 825), primaryHeight: 900), CGRect(x: 0, y: 25, width: 1440, height: 825))
        assertFrame(WindowGeometry.accessibilityFrame(fromAppKit: CGRect(x: -1920, y: 900, width: 1920, height: 1055), primaryHeight: 900), CGRect(x: -1920, y: -1055, width: 1920, height: 1055))
        assertFrame(WindowGeometry.accessibilityFrame(fromAppKit: CGRect(x: 0, y: -1080, width: 1920, height: 1055), primaryHeight: 900), CGRect(x: 0, y: 925, width: 1920, height: 1055))
    }
    func testCenterClampsOversizedWindow() {
        assertFrame(WindowGeometry.frame(for: .center, visible: screen, current: CGRect(x: -50, y: -50, width: 2000, height: 1000)), screen)
    }
    func testSelectsGreatestIntersectionAndNearestDisconnectedDisplay() {
        let displays = [screen, screen.offsetBy(dx: -1440, dy: 0)]
        XCTAssertEqual(WindowGeometry.displayIndex(for: CGRect(x: -900, y: 0, width: 1000, height: 800), screens: displays), 1)
        XCTAssertEqual(WindowGeometry.displayIndex(for: CGRect(x: 3000, y: 0, width: 400, height: 400), screens: displays), 0)
        XCTAssertNil(WindowGeometry.displayIndex(for: current, screens: []))
    }
    func testDisplayMovePreservesRelativePositionAndClampsSize() {
        let destination = CGRect(x: -1000, y: -800, width: 1000, height: 800)
        assertFrame(WindowGeometry.moved(CGRect(x: 840, y: 500, width: 600, height: 400), from: screen, to: destination), CGRect(x: -600, y: -400, width: 600, height: 400))
        assertFrame(WindowGeometry.moved(screen, from: screen, to: destination), destination)
    }
    func testLeftCycleAndManualMoveReset() {
        var cycle = WindowCycle()
        var frame = current
        for expected in [WindowCommand.left, .leftTwoThirds, .leftThird, .left] {
            XCTAssertEqual(cycle.resolve(.left, current: frame), expected)
            frame = WindowGeometry.frame(for: expected, visible: screen, current: frame)
            cycle.didApply(frame)
        }
        XCTAssertEqual(cycle.resolve(.left, current: current), .left)
        XCTAssertEqual(cycle.resolve(.right, current: frame), .right)
    }
    func testOtherCommandsResetCycle() {
        var cycle = WindowCycle()
        _ = cycle.resolve(.right, current: current)
        cycle.didApply(screen)
        XCTAssertEqual(cycle.resolve(.center, current: screen), .center)
        XCTAssertEqual(cycle.resolve(.right, current: screen), .right)
    }
}
