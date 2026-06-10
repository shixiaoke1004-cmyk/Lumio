import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = NotchViewModel()
        let controller = NotchWindowController(viewModel: viewModel)
        controller.start()
        notchWindowController = controller
    }
}
