# ShimKit

A small, native macOS menu-bar app for managing windows, switching individual windows, and hiding menu-bar icons. Swift, AppKit, and a SwiftUI Settings window. Source and releases: [cpkess/ShimKit](https://github.com/cpkess/ShimKit).

Window utilities run entirely on your Mac. The only external dependency is [Sparkle](https://sparkle-project.org), used to verify and install updates from GitHub Releases. No accounts, analytics, system profiling, or window-content uploads. Sparkle’s license and third-party notices are bundled in the app and in `Resources/Sparkle-LICENSE.txt`. Release-note web views are disabled.

## Why ShimKit exists

ShimKit is intended to consolidate small everyday macOS utilities into one extremely lightweight native application. Window positioning, window switching, and menu-bar organization share a small native app.

## Features

- Halves, quarters, thirds, two thirds, maximize, center, previous-frame restore, and previous/next display.
- Repeating Left/Right cycles half → two thirds → one third. Restore swaps with the last frame changed by ShimKit, independently per window.
- Option+Tab switches individual windows in observed most-recently-used order. Hold Option, repeat Tab, use Shift+Tab to reverse, and release Option to activate. Escape cancels; arrows navigate; Return or a click selects.
- Command+` opens the same switcher scoped to the frontmost application. Hold Command and repeat ` to cycle, add Shift to reverse, and release Command to activate. The window list stays fixed while cycling.
- Refined native material switcher with larger rounded previews, app names, window titles, minimized indicators, and keyboard hints. Cached previews appear with the popup and refresh afterward.
- Collapsible menu-bar icons with Command-drag dividers, an optional always-hidden section, automatic hiding, and Control+Option+H.
- Recorded window-manager shortcuts with one to four keys under held modifiers, module toggles, visibility preferences, and native launch-at-login registration.
- Automatic update checks and installation through GitHub Releases, with signed update feeds and archives. Manual Check for Updates is available in Settings and the menu bar.
- Menu-bar-only by default. Reopen the app in Finder to recover Settings if both the menu-bar and Dock icons are hidden.

### Default shortcuts

| Action | Shortcut |
| --- | --- |
| Left / Right and size cycling | Control+Option+Left / Right |
| Maximize / Restore | Control+Option+Up / Down |
| Top Left / Top Right | Control+Option+U / I |
| Bottom Left / Bottom Right | Control+Option+J / K |
| Center | Control+Option+C |
| Window Switcher | Option+Tab; Shift reverses |
| Current application windows | Command+backtick (`); Shift reverses |
| Show / hide menu-bar icons | Control+Option+H (when enabled) |

All positioning commands are available from the menu and can be assigned shortcuts in Settings. Letter shortcuts use physical US keyboard positions. Window-switcher activation is fixed at Option+Tab (all apps) and Command+backtick (current app); both bindings use the shared shortcut model. These combinations and their Shift variants are reserved for switching.

### Recording complex shortcuts

Open **Settings → Windows**, click a command's shortcut, then choose **Record Shortcut**. Hold Control, Option, Command, and/or Shift (at least one of Control, Option, or Command), press one to four keys in order, then release the modifiers and click **Save**.

For **Left Two Thirds**, hold **Control–Option–Command**, press **Left Arrow**, then **Up Arrow**, release the modifiers, and save. The shortcut is displayed as `⌃⌥⌘←, ↑`. You can keep Left held while pressing Up; the key-down order defines the sequence.

To invoke a sequence, keep the same modifiers held and press each key within 1.5 seconds. Modifier changes, switching applications, or a timeout cancel an unfinished sequence. An unmatched key cancels the sequence and is processed normally; the consumed prefix is not replayed. Existing single-key shortcuts still fire immediately. Duplicate shortcuts and bindings that are prefixes of other bindings are rejected with the conflicting command's name. Existing saved shortcuts migrate automatically.

Recording suspends ShimKit's global shortcuts until it finishes or is cancelled. Escape cancels recording; leaving ShimKit also cancels it. macOS or another utility may still intercept system-reserved key combinations. Menu entries display multi-key sequences without registering their first key as a native menu accelerator.

## Menu-bar organization

Enable **Settings → Menu Bar → Hide menu bar icons**. The module is off by default and initially opens in arrangement mode:

1. Hold Command and drag icons to the left of the **│** divider. Keep the arrow to its right.
2. Click the arrow to hide those icons; click again to reveal them. Right-click for Settings and arrangement controls.
3. Optionally enable **Keep an always-hidden section**. Arrange left to right: always-hidden icons, first divider, ordinary hidden icons, second divider, arrow, visible icons.
4. Option-click the arrow or choose **Show All to Arrange** to reveal both sections. This stays open until you click Hide Icons, so auto-hide cannot interrupt arrangement.

Auto-hide defaults to 10 seconds after revealing, with 5, 30, and 60 second options. It waits while the pointer is in the menu bar, a mouse button is held, or AppKit is tracking a menu. Launch hiding can be disabled. Disabling the module or quitting restores the space occupied by both dividers. Display changes reveal all icons for safe rearrangement. macOS saves divider positions.

Mouse controls need no Accessibility or Screen Recording access. Control+Option+H uses the existing Accessibility-authorized keyboard service; if a saved window action uses this shortcut, that action retains it and Settings explains the conflict. The hider arrow remains available independently of the main ShimKit menu-bar icon.

This is an independent implementation of the core behavior popularized by [Hidden Bar](https://github.com/dwarvesf/hidden), using public AppKit status items. macOS does not expose a public API to hide another app's icon: wide divider items move icons offscreen. Small/notched displays may lack space to reveal all icons, and future macOS menu-bar changes can affect this technique. Use one menu-bar hiding utility at a time. No icons are moved between groups automatically.

## Installing the app

Unzip the release, then move **ShimKit.app to `/Applications` before opening it or granting permissions**. Run that copy rather than an app inside this repository, a temporary build directory, or a cloud-synced Documents/Desktop folder. File-provider metadata can invalidate the app signature.

If macOS Settings shows permission enabled but ShimKit still reports access needed:

1. Quit ShimKit.
2. In System Settings → Privacy & Security → Accessibility, remove the old ShimKit entry and add `/Applications/ShimKit.app` using the + button. Enable it.
3. Repeat for Screen & System Audio Recording if you want previews.
4. Reopen `/Applications/ShimKit.app` and choose Refresh Permissions & Retry Shortcuts.

Older 0.1.x builds were ad-hoc signed. Moving to the Developer ID signed 0.2.0 build may require this one-time permission refresh. Subsequent releases use a consistent signing identity. Install before granting permissions.

## Requirements and permissions

- macOS 14 Sonoma or later; Apple Silicon supported. Xcode's Release app build produces arm64 and x86_64 slices.
- Xcode 15 or later with the macOS SDK for development (verified with Xcode 26.2 / Swift 6.2.4).
- **Accessibility is required** for window discovery, positioning, focus, and the keyboard event tap. On first launch, Settings explains the permission. Use Permissions → Manage Accessibility Access, enable ShimKit in System Settings, then return to ShimKit or choose Refresh Permissions & Retry Shortcuts. The app does not repeatedly request authorization.
- **Screen Recording is optional**, used only for previews. Previews are off by default. Enable permission explicitly in Settings; icons and AX titles work without it. macOS may require an app restart after changing authorization.
- Launch at Login uses `SMAppService.mainApp`. Copy the app to a stable location such as `/Applications` before enabling it; macOS may require approval under General → Login Items.

The project uses team `WZJ4ZPRH72`: Apple Development for Debug and Developer ID Application for Release. Contributors can choose their own team in Xcode; `swift test` does not require a signing certificate. App Sandbox is disabled because ShimKit controls other apps via Accessibility. Hardened Runtime remains enabled. No private window APIs are used.

## Build and run

Open `ShimKit.xcodeproj`, select the ShimKit scheme and My Mac, and Run. The shared scheme builds the app; logic tests run through Swift Package Manager. Xcode resolves the pinned Sparkle binary dependency automatically. A compatible signing certificate is needed to run the app with Hardened Runtime.

Or build a signed release app:

```sh
./scripts/build.sh
```

The script prints the app path under `$TMPDIR/ShimKitDerivedData/Build/Products/Release/ShimKit.app`. Open it in Finder or copy it to Applications. Build products deliberately live outside Documents/Desktop: cloud file providers can attach Finder metadata that makes code signing fail. Xcode's default DerivedData location works too.

For a quick compile and the unit tests:

```sh
swift build
swift test
```

The package executable is useful for compilation, but run the `.app` bundle for permissions and launch-at-login behavior. After adding/removing source files outside Xcode, regenerate the checked-in project with `python3 scripts/generate-project.py` (Python 3, no packages required).

## Architecture

- `App/`: lifecycle, menu bar, and explicit service wiring.
- `Core/Accessibility/`: checked AX attribute reads, frame changes, and bounded messaging timeouts.
- `Core/Windowing/`: shared window model/discovery, coordinate geometry, AX/workspace notifications, MRU history, activation, and the independent preview provider.
- `Core/Hotkeys/`: Codable shortcut model/store and one global keyboard event tap. No window discovery or capture inside key callbacks.
- `Core/Permissions/` and `Core/Preferences/`: authorization, UserDefaults, and ServiceManagement.
- `Core/Updates/`: Sparkle lifecycle and observable Settings bindings.
- `Modules/WindowManager/`: positioning, cycle state, per-window restoration.
- `Modules/MenuBarHider/`: movable status-item dividers, layout safety checks, and a one-shot auto-hide timer active only while expanded.
- `Modules/WindowSwitcher/`: session selection and the AppKit panel. Its snapshot stays stable while cycling.
- `UI/Settings/`: native preference forms and shortcut editor.

Geometry uses Accessibility's global top-left coordinate space, in points. `NSScreen.visibleFrame` converts via the primary display's height, preserving negative origins and menu-bar/Dock insets. Display choice uses greatest intersection; display transfers preserve the window's relative position and clamp its size.

## Performance and limitations

- Window services have no recurring timers or continuous screenshot capture. When previews are enabled, window events schedule a debounced preview warmup; there is no capture polling while idle. Workspace and AX notifications drive a coalesced cache refresh. Sparkle separately schedules an update check about once per day when enabled. Cross-process discovery runs on one serial worker with a 150 ms AX messaging timeout. A request can still be slow across many unresponsive applications; the switcher uses its last snapshot immediately.
- AppKit and AX observer registration run on the main thread. Apps with many windows can cause short registration/focus-handling stalls; profile these with Instruments. Do not interpret architectural goals as measured idle CPU or latency guarantees.
- MRU order is learned after launch. Unobserved windows use AX enumeration order. Some applications omit notifications; opening the switcher requests a refresh for subsequent sessions. A very early invocation can have an empty cache.
- Only standard AX application windows are listed, including minimized windows when exposed by the owner. Some apps expose tabs as one window, omit titles/windows, or refuse resizing/focus. Utility panels and dialogs are intentionally excluded. Hidden applications' normal windows can be restored. Full-screen windows can be switched to where macOS allows, but are not resized.
- Spaces, full-screen transitions, Stage Manager, minimum sizes, fixed-size windows, and OS focus policy can constrain positioning/activation. There is one delayed focus retry for asynchronous unminimization. Disappeared windows are ignored safely.
- Thumbnails use [ScreenCaptureKit's SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager), capturing at most 24 nonminimized windows sequentially at up to 384×240. A bounded memory-only cache retains the last snapshots across switcher sessions (roughly 9 MB of pixel data at the maximum size). Cached images are installed before the popup is shown, then snapshots older than three seconds refresh asynchronously. Window changes also prepare previews after a 600 ms debounce. New or uncached windows still need their first capture; cached images may briefly show older content. Closed windows are pruned, and disabling previews or the switcher clears the cache. Images are never saved to disk. Cancellation discards late results; an in-flight system capture may finish after dismissal.
- There is no public AX-to-CG window-ID accessor. Preview matching uses owning PID, frame, and title conservatively; ambiguous/minimized/protected windows retain their icons. A missing preview never excludes a window.
- The global event tap requires Accessibility and may be blocked by Secure Input or another utility's conflicting shortcut. Disable conflicting shortcuts in those utilities or edit ShimKit's bindings. Cross-app shortcut conflicts cannot be detected reliably; duplicates within ShimKit are rejected.
- Restore history is in memory and pruned with discovery. App restarts, disappearing AX elements, or a temporarily unavailable application can invalidate that history.

## Validation

`swift test` covers all geometry layouts at zero, negative, and displaced origins, AppKit/AX conversion, display choice/transfers, oversize centering, cycle reset/wrap, MRU pruning, selection wrap, shortcut serialization/matching, app-scoped window filtering, modifier-release behavior, native panel scrolling/card cleanup, menu-bar divider ordering, spacer sizing, and preference persistence. The panel test requires a logged-in graphical session and skips when no display is available.

Manual checks on a permission-authorized build:

1. Position a standard window with each command; cycle left/right and restore twice.
2. Test a second display above/left/below the primary, different scaling, Dock placements, and a disconnected display.
3. Open several windows from one app and another app; exercise rapid Option+Tab, Shift+Tab, release, Escape, Return, and clicks.
4. Minimize a window and select it; close a window or quit its app while the panel is open.
5. Test without Screen Recording, then with previews authorized; dismiss while capture is pending.
6. Toggle module/menu/Dock settings, restart, and verify persistence. Test launch-at-login from an installed signed bundle.
7. Profile idle CPU/wakeups with Time Profiler/Energy Log and memory during repeated large switcher sessions with Allocations.

## Automatic updates and publishing

Version 0.2.0 is the first updater-enabled build. Install it manually once into `/Applications`; older 0.1.x copies cannot self-update. Future releases use:

- Feed: `https://github.com/cpkess/ShimKit/releases/latest/download/appcast.xml`
- Downloads: immutable, versioned GitHub release assets, not source archives.
- Sparkle 2.9.6, pinned in both the Swift package and Xcode project.
- Ed25519 verification for both the feed and the archive, with verification before extraction.
- Developer ID signing and mandatory Apple notarization using a saved `notarytool` profile.

Automatic checks and automatic downloads/installation default to enabled. Both can be changed under General → Updates. Sparkle controls scheduling, installer prompts, application replacement, and relaunch. Normal GitHub HTTPS requests reveal connection metadata such as IP address and the updater's user agent to GitHub; no window content or system profile is included. Turning off automatic checks leaves only explicit manual checks.

The release-signing private key stays in the maintainer's login Keychain under Sparkle account `com.shimkit.app`; only its public key is committed. Back up the Keychain securely. Apple private keys and notarization credentials are not uploaded to GitHub.

To publish a release from the maintainer's Mac:

1. Increase `CFBundleShortVersionString` and the integer `CFBundleVersion` in `Resources/Info.plist`.
2. Commit and push to `origin/main`. Run `python3 scripts/generate-project.py` if sources changed.
3. Run `python3 scripts/release.py --publish --notary-profile YOUR_SAVED_PROFILE`.

The script tests, archives, exports with Developer ID signing (including Sparkle's helpers), requires Apple to accept notarization, staples and validates the ticket, and checks Gatekeeper. It then generates and verifies the signed appcast and uploads a draft containing both assets before publishing it as the latest release. It rejects dirty/unpushed sources, the wrong repository, changed signing configuration, and non-increasing build numbers. No automatic release is triggered by an ordinary source push.

Use `python3 scripts/release.py` to prepare a signed, notarized local release without publishing. Notarization is mandatory; there is no unnotarized release override. The default Keychain profile is `ShimKit`, overridable with `--notary-profile` or `SHIMKIT_NOTARY_PROFILE`. Set it up once in Terminal:

```sh
xcrun notarytool store-credentials "ShimKit" --team-id "WZJ4ZPRH72"
```

Enter the Apple ID and an Apple app-specific password at the interactive prompts. Credentials remain in the local Keychain. The script checks authentication before building, verifies the expected Developer ID identity, hardened runtime and secure timestamp, and refuses publication unless notarization returns `Accepted`, stapling succeeds, and Gatekeeper accepts the app. Versions through 0.3.1 were signed but unnotarized. Managed work Macs can still require employer approval even for notarized apps.

GitHub Actions runs Swift tests, release-tool tests, generated-project validation, and an unsigned universal app compilation on pushes and pull requests. It does not receive signing credentials. This keeps public contribution builds separate from the local signing/publishing step.

Validation commands:

```sh
swift test
python3 -m unittest discover -s Tests/ReleaseTests -v
```
