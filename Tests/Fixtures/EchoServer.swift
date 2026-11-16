import Foundation

// Isolated synthetic stdio server, compiled by the subprocess test. No account or network I/O.
while let line = readLine() {
    guard let data = line.data(using: .utf8),
        let value = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        exit(1)
    }
    if value["method"] as? String == "hang" { continue }
    if let id = value["id"] {
        var result = try JSONSerialization.data(withJSONObject: [
            "id": id, "result": value["params"] ?? [:],
        ])
        result.append(10)
        try FileHandle.standardOutput.write(contentsOf: result)
    }
}
