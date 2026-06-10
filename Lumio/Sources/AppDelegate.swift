import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var mediaService: MediaRemoteService?
    private var hudService: HUDService?
    private var activityService: ActivityService?
    private var gestureHandler: GestureHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = NotchViewModel()
        let mediaService = MediaRemoteService()
        mediaService.start()
        let hudService = HUDService()
        if HUDService.hasAccessibilityPermission {
            hudService.start()
        } else {
            HUDService.requestAccessibilityPermission()
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

    func applicationWillTerminate(_ notification: Notification) {
        mediaService?.stop()
        hudService?.stop()
        activityService?.stop()
        gestureHandler?.stop()
    }
}
