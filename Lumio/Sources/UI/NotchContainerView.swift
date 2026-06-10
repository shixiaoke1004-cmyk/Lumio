import SwiftUI

struct NotchContainerView: View {
    @Bindable var viewModel: NotchViewModel

    private var cornerRadius: CGFloat {
        switch viewModel.state {
        case .idle: 8
        case .compact: 12
        case .expanded: 24
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            notchShape
            Spacer(minLength: 0)
        }
        .frame(width: NotchViewModel.panelSize.width, height: NotchViewModel.panelSize.height, alignment: .top)
    }

    private var notchShape: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                cornerRadii: .init(bottomLeading: cornerRadius, bottomTrailing: cornerRadius)
            )
            .fill(.black)

            content
        }
        .frame(width: viewModel.contentSize.width, height: viewModel.contentSize.height)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.state)
        .onHover { viewModel.hoverChanged($0) }
        .onTapGesture { viewModel.toggleExpanded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Color.clear
        case .compact:
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
        case .expanded:
            VStack {
                Text("Lumio")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("Expanded panel placeholder")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
