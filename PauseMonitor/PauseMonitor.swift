import DeviceActivity
import ManagedSettings

final class PauseMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.hasPrefix(PauseConfiguration.prefix) else { return }
        PauseConfiguration.store(for: activity).clearAllSettings()
    }

    // Intentionally do not apply restrictions in intervalDidStart. The app
    // applies them once; a delayed start callback must not restart a pause.
}
