import Foundation
import MCP
import BinnacleCore

#if canImport(AppKit)
import AppKit
#endif

/// App management tools -- launch and list running applications
enum AppTools {

    static var allTools: [Tool] { AppToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "open_app":
                return try await handleOpenApp(arguments: arguments)
            case "get_running_apps":
                return try handleGetRunningApps()
            default:
                return errorResult("Unknown app tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Open App

    private static func handleOpenApp(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let name = arguments?["name"]?.stringValue, !name.isEmpty else {
            return errorResult("Missing required parameter: name")
        }

        // Use open -a which handles app name resolution
        let output = try await runCommand(
            "/usr/bin/open",
            arguments: ["-a", name]
        )

        let result: [String: Any] = [
            "opened": true,
            "app": name
        ]

        let _ = output // open produces no stdout on success
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(json)
    }

    // MARK: - Running Apps

    private static func handleGetRunningApps() throws -> CallTool.Result {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications

        var appList: [[String: Any]] = []
        for app in apps {
            // Only include regular apps (not background daemons)
            guard app.activationPolicy == .regular else { continue }
            var entry: [String: Any] = [:]
            if let name = app.localizedName {
                entry["name"] = name
            }
            if let bundleId = app.bundleIdentifier {
                entry["bundle_id"] = bundleId
            }
            entry["pid"] = app.processIdentifier
            entry["active"] = app.isActive
            entry["hidden"] = app.isHidden
            appList.append(entry)
        }

        // Sort by name
        appList.sort { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }

        let result: [String: Any] = [
            "count": appList.count,
            "apps": appList
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
