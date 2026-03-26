import Foundation
import MCP
import BinnacleCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Display settings tools -- resolution, scaling, arrangement
enum DisplayTools {

    static var allTools: [Tool] { DisplayToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "get_display_settings":
                return try await handleGetSettings()
            default:
                return errorResult("Unknown display tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Get Display Settings

    private static func handleGetSettings() async throws -> CallTool.Result {
        var displays: [[String: Any]] = []

        // Use system_profiler for reliable cross-display data
        let profilerOutput = try await runCommand(
            "/usr/sbin/system_profiler",
            arguments: ["SPDisplaysDataType", "-json"]
        )

        if let data = profilerOutput.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let gpus = json["SPDisplaysDataType"] as? [[String: Any]] {
            for gpu in gpus {
                let gpuName = gpu["_name"] as? String ?? "Unknown"
                if let ndrvs = gpu["spdisplays_ndrvs"] as? [[String: Any]] {
                    for display in ndrvs {
                        var info: [String: Any] = [:]
                        if let name = display["_name"] as? String {
                            info["name"] = name
                        }
                        if let res = display["_spdisplays_resolution"] as? String {
                            info["resolution"] = res
                        }
                        if let pixels = display["_spdisplays_pixels"] as? String {
                            info["pixels"] = pixels
                        }
                        if let mirror = display["spdisplays_mirror"] as? String {
                            info["mirrored"] = mirror
                        }
                        if let main = display["spdisplays_main"] as? String {
                            info["main"] = main == "spdisplays_yes"
                        }
                        if let colorProfile = display["spdisplays_color_profile"] as? String {
                            info["color_profile"] = colorProfile
                        }
                        if let retina = display["spdisplays_retina"] as? String {
                            info["retina"] = retina == "spdisplays_yes"
                        }
                        info["gpu"] = gpuName
                        displays.append(info)
                    }
                }
            }
        }

        // Also get CGDisplay info for bounds/arrangement
        let activeDisplays = getActiveDisplayIds()
        if let activeIds = activeDisplays {
            for (index, displayId) in activeIds.enumerated() {
                let bounds = CGDisplayBounds(displayId)
                if index < displays.count {
                    displays[index]["bounds"] = [
                        "x": Int(bounds.origin.x),
                        "y": Int(bounds.origin.y),
                        "width": Int(bounds.size.width),
                        "height": Int(bounds.size.height)
                    ]
                    displays[index]["display_id"] = displayId
                }
            }
        }

        let result: [String: Any] = [
            "display_count": displays.count,
            "displays": displays
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(jsonString)
    }

    // MARK: - Helpers

    /// Get active display list using CoreGraphics
    private static func getActiveDisplayIds() -> [CGDirectDisplayID]? {
        var displayCount: UInt32 = 0
        let countResult = CoreGraphics.CGGetActiveDisplayList(0, nil, &displayCount)
        guard countResult == .success, displayCount > 0 else { return nil }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        let listResult = CoreGraphics.CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        guard listResult == .success else { return nil }

        return displays
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
