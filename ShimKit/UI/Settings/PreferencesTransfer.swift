import AppKit
import UniformTypeIdentifiers

@MainActor
enum PreferencesTransfer {
    static func export(preferences: Preferences, shortcuts: ShortcutStore, login: LoginItemManager, updates: UpdateManager) -> String? {
        login.refresh()
        let archive = PreferencesArchive(
            settings: Preferences.portableBooleans.mapValues { preferences[keyPath: $0] },
            menuBarHideDelay: preferences.menuBarHideDelay,
            shortcuts: Dictionary(uniqueKeysWithValues: shortcuts.bindings.map { ($0.key.rawValue, $0.value) }),
            launchAtLogin: login.enabled, automaticUpdateChecks: updates.automaticallyChecks,
            automaticUpdateDownloads: updates.automaticallyDownloads)
        let panel = NSSavePanel()
        panel.title = "Export ShimKit Preferences"
        panel.nameFieldStringValue = "ShimKit Preferences.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = "Choose iCloud Drive to keep this file in your Apple Account, or save it anywhere on this Mac."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try archive.encoded().write(to: url, options: .atomic)
            return "Preferences exported to \(url.lastPathComponent)."
        } catch { return "Export failed: \(error.localizedDescription)" }
    }

    static func importFile(preferences: Preferences, shortcuts: ShortcutStore, login: LoginItemManager, updates: UpdateManager) -> String? {
        let panel = NSOpenPanel()
        panel.title = "Import ShimKit Preferences"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let archive = try PreferencesArchive.decode(Data(contentsOf: url))
            let confirmation = NSAlert()
            confirmation.messageText = "Import preferences from \(url.lastPathComponent)?"
            confirmation.informativeText = "This replaces all ShimKit settings and shortcuts, including login and update preferences. Export your current settings first if you want a backup. macOS permissions and icon positions stay with this Mac."
            confirmation.addButton(withTitle: "Import")
            confirmation.addButton(withTitle: "Cancel")
            guard confirmation.runModal() == .alertFirstButtonReturn else { return nil }
            try archive.apply(to: preferences, shortcuts: shortcuts)
            updates.setAutomaticDownloads(archive.automaticUpdateDownloads)
            updates.setAutomaticChecks(archive.automaticUpdateChecks)
            login.refresh()
            if login.enabled != archive.launchAtLogin { login.setEnabled(archive.launchAtLogin) }
            return "Preferences imported." + (login.message.isEmpty ? "" : " Login setting: \(login.message)")
        } catch { return "Import failed: \(error.localizedDescription)" }
    }
}
