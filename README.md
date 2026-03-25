# Binnacle

macOS system control MCP server. Gives AI tools native access to Calendar, Reminders, Shortcuts, system info, notifications, and clipboard — all through the [Model Context Protocol](https://modelcontextprotocol.io).

Built with Swift 6 and the [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk). Requires macOS 14+.

## Install

```bash
brew tap seayniclabs/tap
brew install binnacle
```

Or build from source:

```bash
git clone https://github.com/seayniclabs/binnacle.git
cd binnacle
swift build -c release
```

## Setup

Run the setup command to grant Calendar and Reminders access:

```bash
binnacle setup
```

Then add to Claude Code:

```bash
claude mcp add binnacle -- binnacle serve
```

## Tools (19)

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

### Utility (1)

| Tool | Description |
|------|-------------|
| `ping` | Health check — returns server version and status |

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16.3+ (build only)
- Calendar and Reminders access granted via setup command

## License

MIT
