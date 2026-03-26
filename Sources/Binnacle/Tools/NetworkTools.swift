import Foundation
import MCP
import BinnacleCore

#if canImport(SystemConfiguration)
import SystemConfiguration
#endif

/// Network tools -- WiFi info, IP address
enum NetworkTools {

    static var allTools: [Tool] { NetworkToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "get_wifi_info":
                return try await handleGetWifiInfo()
            default:
                return errorResult("Unknown network tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - WiFi Info

    private static func handleGetWifiInfo() async throws -> CallTool.Result {
        var info: [String: Any] = [:]

        // Get WiFi network info via system_profiler
        let airportOutput = try await runCommand(
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
            arguments: ["-I"]
        )

        // Parse airport -I output
        let lines = airportOutput.components(separatedBy: "\n")
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: ": ").trimmingCharacters(in: .whitespaces)

            switch key {
            case "SSID":
                info["ssid"] = value
            case "BSSID":
                info["bssid"] = value
            case "agrCtlRSSI":
                info["rssi"] = Int(value) ?? 0
            case "agrCtlNoise":
                info["noise"] = Int(value) ?? 0
            case "channel":
                info["channel"] = value
            case "lastTxRate":
                info["tx_rate_mbps"] = Int(value) ?? 0
            case "link auth":
                info["security"] = value
            default:
                break
            }
        }

        // Signal quality estimate (RSSI to percentage)
        if let rssi = info["rssi"] as? Int {
            let quality: Int
            if rssi >= -50 { quality = 100 }
            else if rssi >= -60 { quality = 80 }
            else if rssi >= -70 { quality = 60 }
            else if rssi >= -80 { quality = 40 }
            else { quality = max(0, 20 + (rssi + 90) * 2) }
            info["signal_quality_percent"] = quality
        }

        // Get IP address via ifconfig
        let ifconfigOutput = try await runCommand(
            "/sbin/ifconfig",
            arguments: ["en0"]
        )

        let ifLines = ifconfigOutput.components(separatedBy: "\n")
        for line in ifLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("inet ") && !trimmed.contains("127.0.0.1") {
                let parts = trimmed.components(separatedBy: " ")
                if parts.count >= 2 {
                    info["ip_address"] = parts[1]
                }
            }
            if trimmed.hasPrefix("inet6 ") && !trimmed.contains("::1") && !trimmed.contains("fe80") {
                let parts = trimmed.components(separatedBy: " ")
                if parts.count >= 2 {
                    // Strip scope ID suffix (e.g., %en0)
                    let ipv6 = parts[1].components(separatedBy: "%").first ?? parts[1]
                    info["ipv6_address"] = ipv6
                }
            }
        }

        info["interface"] = "en0"

        let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
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
