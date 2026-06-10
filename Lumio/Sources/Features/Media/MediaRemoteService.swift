import Foundation
import os

@MainActor
@Observable
final class MediaRemoteService {
    private(set) var nowPlaying: NowPlaying?

    private var streamProcess: Process?
    private var currentPayload: [String: Any] = [:]
    private let logger = Logger(subsystem: "app.lumio.Lumio", category: "MediaRemote")

    private static var scriptURL: URL? {
        Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")
    }

    private static var frameworkURL: URL? {
        Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework")
    }

    func start() {
        guard streamProcess == nil else { return }
        guard let script = Self.scriptURL, let framework = Self.frameworkURL else {
            logger.error("adapter script or framework missing from bundle")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, framework.path, "stream", "--debounce=100"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let lineBuffer = LineBuffer()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            for line in lineBuffer.append(data) {
                Task { @MainActor [weak self] in
                    self?.handleLine(line)
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.streamProcess = nil
                self?.logger.warning("adapter stream terminated")
            }
        }

        do {
            try process.run()
            streamProcess = process
        } catch {
            logger.error("failed to launch adapter: \(error)")
        }
    }

    func stop() {
        streamProcess?.terminate()
        streamProcess = nil
    }

    func send(_ command: MediaCommand) {
        runOneShot(arguments: ["send", String(command.rawValue)])
    }

    private func runOneShot(arguments: [String]) {
        guard let script = Self.scriptURL, let framework = Self.frameworkURL else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, framework.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private func handleLine(_ line: Data) {
        guard
            let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            json["type"] as? String == "data",
            let payload = json["payload"] as? [String: Any]
        else { return }

        let isDiff = json["diff"] as? Bool ?? false
        if isDiff {
            for (key, value) in payload {
                if value is NSNull {
                    currentPayload.removeValue(forKey: key)
                } else {
                    currentPayload[key] = value
                }
            }
        } else {
            currentPayload = payload.filter { !($0.value is NSNull) }
        }
        nowPlaying = Self.parse(currentPayload)
    }

    private static func parse(_ dict: [String: Any]) -> NowPlaying? {
        guard
            let bundleIdentifier = dict["bundleIdentifier"] as? String,
            let title = dict["title"] as? String,
            let playing = dict["playing"] as? Bool
        else { return nil }

        var timestamp: Date?
        if let ts = dict["timestamp"] as? String {
            timestamp = ISO8601DateFormatter().date(from: ts)
        }

        var artworkData: Data?
        if let base64 = dict["artworkData"] as? String {
            artworkData = Data(base64Encoded: base64)
        }

        return NowPlaying(
            bundleIdentifier: bundleIdentifier,
            title: title,
            artist: dict["artist"] as? String,
            album: dict["album"] as? String,
            isPlaying: playing,
            duration: dict["duration"] as? TimeInterval,
            elapsedTime: dict["elapsedTime"] as? TimeInterval,
            timestamp: timestamp,
            artworkData: artworkData,
            artworkMimeType: dict["artworkMimeType"] as? String
        )
    }
}

// Splits a byte stream into newline-delimited chunks; called on the pipe's reader thread.
private final class LineBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    func append(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        var lines: [Data] = []
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            lines.append(buffer.subdata(in: buffer.startIndex..<newlineIndex))
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
        }
        return lines
    }
}
