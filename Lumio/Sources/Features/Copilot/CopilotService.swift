import Foundation
import Observation

// A scenario bundles the response rules (tone, length, structure) the copilot
// follows; the user's profile material is layered on top in `systemPrompt`.
enum CopilotScenario: String, CaseIterable {
    case general
    case interview
    case meeting
    case custom

    var basePrompt: String {
        switch self {
        case .general, .custom:
            """
            You are a discreet real-time copilot helping the user during an online meeting \
            or job interview. Given the other party's question or statement, suggest a \
            strong, natural-sounding answer the user can say out loud. Be concise: a short \
            suggested answer first, then at most three brief bullet points with key facts \
            or follow-ups. Always respond in the same language as the question.
            """
        case .interview:
            """
            You are a discreet real-time interview copilot. The user is in a live job \
            interview and the other party's question arrives as a transcript. Reply with \
            the answer the user should say, written in the first person and ready to speak \
            verbatim. The very first sentence must directly answer the question; do not \
            preface it with meta commentary. Keep the whole answer under 120 words, \
            confident and natural. Ground every claim in the user's resume and the target \
            job description when provided, and never invent experience that is not in the \
            resume. Always respond in the same language as the question.
            """
        case .meeting:
            """
            You are a discreet real-time meeting copilot. Given what was just said in the \
            meeting, respond with one suggested sentence the user can say out loud, then \
            at most three short bullet points with key facts, numbers, or a sharp \
            follow-up question. Be brief and businesslike. Always respond in the same \
            language as the question.
            """
        }
    }
}

@MainActor
@Observable
final class CopilotService {
    enum Phase: Equatable {
        case idle
        case answering
        case error(String)
    }

    var phase: Phase = .idle
    var suggestion = ""
    private(set) var isListening = false
    // Two transcription pipelines: system output (the other party) and the
    // user's own microphone. Both feed the merged `transcript` timeline.
    let transcriptionOther = TranscriptionService(speaker: .other)
    let transcriptionMe = TranscriptionService(speaker: .me)
    private(set) var transcript: [TranscriptSegment] = []
    // Recent audio levels of the other party, polled by the waveform UI.
    let levelMeter = AudioLevelMeter()
    // True while an eager ask is counting down its stability delay; the
    // waveform tints yellow to signal "about to answer".
    private(set) var isEagerAskPending = false
    private let audioCapture = AudioCaptureService()
    private let micCapture = MicCaptureService()
    private var history: [LLMMessage] = []
    private var streamTask: Task<Void, Never>?
    private var pendingAskTask: Task<Void, Never>?
    private var lastAskedText = ""

    // How long the partial transcript must stay unchanged before the eager
    // path asks, trading a short wait for not asking on every keystroke.
    private static let eagerStabilityDelay: Duration = .milliseconds(800)

    // Scenario rules first, then whatever profile material the user provided.
    private var systemPrompt: String {
        let settings = AppSettings.shared
        var parts: [String] = []
        if settings.copilotScenario == .custom {
            let custom = settings.copilotSystemPrompt
                .trimmingCharacters(in: .whitespacesAndNewlines)
            parts.append(custom.isEmpty ? CopilotScenario.general.basePrompt : custom)
        } else {
            parts.append(settings.copilotScenario.basePrompt)
        }
        let resume = settings.copilotResumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resume.isEmpty { parts.append("## User's resume\n\(resume)") }
        let job = settings.copilotJobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !job.isEmpty { parts.append("## Target job description\n\(job)") }
        let notes = settings.copilotPersonaNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { parts.append("## Additional instructions from the user\n\(notes)") }
        return parts.joined(separator: "\n\n")
    }

    func ask(_ question: String) {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        cancel()

        lastAskedText = question
        history.append(LLMMessage(role: .user, content: question))
        // Keep a short rolling window so long calls don't grow the request.
        if history.count > 12 { history.removeFirst(history.count - 12) }

        suggestion = ""
        phase = .answering
        let client = LLMClientFactory.make()
        let messages = history
        let system = systemPrompt

        streamTask = Task { [weak self] in
            do {
                for try await chunk in client.stream(messages: messages, system: system) {
                    guard let self, !Task.isCancelled else { return }
                    self.suggestion += chunk
                }
                guard let self, !Task.isCancelled else { return }
                if !self.suggestion.isEmpty {
                    self.history.append(LLMMessage(role: .assistant, content: self.suggestion))
                }
                self.phase = .idle
            } catch is CancellationError {
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.phase = .error(error.localizedDescription)
            }
        }
    }

    // Suggest an answer to whatever the other party just said.
    func suggestAnswer() {
        ask(transcriptionOther.latestUtterance)
    }

    // Re-run the last user question, discarding the previous answer.
    func regenerate() {
        guard let idx = history.lastIndex(where: { $0.role == .user }) else { return }
        let question = history[idx].content
        history.removeSubrange(idx...)
        ask(question)
    }

