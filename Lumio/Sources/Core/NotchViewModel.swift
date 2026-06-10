import SwiftUI

enum NotchState: Equatable {
    case idle
    case compact
    case expanded
}

@MainActor
@Observable
final class NotchViewModel {
    var state: NotchState = .idle
    var isHovering = false

    // Panel canvas is fixed at the max (expanded) size; content shrinks within it.
    static let panelSize = NSSize(width: 640, height: 300)

    var notchGeometry: NotchGeometry?

    var contentSize: NSSize {
        let notch = notchGeometry?.notchRect.size ?? NotchGeometry.virtualNotchSize
        switch state {
        case .idle:
            return NSSize(width: notch.width + 16, height: notch.height)
        case .compact:
            return NSSize(width: notch.width + 120, height: notch.height + 4)
        case .expanded:
            return NSSize(width: 560, height: 230)
        }
    }

    func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        switch (hovering, state) {
        case (true, .idle):
            state = .compact
        case (false, .compact):
            state = .idle
        default:
            break
        }
    }

    func toggleExpanded() {
        state = (state == .expanded) ? .idle : .expanded
    }

    func collapse() {
        state = .idle
    }
}
