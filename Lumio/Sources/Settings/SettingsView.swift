import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    @State private var anthropicKey = KeychainStore.get("anthropicAPIKey") ?? ""
    @State private var openaiKey = KeychainStore.get("openaiAPIKey") ?? ""
    @State private var resumeImportFailed = false

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
                Toggle(L("features.stealth"), isOn: $settings.stealthMode)
                Text(L("features.stealth.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L("section.copilot")) {
                Toggle(L("copilot.enable"), isOn: $settings.copilotEnabled)
                if settings.copilotEnabled {
                    Text(L("copilot.hotkey.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !AudioCaptureService.hasScreenRecordingPermission {
                        Label(L("copilot.permission.screen.short"), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !TranscriptionService.hasSpeechPermission {
                        Label(L("copilot.permission.speech.short"), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Picker(L("copilot.backend"), selection: $settings.copilotBackend) {
                        Text("Anthropic").tag(CopilotBackend.anthropic)
                        Text(L("copilot.backend.custom")).tag(CopilotBackend.openai)
                    }
                    .pickerStyle(.segmented)

                    switch settings.copilotBackend {
                    case .anthropic:
                        SecureField(L("copilot.apiKey"), text: $anthropicKey)
                            .onChange(of: anthropicKey) { _, key in
                                KeychainStore.set(key, for: "anthropicAPIKey")
                            }
                        TextField(L("copilot.model"), text: $settings.copilotModel,
                                  prompt: Text("claude-haiku-4-5-20251001"))
                    case .openai:
                        SecureField(L("copilot.apiKey"), text: $openaiKey)
                            .onChange(of: openaiKey) { _, key in
                                KeychainStore.set(key, for: "openaiAPIKey")
                            }
                        TextField(L("copilot.baseURL"), text: $settings.copilotBaseURL,
                                  prompt: Text("https://api.example.com"))
                        TextField(L("copilot.model"), text: $settings.copilotModel)
                    }

                    Picker(L("copilot.scenario"), selection: $settings.copilotScenario) {
                        Text(L("copilot.scenario.general")).tag(CopilotScenario.general)
                        Text(L("copilot.scenario.interview")).tag(CopilotScenario.interview)
                        Text(L("copilot.scenario.meeting")).tag(CopilotScenario.meeting)
                        Text(L("copilot.scenario.custom")).tag(CopilotScenario.custom)
                    }
                    .pickerStyle(.segmented)

                    if settings.copilotScenario == .custom {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("copilot.systemPrompt"))
                            promptEditor($settings.copilotSystemPrompt, height: 56)
                            Text(L("copilot.systemPrompt.hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    resumeEditor

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("copilot.jobDescription"))
                        promptEditor($settings.copilotJobDescription, height: 56)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("copilot.personaNotes"))
                        promptEditor($settings.copilotPersonaNotes, height: 56)
                        Text(L("copilot.personaNotes.hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(L("copilot.eager"), isOn: $settings.copilotEagerSuggest)
                    Text(L("copilot.eager.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(L("copilot.transcribeSelf"), isOn: $settings.copilotTranscribeSelf)
                    if settings.copilotTranscribeSelf && !MicCaptureService.hasMicPermission {
                        Label(L("copilot.permission.mic.short"), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
        .onChange(of: settings.hudEnabled) { _, _ in
            AppDelegate.shared?.applyHUDSetting()
        }
    }

    private var resumeEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L("copilot.resume"))
                Spacer()
                if !settings.copilotResumeText.isEmpty {
                    Text("\(settings.copilotResumeText.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button(L("copilot.resume.clear")) {
                        settings.copilotResumeText = ""
                        resumeImportFailed = false
                    }
                    .controlSize(.small)
                }
                Button(L("copilot.resume.import")) { importResume() }
                    .controlSize(.small)
            }
            promptEditor($settings.copilotResumeText, height: 72)
            if resumeImportFailed {
                Label(L("copilot.resume.importFailed"), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(L("copilot.resume.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            applyResume(url)
            return true
        }
    }

    private func promptEditor(_ text: Binding<String>, height: CGFloat) -> some View {
        TextEditor(text: text)
            .font(.system(size: 11))
            .frame(height: height)
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
    }

    private func importResume() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ResumeImport.allowedTypes
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        applyResume(url)
    }

    private func applyResume(_ url: URL) {
        if let text = ResumeImport.extractText(from: url) {
            settings.copilotResumeText = text
            resumeImportFailed = false
        } else {
            resumeImportFailed = true
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
