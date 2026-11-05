import Foundation

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fast = 1, normal = 3, relaxed = 5, slow = 10, background = 30
    var id: Int { rawValue }
    var label: String { rawValue == 1 ? "1 second" : "\(rawValue) seconds" }

    static func restoring(_ seconds: Int) -> Self { Self(rawValue: seconds) ?? .normal }
}

/// Foreground preference is preserved; background observation backs off without stopping work.
enum RefreshPolicy {
    static func seconds(configured: Int, active: Bool, visible: Bool, lowPower: Bool) -> Int {
        if !visible { return max(configured, 30) }
        if !active || lowPower { return max(configured, 15) }
        return configured
    }
}
