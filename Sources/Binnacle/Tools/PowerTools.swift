import Foundation
import MCP
import BinnacleCore

#if canImport(IOKit)
import IOKit.ps
#endif

/// Power/battery tools -- battery status, charging, health
enum PowerTools {

    static var allTools: [Tool] { PowerToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "get_battery_status":
                return try await handleGetBatteryStatus()
            default:
                return errorResult("Unknown power tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - Battery Status

    private static func handleGetBatteryStatus() async throws -> CallTool.Result {
        var info: [String: Any] = [:]

        // IOKit power source info
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                    if let capacity = desc[kIOPSCurrentCapacityKey] as? Int {
                        info["level_percent"] = capacity
                    }
                    if let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int {
                        info["max_capacity"] = maxCapacity
                    }
                    if let charging = desc[kIOPSIsChargingKey] as? Bool {
                        info["is_charging"] = charging
                    }
                    if let src = desc[kIOPSPowerSourceStateKey] as? String {
                        info["power_source"] = src
                    }
                    if let timeRemaining = desc[kIOPSTimeToEmptyKey] as? Int {
                        if timeRemaining > 0 {
                            info["minutes_to_empty"] = timeRemaining
                        }
                    }
                    if let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int {
                        if timeToFull > 0 {
                            info["minutes_to_full"] = timeToFull
                        }
                    }
                    if let name = desc[kIOPSNameKey] as? String {
                        info["name"] = name
                    }
                }
            }
        }

        // If no battery found (desktop Mac), report that
        if info.isEmpty {
            info["has_battery"] = false
            info["power_source"] = "AC Power"
        } else {
            info["has_battery"] = true
        }

        // Get cycle count and health via system_profiler
        let profilerOutput = try? await runCommand(
            "/usr/sbin/system_profiler",
            arguments: ["SPPowerDataType", "-json"]
        )

        if let output = profilerOutput,
           let data = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let powerData = json["SPPowerDataType"] as? [[String: Any]] {
            for entry in powerData {
                if let batteryInfo = entry["sppower_battery_health_info"] as? [String: Any] {
                    if let cycleCount = batteryInfo["sppower_battery_cycle_count"] as? Int {
                        info["cycle_count"] = cycleCount
                    }
                    if let condition = batteryInfo["sppower_battery_health"] as? String {
                        info["health"] = condition
                    }
                    if let maxCapPct = batteryInfo["sppower_battery_health_maximum_capacity"] as? String {
                        info["health_max_capacity"] = maxCapPct
                    }
                }
            }
        }

        let resultData = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: resultData, encoding: .utf8) ?? "{}"
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
