import Foundation

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
