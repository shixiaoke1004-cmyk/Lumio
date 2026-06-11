# Lumio

Turn your MacBook's notch into a Dynamic Island.

Lumio is an open-source macOS app that transforms the notch into an interactive hub: media controls, volume/brightness HUDs, a file shelf with AirDrop, and live activities.

## Features

- **Media controls** — Now Playing in the notch with album art, progress, and playback control (Apple Music, Spotify, and any app using the Now Playing API). The compact strip stays visible while music plays.
- **HUD takeover** — volume/brightness HUDs rendered in the notch instead of the system popups (requires Accessibility permission).
- **File shelf** — drop files onto the notch to stash them, drag them back out, or AirDrop them in one click.
- **Live activities** — battery charging state and low-battery alerts surface in the notch and auto-dismiss.
- **Trackpad gestures** — swipe down on the notch to expand, up to collapse, sideways to skip tracks.
- **Settings** — bilingual UI (English / 简体中文), island size and position, expand lock, HUD durations, launch at login, per-feature toggles.

## Requirements

- macOS 15.0 (Sequoia) or later
- Works on MacBooks with or without a notch (falls back to a virtual notch)

## Building

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
xcodebuild -project Lumio.xcodeproj -scheme Lumio -configuration Release build
```

Or open `Lumio.xcodeproj` in Xcode and run.

To package a DMG for distribution:

```sh
Scripts/make-dmg.sh
```

## Permissions

- **Accessibility** — needed only for the volume/brightness HUD takeover. All other features work without it.

## Acknowledgements

- [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) — Now Playing access on macOS 15.4+
- [boring.notch](https://github.com/TheBoredTeam/boring.notch) — prior art and inspiration

## License

[MIT](LICENSE)
