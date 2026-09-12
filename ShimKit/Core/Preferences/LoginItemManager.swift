import ServiceManagement
import Combine

final class LoginItemManager: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var message = ""
    func initializeDefaults(isNewInstallation: Bool) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "loginDefaultInitialized") else { return }
        defaults.set(true, forKey: "loginDefaultInitialized")
        if isNewInstallation && FactoryDefaults.launchAtLogin && SMAppService.mainApp.status == .notRegistered {
            setEnabled(true)
        }
    }
    func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval { message = "Approve ShimKit in System Settings → General → Login Items." }
    }
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            message = ""
        } catch { message = error.localizedDescription }
        refresh()
    }
}
