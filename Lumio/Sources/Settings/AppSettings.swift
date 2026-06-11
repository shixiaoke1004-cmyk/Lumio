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

    var expandedScale: Double {
        didSet { UserDefaults.standard.set(expandedScale, forKey: "expandedScale") }
    }
    var expandedPosition: ExpandedPosition {
        didSet { UserDefaults.standard.set(expandedPosition.rawValue, forKey: "expandedPosition") }
    }
    var expandedTopOffset: Double {
        didSet { UserDefaults.standard.set(expandedTopOffset, forKey: "expandedTopOffset") }
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
            "expandedTopOffset": 0.0,
            "hoverCompactEnabled": true,
            "expandLock": false,
            "hudDuration": 1.5,
            "activityDuration": 2.5,
        ])
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        hudEnabled = defaults.bool(forKey: "hudEnabled")
        gesturesEnabled = defaults.bool(forKey: "gesturesEnabled")
        batteryActivityEnabled = defaults.bool(forKey: "batteryActivityEnabled")
        expandedScale = defaults.double(forKey: "expandedScale")
        expandedPosition = ExpandedPosition(rawValue: defaults.string(forKey: "expandedPosition") ?? "") ?? .center
        expandedTopOffset = defaults.double(forKey: "expandedTopOffset")
        hoverCompactEnabled = defaults.bool(forKey: "hoverCompactEnabled")
        expandLock = defaults.bool(forKey: "expandLock")
        hudDuration = defaults.double(forKey: "hudDuration")
        activityDuration = defaults.double(forKey: "activityDuration")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
