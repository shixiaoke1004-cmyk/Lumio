import SwiftUI

struct HUDView: View {
    let hud: HUDKind

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 18)
                .contentTransition(.symbolEffect(.replace))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(level))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }

    private var level: Float {
        switch hud {
        case .volume(let level, let muted): muted ? 0 : level
        case .brightness(let level): level
        }
    }

    private var symbol: String {
        switch hud {
        case .volume(let level, let muted):
            if muted || level == 0 { "speaker.slash.fill" }
            else if level < 0.34 { "speaker.wave.1.fill" }
            else if level < 0.67 { "speaker.wave.2.fill" }
            else { "speaker.wave.3.fill" }
        case .brightness:
            "sun.max.fill"
        }
    }

    private var barColor: Color {
        switch hud {
        case .volume(let level, _):
            // Glow theme: green shifts to red past 80% volume.
            level > 0.8 ? .red : .green
        case .brightness:
            .yellow
        }
    }
}
