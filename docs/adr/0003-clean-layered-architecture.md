# 3. Clean layered architecture with injected ports

Status: accepted

## Context

A dictation app is mostly system-integration glue (audio, hotkeys, accessibility,
speech) around a small amount of real logic. Done naively, that glue collects in the
`AppDelegate` and the logic becomes impossible to test without hardware. We want the
core logic provable in tests and the system seams swappable.

## Decision

Apply Ports & Adapters (Clean Architecture):

- **`ApaceCore`** holds the domain — the dictation state machine and value types —
  with **zero framework imports**.
- The capabilities it needs (audio, transcription, hotkeys, insertion) are expressed
  as **`ApaceClients`: structs of closures**, not protocols. Adapters provide `.live`
  implementations; tests and previews override individual closures in place.
- Dependencies point strictly inward; the App shell wires concrete adapters to
  abstract ports at a single composition root.

We chose struct-of-closures over protocol-with-mock-classes because overriding one
closure is lighter than writing a conforming type, and value semantics fit Swift's
`Sendable`/concurrency model better than mock objects.

## Consequences

- The full dictation flow is unit-testable with synthetic audio and synthetic
  hotkeys — no microphone, no speech model, deterministic.
- The `AppDelegate` stays ~30 lines.
- Adding or swapping an engine/insertion strategy is a local change behind a port.
