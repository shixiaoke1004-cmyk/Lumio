# Lumio

Turn your MacBook's notch into a Dynamic Island.

Lumio is an open-source macOS app that transforms the notch into an interactive hub: media controls, volume/brightness HUDs, a file shelf with AirDrop, live activities, and an AI meeting copilot.

## Features

- **Media controls** — Now Playing in the notch with album art, progress, and playback control (Apple Music, Spotify, and any app using the Now Playing API). The compact strip stays visible while music plays.
- **AI copilot for meetings & interviews** — summon with ⌥Space during a call. Transcribes the conversation with on-device speech recognition (audio never leaves your Mac; only text is sent to the LLM) and streams answer suggestions. Scenario presets (general / interview / meeting / custom), resume & job-description context for personalized answers, eager mode that starts answering before the speaker finishes, live audio waveform, and per-scenario accent colors. Bring your own API key — Anthropic or any OpenAI-compatible endpoint; keys are stored in the macOS Keychain.
- **HUD takeover** — volume/brightness HUDs rendered in the notch instead of the system popups (requires Accessibility permission).
- **File shelf** — drop files onto the notch to stash them, drag them back out, or AirDrop them in one click.
- **Live activities** — battery charging state and low-battery alerts surface in the notch and auto-dismiss.
- **Trackpad gestures** — swipe down on the notch to expand, up to collapse, sideways to skip tracks.
- **Stealth mode** — optionally exclude the island from screen recording and sharing.
- **Settings** — bilingual UI (English / 简体中文), island size and position, expand lock, HUD durations, launch at login, per-feature toggles.

## Requirements

- macOS 15.0 (Sequoia) or later
- Works on MacBooks with or without a notch (falls back to a virtual notch)

## Install

Download the latest `Lumio-x.y.z.dmg` from [Releases](../../releases), open it, and drag Lumio to Applications.

> **First launch:** the app is ad-hoc signed (not notarized), so macOS will warn that it "cannot verify the developer". **Right-click Lumio.app → Open → Open** once; after that it launches normally. Or remove the quarantine flag:
>
> ```sh
> xattr -d com.apple.quarantine /Applications/Lumio.app
> ```

## Permissions

All permissions are optional and requested only when the corresponding feature is used:

| Permission | Used for |
|---|---|
| Accessibility | Volume/brightness HUD takeover |
| Screen & System Audio Recording | Copilot: hearing the other party in a call |
| Speech Recognition | Copilot: on-device transcription |
| Microphone | Copilot: transcribing your own voice (optional) |

## Copilot setup

1. Settings → Copilot → enable, pick a backend (Anthropic or a custom OpenAI-compatible endpoint), paste your API key.
2. Optionally choose a scenario (interview / meeting), import your resume (PDF/TXT/Markdown — parsed locally), and paste the target job description.
3. In a call, press ⌥Space, tap the waveform to start listening, and enable auto-suggest (wand icon) for hands-free suggestions.

Privacy: call audio is transcribed on-device by Apple Speech. Only the transcribed text (plus the profile material you provide) is sent to the LLM backend you configure. Nothing else leaves your machine, and there is no telemetry.

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

The DMG is ad-hoc re-signed so it runs on machines that don't have the local development certificate.

## Acknowledgements

- [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause) — Now Playing access on macOS 15.4+
- [boring.notch](https://github.com/TheBoredTeam/boring.notch) — prior art and inspiration

## Disclaimer

The copilot is an assistive tool. You are responsible for complying with applicable laws and the policies of any meeting, interview, or platform where you use it — including recording-consent laws in your jurisdiction.

## License

[MIT](LICENSE). Bundled `mediaremote-adapter` is BSD-3-Clause (see `Vendor/mediaremote-adapter/LICENSE`).
