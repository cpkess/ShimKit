import AppKit
import SwiftUI

final class SettingsController {
    private let window: NSWindow
    private let permissions: PermissionsManager
    private let login: LoginItemManager
    init(permissions: PermissionsManager, shortcuts: ShortcutStore, hotkeys: HotkeyManager, login: LoginItemManager, updates: UpdateManager) {
        self.permissions = permissions
        self.login = login
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "ShimKit Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(preferences: .shared, permissions: permissions,
                                                                  shortcuts: shortcuts, hotkeys: hotkeys, login: login, updates: updates))
        window.center()
    }
    func show() {
        permissions.refresh()
        login.refresh()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var shortcuts: ShortcutStore
    @ObservedObject var hotkeys: HotkeyManager
    @ObservedObject var login: LoginItemManager
    @ObservedObject var updates: UpdateManager
    @State private var editing: WindowCommand?
    @State private var selectedTab = 0
    var body: some View {
        VStack(spacing: 12) {
            Picker("Settings section", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Window Management").tag(1)
                Text("Window Switcher").tag(2)
                Text("Permissions").tag(3)
            }.pickerStyle(.segmented).labelsHidden()
            if selectedTab == 0 {
            Form {
                Section("ShimKit") {
                    Text("Small tools. Native speed.").font(.headline)
                    Text("Everyday window utilities in one lightweight native app.").foregroundStyle(.secondary)
                    Toggle("Launch at Login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                    if !login.message.isEmpty { Text(login.message).font(.caption).foregroundStyle(.secondary) }
                    Toggle("Show ShimKit in menu bar", isOn: $preferences.showMenuBar)
                    Toggle("Show Dock icon", isOn: $preferences.showDock)
                    if !preferences.showMenuBar && !preferences.showDock {
                        Text("Open ShimKit again from Finder to return to Settings.").font(.caption)
                    }
                }
                Section("Updates") {
                    Toggle("Automatically check for updates", isOn: Binding(get: { updates.automaticallyChecks }, set: updates.setAutomaticChecks))
                    Toggle("Automatically download and install updates", isOn: Binding(get: { updates.automaticallyDownloads }, set: updates.setAutomaticDownloads))
                        .disabled(!updates.automaticallyChecks)
                    Button("Check for Updates…") { updates.checkForUpdates() }.disabled(!updates.canCheckForUpdates)
                    if let date = updates.lastCheck {
                        LabeledContent("Last checked", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                    Text("Updates come from cpkess/ShimKit on GitHub. No window content or system profile is sent.").font(.caption).foregroundStyle(.secondary)
                }
                Section { Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development") · No accounts or analytics.").foregroundStyle(.secondary) }
            }.formStyle(.grouped)
            } else if selectedTab == 1 {
            Form {
                Toggle("Enable Window Manager", isOn: $preferences.managerEnabled)
                Section("Shortcuts") {
                    ForEach(WindowCommand.allCases, id: \.self) { command in
                        HStack {
                            Text(command.title)
                            Spacer()
                            Button(shortcuts.bindings[command]?.label ?? "Set Shortcut…") { editing = command }
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    Button("Restore Default Shortcuts") { shortcuts.reset() }
                }
                Text("Repeat Left or Right to cycle through half, two thirds, and one third. Shortcut letters use physical US keyboard positions.")
                    .font(.caption).foregroundStyle(.secondary)
            }.formStyle(.grouped)
            } else if selectedTab == 2 {
            Form {
                Toggle("Enable Window Switcher", isOn: $preferences.switcherEnabled)
                LabeledContent("All applications", value: "⌥ Tab")
                LabeledContent("Current application", value: "⌘ `")
                Text("Hold Option and press Tab for all windows, or hold Command and press ` for windows of the frontmost app. Add Shift to reverse. Release the held modifier to switch. Escape cancels; arrow keys navigate; Return selects.")
                    .foregroundStyle(.secondary)
                Toggle("Show window previews", isOn: $preferences.previews)
                if preferences.previews && !permissions.screenRecording {
                    Text("Previews need Screen Recording permission. Icons and titles work without it.").font(.caption)
                }
                Toggle("Show minimized windows", isOn: $preferences.minimized)
                Toggle("Show application name", isOn: $preferences.appNames)
                Toggle("Show window title", isOn: $preferences.windowTitles)
            }.formStyle(.grouped)
            } else {
            Form {
                Section("Accessibility — required") {
                    Label(permissions.accessibility ? "Access granted" : "Access needed", systemImage: permissions.accessibility ? "checkmark.circle.fill" : "exclamationmark.circle")
                    Text("ShimKit uses Accessibility to list, move, and focus windows, and handle global keyboard shortcuts. It does not send window information anywhere.")
                    Button("Manage Accessibility Access…") { permissions.requestAccessibility() }
                }
                Section("Screen Recording — optional") {
                    Label(permissions.screenRecording ? "Access granted" : "Not enabled", systemImage: permissions.screenRecording ? "checkmark.circle.fill" : "circle")
                    Text("Used only for still previews while the switcher is open. Window switching works without this permission.")
                    Button("Enable Window Previews…") { permissions.requestScreenRecording() }
                    Text("macOS may require quitting and reopening ShimKit after permission changes.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Keyboard") {
                    Text(hotkeys.status)
                    Button("Refresh Permissions & Retry Shortcuts") { permissions.refresh(); hotkeys.start() }
                }
            }.formStyle(.grouped)
            }
        }
        .onAppear { if !permissions.accessibility { selectedTab = 3 } }
        .padding(16)
        .frame(width: 640, height: 560)
        .sheet(item: $editing) { command in ShortcutEditor(command: command, store: shortcuts) }
    }
}

extension WindowCommand: Identifiable { var id: String { rawValue } }

private struct ShortcutEditor: View {
    let command: WindowCommand
    @ObservedObject var store: ShortcutStore
    @Environment(\.dismiss) private var dismiss
    @State private var key: UInt16 = 123
    @State private var control = true
    @State private var option = true
    @State private var shift = false
    @State private var commandModifier = false
    @State private var error = ""
    var body: some View {
        Form {
            Text(command.title).font(.headline)
            HStack {
                Toggle("Control", isOn: $control)
                Toggle("Option", isOn: $option)
                Toggle("Shift", isOn: $shift)
                Toggle("Command", isOn: $commandModifier)
            }
            Picker("Key", selection: $key) {
                ForEach(Shortcut.keys, id: \.code) { Text($0.label).tag($0.code) }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Remove") { _ = store.update(command, shortcut: nil); dismiss() }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    var flags: CGEventFlags = []
                    if control { flags.insert(.maskControl) }
                    if option { flags.insert(.maskAlternate) }
                    if shift { flags.insert(.maskShift) }
                    if commandModifier { flags.insert(.maskCommand) }
                    if let failure = store.update(command, shortcut: Shortcut(keyCode: key, modifiers: flags.rawValue)) { error = failure }
                    else { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 460)
        .onAppear {
            guard let shortcut = store.bindings[command] else { return }
            key = shortcut.keyCode
            control = shortcut.flags.contains(.maskControl)
            option = shortcut.flags.contains(.maskAlternate)
            shift = shortcut.flags.contains(.maskShift)
            commandModifier = shortcut.flags.contains(.maskCommand)
        }
    }
}
