# QuikWeb

A minimal, native macOS menu-bar search launcher. Press a global shortcut from
anywhere, type, hit Enter — QuikWeb opens the query in your default browser.
No Dock icon, no app menu bar: everything lives behind the menu-bar icon.

## Features

- **Global shortcut** (⌥Space by default, fully rebindable) summons a small
  centered search bar, Spotlight/Raycast-style.
- **Opens your default browser** via `NSWorkspace`, using your choice of
  Google, Bing, DuckDuckGo, Yahoo, or a custom URL template.
- **Launches at login** (toggle in Settings, via `SMAppService`).
- **Menu-bar only** — right-click (or click) the status-bar icon for exactly
  two options: **Menu** (settings) and **Exit** (quit).
- **Settings window** with four tabs: General, Hotkey, Appearance (theme +
  accent color), About — each with its own icon.
- A full custom SVG icon set (`Icons/*.svg`) drives every icon in the app:
  the app icon, the status-bar glyph, the settings tabs, and the status-bar
  menu items. Nothing is left blank.

## Installing (the easy way)

QuikWeb has **no third-party runtime dependencies** — it uses only Apple
system frameworks, so the only thing that needs installing is the app itself.
Build a self-contained, double-click installer with:

```sh
Scripts/make_installer.sh
```

That produces **`build/QuikWeb-Installer.pkg`**, a universal installer (works
on both Apple Silicon and Intel Macs). It installs QuikWeb into
`/Applications`, clears the quarantine flag, and launches the app for you when
it finishes.

To install, double-click the `.pkg`. Because it's ad-hoc signed (no Apple
Developer account is involved), the first time you open it macOS Gatekeeper
may block the double-click. Either:

- right-click `QuikWeb-Installer.pkg` → **Open**, then confirm; or
- install from the terminal, which skips that prompt:
  ```sh
  sudo installer -pkg build/QuikWeb-Installer.pkg -target /
  ```

Building the installer itself needs the Xcode Command Line Tools (`swift`,
`pkgbuild`, `productbuild`); `make_installer.sh` checks for them and tells you
how to install them (`xcode-select --install`) if they're missing.

## Building from source

Requires Xcode (or at least the Xcode Command Line Tools) for `swift`,
`iconutil`, and `codesign`. No other dependencies — the icon pipeline is pure
Swift/AppKit, no `rsvg-convert`/Inkscape needed.

```sh
Scripts/build_app.sh
```

This regenerates every PNG/`.icns` from `Icons/*.svg`, builds a release
binary with Swift Package Manager, hand-assembles `build/QuikWeb.app`, and
ad-hoc codesigns it.

Run it directly:

```sh
open build/QuikWeb.app
```

Or install it to `/Applications` (recommended — see the Login Items note
below):

```sh
Scripts/install.sh
```

### First launch (Gatekeeper)

QuikWeb is ad-hoc signed, not notarized by Apple, since there's no Apple
Developer account involved. The first time you open it, macOS may refuse to
launch it via double-click — right-click `QuikWeb.app` → **Open** instead,
then confirm. You only need to do this once.

## Using QuikWeb

- Press **⌥Space** anywhere to summon the search bar. Type your query, press
  **Return** to search, or **Escape** to dismiss.
- Click the magnifying-glass icon in the menu bar to open its menu:
  - **Menu** — opens Settings (search engine, login item, shortcut, theme).
  - **Exit** — quits QuikWeb.

## Login Items notes

`SMAppService` (the modern "launch at login" API) works fine for an
unsigned, locally-built app, but a few things are worth knowing:

- The first time you enable it, macOS requires you to approve it in
  **System Settings → General → Login Items** — Settings will show a prompt
  and a shortcut button if that's still pending.
- For the most reliable behavior, run QuikWeb from `/Applications` (use
  `Scripts/install.sh`) rather than from a build folder or external drive.
- If you rebuild QuikWeb from source and the login item silently stops
  working, just re-toggle "Launch QuikWeb at login" off and on in Settings —
  re-signing the binary can occasionally make macOS treat it as a changed
  app.

## Project layout

```
Sources/QuikWeb/      Swift sources (AppKit + SwiftUI, no Xcode project)
Icons/                Hand-authored SVG source icons (the source of truth)
Scripts/
  GenerateIcons.swift   SVG -> PNG/iconset rasterizer (pure AppKit)
  build_app.sh          Builds and assembles QuikWeb.app
  install.sh            Copies the built app to /Applications
Resources/Info.plist   App bundle metadata
```

There's no `.xcodeproj` — it's a plain Swift Package executable target,
bundled into a real `.app` by `build_app.sh`. You can still open the folder
in Xcode (File → Open… → select `Package.swift`) to browse/edit with full
indexing; just use the scripts above to produce the actual `.app`.
