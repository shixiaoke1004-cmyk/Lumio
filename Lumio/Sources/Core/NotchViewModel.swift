import SwiftUI

enum NotchState: Equatable {
    case idle
    case compact
    case expanded
}

enum ExpandedTab: Equatable {
    case media
    case shelf
    case copilot
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

    // Panel canvas is fixed at the max (expanded) size; content shrinks within
    // it. Sized with generous horizontal/vertical slack so the largest expanded
    // panel (copilot at max scale) plus its drop shadow never clip, and so the
    // left/right position offset still has room to travel.
    static let panelSize = NSSize(width: 760, height: 480)

    var notchGeometry: NotchGeometry?

    // Always-black footprint that hides the hardware notch even while
    // the animated shape spring-overshoots below its resting size.
    var notchBaseSize: NSSize {
        let notch = notchGeometry?.notchRect.size ?? NotchGeometry.virtualNotchSize
        return NSSize(width: notch.width + 16, height: notch.height)
    }

    // Width of the hardware notch the side "ears" must leave clear.
    var notchWidth: CGFloat {
        notchGeometry?.notchRect.size.width ?? NotchGeometry.virtualNotchSize.width
    }

    // Height of the hardware notch; the expanded content reserves this much
    // at the top so nothing ever sits behind the physical notch.
    var notchHeight: CGFloat {
        notchGeometry?.notchRect.size.height ?? NotchGeometry.virtualNotchSize.height
    }

    // Expanded content is authored at this fixed base size, then scaled by
    // `expandedScale` via .scaleEffect so every icon/font/padding tracks the
    // setting uniformly instead of staying at a fixed point size.
    static let expandedBodyWidth: CGFloat = 460
    // Fixed gap below the notch before the content (tab bar) begins.
    static let expandedTopOffset: CGFloat = 24
    var expandedBodyHeight: CGFloat {
        switch expandedTab {
        case .copilot: 280   // room for streaming answer text
        case .shelf: 190
        case .media: 150     // tabBar + 96pt artwork row, no dead space
        }
    }

    var contentSize: NSSize {
        let notch = notchGeometry?.notchRect.size ?? NotchGeometry.virtualNotchSize
        switch state {
        case .idle:
            if hudVisible {
                return NSSize(width: notch.width + 160, height: notch.height + 4)
            }
            if activityVisible {
                return NSSize(width: notch.width + 140, height: notch.height + 4)
            }
            return notchBaseSize
        case .compact:
            if hudVisible {
                return NSSize(width: notch.width + 160, height: notch.height + 4)
            }
            if activityVisible {
                return NSSize(width: notch.width + 140, height: notch.height + 4)
            }
            return NSSize(width: notch.width + 120, height: notch.height + 4)
        case .expanded:
            // Width/body scale with the setting; the notch reserve and the
            // user top offset stay in screen points (added unscaled) so the
            // tab bar always clears the physical notch at every scale.
            let scale = AppSettings.shared.expandedScale
            let topReserve = notchHeight + Self.expandedTopOffset
            return NSSize(
                width: Self.expandedBodyWidth * scale,
                height: topReserve + expandedBodyHeight * scale
            )
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
                collapse()
            }
        } else {
            state = .expanded
        }
    }

    func collapse() {
        // While media plays the island falls back to the compact strip,
        // mirroring an ongoing live activity, not to the bare notch.
        state = mediaPlaying ? .compact : .idle
    }
}
