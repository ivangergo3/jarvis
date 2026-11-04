import AVFoundation
import AppKit
import Combine
import Speech

/// Pure generation gate: a cancelled/old recognition callback cannot edit a new draft.
struct DictationSession {
    enum Phase: String { case idle, authorizing, listening, finishing, failed }
    private(set) var token = UUID()
    private(set) var phase: Phase = .idle
    private(set) var transcript = ""

    mutating func begin() -> UUID {
        token = UUID()
        phase = .authorizing
        transcript = ""
        return token
    }
    mutating func listening(_ id: UUID) {
        if id == token && phase == .authorizing { phase = .listening }
    }
    mutating func finishing() { if phase == .listening { phase = .finishing } }
    mutating func update(_ text: String, token id: UUID) {
        if id == token && [.listening, .finishing].contains(phase) {
            transcript = String(text.prefix(16_000))
        }
    }
    mutating func complete(_ id: UUID) -> String? {
        guard id == token && [.listening, .finishing].contains(phase) else { return nil }
        let result = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        cancel()
        return result.isEmpty ? nil : result
    }
    mutating func cancel() {
        token = UUID()
        phase = .idle
        transcript = ""
    }
    mutating func fail() {
        cancel()
        phase = .failed
    }
}

@MainActor final class LocalVoice: NSObject, ObservableObject {
    @Published private(set) var session = DictationSession()
    @Published private(set) var error: String?
    @Published var readReplies = false
    @Published var language = "en-GB"
    var onTranscript: ((String) -> Void)?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var limitTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private let speaker = AVSpeechSynthesizer()
    private var workspaceObserver: NSObjectProtocol?

    override init() {
        super.init()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancel()
                self?.stopSpeaking()
            }
        }
    }

    deinit {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    var recording: Bool { [.authorizing, .listening, .finishing].contains(session.phase) }
    var speaking: Bool { speaker.isSpeaking }

    func start() async {
        guard !recording else { return }
        stopSpeaking()
        error = nil
        let token = session.begin()
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard session.token == token else { return }
        guard microphone else {
            fail(
                "Microphone access was denied. You can still type, or enable access in System Settings."
            )
            return
        }
        let status = await withCheckedContinuation { promise in
            SFSpeechRecognizer.requestAuthorization { promise.resume(returning: $0) }
        }
        guard session.token == token else { return }
        guard status == .authorized else {
            fail("Speech recognition access was denied. Typing is still available.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
            recognizer.isAvailable, recognizer.supportsOnDeviceRecognition
        else {
            fail(
                "On-device dictation is unavailable for this language. Choose another language or type. Audio will not be sent to a cloud fallback."
            )
            return
        }
        let audio = AVAudioEngine()
        let format = audio.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            fail("No microphone is available.")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        engine = audio
        session.listening(token)
        // Apple's audio tap appends directly to its recognition request; UI callbacks transfer
        // only immutable strings/bools back to the main actor. Raw buffers are never retained.
        audio.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, failure in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let message = failure?.localizedDescription
            Task { @MainActor in
                guard let self, self.session.token == token else { return }
                if let text { self.session.update(text, token: token) }
                if final {
                    self.complete(token)
                } else if let message {
                    self.fail("Dictation stopped: \(message)")
                }
            }
        }
        do {
            audio.prepare()
            try audio.start()
            limitTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(45)) } catch { return }
                guard self?.session.token == token else { return }
                self?.finish()
            }
        } catch {
            fail("The microphone could not start. Try another input device or type your message.")
        }
    }

    func finish() {
        guard session.phase == .listening else { return }
        session.finishing()
        stopCapture()
        request?.endAudio()
        let token = session.token
        finishTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            // An explicit stop may use the latest partial transcript, but only as an editable
            // draft. Neither partial nor final recognition ever dispatches a Codex request.
            self?.complete(token)
        }
    }

    private func complete(_ token: UUID) {
        guard session.token == token, [.listening, .finishing].contains(session.phase) else {
            return
        }
        let text = session.complete(token)
        cleanup()
        if let text { onTranscript?(text) }
    }

    private func fail(_ message: String) {
        session.fail()
        error = message
        cleanup()
    }
    func cancel() {
        session.cancel()
        cleanup()
    }

    private func stopCapture() {
        limitTask?.cancel()
        limitTask = nil
        engine?.stop()
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private func cleanup() {
        stopCapture()
        finishTask?.cancel()
        finishTask = nil
        request?.endAudio()
        recognition?.cancel()
        recognition = nil
        request = nil
        engine = nil
    }

    func speak(_ text: String) {
        guard readReplies else { return }
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: String(text.prefix(8_000)))
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        speaker.speak(utterance)
    }
    func stopSpeaking() { speaker.stopSpeaking(at: .immediate) }
}
