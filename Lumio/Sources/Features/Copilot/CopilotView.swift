import AppKit
import SwiftUI

// UI-side theming for scenarios; kept out of CopilotService so the service
// layer stays free of SwiftUI.
extension CopilotScenario {
    var accentColor: Color {
        switch self {
        case .general: .white
        case .interview: .blue
        case .meeting: .teal
        case .custom: .purple
        }
    }
}

struct CopilotView: View {
    @Bindable var copilot: CopilotService
    @Bindable var settings = AppSettings.shared

    @State private var question = ""
    @State private var copied = false
    @State private var showTranscript = false
    @FocusState private var inputFocused: Bool

    private var scenarioAccent: Color { settings.copilotScenario.accentColor }

    var body: some View {
        VStack(spacing: 8) {
            suggestionArea
            transcriptBar
            inputBar
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .onAppear { setPanelKeyable(true) }
        .onDisappear { setPanelKeyable(false) }
    }

    @ViewBuilder
    private var suggestionArea: some View {
        ZStack(alignment: .topTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    suggestionContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, actionButtonsReservedWidth)
                        .id("suggestion")
                }
                .onChange(of: copilot.suggestion) {
                    proxy.scrollTo("suggestion", anchor: .bottom)
                }
            }
            actionButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06))
        )
        .overlay {
            if copilot.phase == .answering {
                BreathingGlowBorder(accent: scenarioAccent)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: copilot.phase)
    }

    @ViewBuilder
    private var suggestionContent: some View {
        switch copilot.phase {
        case .error(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.9))
        default:
            if hasAnswer {
                MarkdownContent(text: copilot.suggestion)
                    .foregroundStyle(.white.opacity(0.92))
                    .textSelection(.enabled)
            } else if copilot.phase == .answering {
                ThinkingIndicator()
            } else {
                Text(L("copilot.placeholder"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private var hasAnswer: Bool { !copilot.suggestion.isEmpty }

    // The floating buttons overlay the text's top-right corner; reserve their
    // actual width (22pt each + 6pt spacing + 2pt padding) plus a small gap so
    // no characters hide behind them.
    private var actionButtonsReservedWidth: CGFloat {
        var count = 0
        if hasAnswer {
            count += copilot.phase == .answering ? 1 : 2
        }
        if hasAnswer || !copilot.transcript.isEmpty { count += 1 }
        guard count > 0 else { return 0 }
        return CGFloat(count) * 22 + CGFloat(count - 1) * 6 + 2 + 6
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 6) {
            if hasAnswer {
                iconButton(copied ? "checkmark" : "doc.on.doc",
                           tint: copied ? .green : .white.opacity(0.6)) {
                    copyAnswer()
                }
                .help(L("copilot.copy"))
                if copilot.phase != .answering {
                    iconButton("arrow.clockwise", tint: .white.opacity(0.6)) {
                        copilot.regenerate()
                    }
                    .help(L("copilot.regenerate"))
                }
            }
            if hasAnswer || !copilot.transcript.isEmpty {
                iconButton("trash", tint: .white.opacity(0.5)) {
                    copilot.clear()
                    question = ""
                }
                .help(L("copilot.clear"))
            }
        }
        .padding(2)
    }

    private func iconButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 20)
                .background(Capsule().fill(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // Live transcript of the other party + auto/manual suggest controls.
    private var transcriptBar: some View {
        HStack(spacing: 8) {
            Button {
                copilot.toggleListening()
            } label: {
                Image(systemName: copilot.isListening ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(copilot.isListening ? .green : .white.opacity(0.65))
                    .frame(width: 28, height: 24)
                    .background(Capsule().fill(.white.opacity(0.12)))
                    .symbolEffect(.pulse, isActive: copilot.isListening)
            }
            .buttonStyle(.plain)
            .help(L("copilot.listen.help"))

            if copilot.isListening {
                MiniWaveform(
                    meter: copilot.levelMeter,
                    tint: copilot.isEagerAskPending ? .yellow : scenarioAccent
                )
            }

            Button {
                showTranscript.toggle()
            } label: {
                Text(transcriptPreview)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(copilot.isListening ? 0.75 : 0.35))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTranscript, arrowEdge: .bottom) {
                transcriptPopover
            }

            autoSuggestButton

            Button {
                copilot.suggestAnswer()
            } label: {
                Label(L("copilot.suggest"), systemImage: "lightbulb.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(scenarioAccent.opacity(0.9)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85),
                               value: settings.copilotScenario)
            }
            .buttonStyle(.plain)
            .disabled(copilot.transcriptionOther.latestUtterance.isEmpty || copilot.phase == .answering)
            .opacity(copilot.transcriptionOther.latestUtterance.isEmpty ? 0.4 : 1)
        }
    }

    private var autoSuggestButton: some View {
        Button {
            settings.copilotAutoSuggest.toggle()
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(settings.copilotAutoSuggest ? .yellow : .white.opacity(0.5))
                .frame(width: 28, height: 24)
                .background(
                    Capsule().fill(.white.opacity(settings.copilotAutoSuggest ? 0.2 : 0.12))
                )
        }
        .buttonStyle(.plain)
        .help(L("copilot.auto.help"))
    }

    private var transcriptPopover: some View {
        let segments = copilot.transcript
        let liveOther = copilot.transcriptionOther.liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        let liveMe = copilot.transcriptionMe.liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 8) {
            Text(L("copilot.transcript.title"))
                .font(.caption.bold())
            if segments.isEmpty && liveOther.isEmpty && liveMe.isEmpty {
                Text(L("copilot.transcript.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(segments) { segment in
                            transcriptLine(speaker: segment.speaker, text: segment.text, live: false)
                        }
                        if !liveMe.isEmpty {
                            transcriptLine(speaker: .me, text: liveMe, live: true)
                        }
                        if !liveOther.isEmpty {
                            transcriptLine(speaker: .other, text: liveOther, live: true)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    @ViewBuilder
    private func transcriptLine(speaker: Speaker, text: String, live: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(speakerLabel(speaker))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(speakerColor(speaker))
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(live ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speakerLabel(_ speaker: Speaker) -> String {
        switch speaker {
        case .me: L("copilot.speaker.me")
        case .other: L("copilot.speaker.other")
        }
    }

    private func speakerColor(_ speaker: Speaker) -> Color {
        switch speaker {
        case .me: .blue
        case .other: .secondary
        }
    }

    private var transcriptPreview: String {
        if let last = copilot.transcript.last {
            return "\(speakerLabel(last.speaker)) \(last.text)"
        }
        let utterance = copilot.transcriptionOther.latestUtterance
        if !utterance.isEmpty { return utterance }
        return copilot.isListening ? L("copilot.listening") : L("copilot.notListening")
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            stealthToggle

            TextField(L("copilot.inputPlaceholder"), text: $question)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .focused($inputFocused)
                .onSubmit(submit)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.1)))

            if copilot.phase == .answering {
                Button {
                    copilot.cancel()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 28, height: 24)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 24)
                        .background(Capsule().fill(.white.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var stealthToggle: some View {
        Button {
            settings.stealthMode.toggle()
        } label: {
            Image(systemName: settings.stealthMode ? "eye.slash.fill" : "eye")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(settings.stealthMode ? .purple : .white.opacity(0.65))
                .frame(width: 28, height: 24)
                .background(Capsule().fill(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(L("copilot.stealth.help"))
    }

    private func submit() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        copilot.ask(text)
        question = ""
    }

    private func copyAnswer() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copilot.suggestion, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
    }

    private func setPanelKeyable(_ keyable: Bool) {
        guard let panel = NSApp.windows.compactMap({ $0 as? NotchPanel }).first else { return }
        panel.allowsKey = keyable
        if keyable {
            panel.makeKey()
            inputFocused = true
        } else if panel.isKeyWindow {
            panel.resignKey()
        }
    }
}

// Live level bars for the other party's voice, polled from AudioLevelMeter
// at 20fps; tints yellow while an eager answer is counting down.
private struct MiniWaveform: View {
    let meter: AudioLevelMeter
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { _ in
            let levels = meter.snapshot()
            HStack(spacing: 2) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: 2.5, height: 4 + 16 * CGFloat(levels[index]))
                }
            }
        }
        .frame(height: 20)
        .animation(.easeInOut(duration: 0.25), value: tint)
    }
}

// Animated multicolor border shown while the answer is streaming: a slowly
// rotating angular gradient whose opacity "breathes". Driven by TimelineView
// so it costs nothing once removed from the hierarchy.
private struct BreathingGlowBorder: View {
    let accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((t * 60).truncatingRemainder(dividingBy: 360))
            let breath = 0.55 + 0.35 * sin(t * 2)
            let gradient = AngularGradient(
                colors: [accent, .purple, .pink, .orange, accent],
                center: .center,
                angle: angle
            )
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(gradient, lineWidth: 2.5)
                    .blur(radius: 6)
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(gradient, lineWidth: 1.5)
            }
            .opacity(breath)
            .drawingGroup()
        }
        .allowsHitTesting(false)
    }
}

// Animated three-dot "thinking" indicator shown before the first token arrives.
private struct ThinkingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                        value: animating
                    )
            }
            Text(L("copilot.thinking"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.leading, 2)
        }
        .onAppear { animating = true }
    }
}

