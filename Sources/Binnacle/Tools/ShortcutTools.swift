import Foundation
import MCP

/// Shortcuts integration tools — uses Process with argument arrays (never string interpolation)
enum ShortcutTools {

    // MARK: - Tool Definitions

    static let shortcutsList = Tool(
        name: "shortcuts_list",
        description: "List all Shortcuts available on this Mac",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    static let shortcutsRun = Tool(
        name: "shortcuts_run",
        description: "Run a Shortcut by name with optional text input",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "name": .object(["type": "string", "description": "Shortcut name"]),
                "input": .object(["type": "string", "description": "Text input to pass to the Shortcut (optional)"])
            ]),
            "required": .array(["name"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: true
        )
    )

    static let shortcutsFolders = Tool(
        name: "shortcuts_folders",
        description: "List Shortcut folders",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    static var allTools: [Tool] {
        [shortcutsList, shortcutsRun, shortcutsFolders]
    }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "shortcuts_list":
                return try await handleList()
            case "shortcuts_run":
                return try await handleRun(arguments: arguments)
            case "shortcuts_folders":
                return try await handleFolders()
            default:
                return errorResult("Unknown shortcuts tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - List

    private static func handleList() async throws -> CallTool.Result {
        let output = try await runShortcutsCommand(arguments: ["list"])
        return .init(
            content: [.text(text: output, annotations: nil, _meta: nil)],
            isError: false
        )
    }

    // MARK: - Run

    private static func handleRun(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let shortcutName = arguments?["name"]?.stringValue else {
            return errorResult("Missing required parameter: name")
        }

        // SECURITY: Validate shortcut name has no shell metacharacters
        try Validators.validateShortcutName(shortcutName)

        let input = arguments?["input"]?.stringValue

        var args = ["run", shortcutName]
        if input != nil {
            args.append(contentsOf: ["--input-type", "text"])
        }

        let output = try await runShortcutsCommand(arguments: args, stdinData: input)
        return .init(
            content: [.text(text: output.isEmpty ? "Shortcut completed successfully" : output, annotations: nil, _meta: nil)],
            isError: false
        )
    }

    // MARK: - Folders

    private static func handleFolders() async throws -> CallTool.Result {
        // Try --folders flag first; fall back to parsing list output
        do {
            let output = try await runShortcutsCommand(arguments: ["list", "--folders"])
            return .init(
                content: [.text(text: output, annotations: nil, _meta: nil)],
                isError: false
            )
        } catch {
            // Fallback: list all shortcuts and extract unique folder info
            let output = try await runShortcutsCommand(arguments: ["list", "--show-identifiers"])
            return .init(
                content: [.text(text: output, annotations: nil, _meta: nil)],
                isError: false
            )
        }
    }

    // MARK: - Process Execution

    /// Run the shortcuts CLI with an argument array. NEVER use string interpolation for commands.
    private static func runShortcutsCommand(
        arguments: [String],
        stdinData: String? = nil
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process() // shortcuts execution
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Pass input via stdin pipe, not as a command argument
            if let inputString = stdinData {
                let inputPipe = Pipe()
                process.standardInput = inputPipe
                if let data = inputString.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(data)
                    inputPipe.fileHandleForWriting.closeFile()
                }
            }

            process.terminationHandler = { proc in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = errorOutput.isEmpty ? "Shortcut process exited with code \(proc.terminationStatus)" : errorOutput
                    continuation.resume(throwing: BinnacleError.shortcutFailed(message))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BinnacleError.shortcutFailed("Failed to launch shortcuts: \(error)"))
            }
        }
    }

    private static func errorResult(_ message: String) -> CallTool.Result {
        .init(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }
}
