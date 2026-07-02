# OptionTab

A minimal, from-scratch, Windows-style window switcher for macOS. Hold
**Control+Option**, tap **Tab** to cycle through every open window (not just
apps), release to switch. It's your own code — no subscriptions, no Pro tier,
no telemetry, and no collision with macOS's own Siri hotkey.

~500 lines total, no third-party dependencies.

## How it works

- `HotkeyManager.swift` — a `CGEventTap` globally watches for Control+Option
  held together + Tab presses (and Shift+Tab, Esc to cancel), and separately
  detects Control+Option held together (no Tab) past a short threshold to
  trigger the overview.
- `WindowManager.swift` — enumerates real on-screen windows via
  `CGWindowListCopyWindowInfo`, filtering out menu bar/dock/tiny utility windows.
- `SwitcherPanel.swift` — the floating translucent bar used for the Tab-cycling mode.
- `OverviewPanel.swift` — the grid overview shown on a Control+Option hold, with
  click-to-switch and click-outside-to-dismiss.
- `WindowActivator.swift` — raises and focuses the chosen window via the
  Accessibility API.
- `AppDelegate.swift` — wires it together and adds a small menu-bar icon (with Quit).

## Requirements

- macOS 12+
- Xcode Command Line Tools: `xcode-select --install` (you do **not** need full Xcode)

## Build & run

```bash
cd OptionTab
chmod +x build.sh
./build.sh
```

This compiles the app, packages it into `~/Applications/OptionTab.app`, ad-hoc
signs it, and launches it.

**First launch:** macOS will prompt for Accessibility permission (needed to
capture the global hotkey and to raise other apps' windows). Grant it in
**System Settings → Privacy & Security → Accessibility**, then quit and relaunch
OptionTab from `~/Applications`.

## Usage

| Action | Result |
|---|---|
| Hold `Control+Option`, tap `Tab` | Show switcher, select the previous window |
| Tap `Tab` again (still holding both) | Move forward |
| Hold `Shift` + `Tab` | Move backward |
| Release `Control` or `Option` | Switch to the selected window |
| `Esc` | Cancel, no switch |
| **Hold `Control+Option` together for ~0.35s** (no Tab, no other key) | Show a grid overview of every open window, active one highlighted. It stays open even after you let go of the keys. |
| Click a window in the overview | Jump to it, overview closes |
| Click elsewhere / `Esc` | Dismiss the overview |

A small icon appears in the menu bar with a Quit option.

### Why Control+Option instead of plain Option

Some Macs have Siri's keyboard shortcut configured to trigger on holding
Option, and that's a system-level listener outside anything a CGEventTap can
see or block — so a bare-Option app can end up fighting with Siri for the same
keypress. Control+Option isn't claimed by any default macOS shortcut, so it
doesn't have that problem.

### How the overview trigger avoids false positives

If you press Tab within that ~0.35s window, it's treated as the start of normal
Tab-cycling instead, and the overview never appears. If you press any other key
while Control+Option are held, the overview is also suppressed for that hold.
You can tune the delay by changing `holdThreshold` in `HotkeyManager.swift`.

## Making it start at login

Open **System Settings → General → Login Items**, click **+**, and add
`~/Applications/OptionTab.app`.

## Customizing

- **Change the hotkey**: edit `tabKeyCode`/`escKeyCode` in `HotkeyManager.swift`
  (uses standard macOS virtual keycodes), or edit the `comboActive` logic and
  the `.maskControl`/`.maskAlternate` checks to use different modifiers
  (e.g. swap in `.maskCommand`).
- **Change which windows show up**: adjust the filters in
  `WindowManager.listWindows()` (e.g. minimum size, exclude specific app names).
- **Change the look**: `SwitcherPanel.swift` controls colors, size, corner radius,
  and the highlight style — it's plain AppKit, easy to restyle.
- **Add live thumbnails instead of icons**: swap `WindowItemView`'s image source
  for `CGWindowListCreateImage`, though note this requires Screen Recording
  permission (icons don't).

## Known limitations

- Uses one private API, `_AXUIElementGetWindow`, to map a window ID to its
  Accessibility element — there's no public API for this. It's the same
  approach several open-source switchers use, and it's fine for personal use,
  but it means this build should not be submitted to the Mac App Store as-is.
- Because the app is ad-hoc signed (`codesign --sign -`), each rebuild can
  produce a new signature, which may make macOS ask you to re-grant
  Accessibility permission after every `./build.sh`. If that gets annoying,
  create a free self-signed certificate in Keychain Access (Certificate
  Assistant → Create a Certificate → Code Signing) and sign with that identity
  instead of `-` for a stable identity across rebuilds.
- No multi-monitor-aware placement beyond centering on the main screen, and no
  Mission Control/Spaces-aware filtering — easy follow-ups if you want them.
