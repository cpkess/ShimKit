import XCTest
@testable import ShimKit

final class WindowSnapCycleTests: XCTestCase {
    func display(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 1440, _ height: CGFloat = 900) -> SnapDisplay {
        let frame = CGRect(x: x, y: y, width: width, height: height)
        return SnapDisplay(frame: frame, visible: frame.insetBy(dx: 0, dy: 25))
    }
    func testHorizontalSequenceInBothDirectionsAndOuterEdgeCycle() {
        let screens = [display(1440, 0, 1920, 1080), display(0, 0)] // Deliberately reverse array order.
        for (command, start, destination) in [(WindowCommand.right, 1, 0), (.left, 0, 1)] {
            var cycle = WindowSnapCycle()
            var current = CGRect(x: screens[start].frame.minX + 100, y: 100, width: 500, height: 400)
            var index = start
            let opposite = command.oppositeHalf!
            let twoThirds: WindowCommand = command == .right ? .rightTwoThirds : .leftTwoThirds
            let third: WindowCommand = command == .right ? .rightThird : .leftThird
            for (expectedIndex, layout) in [(start, command), (destination, opposite), (destination, command), (destination, twoThirds), (destination, third)] {
                let target = cycle.target(command, current: current, index: index, displays: screens)
                XCTAssertEqual(target, WindowGeometry.frame(for: layout, visible: screens[expectedIndex].visible, current: current))
                cycle.didApply(target)
                current = target
                index = expectedIndex
            }
        }
    }
    func testVerticalSequenceUsesDestinationUsableFrame() {
        let screens = [display(0, 0), display(0, -1080, 1920, 1080)]
        for (command, start, destination) in [(WindowCommand.top, 0, 1), (.bottom, 1, 0)] {
            var cycle = WindowSnapCycle()
            var current = screens[start].visible.insetBy(dx: 100, dy: 100)
            for (index, expectedIndex, layout) in [(start, start, command), (start, destination, command.oppositeHalf!), (destination, destination, command), (destination, destination, command)] {
                let target = cycle.target(command, current: current, index: index, displays: screens)
                XCTAssertEqual(target, WindowGeometry.frame(for: layout, visible: screens[expectedIndex].visible, current: current))
                cycle.didApply(target); current = target
            }
        }
    }
    func testFirstPressManualMoveRejectedResizeAndArrangementChangesReset() {
        let screens = [display(0, 0), display(1440, 0)]
        let right = WindowGeometry.frame(for: .right, visible: screens[0].visible, current: .zero)
        var cycle = WindowSnapCycle()
        XCTAssertEqual(cycle.target(.right, current: right, index: 0, displays: screens), right)
        cycle.didApply(right)
        let manual = right.offsetBy(dx: -20, dy: 0)
        XCTAssertEqual(cycle.target(.right, current: manual, index: 0, displays: screens), right)
        cycle.didApply(manual) // App rejected the requested frame.
        XCTAssertEqual(cycle.target(.right, current: right, index: 0, displays: screens), right)
        cycle.didApply(right)
        let changed = [display(0, 0, 1440, 1000), screens[1]]
        XCTAssertEqual(cycle.target(.right, current: right, index: 0, displays: changed), WindowGeometry.frame(for: .right, visible: changed[0].visible, current: right))
    }
    func testGeographicalAdjacencyIgnoresDiagonalGapsAndMirrors() {
        let source = display(-1440, 0)
        let screens = [source, display(0, 900), display(20, 0), source, display(0, 0, 1000, 450), display(0, 450, 1000, 450)]
        XCTAssertEqual(WindowGeometry.adjacentDisplay(from: 0, toward: .right, displays: screens, window: CGRect(x: -400, y: 500, width: 300, height: 200)), 5)
        XCTAssertEqual(WindowGeometry.adjacentDisplay(from: 0, toward: .right, displays: screens, window: CGRect(x: -400, y: 50, width: 300, height: 200)), 4)
        XCTAssertNil(WindowGeometry.adjacentDisplay(from: 0, toward: .right, displays: Array(screens.prefix(4)), window: source.visible))
        XCTAssertNil(WindowGeometry.adjacentDisplay(from: 0, toward: .maximize, displays: screens, window: source.visible))
    }
    func testThreeDisplaysAndCommandChange() {
        let screens = [display(0, 0), display(1440, 0), display(2880, 0)]
        var cycle = WindowSnapCycle()
        var current = screens[0].visible
        for (index, destination, layout) in [(0,0,WindowCommand.right),(0,1,.left),(1,1,.right),(1,2,.left)] {
            let target = cycle.target(.right, current: current, index: index, displays: screens)
            XCTAssertEqual(target, WindowGeometry.frame(for: layout, visible: screens[destination].visible, current: current))
            cycle.didApply(target); current = target
        }
        XCTAssertEqual(cycle.target(.left, current: current, index: 2, displays: screens), current)
    }
}
