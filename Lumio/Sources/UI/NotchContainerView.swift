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
    let activityService: ActivityService

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
                .transition(.blurReplace.combined(with: .opacity))
        }
        .frame(width: viewModel.contentSize.width, height: viewModel.contentSize.height)
        .offset(x: expandedXOffset)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.state)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.hudVisible)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.contentSize)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: expandedXOffset)
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
        .onChange(of: activityService.currentActivity) { _, activity in
            viewModel.activityVisible = (activity != nil)
        }
        .onChange(of: mediaService.nowPlaying?.isPlaying ?? false, initial: true) { _, playing in
            viewModel.mediaPlayingChanged(playing)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.activityVisible)
    }

    private var expandedXOffset: CGFloat {
        guard viewModel.state == .expanded else { return 0 }
        let margin = (NotchViewModel.panelSize.width - viewModel.contentSize.width) / 2
        switch AppSettings.shared.expandedPosition {
        case .left: return -margin
        case .center: return 0
        case .right: return margin
        }
    }

    private var notchCorners: RectangleCornerRadii {
        .init(bottomLeading: cornerRadius, bottomTrailing: cornerRadius)
    }

    @ViewBuilder
    private var shapeBackground: some View {
        let expanded = viewModel.state == .expanded
        // Every property here is animatable so the black notch morphs into
        // frosted glass instead of swapping abruptly.
        UnevenRoundedRectangle(cornerRadii: notchCorners)
            .fill(.black.opacity(expanded ? 0.55 : 1))
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(UnevenRoundedRectangle(cornerRadii: notchCorners))
                    .opacity(expanded ? 1 : 0)
            )
            .overlay {
                UnevenRoundedRectangle(cornerRadii: notchCorners)
                    .strokeBorder(.white.opacity(expanded ? 0.08 : 0), lineWidth: 1)
            }
            .shadow(color: .black.opacity(expanded ? 0.35 : 0), radius: 18, y: 8)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            if let hud = hudService.currentHUD {
                HUDView(hud: hud)
            } else if let activity = activityService.currentActivity {
                ActivityView(activity: activity)
            } else {
                Color.clear
            }
        case .compact:
            if let hud = hudService.currentHUD {
                HUDView(hud: hud)
            } else if let activity = activityService.currentActivity {
                ActivityView(activity: activity)
            } else if let nowPlaying = mediaService.nowPlaying {
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
                            Text(L("media.nothingPlaying"))
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
            .padding(.top, AppSettings.shared.expandedTopOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            if AppSettings.shared.expandLock {
                Button {
                    viewModel.collapse()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 30, height: 22)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            tabButton(.media, symbol: "music.note")
            tabButton(.shelf, symbol: "tray.full")
            Button {
                SettingsWindowManager.shared.open()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 30, height: 22)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
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
