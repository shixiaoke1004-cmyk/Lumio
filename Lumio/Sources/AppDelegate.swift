import AppKit
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    // With the SwiftUI lifecycle, NSApp.delegate is SwiftUI's own wrapper,
    // so `NSApp.delegate as? AppDelegate` is nil — expose the instance instead.
    @MainActor private(set) static var shared: AppDelegate?

    private var notchWindowController: NotchWindowController?
    private var mediaService: MediaRemoteService?
    private var hudService: HUDService?
    private var activityService: ActivityService?
    private var gestureHandler: GestureHandler?
    private var copilotService: CopilotService?
    private var notchViewModel: NotchViewModel?
    private var copilotHotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        let viewModel = NotchViewModel()
        let mediaService = MediaRemoteService()
        mediaService.start()
        let hudService = HUDService()
        if AppSettings.shared.hudEnabled {
            hudService.startWhenAuthorized()
        }
        let activityService = ActivityService()
        activityService.start()
        let gestureHandler = GestureHandler(viewModel: viewModel, mediaService: mediaService)
        gestureHandler.start()
        let copilotService = CopilotService()
        let controller = NotchWindowController(
            viewModel: viewModel,
            mediaService: mediaService,
            hudService: hudService,
            shelfService: ShelfService(),
            activityService: activityService,
            copilotService: copilotService
        )
        controller.start()
        self.copilotService = copilotService
        notchViewModel = viewModel

        // Option+Space summons the copilot even from full-screen calls.
        copilotHotKey = HotKey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey)
        ) { [weak self] in
            self?.toggleCopilot()
        }
        notchWindowController = controller
        self.mediaService = mediaService
        self.hudService = hudService
        self.activityService = activityService
        self.gestureHandler = gestureHandler
    }

    @MainActor
    private func toggleCopilot() {
        guard AppSettings.shared.copilotEnabled, let viewModel = notchViewModel else { return }
        if viewModel.state == .expanded, viewModel.expandedTab == .copilot {
            viewModel.collapse()
        } else {
            viewModel.expandedTab = .copilot
            viewModel.state = .expanded
        }
    }

    @MainActor
    func applyStealthSetting() {
        notchWindowController?.applyStealth()
    }

    @MainActor
    func applyHUDSetting() {
        guard let hudService else { return }
        if AppSettings.shared.hudEnabled {
            hudService.startWhenAuthorized()
        } else {
            hudService.stop()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaService?.stop()
        hudService?.stop()
        activityService?.stop()
        gestureHandler?.stop()
        MainActor.assumeIsolated {
            copilotService?.shutdown()
            copilotHotKey?.unregister()
        }
    }
}
