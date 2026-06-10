import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var mediaService: MediaRemoteService?
    private var hudService: HUDService?

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
        let controller = NotchWindowController(
            viewModel: viewModel,
            mediaService: mediaService,
            hudService: hudService,
            shelfService: ShelfService()
        )
        controller.start()
        notchWindowController = controller
        self.mediaService = mediaService
        self.hudService = hudService
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaService?.stop()
        hudService?.stop()
    }
}
