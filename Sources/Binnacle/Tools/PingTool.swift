import MCP

/// Health check tool definitions and handler
enum PingTool {
    static let tool = Tool(
        name: "ping",
        description: "Health check — returns server version and status",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    static func handle(arguments: [String: Value]?) async -> CallTool.Result {
        return .init(
            content: [
                .text(
                    text: """
                    {"status":"ok","server":"binnacle","version":"0.1.0"}
                    """,
                    annotations: nil,
                    _meta: nil
                )
            ],
            isError: false
        )
    }
}
