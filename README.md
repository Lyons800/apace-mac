# Apace

> On-device dictation for macOS — type at the speed of thought.

Hold a key, speak, release. Your words appear in any app — transcribed entirely on
your Mac, with a live transcript in the notch. A voice command mode (in progress)
lets you *act* on your voice, not just type.

> **Source-available, proprietary — not open source.** The code is public so you can
> read, audit, and trust it. See [LICENSE](LICENSE) (PolyForm Strict 1.0.0).

## Features

- **System-wide dictation** — global hotkey, push-to-talk / toggle / hybrid.
- **On-device & private** — no telemetry, no cloud round-trip; audio never leaves your Mac.
- **Multiple engines** — WhisperKit (CoreML), Parakeet, and Apple's SpeechAnalyzer, behind one boundary.
- **Live notch overlay** — a Dynamic-Island-style transcript and waveform while you speak.
- **Command mode** *(in progress)* — a spoken command that acts on your Mac, not just types.

## Requirements

- macOS 14.0+ (Apple SpeechAnalyzer engine requires macOS 26+).
- Apple silicon recommended for on-device models.

## Install

Download the latest signed & notarized DMG from [Releases](../../releases). *(Coming with the first release.)*

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

Apace lives in the menu bar. Hold **Right Option** to dictate and release to insert the
text; grant Microphone, Speech Recognition, and Accessibility access when prompted.

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md). Please do not open a
public issue for security problems.

## Contributing

External code contributions are not accepted under this license — see
[CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature requests are welcome.
