import Foundation
import MCP
import BinnacleCore

/// Calendar tools -- delegates all EventKit ops to EventStoreManager actor
enum CalendarTools {

    static var allTools: [Tool] { CalendarToolDefs.allTools }

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
