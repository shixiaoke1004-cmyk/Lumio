import AppKit

struct NotchGeometry: Equatable {
    let screenFrame: NSRect
    let notchRect: NSRect
    let hasPhysicalNotch: Bool

    static let virtualNotchSize = NSSize(width: 200, height: 32)

    static func current(for screen: NSScreen) -> NotchGeometry {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top

        if topInset > 0,
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            let notchWidth = rightArea.minX - leftArea.maxX
            let notchRect = NSRect(
                x: leftArea.maxX,
                y: frame.maxY - topInset,
                width: notchWidth,
                height: topInset
            )
            return NotchGeometry(screenFrame: frame, notchRect: notchRect, hasPhysicalNotch: true)
        }

        let size = virtualNotchSize
        let notchRect = NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        return NotchGeometry(screenFrame: frame, notchRect: notchRect, hasPhysicalNotch: false)
    }

    func panelFrame(expandedSize: NSSize) -> NSRect {
        NSRect(
            x: notchRect.midX - expandedSize.width / 2,
            y: notchRect.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )
    }
}
