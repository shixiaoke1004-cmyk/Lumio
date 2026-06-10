import SwiftUI

struct MediaCompactView: View {
    let nowPlaying: NowPlaying

    var body: some View {
        HStack {
            artworkThumbnail
            Spacer()
            PlaybackBars(animating: nowPlaying.isPlaying)
        }
        .padding(.horizontal, 9)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var artworkThumbnail: some View {
        if let data = nowPlaying.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 20, height: 20)
        }
    }
}

struct PlaybackBars: View {
    let animating: Bool
    @State private var phase = false

    private let barCount = 4

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.green)
                    .frame(width: 2.5, height: animating ? (phase ? heights(index).0 : heights(index).1) : 4)
            }
        }
        .frame(width: 20, height: 16, alignment: .bottom)
        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: phase)
        .onAppear { phase = true }
    }

    private func heights(_ index: Int) -> (CGFloat, CGFloat) {
        let pairs: [(CGFloat, CGFloat)] = [(14, 6), (8, 15), (15, 5), (7, 12)]
        return pairs[index % pairs.count]
    }
}

struct MediaExpandedView: View {
    let nowPlaying: NowPlaying
    let service: MediaRemoteService

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 14) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(nowPlaying.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let artist = nowPlaying.artist {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                progressBar
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = nowPlaying.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.1))
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(.white).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            HStack {
                Text(format(elapsed))
                Spacer()
                Text(format(nowPlaying.duration ?? 0))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 4)
    }

    private var controls: some View {
        HStack(spacing: 22) {
            controlButton("backward.fill") { service.send(.previousTrack) }
            controlButton(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 18) {
                service.send(.togglePlayPause)
            }
            controlButton("forward.fill") { service.send(.nextTrack) }
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(_ symbol: String, size: CGFloat = 13, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var elapsed: TimeInterval {
        // `now` ties this to the 1s timer so the bar advances during playback.
        _ = now
        return nowPlaying.estimatedElapsedTime ?? 0
    }

    private var progress: CGFloat {
        guard let duration = nowPlaying.duration, duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }

    private func format(_ time: TimeInterval) -> String {
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
