import Foundation
import MCP
import BinnacleCore

/// Reminder tools -- delegates all EventKit ops to EventStoreManager actor
enum ReminderTools {

    static var allTools: [Tool] { ReminderToolDefs.allTools }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "reminders_list":
                return try await handleList(arguments: arguments)
            case "reminders_create":
                return try await handleCreate(arguments: arguments)
            case "reminders_complete":
                return try await handleComplete(arguments: arguments)
            default:
                return errorResult("Unknown reminder tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - List

    private static func handleList(arguments: [String: Value]?) async throws -> CallTool.Result {
        let showCompleted = arguments?["show_completed"]?.boolValue ?? false
        let listName = arguments?["list_name"]?.stringValue

        let manager = EventStoreManager.shared
        try await manager.requestReminderAccess()
        let json = try await manager.fetchRemindersJSON(listName: listName, showCompleted: showCompleted)

        return textResult(json)
    }

    // MARK: - Create

    private static func handleCreate(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let title = arguments?["title"]?.stringValue else {
            return errorResult("Missing required parameter: title")
        }

        var dueDate: Date? = nil
        if let dueDateStr = arguments?["due_date"]?.stringValue {
            dueDate = try Validators.parseISO8601(dueDateStr)
        }

        let manager = EventStoreManager.shared
        try await manager.requestReminderAccess()
        let reminderId = try await manager.createReminder(
            title: title,
            listName: arguments?["list_name"]?.stringValue,
            dueDate: dueDate,
            priority: arguments?["priority"]?.intValue
        )

        return textResult("""
            {"created":true,"reminder_id":"\(reminderId)","title":"\(title)"}
            """)
    }

    // MARK: - Complete

    private static func handleComplete(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let reminderId = arguments?["reminder_id"]?.stringValue else {
            return errorResult("Missing required parameter: reminder_id")
        }
        try Validators.validateEventId(reminderId)

        let manager = EventStoreManager.shared
        try await manager.requestReminderAccess()
        try await manager.completeReminder(reminderId: reminderId)

        return textResult("""
            {"completed":true,"reminder_id":"\(reminderId)"}
            """)
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
