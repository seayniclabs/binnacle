import Foundation
import MCP
import BinnacleCore

/// Storage tools -- disk usage breakdown
enum StorageTools {

    static var allTools: [Tool] { StorageToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "get_storage_summary":
                return try await handleGetSummary()
            default:
                return errorResult("Unknown storage tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Storage Summary

    private static func handleGetSummary() async throws -> CallTool.Result {
        var volumes: [[String: Any]] = []

        // Get mounted volumes
        let fm = FileManager.default
        let volumePaths = fm.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey
        ], options: [.skipHiddenVolumes]) ?? []

        for volumeURL in volumePaths {
            guard let resourceValues = try? volumeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeNameKey,
                .volumeIsRemovableKey,
                .volumeIsLocalKey
            ]) else { continue }

            var volInfo: [String: Any] = [:]
            volInfo["path"] = volumeURL.path
            volInfo["name"] = resourceValues.volumeName ?? volumeURL.lastPathComponent

            if let total = resourceValues.volumeTotalCapacity {
                let totalBytes = UInt64(total)
                volInfo["total_bytes"] = totalBytes
                volInfo["total_human"] = humanReadableSize(totalBytes)
            }
            if let available = resourceValues.volumeAvailableCapacity {
                let availBytes = UInt64(available)
                volInfo["available_bytes"] = availBytes
                volInfo["available_human"] = humanReadableSize(availBytes)
            }
            if let total = resourceValues.volumeTotalCapacity,
               let available = resourceValues.volumeAvailableCapacity, total > 0 {
                let used = total - available
                let usedBytes = UInt64(used)
                volInfo["used_bytes"] = usedBytes
                volInfo["used_human"] = humanReadableSize(usedBytes)
                let usedPercent = (Double(used) / Double(total)) * 100.0
                volInfo["used_percent"] = round(usedPercent * 10) / 10
            }
            if let removable = resourceValues.volumeIsRemovable {
                volInfo["removable"] = removable
            }
            if let local = resourceValues.volumeIsLocal {
                volInfo["local"] = local
            }

            volumes.append(volInfo)
        }

        // Primary disk summary (root volume)
        var primaryDisk: [String: Any] = [:]
        if let attrs = try? fm.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? UInt64) ?? 0
            let free = (attrs[.systemFreeSize] as? UInt64) ?? 0
            let used = total - free
            primaryDisk["total_bytes"] = total
            primaryDisk["total_human"] = humanReadableSize(total)
            primaryDisk["used_bytes"] = used
            primaryDisk["used_human"] = humanReadableSize(used)
            primaryDisk["free_bytes"] = free
            primaryDisk["free_human"] = humanReadableSize(free)
            if total > 0 {
                primaryDisk["used_percent"] = round((Double(used) / Double(total)) * 1000) / 10
            }
        }

        let result: [String: Any] = [
            "primary_disk": primaryDisk,
            "volume_count": volumes.count,
            "volumes": volumes
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(json)
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
