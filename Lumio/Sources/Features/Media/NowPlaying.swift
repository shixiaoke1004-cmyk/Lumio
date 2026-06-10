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
        guard isPlaying, let timestamp else { return elapsedTime }
        return elapsedTime + Date().timeIntervalSince(timestamp)
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
