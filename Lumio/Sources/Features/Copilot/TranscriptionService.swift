import AVFoundation
import os
import Speech

// Which side of the conversation a transcript line belongs to.
enum Speaker { case me, other }

// One finalized line of the merged transcript, tagged with its speaker.
struct TranscriptSegment: Identifiable {
    let id = UUID()
    let speaker: Speaker
    let text: String
}

// Streams PCM buffers from one audio source into on-device speech recognition
// and publishes a rolling transcript for a single speaker. The copilot runs
// two of these (system output → other, microphone → me).
@MainActor
@Observable
final class TranscriptionService {
    let speaker: Speaker
    private(set) var liveText = ""
    private(set) var finishedSegments: [String] = []

    init(speaker: Speaker) {
        self.speaker = speaker
    }

    // Fires when the recognizer finalizes a segment (a sentence-sized chunk),
    // so the copilot can auto-suggest an answer to what the other party said.
    var onFinalSegment: ((String) -> Void)?
    // Fires on every in-flight partial update; the copilot uses this to ask
    // eagerly once the text stabilizes, without waiting for isFinal.
    var onPartial: ((String) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    // Audio arrives on the capture queue, so the request lives behind a lock
    // and append() stays nonisolated (CMSampleBuffer is not Sendable).
    private nonisolated let requestLock =
        OSAllocatedUnfairLock<SFSpeechAudioBufferRecognitionRequest?>(uncheckedState: nil)

    static var hasSpeechPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // nonisolated: the SFSpeech callback fires on a background queue, so this
    // must not inherit the class's MainActor isolation (doing so traps with a
    // dispatch_assert_queue failure when the completion runs off-main).
    nonisolated static func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // The latest question-sized chunk to feed the LLM: the in-flight partial
    // if there is one, otherwise the last finished segment.
    var latestUtterance: String {
        let partial = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !partial.isEmpty { return partial }
        return finishedSegments.last ?? ""
    }

    func start(locale: Locale = .current) {
        guard task == nil else { return }
        let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keep audio on the machine; only typed/extracted text ever goes to the LLM.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.taskHint = .dictation

        self.recognizer = recognizer
        requestLock.withLockUnchecked { $0 = request }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.liveText = result.bestTranscription.formattedString
                    if result.isFinal {
                        let committed = self.commitSegment()
                        self.restartRecognition()
                        if let committed { self.onFinalSegment?(committed) }
                    } else {
                        self.onPartial?(self.liveText)
                    }
                }
                if error != nil, self.task != nil {
                    // Recognition tasks die after ~1 min of audio or on silence
                    // gaps; restart to keep listening for the whole call.
                    self.restartRecognition()
                }
            }
        }
    }

    nonisolated func append(_ sampleBuffer: CMSampleBuffer) {
        // withLockUnchecked: CMSampleBuffer is not Sendable but is consumed
        // synchronously inside the lock, never escaping it.
        requestLock.withLockUnchecked { request in
            request?.appendAudioSampleBuffer(sampleBuffer)
        }
    }

    // Microphone audio arrives as PCM buffers from the AVAudioEngine tap.
    nonisolated func append(_ pcmBuffer: AVAudioPCMBuffer) {
        requestLock.withLockUnchecked { request in
            request?.append(pcmBuffer)
        }
    }

    func stop() {
        requestLock.withLock { request in
            request?.endAudio()
            request = nil
        }
        task?.cancel()
        task = nil
        recognizer = nil
        commitSegment()
    }

    func clear() {
        liveText = ""
        finishedSegments.removeAll()
    }

    @discardableResult
    private func commitSegment() -> String? {
        let text = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        liveText = ""
        guard !text.isEmpty else { return nil }
        finishedSegments.append(text)
        if finishedSegments.count > 20 { finishedSegments.removeFirst(finishedSegments.count - 20) }
        return text
    }

    private func restartRecognition() {
        let recognizer = self.recognizer
        task?.cancel()
        task = nil
        requestLock.withLock { $0 = nil }
        self.recognizer = nil
        if let locale = recognizer?.locale {
            start(locale: locale)
        } else {
            start()
        }
    }
}
