import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var mediaService: MediaRemoteService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = NotchViewModel()
        let mediaService = MediaRemoteService()
        mediaService.start()
        let controller = NotchWindowController(viewModel: viewModel, mediaService: mediaService)
        controller.start()
        notchWindowController = controller
        self.mediaService = mediaService
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaService?.stop()
    }
}