    private func commit(_ speaker: Speaker, _ text: String) {
        transcript.append(TranscriptSegment(speaker: speaker, text: text))
        if transcript.count > 40 { transcript.removeFirst(transcript.count - 40) }
    }

    // Eager path: ask as soon as the partial transcript holds still for the
    // stability delay, instead of waiting for the recognizer's isFinal.
    private func handlePartial(_ text: String) {
        pendingAskTask?.cancel()
        isEagerAskPending = false
        let settings = AppSettings.shared
        guard settings.copilotAutoSuggest, settings.copilotEagerSuggest else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6, !isNearDuplicate(trimmed) else { return }
        isEagerAskPending = true
        pendingAskTask = Task { [weak self] in
            try? await Task.sleep(for: Self.eagerStabilityDelay)
            guard let self, !Task.isCancelled else { return }
            self.isEagerAskPending = false
            let current = self.transcriptionOther.liveText
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard current == trimmed, !self.isNearDuplicate(trimmed) else { return }
            self.askReplacingEager(trimmed)
        }
    }

    // Final text matching the eager ask (or trailing it by a few characters)
    // is the same question; re-asking would just duplicate the answer.
    private func isNearDuplicate(_ text: String) -> Bool {
        guard !lastAskedText.isEmpty else { return false }
        if text == lastAskedText { return true }
        if text.hasPrefix(lastAskedText), text.count - lastAskedText.count < 12 { return true }
        return false
    }

    // When the final segment supersedes an eager ask, drop the eager user
    // message (it has no assistant reply yet) so history stays clean.
    private func askReplacingEager(_ text: String) {
        if let last = history.last, last.role == .user, last.content == lastAskedText {
            history.removeLast()
        }
        ask(text)
    }

    // Auto-suggest fires when the other party finishes a sentence. In eager
    // mode the partial path usually got there first; only re-ask when the
    // final text adds meaningful content beyond what was already asked.
    private func handleFinalSegment(_ text: String) {
        pendingAskTask?.cancel()
        isEagerAskPending = false
        let settings = AppSettings.shared
        guard settings.copilotAutoSuggest else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return }
        if settings.copilotEagerSuggest {
            guard !isNearDuplicate(trimmed) else { return }
            askReplacingEager(trimmed)
        } else {
            guard phase != .answering else { return }
            ask(trimmed)
        }
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard !isListening else { return }
        Task { [weak self] in
            guard let self else { return }
            guard AudioCaptureService.hasScreenRecordingPermission else {
                AudioCaptureService.requestScreenRecordingPermission()
                self.phase = .error(L("copilot.permission.screen"))
                return
            }
            guard await TranscriptionService.requestSpeechPermission() else {
                self.phase = .error(L("copilot.permission.speech"))
                return
            }

            // Other party: only this side triggers auto-suggest.
            self.transcriptionOther.onFinalSegment = { [weak self] text in
                self?.commit(.other, text)
                self?.handleFinalSegment(text)
            }
            self.transcriptionOther.onPartial = { [weak self] text in
                self?.handlePartial(text)
            }
            self.transcriptionOther.start()
            do {
                let transcription = self.transcriptionOther
                let levelMeter = self.levelMeter
                try await self.audioCapture.start { sampleBuffer in
                    transcription.append(sampleBuffer)
                    levelMeter.ingest(sampleBuffer)
                }
                self.isListening = true
                if case .error = self.phase { self.phase = .idle }
            } catch {
                self.transcriptionOther.stop()
                self.phase = .error(error.localizedDescription)
                return
            }

            // My side: optional, degrades gracefully if mic is denied.
            if AppSettings.shared.copilotTranscribeSelf {
                await self.startMicTranscription()
            }
        }
    }

    private func startMicTranscription() async {
        guard await MicCaptureService.requestMicPermission() else {
            self.phase = .error(L("copilot.permission.mic"))
            return
        }
        transcriptionMe.onFinalSegment = { [weak self] text in
            self?.commit(.me, text)
        }
        transcriptionMe.start()
        do {
            let transcription = self.transcriptionMe
            try micCapture.start { pcmBuffer in
                transcription.append(pcmBuffer)
            }
        } catch {
            transcriptionMe.stop()
            // Keep listening to the other party; mic failure is non-fatal.
        }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        transcriptionOther.stop()
        transcriptionMe.stop()
        micCapture.stop()
        levelMeter.reset()
        Task { [audioCapture] in
            await audioCapture.stop()
        }
    }

    func cancel() {
        pendingAskTask?.cancel()
        pendingAskTask = nil
        isEagerAskPending = false
        streamTask?.cancel()
        streamTask = nil
        if phase == .answering { phase = .idle }
    }

    func clear() {
        cancel()
        suggestion = ""
        lastAskedText = ""
        history.removeAll()
        transcript.removeAll()
        transcriptionOther.clear()
        transcriptionMe.clear()
        phase = .idle
    }

    func shutdown() {
        cancel()
        stopListening()
    }
}
