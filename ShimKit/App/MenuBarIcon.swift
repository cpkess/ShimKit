import AppKit

enum MenuBarIcon {
    /// A vector silhouette of the app's fitted panes, without the blue tile or shading.
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            let pane = NSBezierPath()
            pane.move(to: NSPoint(x: 2, y: 5))
            pane.line(to: NSPoint(x: 2, y: 14))
            pane.curve(to: NSPoint(x: 4, y: 16), controlPoint1: NSPoint(x: 2, y: 15.1), controlPoint2: NSPoint(x: 2.9, y: 16))
            pane.line(to: NSPoint(x: 11.5, y: 16))
            pane.curve(to: NSPoint(x: 13, y: 14.5), controlPoint1: NSPoint(x: 12.5, y: 16), controlPoint2: NSPoint(x: 13, y: 15.5))
            pane.curve(to: NSPoint(x: 12, y: 12.5), controlPoint1: NSPoint(x: 13, y: 13.5), controlPoint2: NSPoint(x: 12.7, y: 13))
            pane.line(to: NSPoint(x: 8, y: 9.5))
            pane.curve(to: NSPoint(x: 6.5, y: 7.5), controlPoint1: NSPoint(x: 7.2, y: 8.9), controlPoint2: NSPoint(x: 7, y: 8))
            pane.line(to: NSPoint(x: 3.7, y: 4.6))
            pane.curve(to: NSPoint(x: 2, y: 5), controlPoint1: NSPoint(x: 2.9, y: 3.8), controlPoint2: NSPoint(x: 2, y: 4))
            pane.close()
            pane.fill()

            let rotation = AffineTransform(m11: -1, m12: 0, m21: 0, m22: -1, tX: 18, tY: 18)
            pane.transform(using: rotation)
            pane.fill()
            return true
        }
        // AppKit chooses white or dark ink to match the menu bar and selection state.
        image.isTemplate = true
        image.accessibilityDescription = "ShimKit"
        return image
    }
}
