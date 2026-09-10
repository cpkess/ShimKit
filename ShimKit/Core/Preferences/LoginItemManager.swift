import ServiceManagement
import Combine

final class LoginItemManager: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var message = ""
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
