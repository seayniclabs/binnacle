import MCP

/// Binnacle server metadata and tool registry
public enum Binnacle {
    public static let serverName = "binnacle"
    public static let serverVersion = "0.3.1"

    /// All tool definitions for the Binnacle MCP server.
    /// Separated from the executable so they can be tested independently.
    public static let tools: [Tool] = [PingTool.tool]
        + CalendarToolDefs.allTools
        + ReminderToolDefs.allTools
        + ShortcutToolDefs.allTools
        + SystemInfoToolDefs.allTools
        + NotificationToolDefs.allTools
        + ClipboardToolDefs.allTools
        + SpotlightToolDefs.allTools
        + FinderToolDefs.allTools
        + AppToolDefs.allTools
        + DisplayToolDefs.allTools
        + AppearanceToolDefs.allTools
        + NetworkToolDefs.allTools
        + PowerToolDefs.allTools
        + StorageToolDefs.allTools

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

// MARK: - System Info Tool Definitions

public enum SystemInfoToolDefs {

    public static let getInfo = Tool(
        name: "system_get_info",
        description: "Get macOS system info: CPU usage, memory, disk space, battery level/charging, uptime",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static let getDisplayInfo = Tool(
        name: "system_get_display_info",
        description: "Get display info: resolution, connected displays",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static let getVolume = Tool(
        name: "system_get_volume",
        description: "Get current audio output volume level and mute state",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [getInfo, getDisplayInfo, getVolume]
    }
}

// MARK: - Notification Tool Definitions

public enum NotificationToolDefs {

    public static let send = Tool(
        name: "notification_send",
        description: "Send a macOS notification with title, body, and optional subtitle",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "title": .object(["type": "string", "description": "Notification title"]),
                "body": .object(["type": "string", "description": "Notification body text"]),
                "subtitle": .object(["type": "string", "description": "Notification subtitle (optional)"])
            ]),
            "required": .array(["title", "body"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: false
        )
    )

    public static var allTools: [Tool] {
        [send]
    }
}

// MARK: - Clipboard Tool Definitions

public enum ClipboardToolDefs {

    public static let read = Tool(
        name: "clipboard_read",
        description: "Read the current text content from the macOS clipboard",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static let write = Tool(
        name: "clipboard_write",
        description: "Write text to the macOS clipboard",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "text": .object(["type": "string", "description": "Text to write to clipboard"])
            ]),
            "required": .array(["text"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
    )

    public static var allTools: [Tool] {
        [read, write]
    }
}

// MARK: - Spotlight Tool Definitions

public enum SpotlightToolDefs {

    public static let search = Tool(
        name: "spotlight_search",
        description: "Search files using Spotlight by name, content, kind, or date modified",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "query": .object(["type": "string", "description": "Search query text"]),
                "kind": .object(["type": "string", "description": "File kind filter: document, image, audio, video, pdf, folder, application, email, presentation, spreadsheet (optional)"]),
                "directory": .object(["type": "string", "description": "Limit search to this directory path (optional)"]),
                "limit": .object(["type": "integer", "description": "Maximum results to return (default: 20, max: 100)"])
            ]),
            "required": .array(["query"])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [search]
    }
}

// MARK: - Finder Tool Definitions

public enum FinderToolDefs {

    public static let tags = Tool(
        name: "finder_tags",
        description: "List, get, or set Finder tags on files. Use action: list (all tags on a file), set (replace tags), or add (append tag)",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "path": .object(["type": "string", "description": "File or directory path"]),
                "action": .object(["type": "string", "description": "Action: list, set, or add"]),
                "tags": .object(["type": "array", "items": .object(["type": "string"]), "description": "Tags to set or add (required for set/add actions)"])
            ]),
            "required": .array(["path", "action"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: false
        )
    )

    public static let info = Tool(
        name: "finder_info",
        description: "Get extended file info: size, dates, type, Finder comments, and Spotlight metadata",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "path": .object(["type": "string", "description": "File or directory path"])
            ]),
            "required": .array(["path"])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static let getDownloads = Tool(
        name: "get_downloads",
        description: "List recent files in ~/Downloads with name, size, and date",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "limit": .object(["type": "integer", "description": "Maximum files to return (default: 20)"]),
                "sort_by": .object(["type": "string", "description": "Sort by: date (default), size, or name"])
            ])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [tags, info, getDownloads]
    }
}

// MARK: - App Tool Definitions

public enum AppToolDefs {

    public static let openApp = Tool(
        name: "open_app",
        description: "Launch or activate a macOS application by name",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "name": .object(["type": "string", "description": "Application name (e.g. Safari, Finder, Terminal)"])
            ]),
            "required": .array(["name"])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: true
        )
    )

    public static let getRunningApps = Tool(
        name: "get_running_apps",
        description: "List currently running applications with process IDs",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [openApp, getRunningApps]
    }
}

// MARK: - Display Tool Definitions

public enum DisplayToolDefs {

    public static let getSettings = Tool(
        name: "get_display_settings",
        description: "Get current display configuration: resolution, scaling factor, color profile, and arrangement for all connected displays",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [getSettings]
    }
}

// MARK: - Appearance Tool Definitions

public enum AppearanceToolDefs {

    public static let toggleDarkMode = Tool(
        name: "toggle_dark_mode",
        description: "Toggle between light and dark appearance, or set a specific mode",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "mode": .object(["type": "string", "description": "Set specific mode: dark, light, or toggle (default: toggle)"])
            ])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
    )

    public static let toggleDnd = Tool(
        name: "toggle_dnd",
        description: "Toggle Do Not Disturb (Focus) mode on or off",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "enabled": .object(["type": "boolean", "description": "Set DND on (true) or off (false). Omit to toggle."])
            ])
        ]),
        annotations: .init(
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
    )

    public static var allTools: [Tool] {
        [toggleDarkMode, toggleDnd]
    }
}

// MARK: - Network Tool Definitions

public enum NetworkToolDefs {

    public static let getWifiInfo = Tool(
        name: "get_wifi_info",
        description: "Get current WiFi network name, signal strength (RSSI), IP address, and interface details",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [getWifiInfo]
    }
}

// MARK: - Power Tool Definitions

public enum PowerToolDefs {

    public static let getBatteryStatus = Tool(
        name: "get_battery_status",
        description: "Get battery level, charging state, power source, cycle count, and health",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [getBatteryStatus]
    }
}

// MARK: - Storage Tool Definitions

public enum StorageToolDefs {

    public static let getSummary = Tool(
        name: "get_storage_summary",
        description: "Get disk usage breakdown: total, used, free space, and per-volume details",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:])
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    public static var allTools: [Tool] {
        [getSummary]
    }
}
