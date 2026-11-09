import Foundation
import DeviceActivity
import ManagedSettings

enum PauseConfiguration {
    static let duration: TimeInterval = 30 * 60
    static let prefix = "pauseme."

    static func store(for activity: DeviceActivityName) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
    }
}
