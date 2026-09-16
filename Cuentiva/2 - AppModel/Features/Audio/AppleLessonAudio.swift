import AVFoundation
import Speech
import Observation

@MainActor protocol LessonAudio: AnyObject, Sendable {
    var spokenRange: NSRange? { get }
    var transcript: String { get }
    var recording: Bool { get }
    var error: String? { get }
    func speak(_ text: String, slow: Bool)
    func speakAndWait(_ text: String, slow: Bool) async -> Bool
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
    private var playbackRequestID: UUID?
    private var playbackContinuation: CheckedContinuation<Bool, Never>?
    private var activeUtterance: ObjectIdentifier?
    // Serialize microphone session changes away from the UI thread.
    private nonisolated static let sessionQueue = DispatchQueue(label: "Cuentiva.microphone-session")
    private var microphoneSessionRequested = false
    override init() {
        super.init()
        synthesizer.delegate = self
        // Speech owns its playback session across consecutive reader sentences.
        synthesizer.usesApplicationAudioSession = false
    }
    func speak(_ text: String, slow: Bool) {
        stop(); error = nil
        do {
            let utterance = AVSpeechUtterance(string: text)
            guard let voice = AVSpeechSynthesisVoice(language: "es-ES") else { throw AppFailure.unavailable("A Spanish voice is unavailable on this device. You can continue with Write.") }
            utterance.voice = voice
            utterance.rate = slow ? 0.20 : 0.47
            activeUtterance = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        } catch { self.error = error.localizedDescription }
    }
    func speakAndWait(_ text: String, slow: Bool) async -> Bool {
        guard !Task.isCancelled else { return false }
        let requestID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                speak(text, slow: slow)
                guard activeUtterance != nil else { continuation.resume(returning: false); return }
                playbackRequestID = requestID
                playbackContinuation = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.playbackRequestID == requestID else { return }; self?.stop()
            }
        }
    }
    private func finishPlayback(_ succeeded: Bool) {
        let continuation = playbackContinuation
        playbackContinuation = nil
        playbackRequestID = nil
        continuation?.resume(returning: succeeded)
    }
    func startRecording() async {
        stop(); error = nil; transcript = ""
        let token = generation
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard token == generation else { return }
        guard speechAllowed && micAllowed else { error = "Microphone and speech access are needed for Speak. You can use Write, or enable access in Settings."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES")), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            error = "On-device Spanish recognition is unavailable on this device. Please use Write. No audio has been uploaded."; return
        }
        self.recognizer = recognizer
        do {
            microphoneSessionRequested = true
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                Self.sessionQueue.async {
                    do {
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                        try session.setActive(true)
                        continuation.resume()
                    } catch { continuation.resume(throwing: error) }
                }
            }
            guard token == generation else { return }
            guard !Task.isCancelled else { stopRecording(); return }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode, format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else { throw AppFailure.unavailable("No microphone is available. Please use Write.") }
            input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.makeAudioTap(request: request))
            tapInstalled = true
            recognition = recognizer.recognitionTask(with: request, resultHandler: Self.makeRecognitionHandler { [weak self] text, finished, message in
                guard let self, self.generation == token else { return }
                if let text { self.transcript = text }
                if finished || message != nil {
                    self.stopRecording()
                    if let message, self.transcript.isEmpty { self.error = message }
                }
            })
            engine.prepare(); try engine.start(); recording = true
        } catch {
            guard token == generation else { return }
            stopRecording(); self.error = error.localizedDescription
        }
    }
    // Extract only Sendable values before hopping from Speech's callback queue.
    nonisolated static func makeRecognitionHandler(
        publish: @escaping @MainActor @Sendable (String?, Bool, String?) -> Void
    ) -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, failure in
            let text = result?.bestTranscription.formattedString
            let finished = result?.isFinal == true
            let message = failure?.localizedDescription
            Task { @MainActor in publish(text, finished, message) }
        }
    }
    // AVAudioEngine invokes the tap on its audio queue, never on MainActor.
    // Construct this legacy callback outside actor isolation; append stays on the
    // audio queue and the PCM buffer never crosses an asynchronous boundary.
    nonisolated static func makeAudioTap(request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard buffer.frameLength > 0 else { return }
            request.append(buffer)
        }
    }
    func stopRecording() {
        generation = UUID()
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil
        recording = false
        guard microphoneSessionRequested else { return }
        microphoneSessionRequested = false
        let token = generation
        Self.sessionQueue.async { [weak self] in
            do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
            catch {
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    guard self?.generation == token else { return }
                    self?.error = message
                }
            }
        }
    }
    func stop() { finishPlayback(false); activeUtterance = nil; stopRecording(); synthesizer.stopSpeaking(at: .immediate); spokenRange = nil }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in guard self?.activeUtterance == identity else { return }; self?.spokenRange = range }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in guard self?.activeUtterance == identity else { return }; self?.spokenRange = nil; self?.activeUtterance = nil; self?.finishPlayback(true) }
    }
}

extension AppleLessonAudio {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard self?.activeUtterance == identity else { return }
            self?.spokenRange = nil; self?.activeUtterance = nil; self?.finishPlayback(false)
        }
    }
}
