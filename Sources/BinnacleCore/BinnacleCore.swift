import MCP

/// Binnacle server metadata and tool registry
public enum Binnacle {
    public static let serverName = "binnacle"
    public static let serverVersion = "0.1.0"

    /// All tool definitions for the Binnacle MCP server.
    /// Separated from the executable so they can be tested independently.
    public static let tools: [Tool] = [PingTool.tool]
        + CalendarToolDefs.allTools
        + ReminderToolDefs.allTools
        + ShortcutToolDefs.allTools

    /// Expected tool names in registration order
    public static let toolNames: [String] = tools.map(\.name)

    /// The ping response text, including the current version
    public static var pingResponse: String {
        """
        {"status":"ok","server":"binnacle","version":"\(serverVersion)"}
        """
    }
}

// MARK: - Ping Tool Definition

public enum PingTool {
    public static let tool = Tool(
        name: "ping",
        description: "Health check — returns server version and status",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )
}

// MARK: - Calendar Tool Definitions

public enum CalendarToolDefs {

    public static let calendarList = Tool(
        name: "calendar_list",
        description: "List all calendars available on this Mac",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static let calendarToday = Tool(
        name: "calendar_today",
        description: "List today's calendar events",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static let calendarRange = Tool(
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

    public static let calendarCreate = Tool(
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

    public static let calendarUpdate = Tool(
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

    public static let calendarDelete = Tool(
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

    public static var allTools: [Tool] {
        [calendarList, calendarToday, calendarRange, calendarCreate, calendarUpdate, calendarDelete]
    }
}

// MARK: - Reminder Tool Definitions

public enum ReminderToolDefs {

    public static let remindersList = Tool(
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

    public static let remindersCreate = Tool(
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

    public static let remindersComplete = Tool(
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

    public static var allTools: [Tool] {
        [remindersList, remindersCreate, remindersComplete]
    }
}

// MARK: - Shortcut Tool Definitions

public enum ShortcutToolDefs {

    public static let shortcutsList = Tool(
        name: "shortcuts_list",
        description: "List all Shortcuts available on this Mac",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static let shortcutsRun = Tool(
        name: "shortcuts_run",
        description: "Run a Shortcut by name with optional text input",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "name": .object(["type": "string", "description": "Shortcut name"]),
                "input": .object(["type": "string", "description": "Text input to pass to the Shortcut (optional)"])
            ]),
            "required": .array(["name"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: true
        )
    )

    public static let shortcutsFolders = Tool(
        name: "shortcuts_folders",
        description: "List Shortcut folders",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [shortcutsList, shortcutsRun, shortcutsFolders]
    }
}
