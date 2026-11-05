import Foundation

/// Read-only history plus the shared queue: neither operation resumes or owns the target chat.
struct LinkedConversationSnapshot: Equatable {
    let messages: [CompanionMessage]
    let latestCompletedReply: CompanionMessage?

    static func decode(history: WireValue, queue: WireValue) -> Self {
        var messages: [CompanionMessage] = []
        var ids: Set<String> = []
        var latestReply: CompanionMessage?
        for turn in history["data"].values.reversed() {
            for item in turn["items"].values {
                guard let message = message(item), ids.insert(message.id).inserted else { continue }
                messages.append(message)
                if turn["status"].text == "completed", message.role == .assistant {
                    latestReply = message
                }
            }
        }
        for entry in queue["data"].values {
            guard let message = queuedMessage(entry), ids.insert(message.id).inserted else {
                continue
            }
            messages.append(message)
        }
        return Self(messages: Array(messages.suffix(100)), latestCompletedReply: latestReply)
    }

    static func message(_ item: WireValue) -> CompanionMessage? {
        guard let recordID = item["id"].text, !recordID.isEmpty else { return nil }
        switch item["type"].text {
        case "userMessage":
            let raw = item["content"].values.compactMap { $0["text"].text }.joined(separator: "\n")
            let display = ChatAttachments.unwrap(String(raw.prefix(64_000)))
            let files = ChatAttachments.merge(display.files, ChatAttachments.fromContent(item["content"].values))
            guard let text = LogObservation.cleanTask(display.text) ?? (files.isEmpty ? nil : "") else { return nil }
            let id = item["clientId"].text.flatMap { $0.isEmpty ? nil : $0 } ?? recordID
            return CompanionMessage(id: id, role: .user, text: text, attachments: files)
        case "agentMessage":
            guard let text = item["text"].text, !text.isEmpty else { return nil }
            return CompanionMessage(
                id: recordID, role: .assistant, text: String(text.prefix(64_000)))
        default: return nil  // Never turn tool output, reasoning or metadata into chat messages.
        }
    }

    static func queuedMessage(_ entry: WireValue) -> CompanionMessage? {
        guard let id = entry["clientUserMessageId"].text, !id.isEmpty else { return nil }
        let text = entry["input"].values.compactMap { $0["text"].text }.joined(separator: "\n")
        let display = ChatAttachments.unwrap(String(text.prefix(16_000)))
        let files = ChatAttachments.merge(display.files, ChatAttachments.fromContent(entry["input"].values))
        guard !display.text.isEmpty || !files.isEmpty else { return nil }
        return CompanionMessage(
            id: id, role: .user, text: display.text, queued: true, attachments: files)
    }
}
