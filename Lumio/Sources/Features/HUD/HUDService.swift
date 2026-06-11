import AppKit
import Foundation
import os

enum HUDKind: Equatable {
    case volume(level: Float, muted: Bool)
    case brightness(level: Float)
}

@MainActor
@Observable
final class HUDService {
    private(set) var currentHUD: HUDKind?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var dismissTask: Task<Void, Never>?
    private var authPollTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.lumio.Lumio", category: "HUD")

    // NX key types from IOKit/hidsystem/ev_keymap.h
    private nonisolated static let soundUp: Int32 = 0
    private nonisolated static let soundDown: Int32 = 1
    private nonisolated static let brightnessUp: Int32 = 2
    private nonisolated static let brightnessDown: Int32 = 3
    private nonisolated static let mute: Int32 = 7

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // Accessibility grants are keyed to the binary's code signature; an
    // adhoc-signed build that is rebuilt or moved loses its grant, and the
    // user re-enables it in System Settings while the app is already running.
    // Prompt once, then poll so the tap comes up the moment trust is granted
    // instead of forcing a relaunch.
    func startWhenAuthorized() {
        if Self.hasAccessibilityPermission {
            start()
            return
        }
        Self.requestAccessibilityPermission()
        guard authPollTask == nil else { return }
        authPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if Self.hasAccessibilityPermission {
                    self.authPollTask = nil
                    self.start()
                    return
                }
            }
        }
    }

    func start() {
        guard eventTap == nil else { return }
        guard Self.hasAccessibilityPermission else {
            logger.warning("accessibility permission missing, HUD takeover disabled")
            return
        }

        let systemDefined = CGEventMask(1 << 14) // NSEvent.EventType.systemDefined
        let callback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(cgEvent) }
            let service = Unmanaged<HUDService>.fromOpaque(userInfo).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                Task { @MainActor in service.reenableTap() }
                return Unmanaged.passUnretained(cgEvent)
            }
            let handled = HUDService.handleEvent(cgEvent, service: service)
            return handled ? nil : Unmanaged.passUnretained(cgEvent)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: systemDefined,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("failed to create event tap")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        authPollTask?.cancel()
        authPollTask = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func reenableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // Runs on the event tap thread; must not touch main-actor state directly.
    private nonisolated static func handleEvent(_ cgEvent: CGEvent, service: HUDService) -> Bool {
        guard let nsEvent = NSEvent(cgEvent: cgEvent), nsEvent.subtype.rawValue == 8 else {
            return false
        }

        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = data1 & 0x0000FFFF
        let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A

        let isVolumeKey = [soundUp, soundDown, mute].contains(keyCode)
        let isBrightnessKey = [brightnessUp, brightnessDown].contains(keyCode)
        guard isVolumeKey || isBrightnessKey else { return false }

        if isKeyDown {
            Task { @MainActor in
                service.processKey(keyCode)
            }
        }
        // Swallow both key-down and key-up so the system HUD never appears.
        return true
    }

    private func processKey(_ keyCode: Int32) {
        switch keyCode {
        case Self.soundUp:
            SystemVolume.isMuted = false
            SystemVolume.volume = min(1, SystemVolume.volume + 1.0 / 16.0)
            show(.volume(level: SystemVolume.volume, muted: false))
        case Self.soundDown:
            SystemVolume.isMuted = false
            SystemVolume.volume = max(0, SystemVolume.volume - 1.0 / 16.0)
            show(.volume(level: SystemVolume.volume, muted: false))
        case Self.mute:
            SystemVolume.isMuted.toggle()
            show(.volume(level: SystemVolume.volume, muted: SystemVolume.isMuted))
        case Self.brightnessUp:
            SystemBrightness.brightness = min(1, SystemBrightness.brightness + 1.0 / 16.0)
            show(.brightness(level: SystemBrightness.brightness))
        case Self.brightnessDown:
            SystemBrightness.brightness = max(0, SystemBrightness.brightness - 1.0 / 16.0)
            show(.brightness(level: SystemBrightness.brightness))
        default:
            break
        }
    }

    private func show(_ hud: HUDKind) {
        currentHUD = hud
        dismissTask?.cancel()
        let duration = AppSettings.shared.hudDuration
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.currentHUD = nil
        }
    }
}