// Lightweight Markdown renderer: paragraphs, bullet / numbered lists and
// headings, with inline bold / italic / code. Avoids any external dependency.
private struct MarkdownContent: View {
    let text: String

    private enum Kind: Equatable {
        case paragraph
        case heading(CGFloat)
        case bullet
        case numbered(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(parse().enumerated()), id: \.offset) { _, item in
                row(kind: item.0, content: item.1)
            }
        }
        .font(.system(size: 12))
    }

    @ViewBuilder
    private func row(kind: Kind, content: AttributedString) -> some View {
        switch kind {
        case .paragraph:
            if content.characters.isEmpty {
                Color.clear.frame(height: 2)
            } else {
                Text(content)
            }
        case .heading(let size):
            Text(content).font(.system(size: size, weight: .bold))
        case .bullet:
            HStack(alignment: .top, spacing: 6) {
                Text("•").foregroundStyle(.white.opacity(0.55))
                Text(content)
            }
        case .numbered(let marker):
            HStack(alignment: .top, spacing: 6) {
                Text(marker).foregroundStyle(.white.opacity(0.55))
                Text(content)
            }
        }
    }

    private func parse() -> [(Kind, AttributedString)] {
        text.components(separatedBy: "\n").map { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("### ") { return (.heading(13), inline(String(line.dropFirst(4)))) }
            if line.hasPrefix("## ") { return (.heading(14), inline(String(line.dropFirst(3)))) }
            if line.hasPrefix("# ") { return (.heading(15), inline(String(line.dropFirst(2)))) }
            for marker in ["- ", "* ", "+ ", "• "] where line.hasPrefix(marker) {
                return (.bullet, inline(String(line.dropFirst(marker.count))))
            }
            if let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let marker = line[line.startIndex..<range.upperBound].trimmingCharacters(in: .whitespaces)
                return (.numbered(marker), inline(String(line[range.upperBound...])))
            }
            return (.paragraph, inline(line))
        }
    }

    private func inline(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: string, options: options)) ?? AttributedString(string)
    }
}
