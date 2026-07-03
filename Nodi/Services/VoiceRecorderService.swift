import Foundation
import AVFoundation

@MainActor
final class VoiceRecorderService: NSObject, ObservableObject {

    @Published var isRecording = false
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?

    func requestPermissionAndStart() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard granted else {
            errorMessage = "Microphone access is off. Enable it in Settings to send voice messages."
            return
        }
        start()
    }

    private func start() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            recordingURL = url
            isRecording = true
            elapsedSeconds = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsedSeconds += 0.1 }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns the recorded file's URL and duration, or `nil` if the
    /// recording was too short to be worth sending (avoids a silent
    /// leftover tap generating an empty voice message).
    func stop() -> (url: URL, duration: TimeInterval)? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false

        guard let url = recordingURL, elapsedSeconds > 0.5 else { return nil }
        let duration = elapsedSeconds
        return (url, duration)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recorder = nil
        recordingURL = nil
        isRecording = false
        elapsedSeconds = 0
    }
}

@MainActor
final class VoiceMessagePlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        isPlaying = true

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self, let duration = self.player?.currentItem?.duration.seconds, duration > 0, duration.isFinite else { return }
            self.progress = time.seconds / duration
        }

        NotificationCenter.default.addObserver(self, selector: #selector(didFinish), name: .AVPlayerItemDidPlayToEndTime, object: item)
    }

    func stop() {
        player?.pause()
        isPlaying = false
    }

    @objc private func didFinish() {
        isPlaying = false
        progress = 0
    }
}
