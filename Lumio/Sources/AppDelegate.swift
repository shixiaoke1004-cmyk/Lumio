import AppKit
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
        let controller = NotchWindowController(
            viewModel: viewModel,
            mediaService: mediaService,
            hudService: hudService,
            shelfService: ShelfService(),
            activityService: activityService
        )
        controller.start()
        notchWindowController = controller
        self.mediaService = mediaService
        self.hudService = hudService
        self.activityService = activityService
        self.gestureHandler = gestureHandler
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
    }
}
