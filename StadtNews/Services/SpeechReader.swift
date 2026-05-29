import AVFoundation
import Combine

/// Reads article paragraphs aloud using the system speech synthesiser.
///
/// One reader per article view (`@StateObject`); when the view disappears the
/// instance is deinit'd and the underlying `AVSpeechSynthesizer` stops, so
/// audio never bleeds across screens.
@MainActor
final class SpeechReader: NSObject, ObservableObject {
    @Published private(set) var isReading = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    deinit { synthesizer.stopSpeaking(at: .immediate) }

    /// Reads the joined paragraphs or stops if a read is already in flight.
    func toggle(paragraphs: [String]) {
        if isReading {
            stop()
        } else {
            start(paragraphs: paragraphs)
        }
    }

    private func start(paragraphs: [String]) {
        let text = paragraphs.joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        isReading = true
    }

    func stop() {
        guard isReading else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isReading = false
    }
}

extension SpeechReader: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isReading = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isReading = false }
    }
}
