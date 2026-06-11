import Foundation

struct NowPlaying: Equatable {
    var bundleIdentifier: String
    var title: String
    var artist: String?
    var album: String?
    var isPlaying: Bool
    var duration: TimeInterval?
    var elapsedTime: TimeInterval?
    var timestamp: Date?
    var artworkData: Data?
    var artworkMimeType: String?

    var estimatedElapsedTime: TimeInterval? {
        guard let elapsedTime else { return nil }
        var estimate = elapsedTime
        if isPlaying, let timestamp {
            // Diff updates can pair a fresh `playing` flag with a stale
            // timestamp, so extrapolation must be clamped to the track length.
            estimate += Date().timeIntervalSince(timestamp)
        }
        if let duration, duration > 0 {
            estimate = min(estimate, duration)
        }
        return max(0, estimate)
    }
}

enum MediaCommand: Int {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case stop = 3
    case nextTrack = 4
    case previousTrack = 5
}
