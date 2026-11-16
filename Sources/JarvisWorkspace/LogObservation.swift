import Foundation
import JarvisDomain

struct LogObservation {
    var status: MissionStatus?
    var eventTime: Date?
    var task: String?
    var taskTime: Date?

    mutating func consume(_ line: String) {
        // Skip large tool outputs and reasoning before decoding JSON.
        guard
            line.contains("\"task_started\"") || line.contains("\"task_complete\"")
                || line.contains("\"task_aborted\"") || line.contains("\"turn_aborted\"")
                || (line.contains("\"message\"") && line.contains("\"user\""))
        else { return }
        guard let data = line.data(using: .utf8),
            let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = record["payload"] as? [String: Any]
        else { return }
        let type = payload["type"] as? String ?? ""
        let time = Self.date(record["timestamp"] as? String)
        if record["type"] as? String == "event_msg" {
            let state: MissionStatus?
            switch type {
            case "task_started": state = .working
            case "task_complete": state = .standby
            case "task_aborted", "turn_aborted": state = .interrupted
            default: state = nil
            }
            if let state {
                status = state
                eventTime = time
            }
        }
        if record["type"] as? String == "response_item", type == "message",
            payload["role"] as? String == "user",
            let content = payload["content"] as? [[String: Any]]
        {
            let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if let clean = Self.cleanTask(text) {
                task = clean
                taskTime = time
            }
        }
    }

    static func cleanTask(_ text: String) -> String? { TaskText.cleanTask(text) }

    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        return (try? fractional.parse(value)) ?? (try? whole.parse(value))
    }
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let whole = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
}
