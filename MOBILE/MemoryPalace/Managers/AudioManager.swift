import AVFoundation
import Foundation

@MainActor
class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingTime: TimeInterval = 0
    @Published var playbackTime: TimeInterval = 0
    @Published var recordingLevel: Float = 0
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var levelTimer: Timer?
    private var currentRecordingURL: URL?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
    }

    deinit {
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        recordingTimer?.invalidate()
        playbackTimer?.invalidate()
        levelTimer?.invalidate()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            print("❌ Audio session setup failed: \(error)")
        }
    }
        
    func requestRecordingPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startRecording() async -> Bool {
        let hasPermission = await requestRecordingPermission()
        guard hasPermission else {
            errorMessage = "Microphone permission required for recording"
            return false
        }
        
        stopRecording()
        stopPlayback()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        currentRecordingURL = documentsPath.appendingPathComponent("voice_\(timestamp).m4a")
        
        guard let recordingURL = currentRecordingURL else {
            errorMessage = "Failed to create recording file"
            return false
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                isRecording = true
                recordingTime = 0
                errorMessage = nil
                
                startRecordingTimers()
                
                return true
            } else {
                errorMessage = "Failed to start recording"
                return false
            }
            
        } catch {
            errorMessage = "Recording setup failed: \(error.localizedDescription)"
            print("❌ Recording setup failed: \(error)")
            return false
        }
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        stopRecordingTimers()
        
        isRecording = false
        recordingLevel = 0
        
        let recordingURL = currentRecordingURL
        audioRecorder = nil
                
        return recordingURL
    }
    
    func getRecordingData() async -> Data? {
        guard let url = currentRecordingURL else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            return data
        } catch {
            errorMessage = "Failed to load recording: \(error.localizedDescription)"
            print("❌ Failed to load recording: \(error)")
            return nil
        }
    }
    
    func deleteCurrentRecording() {
        guard let url = currentRecordingURL else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
            currentRecordingURL = nil
        } catch {
            print("❌ Failed to delete recording: \(error)")
        }
    }
        
    func playAudio(from url: URL) async -> Bool {
        stopPlayback()
        stopRecording()
        
        do {
            if url.scheme == "http" || url.scheme == "https" {
                return await playRemoteAudio(from: url)
            } else {
                return await playLocalAudio(from: url)
            }
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
            print("❌ Playback failed: \(error)")
            return false
        }
    }
    
    private func playLocalAudio(from url: URL) async -> Bool {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            
            let success = audioPlayer?.play() ?? false
            
            if success {
                isPlaying = true
                playbackTime = 0
                errorMessage = nil
                startPlaybackTimer()
                
                return true
            } else {
                errorMessage = "Failed to start playback"
                return false
            }
        } catch {
            errorMessage = "Audio file error: \(error.localizedDescription)"
            return false
        }
    }
    
    private func playRemoteAudio(from url: URL) async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Failed to download audio"
                return false
            }
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            
            let success = audioPlayer?.play() ?? false
            
            if success {
                isPlaying = true
                playbackTime = 0
                errorMessage = nil
                startPlaybackTimer()
                
                return true
            } else {
                errorMessage = "Failed to start remote playback"
                return false
            }
            
        } catch {
            errorMessage = "Remote audio error: \(error.localizedDescription)"
            return false
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        stopPlaybackTimer()
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        startPlaybackTimer()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopPlaybackTimer()
        
        isPlaying = false
        playbackTime = 0
        
    }
    
    func seekTo(time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        player.currentTime = time
        playbackTime = time
            }
        
    private func startRecordingTimers() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.recordingTime += 0.1
            }
        }
        
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                self.updateRecordingLevel()
            }
        }
    }
    
    private func stopRecordingTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                if let player = self.audioPlayer {
                    self.playbackTime = player.currentTime
                }
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updateRecordingLevel() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        let normalizedLevel = pow(10, averagePower / 20)
        recordingLevel = Float(normalizedLevel)
    }
        
    var currentRecordingDuration: TimeInterval {
        return recordingTime
    }
    
    var currentPlaybackDuration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    var recordingLevelForDisplay: Float {
        return min(max(recordingLevel * 100, 0), 100)
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasError: Bool {
        return errorMessage != nil
    }
    
    func resetAll() {
        stopRecording()
        stopPlayback()
        deleteCurrentRecording()
        clearError()
    }
    
    func fullReset() {
        
        stopRecording()
        stopPlayback()
        
        stopRecordingTimers()
        stopPlaybackTimer()
        
        isRecording = false
        isPlaying = false
        recordingTime = 0
        playbackTime = 0
        recordingLevel = 0
        errorMessage = nil
        
        deleteCurrentRecording()
        currentRecordingURL = nil
        audioRecorder = nil
        audioPlayer = nil
            }
    
    var canRecord: Bool {
        return !isRecording && !isPlaying
    }
    
    var canPlay: Bool {
        return !isRecording
    }
}

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopRecordingTimers()
            
            if !flag {
                self.errorMessage = "Recording finished with error"
                print("❌ Recording finished unsuccessfully")
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopRecordingTimers()
            self.errorMessage = "Recording error: \(error?.localizedDescription ?? "Unknown")"
            print("❌ Recording encode error: \(error?.localizedDescription ?? "Unknown")")
        }
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopPlaybackTimer()
            self.playbackTime = 0
            
            if flag {
            } else {
                self.errorMessage = "Playback finished with error"
                print("❌ Playback finished unsuccessfully")
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopPlaybackTimer()
            self.errorMessage = "Playback error: \(error?.localizedDescription ?? "Unknown")"
            print("❌ Playback decode error: \(error?.localizedDescription ?? "Unknown")")
        }
    }
}
