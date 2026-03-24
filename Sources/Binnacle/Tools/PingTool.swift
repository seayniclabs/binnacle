import MCP
import BinnacleCore

/// Health check handler
enum PingHandler {
    static let tool = BinnacleCore.PingTool.tool

    static func handle(arguments: [String: Value]?) async -> CallTool.Result {
        return .init(
            content: [.text(text: Binnacle.pingResponse, annotations: nil, _meta: nil)],
            isError: false
        )
    }
}
