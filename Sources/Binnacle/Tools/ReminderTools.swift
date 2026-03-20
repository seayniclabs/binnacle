import Foundation
import MCP

/// Reminder tools — delegates all EventKit ops to EventStoreManager actor
enum ReminderTools {

    // MARK: - Tool Definitions

    static let remindersList = Tool(
        name: "reminders_list",
        description: "List reminders, optionally filtered by list name",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "list_name": .object(["type": "string", "description": "Filter by reminder list name (optional)"]),
                "show_completed": .object(["type": "boolean", "description": "Include completed reminders (default: false)"])
            ])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    static let remindersCreate = Tool(
        name: "reminders_create",
        description: "Create a new reminder",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "title": .object(["type": "string", "description": "Reminder title"]),
                "due_date": .object(["type": "string", "description": "Due date ISO8601 (optional)"]),
                "priority": .object(["type": "integer", "description": "Priority 0-9, 0=none (optional)"]),
                "list_name": .object(["type": "string", "description": "Reminder list name (optional)"])
            ]),
            "required": .array(["title"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: false
        )
    )

    static let remindersComplete = Tool(
        name: "reminders_complete",
        description: "Mark a reminder as complete",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "reminder_id": .object(["type": "string", "description": "Reminder identifier"])
            ]),
            "required": .array(["reminder_id"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
    )

    static var allTools: [Tool] {
        [remindersList, remindersCreate, remindersComplete]
    }

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
