# Apace

> On-device dictation for macOS — type at the speed of thought.

Hold a key, speak, release. Your words appear in any app — transcribed entirely on
your Mac, with a live transcript in the notch. A voice command mode (in progress)
lets you *act* on your voice, not just type.

> **Source-available, proprietary — not open source.** The code is public so you can
> read, audit, and trust it. See [LICENSE](LICENSE) (PolyForm Strict 1.0.0).

## Features

- **System-wide dictation** — choose Right/Left Option, Control, or Fn and use either
  push-to-talk or hands-free toggle mode.
- **Local-first & private** — transcription and audio stay on your Mac; optional cleanup
  uses the provider you explicitly select.
- **Multiple engines** — WhisperKit (Core ML), Parakeet, and Apple Speech, with user
  language controls and automatic detection where the engine supports it.
- **Live notch overlay** — a Dynamic-Island-style transcript and waveform while you speak.
- **Reliable recovery** — retry failed transcription or insertion from local History.
- **Dictation Health** — test permissions, shortcut capture, microphone input,
  transcription, and insertion from one Settings pane.
- **Commands & Actions** *(experimental)* — ask a question, rewrite the focused draft,
  or let Apace complete a supervised task on your Mac. Short-lived, memory-only
  conversation context lets “make it shorter”, “send it”, and similar follow-ups refer
  to the preceding command. With screen visibility enabled, Apace can read a visible
  WhatsApp, Messages, Mail, Slack, Teams, or Telegram conversation and draft a reply in
  the requested language without sending it. Outward and high-impact actions require approval.

## Requirements

- macOS 14.0+.
- Apple silicon recommended for on-device models.

## Install

1. Download the latest signed and notarized DMG from [Releases](../../releases).
2. Open `Apace.dmg`, then drag **Apace** onto the **Applications** folder shown beside it.
3. Open Apace from Applications and complete the permission checklist.

## Architecture

A thin `.app` shell on top of one local Swift package (`ApaceKit`) with layered
modules whose dependencies point strictly inward — a pure, framework-free domain at
the centre, system services injected in as adapters. See
[`docs/architecture.md`](docs/architecture.md) and the [decision records](docs/adr/).

```
App shell  →  Features  →  ApaceCore (pure)  ←  Infrastructure adapters
```

## Building from source

Building for personal use is permitted by the license; redistribution is not.

```bash
git clone https://github.com/Lyons800/apace-mac.git
cd apace-mac

swift build      # builds the ApaceKit modules
swift test       # runs the domain tests (no hardware required)
```

To build and run the app itself, generate the Xcode project with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (the `.xcodeproj` is not checked in
— see [ADR-0006](docs/adr/0006-app-shell-and-project-generation.md)):

```bash
brew install xcodegen
xcodegen generate          # writes Apace.xcodeproj from project.yml
open Apace.xcodeproj       # then build & run the Apace scheme
```

Apace lives in the menu bar. By default, hold **Right Option** to dictate and release to
insert the text. Settings lets you change the key, use a hands-free start/stop toggle,
choose a microphone, and run an end-to-end Dictation Health test. Grant Microphone,
Input Monitoring, and Accessibility access when prompted; Apple Speech also needs Speech
Recognition access when selected. Screen-aware commands additionally need Screen Recording,
which can be granted directly from **Settings → Commands & Actions**.

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md). Please do not open a
public issue for security problems.

## Contributing

External code contributions are not accepted under this license — see
[CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature requests are welcome.
