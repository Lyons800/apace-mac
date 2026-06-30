# Architecture

Apace is a thin macOS `.app` shell on top of one local Swift package, `ApaceKit`,
split into layered modules. The guiding rule is that **dependencies point strictly
inward**: a pure, framework-free domain sits at the centre, and everything that
touches the system is injected in as an adapter.

```
App shell (.app)      @main, MenuBarExtra/Settings/Window scenes, Sparkle,
                      and the composition root that wires the live adapters.
                      Contains almost no logic.
   │
   ▼
Features              One @Observable store + SwiftUI view per surface
                      (DictationModel, SettingsModel, OnboardingModel…).
   │
   ▼
ApaceCore  ★          Pure domain: the dictation state machine and value types.
                      No framework imports — fully unit-testable without hardware.
   ▲
   │  (ports defined as struct-of-closures clients)
   │
Infrastructure        Live adapters, each wrapping a single framework:
  AudioCapture          AVAudioEngine → 16 kHz mono → ring buffer → AsyncStream
  Transcription         WhisperKit / Parakeet / Apple SpeechAnalyzer behind one boundary
  SystemServices        CGEvent-tap hotkey + paste/AX text insertion
```

## Why this shape

- **Pure domain, injected ports.** `ApaceCore` knows nothing about AVFoundation,
  AppKit, or Speech. It expresses what it needs as `ApaceClients` — structs of
  closures. The live adapters provide `.live` implementations; tests swap individual
  closures in place. This is what lets the entire dictation flow run on synthetic
  audio and synthetic hotkeys with zero hardware. ([ADR-0003](adr/0003-clean-layered-architecture.md))
- **One package, layered targets.** Compiler-enforced module walls and fast,
  isolated previews without the ceremony of multiple packages or a project
  generator. ([ADR-0004](adr/0004-single-local-package.md))
- **Real-time safety by construction.** The audio tap and the hotkey tap never touch
  the actor system directly; they hand values to an `AsyncStream` that the async side
  consumes. UI targets default to `@MainActor`; the engine/infrastructure targets stay
  off it. ([ADR-0005](adr/0005-concurrency-strategy.md))

## The core pipeline

```
[hotkey tap] → HotkeyIntent → [coordinator] → AudioCapture → AudioChunk stream
                                   │                              │
                            DictationModel ← throttled partials ──┤ (preview, never inserted)
                                   │                              │
                            TextInserter ← final accurate pass ───┘
```

Two channels: throttled **partials** drive the live notch preview; one accurate
**final pass** produces the text that is actually inserted. They never cross.

## Module map

| Module | Responsibility | Depends on |
| --- | --- | --- |
| `ApaceCore` | Domain: state machine, value types | — |
| `ApaceClients` | The ports (struct-of-closures) | `ApaceCore` |
| `DictationPipeline` | The coordinator: drives the state machine through the ports | `ApaceCore`, `ApaceClients` |
| `AudioCapture` | `AVAudioEngine` adapter | `ApaceClients` |
| `Transcription` | ASR engine adapters | `ApaceClients` |
| `SystemServices` | Hotkey tap + text insertion | `ApaceClients` |
| `DesignSystem` | Theme + notch overlay UI | `ApaceCore` |
| `Features` | `@Observable` stores + views | `ApaceCore`, `ApaceClients`, `DesignSystem` |
