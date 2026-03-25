import Foundation
import Testing
import MCP
@testable import BinnacleCore

@Suite("Tool Registration")
struct ToolRegistrationTests {

    @Test("All tools are registered")
    func allToolsRegistered() {
        let expectedNames: Set<String> = [
            "ping",
            "calendar_list", "calendar_today", "calendar_range",
            "calendar_create", "calendar_update", "calendar_delete",
            "reminders_list", "reminders_create", "reminders_complete",
            "shortcuts_list", "shortcuts_run", "shortcuts_folders",
            "system_get_info", "system_get_display_info", "system_get_volume",
            "notification_send",
            "clipboard_read", "clipboard_write"
        ]

        let actualNames = Set(Binnacle.toolNames)
        #expect(actualNames == expectedNames)
    }

    @Test("Tool count matches spec (19 tools)")
    func toolCountMatches() {
        #expect(Binnacle.tools.count == 19)
    }

    @Test("Ping response contains version")
    func pingResponseContainsVersion() {
        let response = Binnacle.pingResponse
        #expect(response.contains(Binnacle.serverVersion))
        #expect(response.contains("binnacle"))
    }

    @Test("Server metadata is correct")
    func serverMetadata() {
        #expect(Binnacle.serverName == "binnacle")
        #expect(Binnacle.serverVersion == "0.1.0")
    }
}

@Suite("Calendar Tool Definitions")
struct CalendarToolDefTests {

    @Test("calendar_create requires title, start, end")
    func createRequiredParams() {
        let tool = CalendarToolDefs.calendarCreate
        // Check the inputSchema contains required fields
        if case .object(let schema) = tool.inputSchema,
           case .array(let required)? = schema["required"] {
            let requiredNames = required.compactMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }
            #expect(requiredNames.contains("title"))
            #expect(requiredNames.contains("start"))
            #expect(requiredNames.contains("end"))
        } else {
            Issue.record("calendar_create schema missing required array")
        }
    }

    @Test("calendar_delete is marked destructive")
    func deleteIsDestructive() {
        let tool = CalendarToolDefs.calendarDelete
        #expect(tool.annotations.destructiveHint == true)
    }

    @Test("calendar_today is read-only")
    func todayIsReadOnly() {
        let tool = CalendarToolDefs.calendarToday
        #expect(tool.annotations.readOnlyHint == true)
    }

    @Test("calendar_list is read-only")
    func listIsReadOnly() {
        let tool = CalendarToolDefs.calendarList
        #expect(tool.annotations.readOnlyHint == true)
    }
}

@Suite("Reminder Tool Definitions")
struct ReminderToolDefTests {

    @Test("reminders_create requires title")
    func createRequiresTitle() {
        let tool = ReminderToolDefs.remindersCreate
        if case .object(let schema) = tool.inputSchema,
           case .array(let required)? = schema["required"] {
            let requiredNames = required.compactMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }
            #expect(requiredNames.contains("title"))
        } else {
            Issue.record("reminders_create schema missing required array")
        }
    }

    @Test("reminders_complete is idempotent")
    func completeIsIdempotent() {
        let tool = ReminderToolDefs.remindersComplete
        #expect(tool.annotations.idempotentHint == true)
    }
}

@Suite("Shortcut Tool Definitions")
struct ShortcutToolDefTests {

    @Test("shortcuts_run requires name")
    func runRequiresName() {
        let tool = ShortcutToolDefs.shortcutsRun
        if case .object(let schema) = tool.inputSchema,
           case .array(let required)? = schema["required"] {
            let requiredNames = required.compactMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }
            #expect(requiredNames.contains("name"))
        } else {
            Issue.record("shortcuts_run schema missing required array")
        }
    }

    @Test("shortcuts_run is marked openWorld")
    func runIsOpenWorld() {
        let tool = ShortcutToolDefs.shortcutsRun
        #expect(tool.annotations.openWorldHint == true)
    }

    @Test("shortcuts_list is read-only")
    func listIsReadOnly() {
        let tool = ShortcutToolDefs.shortcutsList
        #expect(tool.annotations.readOnlyHint == true)
    }
}
