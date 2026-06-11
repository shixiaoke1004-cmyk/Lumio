import AppKit

@MainActor
final class GestureHandler {
    private let viewModel: NotchViewModel
    private let mediaService: MediaRemoteService
    private var monitor: Any?

    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var consumed = false
    private var lastEventTime: TimeInterval = 0

    init(viewModel: NotchViewModel, mediaService: MediaRemoteService) {
        self.viewModel = viewModel
        self.mediaService = mediaService
    }

    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.window is NotchPanel, AppSettings.shared.gesturesEnabled else { return }

        if event.phase == .began || event.timestamp - lastEventTime > 0.3 {
            accumulatedX = 0
            accumulatedY = 0
            consumed = false
        }
        lastEventTime = event.timestamp
        guard !consumed, event.momentumPhase == [] else { return }

        accumulatedX += event.scrollingDeltaX
        accumulatedY += event.scrollingDeltaY

        // Natural scrolling: swiping fingers down yields positive deltaY.
        if accumulatedY < -30, viewModel.state == .expanded, !AppSettings.shared.expandLock {
            viewModel.collapse()
            consumed = true
        } else if accumulatedY > 30, viewModel.state != .expanded {
            viewModel.state = .expanded
            consumed = true
        } else if abs(accumulatedX) > 50, viewModel.state != .expanded, mediaService.nowPlaying != nil {
            mediaService.send(accumulatedX < 0 ? .nextTrack : .previousTrack)
            consumed = true
        }
    }
}
