import Foundation

/// Display geometry uses full frames for adjacency and usable frames for placement.
struct SnapDisplay {
    let frame: CGRect
    let visible: CGRect
}

extension WindowCommand {
    var oppositeHalf: WindowCommand? {
        switch self {
        case .left: return .right
        case .right: return .left
        case .top: return .bottom
        case .bottom: return .top
        default: return nil
        }
    }
}

extension WindowGeometry {
    static func adjacentDisplay(from index: Int, toward direction: WindowCommand, displays: [SnapDisplay], window: CGRect) -> Int? {
        guard displays.indices.contains(index), direction.oppositeHalf != nil else { return nil }
        let source = displays[index].frame
        let horizontal = direction == .left || direction == .right
        let candidates = displays.indices.filter { other in
            guard other != index else { return false }
            let destination = displays[other].frame
            let overlap = horizontal ? min(source.maxY, destination.maxY) - max(source.minY, destination.minY)
                                     : min(source.maxX, destination.maxX) - max(source.minX, destination.minX)
            guard overlap > 1 else { return false }
            switch direction {
            case .left: return abs(destination.maxX - source.minX) <= 3
            case .right: return abs(destination.minX - source.maxX) <= 3
            case .top: return abs(destination.maxY - source.minY) <= 3
            case .bottom: return abs(destination.minY - source.maxY) <= 3
            default: return false
            }
        }
        // A split edge can touch several displays. Prefer the one aligned with the window.
        func distance(_ other: Int) -> CGFloat {
            let frame = displays[other].frame
            let position = horizontal ? window.midY : window.midX
            let low = horizontal ? frame.minY : frame.minX
            let high = horizontal ? frame.maxY : frame.maxX
            return max(low - position, position - high, 0)
        }
        return candidates.min { a, b in
            if distance(a) != distance(b) { return distance(a) < distance(b) }
            let da = displays[a].frame, db = displays[b].frame
            let center = horizontal ? window.midY : window.midX
            let ca = abs((horizontal ? da.midY : da.midX) - center)
            let cb = abs((horizontal ? db.midY : db.midX) - center)
            return ca == cb ? a < b : ca < cb
        }
    }
}

struct WindowSnapCycle {
    private var widths = WindowCycle()
    private var lastCommand: WindowCommand?
    private var lastTarget: CGRect?
    private var lastDisplay: SnapDisplay?
    private var arrivedAcrossBoundary = false

    mutating func target(_ command: WindowCommand, current: CGRect, index: Int, displays: [SnapDisplay]) -> CGRect {
        let source = displays[index]
        let repeated = command == lastCommand && lastTarget.map { WindowGeometry.approximatelyEqual($0, current) } == true &&
            lastDisplay?.frame == source.frame && lastDisplay?.visible == source.visible
        var destination = index
        let result: CGRect
        if repeated, arrivedAcrossBoundary {
            // Enter at the near half, then move to the far half before crossing again.
            widths = WindowCycle()
            _ = widths.resolve(command, current: current)
            result = WindowGeometry.frame(for: command, visible: source.visible, current: current)
            arrivedAcrossBoundary = false
        } else if repeated, let opposite = command.oppositeHalf,
                  WindowGeometry.approximatelyEqual(current, WindowGeometry.frame(for: command, visible: source.visible, current: current)),
                  let next = WindowGeometry.adjacentDisplay(from: index, toward: command, displays: displays, window: current) {
            destination = next
            result = WindowGeometry.frame(for: opposite, visible: displays[next].visible, current: current)
            arrivedAcrossBoundary = true
            widths = WindowCycle()
        } else {
            if !repeated { widths = WindowCycle() }
            result = WindowGeometry.frame(for: widths.resolve(command, current: current), visible: source.visible, current: current)
            arrivedAcrossBoundary = false
        }
        lastCommand = command
        lastTarget = result
        lastDisplay = displays[destination]
        return result
    }

    mutating func didApply(_ actual: CGRect) {
        widths.didApply(actual)
        // A rejected resize must not qualify as a successful snap across the next boundary.
        if let lastTarget, !WindowGeometry.approximatelyEqual(lastTarget, actual) {
            lastCommand = nil
            arrivedAcrossBoundary = false
        }
    }
}
