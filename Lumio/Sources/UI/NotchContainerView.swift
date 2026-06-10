import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct NotchContainerView: View {
    @Bindable var viewModel: NotchViewModel
    let mediaService: MediaRemoteService
    let hudService: HUDService
    let shelfService: ShelfService

    @State private var isDropTargeted = false

    private var cornerRadius: CGFloat {
        switch viewModel.state {
        case .idle: 8
        case .compact: 12
        case .expanded: 24
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Static cover so the hardware notch never peeks out while the
            // animated shape spring-overshoots below its resting size.
            UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 8, bottomTrailing: 8))
                .fill(.black)
                .frame(width: viewModel.notchBaseSize.width, height: viewModel.notchBaseSize.height)
            notchShape
        }
        .frame(width: NotchViewModel.panelSize.width, height: NotchViewModel.panelSize.height, alignment: .top)
    }

    private var notchShape: some View {
        ZStack(alignment: .top) {
            shapeBackground
            content
        }
        .frame(width: viewModel.contentSize.width, height: viewModel.contentSize.height)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.state)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.hudVisible)
        .onHover { viewModel.hoverChanged($0) }
        .onTapGesture { viewModel.toggleExpanded() }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            shelfService.handleDrop(providers)
        }
        .onChange(of: isDropTargeted) { _, targeted in
            // Dragging a file over the collapsed notch opens the shelf.
            if targeted, viewModel.state != .expanded {
                viewModel.state = .expanded
                viewModel.expandedTab = .shelf
            }
        }
        .onChange(of: hudService.currentHUD) { _, hud in
            viewModel.hudVisible = (hud != nil)
        }
    }

    private var notchCorners: RectangleCornerRadii {
        .init(bottomLeading: cornerRadius, bottomTrailing: cornerRadius)
    }

    @ViewBuilder
    private var shapeBackground: some View {
        if viewModel.state == .expanded {
            // Frosted glass for the expanded panel; idle/compact stay pure
            // black to blend into the hardware notch.
            UnevenRoundedRectangle(cornerRadii: notchCorners)
                .fill(.black.opacity(0.55))
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(UnevenRoundedRectangle(cornerRadii: notchCorners))
                )
                .overlay {
                    UnevenRoundedRectangle(cornerRadii: notchCorners)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        } else {
            UnevenRoundedRectangle(cornerRadii: notchCorners)
                .fill(.black)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            if let hud = hudService.currentHUD {
                HUDView(hud: hud)
            } else {
                Color.clear
            }
        case .compact:
            if let nowPlaying = mediaService.nowPlaying {
                MediaCompactView(nowPlaying: nowPlaying)
            } else {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.system(size: 12))
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
            }
        case .expanded:
            VStack(spacing: 0) {
                tabBar
                switch viewModel.expandedTab {
                case .media:
                    if let nowPlaying = mediaService.nowPlaying {
                        MediaExpandedView(nowPlaying: nowPlaying, service: mediaService)
                    } else {
                        VStack {
                            Text("Lumio")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Nothing playing")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .shelf:
                    ShelfView(shelf: shelfService)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.media, symbol: "music.note")
            tabButton(.shelf, symbol: "tray.full")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 16)
        .padding(.top, 6)
        .frame(height: 30, alignment: .bottom)
    }

    private func tabButton(_ tab: ExpandedTab, symbol: String) -> some View {
        let selected = viewModel.expandedTab == tab
        return Button {
            viewModel.expandedTab = tab
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .black : .white.opacity(0.65))
                .frame(width: 30, height: 22)
                .background(
                    Capsule().fill(selected ? Color.white.opacity(0.9) : .white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}
