import Foundation
import MCP
import BinnacleCore

/// Finder tools -- tags, file info, downloads
enum FinderTools {

    static var allTools: [Tool] { FinderToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "finder_tags":
                return try await handleTags(arguments: arguments)
            case "finder_info":
                return try await handleInfo(arguments: arguments)
            case "get_downloads":
                return try await handleGetDownloads(arguments: arguments)
            default:
                return errorResult("Unknown finder tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Tags

    private static func handleTags(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let path = arguments?["path"]?.stringValue, !path.isEmpty else {
            return errorResult("Missing required parameter: path")
        }
        guard let action = arguments?["action"]?.stringValue else {
            return errorResult("Missing required parameter: action")
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let fm = FileManager.default
        guard fm.fileExists(atPath: expandedPath) else {
            return errorResult("File not found: \(path)")
        }

        let url = URL(fileURLWithPath: expandedPath)

        switch action.lowercased() {
        case "list":
            let resourceValues = try url.resourceValues(forKeys: [.tagNamesKey])
            let tags = resourceValues.tagNames ?? []
            let result: [String: Any] = [
                "path": expandedPath,
                "tags": tags
            ]
            return try jsonResult(result)

        case "set":
            guard let tagValues = arguments?["tags"]?.arrayValue else {
                return errorResult("Missing required parameter: tags (array of strings)")
            }
            let tags = tagValues.compactMap { $0.stringValue }
            try setFinderTags(url: url, tags: tags)
            let result: [String: Any] = [
                "path": expandedPath,
                "tags_set": tags
            ]
            return try jsonResult(result)

        case "add":
            guard let tagValues = arguments?["tags"]?.arrayValue else {
                return errorResult("Missing required parameter: tags (array of strings)")
            }
            let newTags = tagValues.compactMap { $0.stringValue }
            let existing = try url.resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
            let combined = Array(Set(existing + newTags))
            try setFinderTags(url: url, tags: combined)
            let result: [String: Any] = [
                "path": expandedPath,
                "tags": combined
            ]
            return try jsonResult(result)

        default:
            return errorResult("Unknown action: \(action). Use list, set, or add.")
        }
    }

    // MARK: - File Info

    private static func handleInfo(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let path = arguments?["path"]?.stringValue, !path.isEmpty else {
            return errorResult("Missing required parameter: path")
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let fm = FileManager.default
        guard fm.fileExists(atPath: expandedPath) else {
            return errorResult("File not found: \(path)")
        }

        let url = URL(fileURLWithPath: expandedPath)
        let attrs = try fm.attributesOfItem(atPath: expandedPath)

        var info: [String: Any] = [
            "path": expandedPath,
            "name": (expandedPath as NSString).lastPathComponent
        ]

        if let size = attrs[.size] as? UInt64 {
            info["size_bytes"] = size
            info["size_human"] = humanReadableSize(size)
        }
        if let created = attrs[.creationDate] as? Date {
            info["created"] = Validators.formatISO8601(created)
        }
        if let modified = attrs[.modificationDate] as? Date {
            info["modified"] = Validators.formatISO8601(modified)
        }
        if let type = attrs[.type] as? FileAttributeType {
            info["type"] = type == .typeDirectory ? "directory" : "file"
        }

        // Finder tags
        if let resourceValues = try? url.resourceValues(forKeys: [.tagNamesKey]) {
            info["tags"] = resourceValues.tagNames ?? []
        }

        // Finder comment via mdls
        let commentOutput = try? await runCommand(
            "/usr/bin/mdls",
            arguments: ["-name", "kMDItemFinderComment", expandedPath]
        )
        if let commentOutput = commentOutput, !commentOutput.contains("(null)") {
            let parts = commentOutput.components(separatedBy: "= ")
            if parts.count > 1 {
                let comment = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"").union(.whitespacesAndNewlines))
                if !comment.isEmpty {
                    info["finder_comment"] = comment
                }
            }
        }

        // Content type via resource values
        if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]) {
            if let contentType = resourceValues.contentType {
                info["content_type"] = contentType.identifier
            }
        }

        return try jsonResult(info)
    }

    // MARK: - Downloads

    private static func handleGetDownloads(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit = arguments?["limit"]?.intValue ?? 20
        let sortBy = arguments?["sort_by"]?.stringValue ?? "date"
        let effectiveLimit = min(max(limit, 1), 100)

        let downloadsPath = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
        let fm = FileManager.default
        guard fm.fileExists(atPath: downloadsPath) else {
            return errorResult("Downloads folder not found")
        }

        let contents = try fm.contentsOfDirectory(atPath: downloadsPath)

        var files: [[String: Any]] = []
        for name in contents {
            guard !name.hasPrefix(".") else { continue }
            let fullPath = (downloadsPath as NSString).appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath) else { continue }

            var entry: [String: Any] = [
                "name": name,
                "path": fullPath
            ]
            if let size = attrs[.size] as? UInt64 {
                entry["size_bytes"] = size
                entry["size_human"] = humanReadableSize(size)
            }
            if let modified = attrs[.modificationDate] as? Date {
                entry["modified"] = Validators.formatISO8601(modified)
                entry["_sort_date"] = modified.timeIntervalSince1970
            }
            if let type = attrs[.type] as? FileAttributeType {
                entry["type"] = type == .typeDirectory ? "directory" : "file"
            }
            files.append(entry)
        }

        // Sort
        switch sortBy.lowercased() {
        case "size":
            files.sort { ($0["size_bytes"] as? UInt64 ?? 0) > ($1["size_bytes"] as? UInt64 ?? 0) }
        case "name":
            files.sort { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }
        default: // date
            files.sort { ($0["_sort_date"] as? Double ?? 0) > ($1["_sort_date"] as? Double ?? 0) }
        }

        // Remove internal sort key and limit
        files = Array(files.prefix(effectiveLimit)).map { entry in
            var clean = entry
            clean.removeValue(forKey: "_sort_date")
            return clean
        }

        let result: [String: Any] = [
            "count": files.count,
            "files": files
        ]

        return try jsonResult(result)
    }

    // MARK: - Finder Tags (xattr-based for compatibility)

    /// Set Finder tags on a file using NSFileManager extended attributes.
    /// This avoids the macOS 26+ availability restriction on URLResourceValues.tagNames setter.
    private static func setFinderTags(url: URL, tags: [String]) throws {
        // Use NSURL setResourceValue which has been available since macOS 10.9
        let nsUrl = url as NSURL
        try nsUrl.setResourceValue(tags as NSArray, forKey: .tagNamesKey)
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

    private static func humanReadableSize(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        return String(format: "%.1f %@", size, units[unitIndex])
    }

    private static func jsonResult(_ dict: [String: Any]) throws -> CallTool.Result {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(json)
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
