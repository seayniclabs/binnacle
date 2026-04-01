import EventKit
import Foundation
import MCP
import BinnacleCore

// MARK: - Entry Point

let args = CommandLine.arguments

func log(_ msg: String) {
    FileHandle.standardError.write(Data("[binnacle] \(msg)\n".utf8))
}

if args.contains("setup") {
    await runSetup()
} else {
    do {
        log("starting server...")
        try await startServer()
    } catch {
        log("error: \(error)")
        exit(1)
    }
}

// MARK: - Setup Command

func runSetup() async {
    let binary = args[0]

    print("""

    Binnacle -- macOS system control for your AI tools
    by Seaynic Labs

    """)

    // Request Calendar access
    let eventStore = EKEventStore()
    do {
        let calendarGranted = try await eventStore.requestFullAccessToEvents()
        if calendarGranted {
            print("[ok] Calendar access granted")
        } else {
            print("[!!] Calendar access denied.")
            print("  Grant access in System Settings -> Privacy & Security -> Calendars")
        }
    } catch {
        print("[!!] Calendar access request failed: \(error.localizedDescription)")
    }

    // Request Reminders access
    do {
        let remindersGranted = try await eventStore.requestFullAccessToReminders()
        if remindersGranted {
            print("[ok] Reminders access granted")
        } else {
            print("[!!] Reminders access denied.")
            print("  Grant access in System Settings -> Privacy & Security -> Reminders")
        }
    } catch {
        print("[!!] Reminders access request failed: \(error.localizedDescription)")
    }

    print("")
    print("""
    Add Binnacle to Claude Code:

      claude mcp add binnacle -- \(binary) serve

    Or add manually to ~/.claude.json:

      {
        "mcpServers": {
          "binnacle": {
            "command": "\(binary)",
            "args": ["serve"]
          }
        }
      }

    Setup complete. Try: "What's on my calendar today?"
    """)
}

// MARK: - Tool Registry

/// Route a tool call to the appropriate handler

/// Route a tool call to the appropriate handler
func handleToolCall(name: String, arguments: [String: Value]?) async -> CallTool.Result {
    switch name {
    case "ping":
        return await PingHandler.handle(arguments: arguments)
    case let n where n.hasPrefix("calendar_"):
        return await CalendarTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("reminders_"):
        return await ReminderTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("shortcuts_"):
        return await ShortcutTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("system_"):
        return await SystemInfoTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("notification_"):
        return await NotificationTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("clipboard_"):
        return await ClipboardTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("spotlight_"):
        return await SpotlightTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("finder_"):
        return await FinderTools.handle(name: n, arguments: arguments)
    case "get_downloads":
        return await FinderTools.handle(name: name, arguments: arguments)
    case "open_app", "get_running_apps":
        return await AppTools.handle(name: name, arguments: arguments)
    case "get_display_settings":
        return await DisplayTools.handle(name: name, arguments: arguments)
    case "toggle_dark_mode", "toggle_dnd":
        return await AppearanceTools.handle(name: name, arguments: arguments)
    case "get_wifi_info":
        return await NetworkTools.handle(name: name, arguments: arguments)
    case "get_battery_status":
        return await PowerTools.handle(name: name, arguments: arguments)
    case "get_storage_summary":
        return await StorageTools.handle(name: name, arguments: arguments)
    default:
        return .init(
            content: [.text(text: "Unknown tool: \(name)", annotations: nil, _meta: nil)],
            isError: true
        )
    }
}

// MARK: - MCP Server

@_optimize(none)
func startServer() async throws {
    let server = Server(
        name: Binnacle.serverName,
        version: Binnacle.serverVersion,
        capabilities: .init(tools: .init(listChanged: false))
    )

    // Build the tool list as a local — avoids Swift's lazy global init which races
    // with async actor hops when stdout is a pipe (proxy subprocess invocation).
    var tools: [Tool] = [PingHandler.tool]
    tools += CalendarTools.allTools + ReminderTools.allTools + ShortcutTools.allTools
    tools += SystemInfoTools.allTools + NotificationTools.allTools + ClipboardTools.allTools
    tools += SpotlightTools.allTools + FinderTools.allTools + AppTools.allTools
    tools += DisplayTools.allTools + AppearanceTools.allTools + NetworkTools.allTools
    tools += PowerTools.allTools + StorageTools.allTools
    let registeredTools = tools  // immutable copy for @Sendable capture

    // Register tools/list handler
    await server.withMethodHandler(ListTools.self) { _ in
        .init(tools: registeredTools)
    }

    // Register tools/call handler
    await server.withMethodHandler(CallTool.self) { params in
        await handleToolCall(name: params.name, arguments: params.arguments)
    }

    // Start on stdio transport
    let transport = StdioTransport()
    try await server.start(transport: transport)

    log("server running with \(tools.count) tools")

    await server.waitUntilCompleted()
}
