import Foundation
import os

@MainActor
@Observable
final class MediaRemoteService {
    private(set) var nowPlaying: NowPlaying?

    private var streamProcess: Process?
    private var currentPayload: [String: Any] = [:]
    private var restartTask: Task<Void, Never>?
    private var stopped = false
    private let logger = Logger(subsystem: "app.lumio.Lumio", category: "MediaRemote")

    private static var scriptURL: URL? {
        Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")
    }

    private static var frameworkURL: URL? {
        Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework")
    }

    func start() {
        stopped = false
        launchStream()
    }

    private func launchStream() {
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
                guard let self else { return }
                self.streamProcess = nil
                guard !self.stopped else { return }
                self.logger.warning("adapter stream terminated, restarting in 2s")
                self.restartTask?.cancel()
                self.restartTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    self?.launchStream()
                }
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
        stopped = true
        restartTask?.cancel()
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
        do {
            try process.run()
        } catch {
            logger.error("one-shot adapter command failed to launch: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleLine(_ line: Data) {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: line)
        } catch {
            logger.debug("ignoring malformed adapter line: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard
            let json = object as? [String: Any],
            json["type"] as? String == "data",
            let payload = json["payload"] as? [String: Any]
        else { return }

        let isDiff = json["diff"] as? Bool ?? false
        if isDiff {
            // A `playing` flip arrives in its own diff; the matching
            // elapsedTime/timestamp follow ~100ms later. Freeze the currently
            // displayed (extrapolated) position so the UI doesn't fall back
            // to the stale stored elapsedTime in between.
            if payload["playing"] != nil, payload["elapsedTime"] == nil {
                if let estimate = nowPlaying?.estimatedElapsedTime {
                    currentPayload["elapsedTime"] = estimate
                }
                if payload["timestamp"] == nil {
                    currentPayload["timestamp"] = Self.fractionalFormatter.string(from: Date())
                }
            }
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

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plainFormatter = ISO8601DateFormatter()

    private static func parseTimestamp(_ string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? plainFormatter.date(from: string)
    }

    private static func parse(_ dict: [String: Any]) -> NowPlaying? {
        guard
            let bundleIdentifier = dict["bundleIdentifier"] as? String,
            let title = dict["title"] as? String,
            let playing = dict["playing"] as? Bool
        else { return nil }

        var timestamp: Date?
        if let ts = dict["timestamp"] as? String {
            timestamp = Self.parseTimestamp(ts)
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
