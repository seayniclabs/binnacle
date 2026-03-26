import Foundation
import MCP
import BinnacleCore

/// Appearance tools -- dark mode, Do Not Disturb
enum AppearanceTools {

    static var allTools: [Tool] { AppearanceToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "toggle_dark_mode":
                return try await handleToggleDarkMode(arguments: arguments)
            case "toggle_dnd":
                return try await handleToggleDnd(arguments: arguments)
            default:
                return errorResult("Unknown appearance tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Dark Mode

    private static func handleToggleDarkMode(arguments: [String: Value]?) async throws -> CallTool.Result {
        let mode = arguments?["mode"]?.stringValue ?? "toggle"

        let script: String
        switch mode.lowercased() {
        case "dark":
            script = "tell application \"System Events\" to tell appearance preferences to set dark mode to true"
        case "light":
            script = "tell application \"System Events\" to tell appearance preferences to set dark mode to false"
        default: // toggle
            script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        }

        _ = try await runCommand("/usr/bin/osascript", arguments: ["-e", script])

        // Read current state
        let checkScript = "tell application \"System Events\" to tell appearance preferences to get dark mode"
        let isDarkStr = try await runCommand("/usr/bin/osascript", arguments: ["-e", checkScript])
        let isDark = isDarkStr.trimmingCharacters(in: .whitespacesAndNewlines) == "true"

        let result: [String: Any] = [
            "dark_mode": isDark,
            "appearance": isDark ? "dark" : "light"
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(json)
    }

    // MARK: - Do Not Disturb

    private static func handleToggleDnd(arguments: [String: Value]?) async throws -> CallTool.Result {
        // macOS Sonoma+ uses Focus modes via shortcuts CLI
        // We toggle DND by calling the shortcuts command or using defaults
        let enabled = arguments?["enabled"]

        // Check current DND state via defaults
        let checkOutput = try? await runCommand(
            "/usr/bin/defaults",
            arguments: ["-currentHost", "read", "com.apple.notificationcenterui", "doNotDisturb"]
        )
        let currentlyEnabled = checkOutput?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"

        let shouldEnable: Bool
        if let enabledVal = enabled {
            if case .bool(let b) = enabledVal {
                shouldEnable = b
            } else if let s = enabledVal.stringValue {
                shouldEnable = s == "true"
            } else {
                shouldEnable = !currentlyEnabled
            }
        } else {
            shouldEnable = !currentlyEnabled
        }

        // Use shortcuts to toggle Focus/DND
        // On macOS 14+, the best approach is osascript to toggle the menu bar DND
        let script: String
        if shouldEnable {
            script = """
            do shell script "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean true"
            do shell script "defaults -currentHost write com.apple.notificationcenterui doNotDisturbDate -date \\\"$(date -u +\\"%Y-%m-%dT%H:%M:%S.000Z\\")\\\" "
            do shell script "killall NotificationCenter 2>/dev/null || true"
            """
        } else {
            script = """
            do shell script "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean false"
            do shell script "defaults -currentHost delete com.apple.notificationcenterui doNotDisturbDate 2>/dev/null || true"
            do shell script "killall NotificationCenter 2>/dev/null || true"
            """
        }

        _ = try await runCommand("/usr/bin/osascript", arguments: ["-e", script])

        let result: [String: Any] = [
            "dnd_enabled": shouldEnable,
            "previous_state": currentlyEnabled
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(json)
    }

    // MARK: - Process Execution

    private static func runCommand(
        _ executable: String,
        arguments: [String]
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let message = errorOutput.isEmpty ? "Process exited with code \(proc.terminationStatus)" : errorOutput
                    continuation.resume(throwing: BinnacleError.commandFailed(message))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BinnacleError.commandFailed("Failed to launch \(executable): \(error)"))
            }
        }
    }

    // MARK: - Helpers

    private static func textResult(_ text: String) -> CallTool.Result {
        .init(
            content: [.text(text: text, annotations: nil, _meta: nil)],
            isError: false
        )
    }

    private static func errorResult(_ message: String) -> CallTool.Result {
        .init(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }
}
