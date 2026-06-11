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
    var activityVisible = false
    var mediaPlaying = false

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
            if hudVisible {
                return NSSize(width: notch.width + 220, height: notch.height + 4)
            }
            if activityVisible {
                return NSSize(width: notch.width + 150, height: notch.height + 4)
            }
            return notchBaseSize
        case .compact:
            if hudVisible {
                return NSSize(width: notch.width + 220, height: notch.height + 4)
            }
            if activityVisible {
                return NSSize(width: notch.width + 150, height: notch.height + 4)
            }
            return NSSize(width: notch.width + 120, height: notch.height + 4)
        case .expanded:
            let scale = AppSettings.shared.expandedScale
            return NSSize(width: 460 * scale, height: 190 * scale)
        }
    }

    func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        switch (hovering, state) {
        case (true, .idle):
            if AppSettings.shared.hoverCompactEnabled {
                state = .compact
            }
        case (false, .compact):
            // While media plays the compact strip stays up like an ongoing
            // live activity; it only retracts when playback stops.
            if !mediaPlaying {
                state = .idle
            }
        default:
            break
        }
    }

    func mediaPlayingChanged(_ playing: Bool) {
        mediaPlaying = playing
        if playing, state == .idle {
            state = .compact
        } else if !playing, state == .compact, !isHovering {
            state = .idle
        }
    }

    func toggleExpanded() {
        if state == .expanded {
            if !AppSettings.shared.expandLock {
                state = .idle
            }
        } else {
            state = .expanded
        }
    }

    func collapse() {
        state = .idle
    }
}
