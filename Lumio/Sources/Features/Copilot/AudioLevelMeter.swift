import Accelerate
import CoreMedia
import os

// Tracks recent audio levels from the capture stream so the UI can render a
// live waveform. Ingest happens on the capture queue ~100×/s; the UI polls
// `snapshot()` at its own frame rate instead of being pushed per buffer.
final class AudioLevelMeter: Sendable {
    static let barCount = 7

    private let levels = OSAllocatedUnfairLock<[Float]>(
        initialState: Array(repeating: 0, count: AudioLevelMeter.barCount)
    )

    nonisolated func ingest(_ sampleBuffer: CMSampleBuffer) {
        guard let level = Self.normalizedLevel(of: sampleBuffer) else { return }
        levels.withLock { values in
            values.removeFirst()
            values.append(level)
        }
    }

    func snapshot() -> [Float] {
        levels.withLock { $0 }
    }

    func reset() {
        levels.withLock { $0 = Array(repeating: 0, count: Self.barCount) }
    }

    // RMS of the buffer's Float32 samples mapped from dBFS to 0...1.
    private nonisolated static func normalizedLevel(of sampleBuffer: CMSampleBuffer) -> Float? {
        guard let description = sampleBuffer.formatDescription,
              let asbd = description.audioStreamBasicDescription,
              asbd.mFormatID == kAudioFormatLinearPCM,
              asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              asbd.mBitsPerChannel == 32 else { return nil }

        var rms: Float = 0
        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, _ in
                guard let buffer = audioBufferList.first,
                      let data = buffer.mData, buffer.mDataByteSize > 0 else { return }
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                let samples = data.assumingMemoryBound(to: Float.self)
                vDSP_rmsqv(samples, 1, &rms, vDSP_Length(count))
            }
        } catch {
            return nil
        }
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(max((db + 50) / 50, 0), 1)
    }
}
