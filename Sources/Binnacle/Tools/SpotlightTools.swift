import Foundation
import MCP
import BinnacleCore

/// Spotlight search tools -- uses mdfind for Spotlight queries
enum SpotlightTools {

    static var allTools: [Tool] { SpotlightToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "spotlight_search":
                return try await handleSearch(arguments: arguments)
            default:
                return errorResult("Unknown spotlight tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Search

    private static func handleSearch(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let query = arguments?["query"]?.stringValue, !query.isEmpty else {
            return errorResult("Missing required parameter: query")
        }

        let kind = arguments?["kind"]?.stringValue
        let directory = arguments?["directory"]?.stringValue
        let limit = arguments?["limit"]?.intValue ?? 20
        let effectiveLimit = min(max(limit, 1), 100)

        // Build the mdfind query
        var mdfindQuery = ""

        // Map kind to Spotlight kMDItemContentTypeTree values
        if let kind = kind {
            let kindFilter = spotlightKind(for: kind)
            if !kindFilter.isEmpty {
                mdfindQuery += kindFilter + " && "
            }
        }

        // Add the user query as a name or content match
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"")
        mdfindQuery += "(kMDItemDisplayName == \"*\(escapedQuery)*\"cdw || kMDItemTextContent == \"*\(escapedQuery)*\"cdw)"

        var args = ["-interpret", mdfindQuery]
        if let directory = directory {
            args = ["-onlyin", directory, "-interpret", mdfindQuery]
        }

        let output = try await runCommand("/usr/bin/mdfind", arguments: args)

        // Parse results and limit
        let paths = output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .prefix(effectiveLimit)

        // Get basic info for each result
        var results: [[String: Any]] = []
        let fm = FileManager.default
        for path in paths {
            var info: [String: Any] = ["path": path]
            info["name"] = (path as NSString).lastPathComponent

            if let attrs = try? fm.attributesOfItem(atPath: path) {
                if let size = attrs[.size] as? UInt64 {
                    info["size_bytes"] = size
                }
                if let modified = attrs[.modificationDate] as? Date {
                    info["modified"] = Validators.formatISO8601(modified)
                }
                if let type = attrs[.type] as? FileAttributeType {
                    info["type"] = type == .typeDirectory ? "directory" : "file"
                }
            }
            results.append(info)
        }

        let response: [String: Any] = [
            "query": query,
            "count": results.count,
            "results": results
        ]

        let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(jsonString)
    }

    // MARK: - Kind Mapping

    private static func spotlightKind(for kind: String) -> String {
        switch kind.lowercased() {
        case "document": return "kMDItemContentTypeTree == 'public.text'"
        case "image": return "kMDItemContentTypeTree == 'public.image'"
        case "audio": return "kMDItemContentTypeTree == 'public.audio'"
        case "video": return "kMDItemContentTypeTree == 'public.movie'"
        case "pdf": return "kMDItemContentType == 'com.adobe.pdf'"
        case "folder": return "kMDItemContentType == 'public.folder'"
        case "application": return "kMDItemContentType == 'com.apple.application-bundle'"
        case "email": return "kMDItemContentTypeTree == 'public.message'"
        case "presentation": return "kMDItemContentTypeTree == 'public.presentation'"
        case "spreadsheet": return "kMDItemContentTypeTree == 'public.spreadsheet'"
        default: return ""
        }
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
