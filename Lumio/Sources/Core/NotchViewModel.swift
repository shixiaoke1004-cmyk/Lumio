import SwiftUI

enum NotchState: Equatable {
    case idle
    case compact
    case expanded
}

enum ExpandedTab: Equatable {
    case media
    case shelf
}

@MainActor
@Observable
final class NotchViewModel {
    var state: NotchState = .idle
    var expandedTab: ExpandedTab = .media
    var isHovering = false
    var hudVisible = false

    // Panel canvas is fixed at the max (expanded) size; content shrinks within it.
    static let panelSize = NSSize(width: 640, height: 360)

    var notchGeometry: NotchGeometry?

    // Always-black footprint that hides the hardware notch even while
    // the animated shape spring-overshoots below its resting size.
    var notchBaseSize: NSSize {
        let notch = notchGeometry?.notchRect.size ?? NotchGeometry.virtualNotchSize
        return NSSize(width: notch.width + 16, height: notch.height)
    }

    var contentSize: NSSize {
        let notch = notchGeometry?.notchRect.size ?? NotchGeometry.virtualNotchSize
        switch state {
        case .idle:
            return hudVisible
                ? NSSize(width: notch.width + 220, height: notch.height + 4)
                : notchBaseSize
        case .compact:
            return NSSize(width: notch.width + 120, height: notch.height + 4)
        case .expanded:
            return NSSize(width: 460, height: 190)
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
