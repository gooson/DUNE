import AVFoundation
import Foundation
import OSLog

@MainActor
final class AVRunningVoiceSpeaker: NSObject, RunningVoiceSpeaking, @preconcurrency AVSpeechSynthesizerDelegate {
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "RunningVoiceFeedback")
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (@MainActor () -> Void)?
    private var currentUtterance: AVSpeechUtterance?
    private var isSessionActive = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String, volume: Float, onFinish: @escaping @MainActor () -> Void) {
        stop()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
            isSessionActive = true
        } catch {
            // Avoid queuing silent speech when the audio session cannot be activated.
            Self.logger.error("Could not activate running audio: \(error.localizedDescription, privacy: .public)")
            restoreAudioSession()
            onFinish()
            return
        }

        self.onFinish = onFinish
        let utterance = AVSpeechUtterance(string: text)
        currentUtterance = utterance
        utterance.voice = AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = volume
        synthesizer.speak(utterance)
    }

    func stop() {
        onFinish = nil
        currentUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        restoreAudioSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        complete(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        complete(utterance)
    }

    private func complete(_ utterance: AVSpeechUtterance) {
        guard currentUtterance === utterance else { return }
        currentUtterance = nil
        guard let completion = onFinish else { return }
        onFinish = nil
        restoreAudioSession()
        completion()
    }

    private func restoreAudioSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Deactivation may fail if another Watch audio owner changed the session.
            Self.logger.error("Could not restore running audio: \(error.localizedDescription, privacy: .public)")
        }
    }
}
