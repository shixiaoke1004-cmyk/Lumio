import Foundation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }

    var hudEnabled: Bool {
        didSet { UserDefaults.standard.set(hudEnabled, forKey: "hudEnabled") }
    }
    var gesturesEnabled: Bool {
        didSet { UserDefaults.standard.set(gesturesEnabled, forKey: "gesturesEnabled") }
    }
    var batteryActivityEnabled: Bool {
        didSet { UserDefaults.standard.set(batteryActivityEnabled, forKey: "batteryActivityEnabled") }
    }

    // When on, the notch panel is excluded from screen capture / sharing
    // (sharingType = .none), so it stays invisible to the other party.
    var stealthMode: Bool {
        didSet {
            UserDefaults.standard.set(stealthMode, forKey: "stealthMode")
            AppDelegate.shared?.applyStealthSetting()
        }
    }

    var copilotEnabled: Bool {
        didSet { UserDefaults.standard.set(copilotEnabled, forKey: "copilotEnabled") }
    }
    var copilotBackend: CopilotBackend {
        didSet { UserDefaults.standard.set(copilotBackend.rawValue, forKey: "copilotBackend") }
    }
    var copilotModel: String {
        didSet { UserDefaults.standard.set(copilotModel, forKey: "copilotModel") }
    }
    var copilotBaseURL: String {
        didSet { UserDefaults.standard.set(copilotBaseURL, forKey: "copilotBaseURL") }
    }
    var copilotSystemPrompt: String {
        didSet { UserDefaults.standard.set(copilotSystemPrompt, forKey: "copilotSystemPrompt") }
    }
    // Auto-request a suggestion each time the other party finishes a sentence.
    var copilotAutoSuggest: Bool {
        didSet { UserDefaults.standard.set(copilotAutoSuggest, forKey: "copilotAutoSuggest") }
    }
    // Ask as soon as the partial transcript stabilizes instead of waiting for
    // the recognizer's isFinal, trading extra API calls for faster answers.
    var copilotEagerSuggest: Bool {
        didSet { UserDefaults.standard.set(copilotEagerSuggest, forKey: "copilotEagerSuggest") }
    }
    var copilotScenario: CopilotScenario {
        didSet { UserDefaults.standard.set(copilotScenario.rawValue, forKey: "copilotScenario") }
    }
    var copilotResumeText: String {
        didSet { UserDefaults.standard.set(copilotResumeText, forKey: "copilotResumeText") }
    }
    var copilotJobDescription: String {
        didSet { UserDefaults.standard.set(copilotJobDescription, forKey: "copilotJobDescription") }
    }
    var copilotPersonaNotes: String {
        didSet { UserDefaults.standard.set(copilotPersonaNotes, forKey: "copilotPersonaNotes") }
    }
    // Also transcribe the user's own microphone alongside the other party.
    var copilotTranscribeSelf: Bool {
        didSet { UserDefaults.standard.set(copilotTranscribeSelf, forKey: "copilotTranscribeSelf") }
    }

    var expandedScale: Double {
        didSet { UserDefaults.standard.set(expandedScale, forKey: "expandedScale") }
    }
    var expandedPosition: ExpandedPosition {
        didSet { UserDefaults.standard.set(expandedPosition.rawValue, forKey: "expandedPosition") }
    }

    var hoverCompactEnabled: Bool {
        didSet { UserDefaults.standard.set(hoverCompactEnabled, forKey: "hoverCompactEnabled") }
    }
    var expandLock: Bool {
        didSet { UserDefaults.standard.set(expandLock, forKey: "expandLock") }
    }
    var hudDuration: Double {
        didSet { UserDefaults.standard.set(hudDuration, forKey: "hudDuration") }
    }
    var activityDuration: Double {
        didSet { UserDefaults.standard.set(activityDuration, forKey: "activityDuration") }
    }

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "language": AppLanguage.system.rawValue,
            "hudEnabled": true,
            "gesturesEnabled": true,
            "batteryActivityEnabled": true,
            "expandedScale": 1.0,
            "expandedPosition": ExpandedPosition.center.rawValue,
            "hoverCompactEnabled": true,
            "expandLock": false,
            "hudDuration": 1.5,
            "activityDuration": 2.5,
            "stealthMode": false,
            "copilotEnabled": false,
            "copilotBackend": CopilotBackend.anthropic.rawValue,
            "copilotModel": "",
            "copilotBaseURL": "",
            "copilotSystemPrompt": "",
            "copilotAutoSuggest": false,
            "copilotEagerSuggest": true,
            "copilotScenario": CopilotScenario.general.rawValue,
            "copilotResumeText": "",
            "copilotJobDescription": "",
            "copilotPersonaNotes": "",
            "copilotTranscribeSelf": true,
        ])
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        hudEnabled = defaults.bool(forKey: "hudEnabled")
        gesturesEnabled = defaults.bool(forKey: "gesturesEnabled")
        batteryActivityEnabled = defaults.bool(forKey: "batteryActivityEnabled")
        expandedScale = defaults.double(forKey: "expandedScale")
        expandedPosition = ExpandedPosition(rawValue: defaults.string(forKey: "expandedPosition") ?? "") ?? .center
        hoverCompactEnabled = defaults.bool(forKey: "hoverCompactEnabled")
        expandLock = defaults.bool(forKey: "expandLock")
        hudDuration = defaults.double(forKey: "hudDuration")
        activityDuration = defaults.double(forKey: "activityDuration")
        stealthMode = defaults.bool(forKey: "stealthMode")
        copilotEnabled = defaults.bool(forKey: "copilotEnabled")
        copilotBackend = CopilotBackend(rawValue: defaults.string(forKey: "copilotBackend") ?? "") ?? .anthropic
        copilotModel = defaults.string(forKey: "copilotModel") ?? ""
        copilotBaseURL = defaults.string(forKey: "copilotBaseURL") ?? ""
        copilotSystemPrompt = defaults.string(forKey: "copilotSystemPrompt") ?? ""
        copilotAutoSuggest = defaults.bool(forKey: "copilotAutoSuggest")
        copilotEagerSuggest = defaults.bool(forKey: "copilotEagerSuggest")
        copilotScenario = CopilotScenario(rawValue: defaults.string(forKey: "copilotScenario") ?? "") ?? .general
        copilotResumeText = defaults.string(forKey: "copilotResumeText") ?? ""
        copilotJobDescription = defaults.string(forKey: "copilotJobDescription") ?? ""
        copilotPersonaNotes = defaults.string(forKey: "copilotPersonaNotes") ?? ""
        copilotTranscribeSelf = defaults.bool(forKey: "copilotTranscribeSelf")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
