import AppKit
import IOKit.ps

enum ActivityKind: Equatable {
    case battery(level: Int, charging: Bool)
}

@MainActor
@Observable
final class ActivityService {
    private(set) var currentActivity: ActivityKind?

    private var runLoopSource: CFRunLoopSource?
    private var lastCharging: Bool?
    private var lastWarnedLevel: Int?
    private var dismissTask: Task<Void, Never>?

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let service = Unmanaged<ActivityService>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                service.powerSourceChanged()
            }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
        lastCharging = Self.batterySnapshot()?.charging
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
        dismissTask?.cancel()
    }

    private func powerSourceChanged() {
        guard let snapshot = Self.batterySnapshot() else { return }

        if snapshot.charging != lastCharging {
            lastCharging = snapshot.charging
            show(.battery(level: snapshot.level, charging: snapshot.charging))
            return
        }

        // Warn once per threshold while discharging.
        if !snapshot.charging, snapshot.level <= 20, lastWarnedLevel != snapshot.level,
           snapshot.level == 20 || snapshot.level == 10 || snapshot.level <= 5 {
            lastWarnedLevel = snapshot.level
            show(.battery(level: snapshot.level, charging: false))
        }
    }

    private func show(_ activity: ActivityKind, duration: TimeInterval = 2.5) {
        currentActivity = activity
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.currentActivity = nil
        }
    }

    nonisolated private static func batterySnapshot() -> (level: Int, charging: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any],
                let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (capacity * 100 / max, charging)
        }
        return nil
    }
}
