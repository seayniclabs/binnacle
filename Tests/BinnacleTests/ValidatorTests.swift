import Foundation
import Testing

@testable import BinnacleCore

@Suite("Shortcut Name Validation")
struct ShortcutNameValidationTests {

    @Test("Valid shortcut name accepted")
    func validNameAccepted() throws {
        #expect(throws: Never.self) {
            try Validators.validateShortcutName("My Cool Shortcut")
        }
    }

    @Test("Name with semicolon rejected")
    func semicolonRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateShortcutName("run; rm -rf /")
        }
    }

    @Test("Name with pipe rejected")
    func pipeRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateShortcutName("name | cat /etc/passwd")
        }
    }

    @Test("Name with backtick rejected")
    func backtickRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateShortcutName("run `whoami`")
        }
    }

    @Test("Name with ampersand rejected")
    func ampersandRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateShortcutName("run & echo pwned")
        }
    }

    @Test("Name with dollar sign rejected")
    func dollarSignRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateShortcutName("run $HOME")
        }
    }

    @Test("Empty name rejected")
    func emptyNameRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateShortcutName("")
        }
    }
}

@Suite("ISO8601 Date Parsing")
struct ISO8601ParsingTests {

    @Test("ISO8601 full datetime parses correctly")
    func fullDatetimeParses() throws {
        let date = try Validators.parseISO8601("2026-03-20T14:30:00Z")
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 20)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }

    @Test("ISO8601 with fractional seconds parses")
    func fractionalSecondsParses() throws {
        let date = try Validators.parseISO8601("2026-03-20T14:30:00.500Z")
        #expect(date.timeIntervalSince1970 > 0)
    }

    @Test("ISO8601 date-only parses")
    func dateOnlyParses() throws {
        let date = try Validators.parseISO8601("2026-03-20")
        #expect(date.timeIntervalSince1970 > 0)
    }

    @Test("Invalid date rejected")
    func invalidDateRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.parseISO8601("not-a-date")
        }
    }

    @Test("Empty date rejected")
    func emptyDateRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.parseISO8601("")
        }
    }
}

@Suite("Event ID Validation")
struct EventIdValidationTests {

    @Test("Valid event ID accepted")
    func validIdAccepted() throws {
        #expect(throws: Never.self) {
            try Validators.validateEventId("ABC123-DEF456")
        }
    }

    @Test("Empty event ID rejected")
    func emptyIdRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateEventId("")
        }
    }

    @Test("Whitespace-only ID rejected")
    func whitespaceIdRejected() {
        #expect(throws: ValidationError.self) {
            try Validators.validateEventId("   ")
        }
    }
}
