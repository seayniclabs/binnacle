## [v0.3.1] - 2026-04-01

### Fixed
- Crash (SIGSEGV) when launched as a subprocess with stdout connected to a pipe (e.g., via mcp-proxy). Root cause: Swift lazy global initialization is unsafe on macOS 26 / Swift 6.2.4 when the process stdout file descriptor is a non-TTY pipe. Removed the module-level `allTools` global entirely; tools are now built as a local variable inside `startServer()`, bypassing the Swift runtime's `swift_once` lazy init path.

### Changed
- Bumped server version from `0.2.0` to `0.3.1`.
- Added `@_optimize(none)` to `startServer()` as secondary protection against optimizer-driven lazy init reordering.

## [v0.2.0] - 2026-03-27

### Added
- 12 new macOS tools across Spotlight, Finder, Apps, Display, Appearance, Network, Power, and Storage (31 total tools).
- Expanded tool definitions and test coverage for the Phase 2 capabilities.

### Changed
- Updated README tool catalog to match current server capabilities.
- Bumped server version from `0.1.0` to `0.2.0`.

### Fixed
- Corrected release/documentation drift where README listed only 19 tools.

## [v0.1.0] - 2026-03-25

### Added
- Initial public packaging baseline with Calendar, Reminders, Shortcuts, system info, notifications, and clipboard tools.
