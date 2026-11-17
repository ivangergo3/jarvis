import Foundation

struct ConversationScope: Hashable, Sendable {
    let projectID: String?
    let name: String
    let directory: String?
    var threadID: String? = nil

    static let global = ConversationScope(projectID: nil, name: "Jarvis", directory: nil)
}

enum ConversationPhase: String, Sendable {
    case ready, connecting, sending, working, needsInput, complete, interrupted, failed,
        outcomeUnknown, queued

    var busy: Bool { [.connecting, .sending, .working, .needsInput].contains(self) }
    var label: String {
        switch self {
        case .ready: return "READY"
        case .connecting: return "CONNECTING"
        case .sending: return "SENDING"
        case .working: return "WORKING"
        case .needsInput: return "NEEDS YOUR INPUT"
        case .complete: return "REPLY READY"
        case .interrupted: return "INTERRUPTED"
        case .failed: return "UNAVAILABLE"
        case .outcomeUnknown: return "SEND OUTCOME UNKNOWN"
        case .queued: return "QUEUED IN CODEX"
        }
    }
}

struct CompanionMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id: String
    let role: Role
    var text: String
    var queued = false
    var attachments: [ChatAttachment] = []
}

struct CompanionApproval: Identifiable {
    let id = UUID()
    let requestID: WireValue
    let method: String
    let params: WireValue
    var reviewContext: String = ""
    var questions: [WireValue] { params["questions"].values }
    var isQuestion: Bool { method == "item/tool/requestUserInput" }
    var details: String {
        let fields = [
            "command", "cwd", "reason", "networkApprovalContext", "additionalPermissions",
            "grantRoot",
        ]
        let summary = fields.compactMap { key -> String? in
            let value = params[key]
            if value == .null { return nil }
            if let text = value.text { return "\(key): \(text)" }
            guard let data = try? JSONEncoder().encode(value) else { return nil }
            return "\(key): \(String(decoding: data, as: UTF8.self))"
        }.joined(separator: "\n")
        return summary + (reviewContext.isEmpty ? "" : "\n\n" + reviewContext)
    }
    var decisions: [String] {
        let offered = params["availableDecisions"].values
        let choices =
            offered.isEmpty
            ? ["accept", "decline", "cancel"]
            : offered.compactMap(\.text).filter { ["accept", "decline", "cancel"].contains($0) }
        // Never offer a grant when the actual file change could not be presented completely.
        return method.contains("fileChange") && reviewContext.isEmpty
            ? choices.filter { $0 != "accept" } : choices
    }
}
