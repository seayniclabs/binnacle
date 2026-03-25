import Foundation
import MCP
import BinnacleCore

#if canImport(AppKit)
import AppKit
#endif

/// Clipboard tools -- read and write the macOS pasteboard
enum ClipboardTools {

    static var allTools: [Tool] { ClipboardToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        switch name {
        case "clipboard_read":
            return handleRead()
        case "clipboard_write":
            return handleWrite(arguments: arguments)
        default:
            return errorResult("Unknown clipboard tool: \(name)")
        }
    }

    // MARK: - Read

    private static func handleRead() -> CallTool.Result {
        let pasteboard = NSPasteboard.general
        guard let content = pasteboard.string(forType: .string) else {
            return textResult("{\"content\":null,\"has_text\":false}")
        }
        // Serialize via JSONSerialization to properly escape the content
        let result: [String: Any] = [
            "content": content,
            "has_text": true,
            "length": content.count
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return textResult(json)
        }
        return textResult("{\"content\":null,\"has_text\":false,\"error\":\"serialization_failed\"}")
    }

    // MARK: - Write

    private static func handleWrite(arguments: [String: Value]?) -> CallTool.Result {
        guard let text = arguments?["text"]?.stringValue else {
            return errorResult("Missing required parameter: text")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        return textResult("{\"written\":true,\"length\":\(text.count)}")
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
