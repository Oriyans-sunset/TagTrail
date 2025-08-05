//
//  AudioRecorder.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-06-30.
//

import AVFoundation
import SwiftUI

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var hasRecording = false
    @Published var statusMessage = "Tap the microphone to start recording"
    @Published var waveformLevel: CGFloat = 0.0
    
    private var meterTimer: Timer?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL
    
    init(existingRecordingURL: URL? = nil) {
        if let url = existingRecordingURL {
            self.recordingURL = url
        } else {
            // Save voice memos into Documents/Media/Audio so they persist between installs
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let mediaDir = docs.appendingPathComponent("Media/Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
            self.recordingURL = mediaDir.appendingPathComponent("\(UUID().uuidString).m4a")
        }
        
        super.init()
        checkForExistingRecording()
    }
    
    func getRecordingURL() -> URL {
        return recordingURL
    }
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    self.statusMessage = "Ready to record"
                } else {
                    self.statusMessage = "Microphone permission denied"
                }
            }
        }
    }
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.isInputGainSettable {
            try? audioSession.setInputGain(1.0) // Max gain (range: 0.0 to 1.0)
        }
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.overrideOutputAudioPort(.speaker)
            try audioSession.setActive(true)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            // make waveform bars
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.audioRecorder?.updateMeters()
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                let normalized = CGFloat(max(0.0, (power + 60) / 60)) // Convert Float to CGFloat
                DispatchQueue.main.async {
                    self.waveformLevel = normalized
                }
            }
            
            isRecording = true
            statusMessage = "Recording in progress..."
            
        } catch {
            statusMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        meterTimer?.invalidate()
        meterTimer = nil
        
        audioRecorder?.stop()
        isRecording = false
        hasRecording = true
        statusMessage = "Recording saved. Tap play to listen."
    }
    
    func playRecording() {
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            statusMessage = "No recording found"
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            
            isPlaying = true
            statusMessage = "Playing recording..."
            
        } catch {
            statusMessage = "Failed to play recording: \(error.localizedDescription)"
        }
    }
    
    private func checkForExistingRecording() {
        if FileManager.default.fileExists(atPath: recordingURL.path) {
            hasRecording = true
            statusMessage = "Previous recording found. Tap play to listen or record to replace."
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            hasRecording = true
            statusMessage = "Recording completed successfully"
        } else {
            statusMessage = "Recording failed"
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        statusMessage = flag ? "Playback completed" : "Playback failed"
    }
}

struct RealWaveform: View {
    @Binding var level: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { _ in
                Capsule()
                    .frame(width: 4, height: CGFloat.random(in: 0.2...1.0) * 60 * level)
                    .foregroundColor(.red)
            }
        }
        .animation(.easeOut(duration: 0.05), value: level)
    }
}
