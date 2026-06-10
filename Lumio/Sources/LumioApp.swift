import SwiftUI

@main
struct LumioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Lumio", systemImage: "sparkles.rectangle.stack") {
            Button("About Lumio") {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Divider()
            Button("Quit Lumio") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
