import Darwin
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

enum CodexExecutable {
    static func locate() -> URL? {
        let custom = UserDefaults.standard.string(forKey: "codexExecutable")
        let candidates = [
            custom,
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
        ].compactMap { $0 }
        return candidates.map { URL(fileURLWithPath: $0) }.first(where: isValid)
    }

    static func isValid(_ url: URL) -> Bool {
        guard url.isFileURL, url.path.hasPrefix("/"),
            let values = try? url.resolvingSymlinksInPath().resourceValues(forKeys: [
                .isRegularFileKey
            ]),
            values.isRegularFile == true
        else { return false }
        return FileManager.default.isExecutableFile(atPath: url.path)
    }
}

/// Owns only its child app-server. No listeners, shell interpolation, auth scraping or database writes.
actor CodexProcessConnection: CodexConnection {
    private let executable: URL?
    private let timeout: Duration
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var readerTask: Task<Void, Never>?
    private var parser = ProtocolLines()
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<WireValue, Error>] = [:]
    private var deadlines: [Int: Task<Void, Never>] = [:]
    private var continuation: AsyncStream<CodexEvent>.Continuation?
    private var closed = false

    init(executable: URL?, timeout: Duration = .seconds(45)) {
        self.executable = executable
        self.timeout = timeout
    }

    func events() -> AsyncStream<CodexEvent> {
        AsyncStream(bufferingPolicy: .bufferingOldest(256)) { continuation = $0 }
    }

    private func start() throws {
        guard !closed else { throw ConnectionFailure.disconnected }
        guard process == nil else { return }
        guard let executable, CodexExecutable.isValid(executable) else {
            throw ConnectionFailure.unavailable
        }
        let child = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        child.executableURL = executable
        child.arguments = ["app-server", "--listen", "stdio://"]
        child.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        child.standardInput = stdin
        child.standardOutput = stdout
        // Never retain raw stderr: startup output can include sensitive provider/configuration data.
        child.standardError = FileHandle.nullDevice
        try child.run()
        process = child
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        // A child exiting between the write and EOF must produce an error, not SIGPIPE-kill Jarvis.
        _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        // Blocking pipe reads need a non-actor executor. One owned task preserves byte order;
        // close() cancels it and closes the handle, unblocking the read. No task per incoming chunk.
        let descriptor = stdout.fileHandleForReading.fileDescriptor
        readerTask = Task.detached { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 65_536)
            while !Task.isCancelled {
                let count = Darwin.read(descriptor, &buffer, buffer.count)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else {
                    await self?.receive(Data())
                    break
                }
                await self?.receive(Data(buffer.prefix(count)))
            }
        }
    }

    func request(_ method: String, params: WireValue) async throws -> WireValue {
        try Task.checkCancellation()
        try start()
        nextID += 1
        let id = nextID
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { promise in
                pending[id] = promise
                deadlines[id] = Task { [weak self, timeout] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    await self?.expire(id)
                }
                do {
                    try write(
                        .object(["id": .number(id), "method": .string(method), "params": params]))
                } catch { fail(.disconnected) }
            }
        } onCancel: {
            Task { await self.expire(id) }
        }
    }

    func notify(_ method: String) throws { try write(.object(["method": .string(method)])) }
    func respond(to id: WireValue, result: WireValue) throws {
        try write(.object(["id": id, "result": result]))
    }
    func reject(_ id: WireValue, message: String) throws {
        try write(
            .object([
                "id": id, "error": .object(["code": .number(-32601), "message": .string(message)]),
            ]))
    }

    private func write(_ message: WireValue) throws {
        guard !closed, let input else { throw ConnectionFailure.disconnected }
        var data = try JSONEncoder().encode(message)
        data.append(10)
        try input.write(contentsOf: data)
    }

    private func receive(_ data: Data) {
        guard !closed else { return }
        guard !data.isEmpty else {
            fail(.disconnected)
            return
        }
        do {
            for record in try parser.feed(data) {
                if let method = record["method"].text {
                    let event = CodexEvent(
                        method: method, params: record["params"],
                        requestID: record["id"] == .null ? nil : record["id"])
                    if case .dropped = continuation?.yield(event) {
                        fail(.invalidRecord)
                        return
                    }
                } else if let id = record["id"].integer,
                    let promise = pending.removeValue(forKey: id)
                {
                    deadlines.removeValue(forKey: id)?.cancel()
                    if record["error"] != .null {
                        promise.resume(
                            throwing: ConnectionFailure.remote(
                                record["error"]["message"].text ?? "Codex rejected the request."))
                    } else {
                        promise.resume(returning: record["result"])
                    }
                }
            }
        } catch { fail(.invalidRecord) }
    }

    private func expire(_ id: Int) {
        deadlines.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(throwing: ConnectionFailure.timeout)
    }

    private func fail(_ error: ConnectionFailure) {
        guard !closed else { return }
        continuation?.yield(
            CodexEvent(method: "jarvis/disconnected", params: .null, requestID: nil))
        closed = true
        for task in deadlines.values { task.cancel() }
        deadlines.removeAll()
        let promises = pending.values
        pending.removeAll()
        for promise in promises { promise.resume(throwing: error) }
        continuation?.finish()
        readerTask?.cancel()
        readerTask = nil
        try? input?.close()
        try? output?.close()
        if process?.isRunning == true { process?.terminate() }
        process = nil
        input = nil
        output = nil
    }

    func close() { fail(.disconnected) }
}
