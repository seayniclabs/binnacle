import Foundation

// MARK: - Validation Errors

enum ValidationError: Error, CustomStringConvertible {
    case invalidShortcutName(String)
    case invalidDateFormat(String)
    case invalidEventId(String)

    var description: String {
        switch self {
        case .invalidShortcutName(let reason):
            return "Invalid shortcut name: \(reason)"
        case .invalidDateFormat(let value):
            return "Invalid ISO8601 date format: \(value)"
        case .invalidEventId(let value):
            return "Invalid event ID: \(value)"
        }
    }
}

// MARK: - Validators

enum Validators {
    /// Shell metacharacters that must not appear in shortcut names
    private static let forbiddenCharacters: Set<Character> = [
        ";", "&", "|", "`", "$", "\\", "(", ")", "{", "}", "<", ">", "\"", "'", "\n", "\r"
    ]

    /// Validate a shortcut name contains no shell metacharacters
    static func validateShortcutName(_ name: String) throws {
        guard !name.isEmpty else {
            throw ValidationError.invalidShortcutName("name cannot be empty")
        }

        for char in name {
            if forbiddenCharacters.contains(char) {
                throw ValidationError.invalidShortcutName(
                    "contains forbidden character: \(char)"
                )
            }
        }
    }

    /// Parse an ISO8601 date string into a Date
    static func parseISO8601(_ string: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            return date
        }

        // Try date-only format (YYYY-MM-DD)
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        if let date = dateOnly.date(from: string) {
            return date
        }

        throw ValidationError.invalidDateFormat(string)
    }

    /// Format a Date as ISO8601 string
    static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    /// Validate an event/reminder identifier is non-empty
    static func validateEventId(_ id: String) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidEventId("ID cannot be empty")
        }
    }
}
