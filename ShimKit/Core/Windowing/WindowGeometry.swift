import Foundation

enum WindowCommand: String, CaseIterable, Codable {
    case left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case maximize, center, restore, previousDisplay, nextDisplay

    var title: String {
        switch self {
        case .left: return "Left Half"
        case .right: return "Right Half"
        case .top: return "Top Half"
        case .bottom: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .rightTwoThirds: return "Right Two Thirds"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .restore: return "Restore Previous Size/Position"
        case .previousDisplay: return "Previous Display"
        case .nextDisplay: return "Next Display"
        }
    }
}

/// All geometry here uses Accessibility's global top-left coordinate system, in points.
enum WindowGeometry {
    static func accessibilityFrame(fromAppKit frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    static func frame(for command: WindowCommand, visible: CGRect, current: CGRect) -> CGRect {
        func portion(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: visible.minX + visible.width * x, y: visible.minY + visible.height * y,
                   width: visible.width * w, height: visible.height * h)
        }
        switch command {
        case .left: return portion(0, 0, 0.5, 1)
        case .right: return portion(0.5, 0, 0.5, 1)
        case .top: return portion(0, 0, 1, 0.5)
        case .bottom: return portion(0, 0.5, 1, 0.5)
        case .topLeft: return portion(0, 0, 0.5, 0.5)
        case .topRight: return portion(0.5, 0, 0.5, 0.5)
        case .bottomLeft: return portion(0, 0.5, 0.5, 0.5)
        case .bottomRight: return portion(0.5, 0.5, 0.5, 0.5)
        case .leftThird: return portion(0, 0, 1 / 3, 1)
        case .centerThird: return portion(1 / 3, 0, 1 / 3, 1)
        case .rightThird: return portion(2 / 3, 0, 1 / 3, 1)
        case .leftTwoThirds: return portion(0, 0, 2 / 3, 1)
        case .rightTwoThirds: return portion(1 / 3, 0, 2 / 3, 1)
        case .maximize: return visible
        case .center:
            let size = CGSize(width: min(current.width, visible.width), height: min(current.height, visible.height))
            return CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                          width: size.width, height: size.height)
        default: return current
        }
    }

    static func displayIndex(for window: CGRect, screens: [CGRect]) -> Int? {
        guard !screens.isEmpty else { return nil }
        // Greatest intersection handles windows spanning two displays. Nearest handles disconnected displays.
        let areas = screens.map { screen -> CGFloat in
            let intersection = screen.intersection(window)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 { return best }
        return screens.indices.min {
            hypot(screens[$0].midX - window.midX, screens[$0].midY - window.midY) <
            hypot(screens[$1].midX - window.midX, screens[$1].midY - window.midY)
        }
    }

    static func moved(_ frame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return destination }
        let size = CGSize(width: min(frame.width, destination.width), height: min(frame.height, destination.height))
        let xFraction = (frame.minX - source.minX) / max(1, source.width - frame.width)
        let yFraction = (frame.minY - source.minY) / max(1, source.height - frame.height)
        return CGRect(x: destination.minX + min(1, max(0, xFraction)) * (destination.width - size.width),
                      y: destination.minY + min(1, max(0, yFraction)) * (destination.height - size.height),
                      width: size.width, height: size.height)
    }

    static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 3) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance &&
        abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}

struct WindowCycle {
    private var command: WindowCommand?
    private var lastFrame: CGRect?
    private var step = 0

    mutating func resolve(_ requested: WindowCommand, current: CGRect) -> WindowCommand {
        let sequence: [WindowCommand]
        switch requested {
        case .left: sequence = [.left, .leftTwoThirds, .leftThird]
        case .right: sequence = [.right, .rightTwoThirds, .rightThird]
        default: command = nil; lastFrame = nil; return requested
        }
        if command == requested, let lastFrame, WindowGeometry.approximatelyEqual(lastFrame, current) {
            step = (step + 1) % sequence.count
        } else { step = 0 }
        command = requested
        return sequence[step]
    }

    mutating func didApply(_ frame: CGRect) { lastFrame = frame }
}
