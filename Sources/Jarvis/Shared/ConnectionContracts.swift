import Foundation

/// JSON stays at the protocol boundary; it never becomes a shell command or UI action.
enum WireValue: Codable, Equatable, Sendable {
    case object([String: WireValue])
    case array([WireValue])
    case string(String)
    case number(Int)
    case decimal(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let v = try? value.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? value.decode(Int.self) {
            self = .number(v)
        } else if let v = try? value.decode(Double.self) {
            self = .decimal(v)
        } else if let v = try? value.decode(String.self) {
            self = .string(v)
        } else if let v = try? value.decode([WireValue].self) {
            self = .array(v)
        } else {
            self = .object(try value.decode([String: WireValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .object(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .decimal(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }

    subscript(_ key: String) -> WireValue {
        if case .object(let v) = self { return v[key] ?? .null }
        return .null
    }
    var text: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    var integer: Int? {
        if case .number(let v) = self { return v }
        return nil
    }
    var values: [WireValue] {
        if case .array(let v) = self { return v }
        return []
    }
}

enum ConnectionFailure: LocalizedError, Equatable {
    case unavailable, disconnected, timeout, invalidRecord
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return
                "Choose the Codex executable in Connection settings. Install or sign in to Codex first."
        case .disconnected:
            return "The Codex connection closed. An unanswered send may already have been accepted."
        case .timeout:
            return "Codex did not acknowledge the request in time. It has not been resent."
        case .invalidRecord: return "Codex returned an unsupported or oversized protocol record."
        case .remote(let message): return String(message.prefix(1000))
        }
    }
}

struct CodexEvent: Sendable {
    let method: String
    let params: WireValue
    let requestID: WireValue?
}

protocol CodexConnection: Sendable {
    func request(_ method: String, params: WireValue) async throws -> WireValue
    func notify(_ method: String) async throws
    func respond(to id: WireValue, result: WireValue) async throws
    func reject(_ id: WireValue, message: String) async throws
    func events() async -> AsyncStream<CodexEvent>
    func close() async
}

struct ProtocolLines {
    static let limit = 1_048_576
    private var buffer = Data()

    mutating func feed(_ data: Data) throws -> [WireValue] {
        buffer.append(data)
        var records: [WireValue] = []
        while let end = buffer.firstIndex(of: 10) {
            let line = buffer.prefix(upTo: end)
            guard line.count <= Self.limit else { throw ConnectionFailure.invalidRecord }
            if !line.isEmpty {
                guard let value = try? JSONDecoder().decode(WireValue.self, from: line),
                    case .object = value
                else { throw ConnectionFailure.invalidRecord }
                records.append(value)
            }
            buffer.removeSubrange(...end)
        }
        guard buffer.count <= Self.limit else { throw ConnectionFailure.invalidRecord }
        return records
    }
}
