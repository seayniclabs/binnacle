import Foundation
import MCP

/// Calendar tools — delegates all EventKit ops to EventStoreManager actor
enum CalendarTools {

    // MARK: - Tool Definitions

    static let calendarList = Tool(
        name: "calendar_list",
        description: "List all calendars available on this Mac",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    static let calendarToday = Tool(
        name: "calendar_today",
        description: "List today's calendar events",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    static let calendarRange = Tool(
        name: "calendar_range",
        description: "List calendar events in a date range",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "start": .object(["type": "string", "description": "Start date (ISO8601)"]),
                "end": .object(["type": "string", "description": "End date (ISO8601)"])
            ]),
            "required": .array(["start", "end"])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    static let calendarCreate = Tool(
        name: "calendar_create",
        description: "Create a calendar event",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "title": .object(["type": "string", "description": "Event title"]),
                "start": .object(["type": "string", "description": "Start date (ISO8601)"]),
                "end": .object(["type": "string", "description": "End date (ISO8601)"]),
                "calendar_id": .object(["type": "string", "description": "Calendar identifier (optional)"]),
                "location": .object(["type": "string", "description": "Event location (optional)"]),
                "notes": .object(["type": "string", "description": "Event notes (optional)"])
            ]),
            "required": .array(["title", "start", "end"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: false
        )
    )

    static let calendarUpdate = Tool(
        name: "calendar_update",
        description: "Update an existing calendar event",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "event_id": .object(["type": "string", "description": "Event identifier"]),
                "title": .object(["type": "string", "description": "New title (optional)"]),
                "start": .object(["type": "string", "description": "New start date ISO8601 (optional)"]),
                "end": .object(["type": "string", "description": "New end date ISO8601 (optional)"]),
                "location": .object(["type": "string", "description": "New location (optional)"]),
                "notes": .object(["type": "string", "description": "New notes (optional)"])
            ]),
            "required": .array(["event_id"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
    )

    static let calendarDelete = Tool(
        name: "calendar_delete",
        description: "Delete a calendar event",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "event_id": .object(["type": "string", "description": "Event identifier"])
            ]),
            "required": .array(["event_id"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: true,
            idempotentHint: true,
            openWorldHint: false
        )
    )

    static var allTools: [Tool] {
        [calendarList, calendarToday, calendarRange, calendarCreate, calendarUpdate, calendarDelete]
    }

    // MARK: - Handlers

    static func handle(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            switch name {
            case "calendar_list":
                return try await handleList()
            case "calendar_today":
                return try await handleToday()
            case "calendar_range":
                return try await handleRange(arguments: arguments)
            case "calendar_create":
                return try await handleCreate(arguments: arguments)
            case "calendar_update":
                return try await handleUpdate(arguments: arguments)
            case "calendar_delete":
                return try await handleDelete(arguments: arguments)
            default:
                return errorResult("Unknown calendar tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    // MARK: - List

    private static func handleList() async throws -> CallTool.Result {
        let manager = EventStoreManager.shared
        try await manager.requestEventAccess()
        let json = await manager.listCalendarsJSON()
        return textResult(json)
    }

    // MARK: - Today

    private static func handleToday() async throws -> CallTool.Result {
        let manager = EventStoreManager.shared
        try await manager.requestEventAccess()
        let json = await manager.eventsForTodayJSON()
        return textResult(json)
    }

    // MARK: - Range

    private static func handleRange(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let startStr = arguments?["start"]?.stringValue,
              let endStr = arguments?["end"]?.stringValue else {
            return errorResult("Missing required parameters: start, end")
        }

        let start = try Validators.parseISO8601(startStr)
        let end = try Validators.parseISO8601(endStr)

        let manager = EventStoreManager.shared
        try await manager.requestEventAccess()
        let json = await manager.eventsInRangeJSON(start: start, end: end)
        return textResult(json)
    }

    // MARK: - Create

    private static func handleCreate(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let title = arguments?["title"]?.stringValue,
              let startStr = arguments?["start"]?.stringValue,
              let endStr = arguments?["end"]?.stringValue else {
            return errorResult("Missing required parameters: title, start, end")
        }

        let startDate = try Validators.parseISO8601(startStr)
        let endDate = try Validators.parseISO8601(endStr)

        let manager = EventStoreManager.shared
        try await manager.requestEventAccess()

        let eventId = try await manager.createEvent(
            title: title,
            start: startDate,
            end: endDate,
            calendarId: arguments?["calendar_id"]?.stringValue,
            location: arguments?["location"]?.stringValue,
            notes: arguments?["notes"]?.stringValue
        )

        return textResult("""
            {"created":true,"event_id":"\(eventId)","title":"\(title)"}
            """)
    }

    // MARK: - Update

    private static func handleUpdate(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let eventId = arguments?["event_id"]?.stringValue else {
            return errorResult("Missing required parameter: event_id")
        }
        try Validators.validateEventId(eventId)

        var startDate: Date? = nil
        var endDate: Date? = nil
        if let startStr = arguments?["start"]?.stringValue {
            startDate = try Validators.parseISO8601(startStr)
        }
        if let endStr = arguments?["end"]?.stringValue {
            endDate = try Validators.parseISO8601(endStr)
        }

        let manager = EventStoreManager.shared
        try await manager.requestEventAccess()
        try await manager.updateEvent(
            eventId: eventId,
            title: arguments?["title"]?.stringValue,
            start: startDate,
            end: endDate,
            location: arguments?["location"]?.stringValue,
            notes: arguments?["notes"]?.stringValue
        )

        return textResult("""
            {"updated":true,"event_id":"\(eventId)"}
            """)
    }

    // MARK: - Delete

    private static func handleDelete(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let eventId = arguments?["event_id"]?.stringValue else {
            return errorResult("Missing required parameter: event_id")
        }
        try Validators.validateEventId(eventId)

        let manager = EventStoreManager.shared
        try await manager.requestEventAccess()
        try await manager.deleteEvent(eventId: eventId)

        return textResult("""
            {"deleted":true,"event_id":"\(eventId)"}
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
