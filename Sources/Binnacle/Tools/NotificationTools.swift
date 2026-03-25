import Foundation
import MCP
import BinnacleCore

/// Notification tools -- send macOS notifications
enum NotificationTools {

    static var allTools: [Tool] { NotificationToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "notification_send":
                return try await handleSend(arguments: arguments)
            default:
                return errorResult("Unknown notification tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Send Notification

    private static func handleSend(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let title = arguments?["title"]?.stringValue else {
            return errorResult("Missing required parameter: title")
        }
        guard let body = arguments?["body"]?.stringValue else {
            return errorResult("Missing required parameter: body")
        }

        let subtitle = arguments?["subtitle"]?.stringValue

        // Build osascript command for notification
        var script = "display notification \"\(escapeAppleScript(body))\" with title \"\(escapeAppleScript(title))\""
        if let subtitle = subtitle {
            script += " subtitle \"\(escapeAppleScript(subtitle))\""
        }

        _ = try await runCommand(
            "/usr/bin/osascript",
            arguments: ["-e", script]
        )

        return textResult("{\"sent\":true,\"title\":\"\(escapeJSON(title))\"}")
    }

    // MARK: - Helpers

    /// Escape a string for use inside AppleScript double-quoted strings
    private static func escapeAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Escape a string for use inside JSON double-quoted strings
    private static func escapeJSON(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
           .replacingOccurrences(of: "\n", with: "\\n")
    }

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
