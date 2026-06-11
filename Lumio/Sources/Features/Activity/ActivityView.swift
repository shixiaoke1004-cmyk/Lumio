import SwiftUI

struct ActivityView: View {
    let activity: ActivityKind
    let notchWidth: CGFloat

    var body: some View {
        switch activity {
        case .battery(let level, let charging):
            HStack(spacing: 0) {
                // Left ear: battery glyph hugs the notch's left edge.
                Image(systemName: charging ? "battery.100percent.bolt" : batterySymbol(level))
                    .font(.system(size: 14))
                    .foregroundStyle(batteryColor(level, charging: charging))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 10)

                Color.clear.frame(width: notchWidth)

                // Right ear: percentage past the notch.
                Text("\(level)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(batteryColor(level, charging: charging))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
        }
    }

    private func batterySymbol(_ level: Int) -> String {
        switch level {
        case ..<10: "battery.0percent"
        case ..<35: "battery.25percent"
        case ..<60: "battery.50percent"
        case ..<85: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private func batteryColor(_ level: Int, charging: Bool) -> Color {
        if charging { return .green }
        return level <= 20 ? .red : .white
    }
}
