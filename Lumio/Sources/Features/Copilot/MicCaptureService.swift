import AVFoundation

// Captures the user's own microphone via AVAudioEngine and forwards PCM buffers
// for transcription (the "me" side of the conversation). Mirrors the shape of
// AudioCaptureService, which handles system output (the other party).
final class MicCaptureService: NSObject, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var running = false

    static var hasMicPermission: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func start(onPCMBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        guard !running else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            onPCMBuffer(buffer)
        }
        engine.prepare()
        try engine.start()
        running = true
    }

    func stop() {
        guard running else { return }
        running = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
