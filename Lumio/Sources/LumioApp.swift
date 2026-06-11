import SwiftUI

@main
struct LumioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Lumio", systemImage: "sparkles.rectangle.stack") {
            MenuContent()
        }
    }
}

private struct MenuContent: View {
    var body: some View {
        Button(L("menu.about")) {
            NSApp.orderFrontStandardAboutPanel(nil)
        }
        Button(L("menu.settings")) {
            SettingsWindowManager.shared.open()
        }
        .keyboardShortcut(",")
        Divider()
        Button(L("menu.quit")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
