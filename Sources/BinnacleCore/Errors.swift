// MARK: - Binnacle Errors

public enum BinnacleError: Error, CustomStringConvertible {
    case permissionDenied(String)
    case notFound(String)
    case invalidInput(String)
    case shortcutFailed(String)
    case commandFailed(String)

    public var description: String {
        switch self {
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .notFound(let msg): return "Not found: \(msg)"
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .shortcutFailed(let msg): return "Shortcut failed: \(msg)"
        case .commandFailed(let msg): return "Command failed: \(msg)"
        }
    }
}
