import AppKit
import SwiftUI

final class SettingsController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let permissions: PermissionsManager
    private let login: LoginItemManager
    init(permissions: PermissionsManager, shortcuts: ShortcutStore, hotkeys: HotkeyManager, login: LoginItemManager, updates: UpdateManager, menuBarHider: MenuBarHiderController) {
        self.permissions = permissions
        self.login = login
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        super.init()
        window.delegate = self
        window.title = "ShimKit Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(preferences: .shared, permissions: permissions,
                                                                  shortcuts: shortcuts, hotkeys: hotkeys, login: login, updates: updates, menuBarHider: menuBarHider))
        window.center()
    }
    func windowWillClose(_ notification: Notification) { permissions.stopMonitoring() }
    func show() {
        permissions.monitorChanges()
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
    @ObservedObject var menuBarHider: MenuBarHiderController
    @State private var editing: WindowCommand?
    @State private var selectedTab = 0
    @State private var transferMessage = ""
    private var previewBinding: Binding<Bool> {
        Binding(get: { preferences.previews }, set: { enabled in
            preferences.previews = enabled
            if enabled && !permissions.screenRecording { permissions.requestScreenRecording() }
        })
    }
    private var accessibilityHelp: some View {
        HStack {
            Label("Allow Accessibility to use window tools", systemImage: "hand.raised")
            Spacer()
            Button("Enable…") { selectedTab = 3; permissions.requestAccessibility() }
        }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
    var body: some View {
        VStack(spacing: 12) {
            Picker("Settings section", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Windows").tag(1)
                Text("Switcher").tag(2)
                Text("Menu Bar").tag(4)
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
                Section("Preferences Backup") {
                    HStack {
                        Button("Export Preferences…") {
                            if let message = PreferencesTransfer.export(preferences: preferences, shortcuts: shortcuts, login: login, updates: updates) { transferMessage = message }
                        }
                        Button("Import Preferences…") {
                            if let message = PreferencesTransfer.importFile(preferences: preferences, shortcuts: shortcuts, login: login, updates: updates) { transferMessage = message }
                        }
                    }
                    Text("Save in iCloud Drive to access your backup on other Macs. Export again after making changes; import to apply it. Includes all settings and shortcuts. Permissions and icon positions are managed by macOS.").font(.caption).foregroundStyle(.secondary)
                    if !transferMessage.isEmpty { Text(transferMessage).font(.caption).textSelection(.enabled) }
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
                if !permissions.accessibility { accessibilityHelp }
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
                Text("Repeat a half-screen shortcut to cross a shared monitor edge. At an outer left or right edge, repeat to cycle half, two thirds, and one third. Shortcut letters use physical US keyboard positions.")
                    .font(.caption).foregroundStyle(.secondary)
            }.formStyle(.grouped)
            } else if selectedTab == 2 {
            Form {
                if !permissions.accessibility { accessibilityHelp }
                Toggle("Enable Window Switcher", isOn: $preferences.switcherEnabled)
                LabeledContent("All applications", value: "⌥ Tab")
                LabeledContent("Current application", value: "⌘ `")
                Text("Hold Option and press Tab for all windows, or hold Command and press ` for windows of the frontmost app. Add Shift to reverse. Release the held modifier to switch. Escape cancels; arrow keys navigate; Return selects.")
                    .foregroundStyle(.secondary)
                Toggle("Show window previews", isOn: previewBinding)
                Text("Previews are prepared when windows change and kept in memory for instant display. The last snapshot appears first, then refreshes. New windows need an initial capture.").font(.caption).foregroundStyle(.secondary)
                if preferences.previews && !permissions.screenRecording {
                    HStack {
                        Text("Allow Screen Recording for previews.").font(.caption)
                        Spacer()
                        Button("Enable…") { permissions.requestScreenRecording() }
                    }
                    Text("Window switching already works with icons and titles.").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Show minimized windows", isOn: $preferences.minimized)
                Toggle("Show application name", isOn: $preferences.appNames)
                Toggle("Show window title", isOn: $preferences.windowTitles)
            }.formStyle(.grouped)
            } else if selectedTab == 4 {
            Form {
                Toggle("Hide menu bar icons", isOn: $preferences.menuBarHiderEnabled)
                if #available(macOS 27, *) {
                    Text("On macOS 27, hidden icons move into the system’s overflow menu («). Use Show All to Arrange to bring the sections back. Keep the dividers and their spacers to the left of the arrow.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Arrange your icons") {
                    Text("Hold Command and drag icons to the left of the │ divider to hide them. Keep the arrow to the right of the dividers. Click the arrow to hide or reveal icons.")
                    Text("With an always-hidden section, arrange left to right: always-hidden icons, first divider, hidden icons, second divider, arrow, visible icons.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Show All to Arrange") { menuBarHider.arrange() }
                        Button(menuBarHider.state == .collapsed ? "Show Hidden Icons" : "Hide Icons") { menuBarHider.toggle() }
                    }.disabled(!preferences.menuBarHiderEnabled)
                    if !menuBarHider.message.isEmpty { Text(menuBarHider.message).foregroundStyle(.orange) }
                }
                Section("Behavior") {
                    Toggle("Hide icons when ShimKit starts", isOn: $preferences.menuBarHideOnLaunch)
                    Toggle("Keep an always-hidden section", isOn: $preferences.menuBarAlwaysHidden)
                    Toggle("Automatically hide after revealing", isOn: $preferences.menuBarAutoHide)
                    Picker("Hide after", selection: $preferences.menuBarHideDelay) {
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                    }.disabled(!preferences.menuBarAutoHide)
                    Toggle("Toggle with ⌃⌥H", isOn: $preferences.menuBarHiderHotkey)
                    if shortcuts.bindings.values.contains(where: { $0.overlapsKeys(with: .menuBarHider) }) {
                        Text("⌃⌥H is assigned to a window action. Remove that assignment to enable the menu bar shortcut.").font(.caption)
                    }
                }.disabled(!preferences.menuBarHiderEnabled)
                Text("Option-click the arrow to reveal every section for arranging. Arrangement stays open until you hide it. Mouse controls need no permissions; the shortcut uses Accessibility. On smaller or notched screens, there may not be room to show every icon at once.").font(.caption).foregroundStyle(.secondary)
            }.formStyle(.grouped)
            } else {
            Form {
                Section {
                    Label(permissions.accessibility ? "You're ready to use ShimKit" : "Set up ShimKit",
                          systemImage: permissions.accessibility ? "checkmark.circle.fill" : "hand.raised.fill")
                        .font(.title3.weight(.semibold))
                    Text(permissions.accessibility ? "Window tools are enabled. Previews are optional." : "Allow Accessibility to move and switch windows. You can add previews whenever you like.")
                        .foregroundStyle(.secondary)
                }
                Section("Window tools") {
                    HStack {
                        Label("Accessibility", systemImage: "macwindow")
                        Spacer()
                        if permissions.accessibility {
                            Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button("Enable Accessibility…") { permissions.requestAccessibility() }.buttonStyle(.borderedProminent)
                        }
                    }
                    if !permissions.accessibility {
                        Text("Turn on ShimKit in System Settings. This screen updates automatically.").font(.caption).foregroundStyle(.secondary)
                    }
                    if permissions.pending == .accessibility { Text("Waiting for access…").font(.caption).foregroundStyle(.secondary) }
                    if permissions.accessibility && !hotkeys.isActive {
                        Text(hotkeys.status).font(.caption)
                        Button("Reconnect Keyboard Shortcuts") { hotkeys.start() }
                    }
                }
                Section("Window previews · Optional") {
                    Toggle("Show window previews", isOn: previewBinding)
                    Text("Small snapshots are kept in memory for fast switching. They are never saved to disk.").font(.caption).foregroundStyle(.secondary)
                    if preferences.previews {
                        if permissions.screenRecording {
                            Label("Screen Recording allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button("Allow Screen Recording…") { permissions.requestScreenRecording() }
                            Text("Enable ShimKit in System Settings. Icons and titles work while previews are off.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if preferences.previews && permissions.pending == .previews { Text("Waiting for access…").font(.caption).foregroundStyle(.secondary) }
                }
                DisclosureGroup("Already enabled in System Settings?") {
                    Text("If macOS still reports access unavailable, restart ShimKit. If it persists, remove its old entry and add this copy again.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Restart ShimKit") { permissions.restart() }
                        Button("Show This App in Finder") { permissions.revealApp() }
                    }
                    Text("Use the copy in Applications, rather than running from the installer disk image.").font(.caption).foregroundStyle(.secondary)
                    if !permissions.message.isEmpty { Text(permissions.message).font(.caption).foregroundStyle(.secondary) }
                }
            }.formStyle(.grouped)
            }
        }
        .onAppear {
            if !permissions.accessibility { selectedTab = 3 }
            permissions.monitorChanges()
        }
        .onChange(of: selectedTab) { _, _ in permissions.monitorChanges() }
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
    @StateObject private var recorder = ShortcutRecorder()
    @State private var error = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(command.title).font(.title3.weight(.semibold))
            Text("Record a shortcut").foregroundStyle(.secondary)
            Text(recorder.recorded?.label ?? "No shortcut")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Recorded shortcut")
            Button(recorder.isRecording ? "Cancel Recording" : "Record Shortcut") {
                error = ""
                if recorder.isRecording { recorder.stop(cancel: true) }
                else { recorder.start(store: store) }
            }
            Text("Hold Control, Option, or Command in any combination, together with one to four keys. Release a key to finish. For example: hold ⌃⌥⌘ and both ← and ↑ together.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Key order does not matter. Unambiguous combinations fire immediately; a combination that could grow into another assignment waits for release. Key positions follow the US keyboard.")
                .font(.caption).foregroundStyle(.secondary)
            if !recorder.message.isEmpty { Text(recorder.message).font(.caption) }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Remove") { recorder.stop(); _ = store.update(command, shortcut: nil); dismiss() }
                Spacer()
                Button("Cancel") { recorder.stop(); dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let failure = store.update(command, shortcut: recorder.recorded) { error = failure }
                    else { dismiss() }
                }.keyboardShortcut(.defaultAction).disabled(recorder.isRecording || recorder.recorded == nil)
            }
        }.padding(24).frame(width: 480)
        .onAppear { recorder.recorded = store.bindings[command] }
        .onDisappear { recorder.stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if recorder.isRecording { recorder.stop(cancel: true) }
        }
    }
}
