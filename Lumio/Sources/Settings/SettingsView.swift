import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section(L("section.general")) {
                Picker(L("general.language"), selection: $settings.language) {
                    Text(L("language.system")).tag(AppLanguage.system)
                    Text(L("language.english")).tag(AppLanguage.english)
                    Text(L("language.chinese")).tag(AppLanguage.chinese)
                }
                Toggle(L("general.launchAtLogin"), isOn: $settings.launchAtLogin)
            }

            Section(L("section.appearance")) {
                sliderRow(
                    L("appearance.islandSize"),
                    value: $settings.expandedScale,
                    range: 0.85...1.3,
                    label: String(format: "%.0f%%", settings.expandedScale * 100)
                )
                Picker(L("appearance.position"), selection: $settings.expandedPosition) {
                    Text(L("position.left")).tag(ExpandedPosition.left)
                    Text(L("position.center")).tag(ExpandedPosition.center)
                    Text(L("position.right")).tag(ExpandedPosition.right)
                }
                .pickerStyle(.segmented)
                sliderRow(
                    L("appearance.topOffset"),
                    value: $settings.expandedTopOffset,
                    range: 0...24,
                    label: String(format: "%.0f pt", settings.expandedTopOffset)
                )
            }

            Section(L("section.behavior")) {
                Toggle(L("behavior.hoverCompact"), isOn: $settings.hoverCompactEnabled)
                Toggle(L("behavior.expandLock"), isOn: $settings.expandLock)
                Text(L("behavior.expandLock.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                sliderRow(
                    L("behavior.hudDuration"),
                    value: $settings.hudDuration,
                    range: 0.5...4,
                    label: String(format: "%.1f %@", settings.hudDuration, L("unit.seconds"))
                )
                sliderRow(
                    L("behavior.activityDuration"),
                    value: $settings.activityDuration,
                    range: 1...6,
                    label: String(format: "%.1f %@", settings.activityDuration, L("unit.seconds"))
                )
            }

            Section(L("section.features")) {
                Toggle(L("features.hud"), isOn: $settings.hudEnabled)
                if settings.hudEnabled && !HUDService.hasAccessibilityPermission {
                    Label(L("features.hud.warning"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Toggle(L("features.gestures"), isOn: $settings.gesturesEnabled)
                Toggle(L("features.battery"), isOn: $settings.batteryActivityEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
        .onChange(of: settings.hudEnabled) { _, _ in
            AppDelegate.shared?.applyHUDSetting()
        }
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(label)
                    .foregroundStyle(.secondary)
                    .font(.callout.monospacedDigit())
            }
            Slider(value: value, in: range)
        }
    }
}
