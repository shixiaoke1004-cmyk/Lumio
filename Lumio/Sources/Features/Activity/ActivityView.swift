import SwiftUI

struct ActivityView: View {
    let activity: ActivityKind

    var body: some View {
        switch activity {
        case .battery(let level, let charging):
            HStack {
                Image(systemName: charging ? "battery.100percent.bolt" : batterySymbol(level))
                    .font(.system(size: 14))
                    .foregroundStyle(batteryColor(level, charging: charging))
                Spacer()
                Text("\(level)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(batteryColor(level, charging: charging))
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
