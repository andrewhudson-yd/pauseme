import Foundation
import Combine
import FamilyControls
import DeviceActivity
import ManagedSettings

enum PauseScope: String, Codable {
    case websites
    case appsAndWebsites
}

struct PauseRecord: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let completed: Bool
    var feeling: String?
    var reflection: String?

    var minutes: Int { max(0, Int(endedAt.timeIntervalSince(startedAt) / 60)) }
}

/// Each pause owns a named settings store so old callbacks cannot release a new pause.
@MainActor
final class PauseSession: ObservableObject {
    @Published private(set) var endDate: Date?
    @Published private(set) var startedAt: Date?
    @Published private(set) var authorized = false
    @Published private(set) var requestingPermission = false
    @Published private(set) var records: [PauseRecord] = []
    @Published var checkIn: PauseRecord?
    @Published var errorMessage: String?

    private struct SavedSession: Codable {
        let activity: String
        let endDate: Date
        // Optional for compatibility with pauses saved by the original prototype.
        let startedAt: Date?
        // Pauses saved before app shielding used the web filter only.
        let scope: PauseScope?
    }

    private let center = DeviceActivityCenter()
    private let defaults = UserDefaults.standard
    private let stateKey = "pauseme.session.v1"
    private let historyKey = "pauseme.history.v1"
    private var saved: SavedSession?
    var activeScope: PauseScope { saved?.scope ?? .websites }

    init() {
        if let data = defaults.data(forKey: stateKey) {
            saved = try? JSONDecoder().decode(SavedSession.self, from: data)
        }
        if let data = defaults.data(forKey: historyKey) {
            records = (try? JSONDecoder().decode([PauseRecord].self, from: data)) ?? []
        }
        refresh()
    }

    func requestPermission() async {
        requestingPermission = true
        defer { requestingPermission = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
        } catch {
            errorMessage = "Screen Time permission was not granted. \(error.localizedDescription)"
            refresh()
        }
    }

    func refresh(now: Date = Date()) {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if let saved {
            if saved.endDate <= now {
                finish(at: saved.endDate, completed: true)
            } else if !authorized {
                finish(at: now, completed: false)
            } else {
                endDate = saved.endDate
                startedAt = saved.startedAt ?? saved.endDate.addingTimeInterval(-PauseConfiguration.duration)
            }
        } else {
            endDate = nil
            startedAt = nil
        }
        // Also recover interrupted replacements, not just interrupted first starts.
        for activity in center.activities where activity.rawValue.hasPrefix(PauseConfiguration.prefix)
            && activity.rawValue != saved?.activity {
            PauseConfiguration.store(for: activity).clearAllSettings()
            center.stopMonitoring([activity])
        }
    }

    func start(minutes: Int = 30, scope: PauseScope = .websites) {
        refresh()
        guard authorized, saved == nil, [15, 30, 60].contains(minutes) else { return }
        let now = Date()
        begin(endingAt: now.addingTimeInterval(TimeInterval(minutes * 60)), startedAt: now, scope: scope)
    }

    func extend() {
        refresh()
        guard authorized, let saved else { return }
        begin(endingAt: saved.endDate.addingTimeInterval(15 * 60),
              startedAt: saved.startedAt ?? saved.endDate.addingTimeInterval(-PauseConfiguration.duration),
              scope: activeScope)
    }

    private func begin(endingAt end: Date, startedAt start: Date, scope: PauseScope) {
        errorMessage = nil
        let previous = saved
        let now = previous == nil ? start : Date()
        let activity = DeviceActivityName(PauseConfiguration.prefix + UUID().uuidString)
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: now),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        do {
            // A replacement is registered before releasing the previous store.
            try center.startMonitoring(activity, during: schedule)
            let state = SavedSession(activity: activity.rawValue, endDate: end, startedAt: start, scope: scope)
            let data = try JSONEncoder().encode(state)
            let store = PauseConfiguration.store(for: activity)
            store.webContent.blockedByFilter = .all(except: [])
            if scope == .appsAndWebsites {
                store.shield.applicationCategories = .all(except: [])
            }
            defaults.set(data, forKey: stateKey)
            saved = state
            endDate = end
            startedAt = start
            checkIn = nil
            if let previous {
                let old = DeviceActivityName(previous.activity)
                PauseConfiguration.store(for: old).clearAllSettings()
                center.stopMonitoring([old])
            }
        } catch {
            PauseConfiguration.store(for: activity).clearAllSettings()
            center.stopMonitoring([activity])
            errorMessage = previous == nil
                ? "The pause could not start. No new restriction was applied. \(error.localizedDescription)"
                : "The pause could not be extended. Your existing pause is unchanged. \(error.localizedDescription)"
        }
    }

    func release() {
        guard let saved else { return }
        let now = Date()
        finish(at: min(now, saved.endDate), completed: now >= saved.endDate)
    }

    private func finish(at date: Date, completed: Bool) {
        guard let saved else { return }
        let activity = DeviceActivityName(saved.activity)
        PauseConfiguration.store(for: activity).clearAllSettings()
        center.stopMonitoring([activity])
        let record = PauseRecord(id: UUID(), startedAt: saved.startedAt ?? saved.endDate.addingTimeInterval(-PauseConfiguration.duration),
                                 endedAt: date, completed: completed)
        self.saved = nil
        endDate = nil
        startedAt = nil
        defaults.removeObject(forKey: stateKey)
        records.insert(record, at: 0)
        records = Array(records.prefix(365))
        saveHistory()
        checkIn = record
    }

    func saveCheckIn(feeling: String? = nil, reflection: String? = nil) {
        guard let id = checkIn?.id, let index = records.firstIndex(where: { $0.id == id }) else { return }
        if let feeling { records[index].feeling = feeling }
        if let reflection { records[index].reflection = reflection }
        checkIn = records[index]
        saveHistory()
    }

    func clearHistory() {
        records = []
        checkIn = nil
        defaults.removeObject(forKey: historyKey)
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: historyKey)
        }
    }
}
