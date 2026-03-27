import Foundation
import Testing
import MCP
@testable import BinnacleCore

@Suite("Tool Registration")
struct ToolRegistrationTests {

    @Test("All tools are registered")
    func allToolsRegistered() {
        let expectedNames: Set<String> = [
            // Phase 1
            "ping",
            "calendar_list", "calendar_today", "calendar_range",
            "calendar_create", "calendar_update", "calendar_delete",
            "reminders_list", "reminders_create", "reminders_complete",
            "shortcuts_list", "shortcuts_run", "shortcuts_folders",
            "system_get_info", "system_get_display_info", "system_get_volume",
            "notification_send",
            "clipboard_read", "clipboard_write",
            // Phase 2
            "spotlight_search",
            "finder_tags", "finder_info", "get_downloads",
            "open_app", "get_running_apps",
            "get_display_settings",
            "toggle_dark_mode", "toggle_dnd",
            "get_wifi_info",
            "get_battery_status",
            "get_storage_summary"
        ]

        let actualNames = Set(Binnacle.toolNames)
        #expect(actualNames == expectedNames)
    }

    @Test("Tool count matches spec (31 tools)")
    func toolCountMatches() {
        #expect(Binnacle.tools.count == 31)
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
        #expect(Binnacle.serverVersion == "0.2.0")
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

// MARK: - Phase 2 Tool Definition Tests

@Suite("Spotlight Tool Definitions")
struct SpotlightToolDefTests {

    @Test("spotlight_search requires query")
    func searchRequiresQuery() {
        let tool = SpotlightToolDefs.search
        if case .object(let schema) = tool.inputSchema,
           case .array(let required)? = schema["required"] {
            let requiredNames = required.compactMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }
            #expect(requiredNames.contains("query"))
        } else {
            Issue.record("spotlight_search schema missing required array")
        }
    }

    @Test("spotlight_search is read-only")
    func searchIsReadOnly() {
        let tool = SpotlightToolDefs.search
        #expect(tool.annotations.readOnlyHint == true)
    }
}

@Suite("Finder Tool Definitions")
struct FinderToolDefTests {

    @Test("finder_tags requires path and action")
    func tagsRequiresParams() {
        let tool = FinderToolDefs.tags
        if case .object(let schema) = tool.inputSchema,
           case .array(let required)? = schema["required"] {
            let requiredNames = required.compactMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }
            #expect(requiredNames.contains("path"))
            #expect(requiredNames.contains("action"))
        } else {
            Issue.record("finder_tags schema missing required array")
        }
    }

    @Test("finder_info requires path")
    func infoRequiresPath() {
        let tool = FinderToolDefs.info
        if case .object(let schema) = tool.inputSchema,
           case .array(let required)? = schema["required"] {
            let requiredNames = required.compactMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }
            #expect(requiredNames.contains("path"))
        } else {
            Issue.record("finder_info schema missing required array")
        }
    }

    @Test("finder_info is read-only")
    func infoIsReadOnly() {
        let tool = FinderToolDefs.info
        #expect(tool.annotations.readOnlyHint == true)
    }

    @Test("get_downloads is read-only")
    func downloadsIsReadOnly() {
        let tool = FinderToolDefs.getDownloads
        #expect(tool.annotations.readOnlyHint == true)
    }
}

@Suite("App Tool Definitions")
struct AppToolDefTests {

    @Test("open_app requires name")
    func openAppRequiresName() {
        let tool = AppToolDefs.openApp
        if case .object(let schema) = tool.inputSchema,
           case .array(let required)? = schema["required"] {
            let requiredNames = required.compactMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }
            #expect(requiredNames.contains("name"))
        } else {
            Issue.record("open_app schema missing required array")
        }
    }

    @Test("open_app is idempotent and openWorld")
    func openAppAnnotations() {
        let tool = AppToolDefs.openApp
        #expect(tool.annotations.idempotentHint == true)
        #expect(tool.annotations.openWorldHint == true)
    }

    @Test("get_running_apps is read-only")
    func runningAppsIsReadOnly() {
        let tool = AppToolDefs.getRunningApps
        #expect(tool.annotations.readOnlyHint == true)
    }
}

@Suite("Display Tool Definitions")
struct DisplayToolDefTests {

    @Test("get_display_settings is read-only")
    func getSettingsIsReadOnly() {
        let tool = DisplayToolDefs.getSettings
        #expect(tool.annotations.readOnlyHint == true)
    }
}

@Suite("Appearance Tool Definitions")
struct AppearanceToolDefTests {

    @Test("toggle_dark_mode is idempotent")
    func darkModeIsIdempotent() {
        let tool = AppearanceToolDefs.toggleDarkMode
        #expect(tool.annotations.idempotentHint == true)
    }

    @Test("toggle_dnd is idempotent")
    func dndIsIdempotent() {
        let tool = AppearanceToolDefs.toggleDnd
        #expect(tool.annotations.idempotentHint == true)
    }
}

@Suite("Network Tool Definitions")
struct NetworkToolDefTests {

    @Test("get_wifi_info is read-only")
    func wifiInfoIsReadOnly() {
        let tool = NetworkToolDefs.getWifiInfo
        #expect(tool.annotations.readOnlyHint == true)
    }
}

@Suite("Power Tool Definitions")
struct PowerToolDefTests {

    @Test("get_battery_status is read-only")
    func batteryStatusIsReadOnly() {
        let tool = PowerToolDefs.getBatteryStatus
        #expect(tool.annotations.readOnlyHint == true)
    }
}

@Suite("Storage Tool Definitions")
struct StorageToolDefTests {

    @Test("get_storage_summary is read-only")
    func storageSummaryIsReadOnly() {
        let tool = StorageToolDefs.getSummary
        #expect(tool.annotations.readOnlyHint == true)
    }
}
