import AVFoundation
import Speech
import Observation

@MainActor protocol LessonAudio: AnyObject, Sendable {
    var spokenRange: NSRange? { get }
    var transcript: String { get }
    var recording: Bool { get }
    var error: String? { get }
    func speak(_ text: String, slow: Bool)
    func startRecording() async
    func stopRecording()
    func stop()
}
/// Short, on-device utterances use SFSpeechRecognizer. The boundary permits a
/// SpeechAnalyzer adapter later without coupling framework objects to lesson rules.
@MainActor @Observable final class AppleLessonAudio: NSObject, LessonAudio, AVSpeechSynthesizerDelegate {
    private(set) var spokenRange: NSRange?
    private(set) var transcript = ""
    private(set) var recording = false
    private(set) var error: String?
    private let synthesizer = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var tapInstalled = false
    private var generation = UUID()
    private var activeUtterance: ObjectIdentifier?
    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String, slow: Bool) {
        stop(); error = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            guard let voice = AVSpeechSynthesisVoice(language: "es-ES") else { throw AppFailure.unavailable("A Spanish voice is unavailable on this device. You can continue with Write.") }
            utterance.voice = voice
            utterance.rate = slow ? 0.35 : 0.47
            activeUtterance = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        } catch { self.error = error.localizedDescription }
    }
    func startRecording() async {
        stop(); error = nil; transcript = ""
        let token = generation
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard token == generation else { return }
        guard speechAllowed && micAllowed else { error = "Microphone and speech access are needed for Speak. You can use Write, or enable access in Settings."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES")), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            error = "On-device Spanish recognition is unavailable on this device. Please use Write. No audio has been uploaded."; return
        }
        self.recognizer = recognizer
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode, format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else { throw AppFailure.unavailable("No microphone is available. Please use Write.") }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            tapInstalled = true
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, failure in
                let text = result?.bestTranscription.formattedString
                let finished = result?.isFinal == true
                let message = failure?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if let text { self.transcript = text }
                    if finished || message != nil {
                        self.stopRecording()
                        if let message, self.transcript.isEmpty { self.error = message }
                    }
                }
            }
            engine.prepare(); try engine.start(); recording = true
        } catch { stopRecording(); self.error = error.localizedDescription }
    }
    func stopRecording() {
        generation = UUID()
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil
        recording = false
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        catch { self.error = error.localizedDescription }
    }
    func stop() { activeUtterance = nil; stopRecording(); synthesizer.stopSpeaking(at: .immediate); spokenRange = nil }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in guard self?.activeUtterance == identity else { return }; self?.spokenRange = range }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in guard self?.activeUtterance == identity else { return }; self?.spokenRange = nil; self?.activeUtterance = nil }
    }
}
