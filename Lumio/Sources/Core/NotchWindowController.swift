import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private let viewModel: NotchViewModel
    private let mediaService: MediaRemoteService
    private let hudService: HUDService
    private let shelfService: ShelfService
    private var screenObserver: Any?

    init(
        viewModel: NotchViewModel,
        mediaService: MediaRemoteService,
        hudService: HUDService,
        shelfService: ShelfService
    ) {
        self.viewModel = viewModel
        self.mediaService = mediaService
        self.hudService = hudService
        self.shelfService = shelfService
    }

    func start() {
        showPanel()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.repositionPanel()
            }
        }
    }

    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func showPanel() {
        guard let screen = targetScreen else { return }
        let geometry = NotchGeometry.current(for: screen)
        viewModel.notchGeometry = geometry

        let panel = NotchPanel(
            contentRect: geometry.panelFrame(expandedSize: NotchViewModel.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false

        let hosting = NotchHostingView(rootView: NotchContainerView(
            viewModel: viewModel,
            mediaService: mediaService,
            hudService: hudService,
            shelfService: shelfService
        ))
        hosting.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = hosting

        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func repositionPanel() {
        guard let panel, let screen = targetScreen else { return }
        let geometry = NotchGeometry.current(for: screen)
        viewModel.notchGeometry = geometry
        panel.setFrame(geometry.panelFrame(expandedSize: NotchViewModel.panelSize), display: true)
    }
}
