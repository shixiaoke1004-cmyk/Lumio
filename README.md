# Lumio

Turn your MacBook's notch into a Dynamic Island.

Lumio is an open-source macOS app that transforms the notch into an interactive hub: media controls, volume/brightness HUDs, a file shelf with AirDrop, and live activities.

## Features (roadmap)

- [ ] Media controls — Now Playing in the notch with playback control and album art
- [ ] HUD takeover — volume/brightness HUDs in the notch instead of the system popups
- [ ] File shelf — drop files into the notch, drag them out or AirDrop them
- [ ] Live activities — battery, system status, and notification animations

## Requirements

- macOS 15.0 (Sequoia) or later
- Works on MacBooks with or without a notch (falls back to a virtual notch)

## Building

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open Lumio.xcodeproj
```

## License

[MIT](LICENSE)
