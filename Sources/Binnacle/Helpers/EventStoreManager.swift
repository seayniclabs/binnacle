import EventKit
import Foundation

/// Shared EventKit access manager — all EKEventStore operations stay inside this actor.
/// Returns JSON strings to avoid Sendable issues with [String: Any] and EK types.
actor EventStoreManager {
    static let shared = EventStoreManager()

    private let store = EKEventStore()

    private var eventsAuthorized = false
    private var remindersAuthorized = false

    private init() {}

    // MARK: - Authorization

    func requestEventAccess() async throws {
        guard !eventsAuthorized else { return }
        let granted = try await store.requestFullAccessToEvents()
        guard granted else {
            throw BinnacleError.permissionDenied("Calendar access denied")
        }
        eventsAuthorized = true
    }

    func requestReminderAccess() async throws {
        guard !remindersAuthorized else { return }
        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            throw BinnacleError.permissionDenied("Reminders access denied")
        }
        remindersAuthorized = true
    }

    // MARK: - Calendar Operations (return JSON strings)

    func listCalendarsJSON() -> String {
        let calendars = store.calendars(for: .event)
        let results: [[String: String]] = calendars.map { cal in
            [
                "id": cal.calendarIdentifier,
                "title": cal.title,
                "type": calendarTypeString(cal.type),
                "source": cal.source?.title ?? "Unknown"
            ]
        }
        return toJSON(results)
    }

    func eventsForTodayJSON() -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return fetchEventsJSON(start: start, end: end)
    }

    func eventsInRangeJSON(start: Date, end: Date) -> String {
        return fetchEventsJSON(start: start, end: end)
    }

    func createEvent(
        title: String,
        start: Date,
        end: Date,
        calendarId: String?,
        location: String?,
        notes: String?
    ) throws -> String {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end

        if let calId = calendarId, let calendar = store.calendar(withIdentifier: calId) {
            event.calendar = calendar
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        if let location = location { event.location = location }
        if let notes = notes { event.notes = notes }

        try store.save(event, span: .thisEvent)
        return event.eventIdentifier ?? "unknown"
    }

    func updateEvent(
        eventId: String,
        title: String?,
        start: Date?,
        end: Date?,
        location: String?,
        notes: String?
    ) throws {
        guard let event = store.event(withIdentifier: eventId) else {
            throw BinnacleError.notFound("Event not found: \(eventId)")
        }

        if let title = title { event.title = title }
        if let start = start { event.startDate = start }
        if let end = end { event.endDate = end }
        if let location = location { event.location = location }
        if let notes = notes { event.notes = notes }

        try store.save(event, span: .thisEvent)
    }

    func deleteEvent(eventId: String) throws {
        guard let event = store.event(withIdentifier: eventId) else {
            throw BinnacleError.notFound("Event not found: \(eventId)")
        }
        try store.remove(event, span: .thisEvent)
    }

    // MARK: - Reminder Operations (return JSON strings)

    func fetchRemindersJSON(listName: String?, showCompleted: Bool) async throws -> String {
        var calendars: [EKCalendar]? = nil
        if let listName = listName {
            let allReminderCalendars = store.calendars(for: .reminder)
            let matched = allReminderCalendars.filter {
                $0.title.lowercased() == listName.lowercased()
            }
            if matched.isEmpty {
                throw BinnacleError.notFound("Reminder list not found: \(listName)")
            }
            calendars = matched
        }

        let predicate: NSPredicate
        if showCompleted {
            predicate = store.predicateForReminders(in: calendars)
        } else {
            predicate = store.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: calendars
            )
        }

        // fetchReminders is callback-based; serialize to JSON string inside the callback
        // to avoid sending non-Sendable EKReminder across isolation boundaries
        let jsonString: String = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                let reminders = result ?? []
                let results: [[String: String]] = reminders.map { reminder in
                    var dict: [String: String] = [
                        "id": reminder.calendarItemIdentifier,
                        "title": reminder.title ?? "",
                        "completed": reminder.isCompleted ? "true" : "false",
                        "list": reminder.calendar?.title ?? "",
                        "priority": "\(reminder.priority)"
                    ]
                    if let dueDate = reminder.dueDateComponents,
                       let date = Calendar.current.date(from: dueDate) {
                        dict["due_date"] = Validators.formatISO8601(date)
                    }
                    return dict
                }
                let json: String
                if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    json = str
                } else {
                    json = "[]"
                }
                continuation.resume(returning: json)
            }
        }

        return jsonString
    }

    func createReminder(
        title: String,
        listName: String?,
        dueDate: Date?,
        priority: Int?
    ) throws -> String {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title

        if let listName = listName {
            let calendars = store.calendars(for: .reminder)
            guard let cal = calendars.first(where: { $0.title.lowercased() == listName.lowercased() }) else {
                throw BinnacleError.notFound("Reminder list not found: \(listName)")
            }
            reminder.calendar = cal
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        if let dueDate = dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: dueDate
            )
        }

        if let priority = priority {
            reminder.priority = max(0, min(9, priority))
        }

        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    func completeReminder(reminderId: String) throws {
        guard let item = store.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw BinnacleError.notFound("Reminder not found: \(reminderId)")
        }
        item.isCompleted = true
        try store.save(item, commit: true)
    }

    // MARK: - Private Helpers

    private func fetchEventsJSON(start: Date, end: Date) -> String {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        let results: [[String: String]] = events.map { event in
            var dict: [String: String] = [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start": Validators.formatISO8601(event.startDate),
                "end": Validators.formatISO8601(event.endDate),
                "all_day": event.isAllDay ? "true" : "false",
                "calendar": event.calendar?.title ?? ""
            ]
            if let location = event.location, !location.isEmpty {
                dict["location"] = location
            }
            if let notes = event.notes, !notes.isEmpty {
                dict["notes"] = notes
            }
            return dict
        }

        return toJSON(results)
    }

    private func toJSON(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private func calendarTypeString(_ type: EKCalendarType) -> String {
        switch type {
        case .local: return "local"
        case .calDAV: return "calDAV"
        case .exchange: return "exchange"
        case .subscription: return "subscription"
        case .birthday: return "birthday"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Binnacle Errors

enum BinnacleError: Error, CustomStringConvertible {
    case permissionDenied(String)
    case notFound(String)
    case invalidInput(String)
    case shortcutFailed(String)

    var description: String {
        switch self {
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .notFound(let msg): return "Not found: \(msg)"
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .shortcutFailed(let msg): return "Shortcut failed: \(msg)"
        }
    }
}
