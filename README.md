# Binnacle

macOS system control MCP server. Gives AI tools native access to Calendar, Reminders, Shortcuts, system info, notifications, and clipboard — all through the [Model Context Protocol](https://modelcontextprotocol.io).

Built with Swift 6 and the [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk). Requires macOS 14+.

## Install

Purchase from the Seaynic Labs Store, then download from your account:

```bash
open https://store.seayniclabs.com/products/binnacle
# after purchase
open https://store.seayniclabs.com/account/downloads
```

For local development, build from source:

```bash
git clone https://github.com/seayniclabs/binnacle.git
cd binnacle
swift build -c release
```

## Release (Signed + Notarized)

Use the release script to build, sign, package, notarize, and verify:

```bash
export BINNACLE_VERSION=v0.2.0
export APP_SIGN_IDENTITY="Developer ID Application: <Team Name> (<TEAM_ID>)"
export PKG_SIGN_IDENTITY="Developer ID Installer: <Team Name> (<TEAM_ID>)"
export NOTARY_PROFILE="<notarytool-keychain-profile>"

./scripts/release-notarize.sh
```

This produces:

- `dist/binnacle-vX.Y.Z-arm64.pkg` (+ `.sha256`)
- `dist/binnacle-vX.Y.Z-arm64-macos.tar.gz` (+ `.sha256`)

## Setup

Run the setup command to grant Calendar and Reminders access:

```bash
binnacle setup
```

Then add to Claude Code:

```bash
claude mcp add binnacle -- binnacle serve
```

## Tools (31)

### Calendar (6)

| Tool | Description |
|------|-------------|
| `calendar_list` | List all calendars available on this Mac |
| `calendar_today` | List today's calendar events |
| `calendar_range` | List calendar events in a date range (start, end) |
| `calendar_create` | Create a calendar event (title, start, end, calendar_id, location, notes) |
| `calendar_update` | Update an existing calendar event (event_id, title, start, end, location, notes) |
| `calendar_delete` | Delete a calendar event (event_id) |

### Reminders (3)

| Tool | Description |
|------|-------------|
| `reminders_list` | List reminders, optionally filtered by list name |
| `reminders_create` | Create a new reminder (title, due_date, priority, list_name) |
| `reminders_complete` | Mark a reminder as complete (reminder_id) |

### Shortcuts (3)

| Tool | Description |
|------|-------------|
| `shortcuts_list` | List all Shortcuts available on this Mac |
| `shortcuts_run` | Run a Shortcut by name with optional text input |
| `shortcuts_folders` | List Shortcut folders |

### System Info (3)

| Tool | Description |
|------|-------------|
| `system_get_info` | CPU usage, memory, disk space, battery level/charging, uptime |
| `system_get_display_info` | Resolution and connected displays |
| `system_get_volume` | Audio output volume level and mute state |

### Notifications (1)

| Tool | Description |
|------|-------------|
| `notification_send` | Send a macOS notification (title, body, subtitle) |

### Clipboard (2)

| Tool | Description |
|------|-------------|
| `clipboard_read` | Read text from the macOS clipboard |
| `clipboard_write` | Write text to the macOS clipboard |

### Spotlight (1)

| Tool | Description |
|------|-------------|
| `spotlight_search` | Search files by name, content, kind, and date |

### Finder (3)

| Tool | Description |
|------|-------------|
| `finder_tags` | List/get/set Finder tags on files |
| `finder_info` | Extended file info (Spotlight metadata, Finder comments) |
| `get_downloads` | List recent downloads with size/date |

### Apps (2)

| Tool | Description |
|------|-------------|
| `open_app` | Launch or activate an app by name |
| `get_running_apps` | List running applications |

### Display (1)

| Tool | Description |
|------|-------------|
| `get_display_settings` | Current display configuration and arrangement |

### Appearance (2)

| Tool | Description |
|------|-------------|
| `toggle_dark_mode` | Toggle light/dark appearance |
| `toggle_dnd` | Toggle Do Not Disturb / Focus mode |

### Network (1)

| Tool | Description |
|------|-------------|
| `get_wifi_info` | Current WiFi network, signal, and IP details |

### Power (1)

| Tool | Description |
|------|-------------|
| `get_battery_status` | Battery level, charging state, and health details |

### Storage (1)

| Tool | Description |
|------|-------------|
| `get_storage_summary` | Disk usage breakdown by volume/category |

### Utility (1)

| Tool | Description |
|------|-------------|
| `ping` | Health check — returns server version and status |

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16.3+ (build only)
- Calendar and Reminders access granted via setup command

## License

Proprietary commercial software by Seaynic Labs.
