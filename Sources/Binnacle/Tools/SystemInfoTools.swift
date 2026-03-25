import Foundation
import MCP
import BinnacleCore

#if canImport(AppKit)
import AppKit
#endif
#if canImport(IOKit)
import IOKit.ps
#endif

/// System info tools -- CPU, memory, disk, battery, display, volume
enum SystemInfoTools {

    static var allTools: [Tool] { SystemInfoToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "system_get_info":
                return try await handleGetInfo()
            case "system_get_display_info":
                return try await handleGetDisplayInfo()
            case "system_get_volume":
                return try await handleGetVolume()
            default:
                return errorResult("Unknown system tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - System Info

    private static func handleGetInfo() async throws -> CallTool.Result {
        let info = ProcessInfo.processInfo

        // Memory
        let physicalMemory = info.physicalMemory
        let physicalMemoryGB = Double(physicalMemory) / 1_073_741_824.0

        // Active processor count
        let processorCount = info.activeProcessorCount

        // Uptime
        let uptime = info.systemUptime
        let uptimeHours = Int(uptime) / 3600
        let uptimeMinutes = (Int(uptime) % 3600) / 60

        // CPU usage via host_statistics
        var cpuPercent: Double = 0
        let cpuLoadInfoSize = MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        var cpuInfoCount = mach_msg_type_number_t(cpuLoadInfoSize)
        var cpuLoadInfo = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: cpuLoadInfoSize) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &cpuInfoCount)
            }
        }
        if result == KERN_SUCCESS {
            let user = Double(cpuLoadInfo.cpu_ticks.0)
            let system = Double(cpuLoadInfo.cpu_ticks.1)
            let idle = Double(cpuLoadInfo.cpu_ticks.2)
            let nice = Double(cpuLoadInfo.cpu_ticks.3)
            let total = user + system + idle + nice
            if total > 0 {
                cpuPercent = ((user + system + nice) / total) * 100.0
            }
        }

        // Disk space
        var diskTotal: UInt64 = 0
        var diskFree: UInt64 = 0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            diskTotal = (attrs[.systemSize] as? UInt64) ?? 0
            diskFree = (attrs[.systemFreeSize] as? UInt64) ?? 0
        }
        let diskTotalGB = Double(diskTotal) / 1_073_741_824.0
        let diskFreeGB = Double(diskFree) / 1_073_741_824.0
        let diskUsedGB = diskTotalGB - diskFreeGB

        // Battery
        var batteryLevel: Int = -1
        var isCharging = false
        var powerSource = "unknown"

        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                    if let capacity = desc[kIOPSCurrentCapacityKey] as? Int {
                        batteryLevel = capacity
                    }
                    if let charging = desc[kIOPSIsChargingKey] as? Bool {
                        isCharging = charging
                    }
                    if let src = desc[kIOPSPowerSourceStateKey] as? String {
                        powerSource = src
                    }
                }
            }
        }

        // Build JSON
        var json: [String: Any] = [
            "cpu_usage_percent": round(cpuPercent * 10) / 10,
            "active_processors": processorCount,
            "physical_memory_gb": round(physicalMemoryGB * 10) / 10,
            "uptime": "\(uptimeHours)h \(uptimeMinutes)m",
            "disk": [
                "total_gb": round(diskTotalGB * 10) / 10,
                "used_gb": round(diskUsedGB * 10) / 10,
                "free_gb": round(diskFreeGB * 10) / 10
            ]
        ]

        if batteryLevel >= 0 {
            json["battery"] = [
                "level_percent": batteryLevel,
                "is_charging": isCharging,
                "power_source": powerSource
            ]
        } else {
            json["battery"] = "no_battery"
        }

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(jsonString)
    }

    // MARK: - Display Info

    private static func handleGetDisplayInfo() async throws -> CallTool.Result {
        var displays: [[String: Any]] = []

        // Get screen info from system_profiler for reliable data
        let profilerOutput = try await runCommand(
            "/usr/sbin/system_profiler",
            arguments: ["SPDisplaysDataType", "-json"]
        )

        if let data = profilerOutput.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let gpus = json["SPDisplaysDataType"] as? [[String: Any]] {
            for gpu in gpus {
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
                        displays.append(info)
                    }
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

    // MARK: - Volume

    private static func handleGetVolume() async throws -> CallTool.Result {
        let output = try await runCommand(
            "/usr/bin/osascript",
            arguments: ["-e", "get volume settings"]
        )

        // Parse osascript output: "output volume:50, input volume:67, alert volume:100, output muted:false"
        var volume: Int? = nil
        var muted: Bool = false

        let parts = output.components(separatedBy: ", ")
        for part in parts {
            let kv = part.components(separatedBy: ":")
            if kv.count == 2 {
                let key = kv[0].trimmingCharacters(in: .whitespaces)
                let val = kv[1].trimmingCharacters(in: .whitespaces)
                if key == "output volume" {
                    volume = Int(val)
                } else if key == "output muted" {
                    muted = val == "true"
                }
            }
        }

        let result: [String: Any] = [
            "output_volume": volume ?? -1,
            "output_muted": muted
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        return textResult(jsonString)
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
