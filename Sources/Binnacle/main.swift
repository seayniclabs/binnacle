import Foundation
import MCP

// MARK: - Tool Registry

/// All tools registered in the server
let allTools: [Tool] = [PingTool.tool] + CalendarTools.allTools + ReminderTools.allTools + ShortcutTools.allTools

/// Route a tool call to the appropriate handler
func handleToolCall(name: String, arguments: [String: Value]?) async -> CallTool.Result {
    switch name {
    case "ping":
        return await PingTool.handle(arguments: arguments)
    case let n where n.hasPrefix("calendar_"):
        return await CalendarTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("reminders_"):
        return await ReminderTools.handle(name: n, arguments: arguments)
    case let n where n.hasPrefix("shortcuts_"):
        return await ShortcutTools.handle(name: n, arguments: arguments)
    default:
        return .init(
            content: [.text(text: "Unknown tool: \(name)", annotations: nil, _meta: nil)],
            isError: true
        )
    }
}

// MARK: - Server Setup

let server = Server(
    name: "binnacle",
    version: "0.1.0",
    capabilities: .init(tools: .init(listChanged: false))
)

// Register tools/list handler
await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: allTools)
}

// Register tools/call handler
await server.withMethodHandler(CallTool.self) { params in
    await handleToolCall(name: params.name, arguments: params.arguments)
}

// Start on stdio transport
let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
