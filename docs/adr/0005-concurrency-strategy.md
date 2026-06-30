# 5. Concurrency: MainActor by default, AsyncStream at the real-time edges

Status: accepted

## Context

Swift 6 strict concurrency is unforgiving, and a dictation app is genuinely hard
here: a real-time audio thread and a global event tap both produce data far faster
than the UI should redraw, and neither may touch the actor system from its callback.

## Decision

- **UI and Features targets default to `@MainActor`** (Swift 6.2 default isolation).
  UI state, stores, and orchestration run on the main actor with no annotations and
  no data races by construction. The **engine/infrastructure targets do not** — they
  are background/`Sendable` by design.
- **The real-time audio callback and the `CGEvent` tap callback never touch the actor
  system.** They do one cheap thing: hand a `Sendable` value (`AudioChunk`,
  `HotkeyIntent`) to an `AsyncStream.Continuation`. The async side consumes the stream.
- **High-frequency data is throttled before it reaches SwiftUI** — audio levels and
  volatile partials are sampled down on the consuming side, so the render path stays
  cheap regardless of pipeline throughput.

## Consequences

- No locks, allocation, or actor hops on the real-time threads — no glitches or
  priority inversion.
- Backpressure is handled by the stream's buffering policy (drop stale audio rather
  than grow unbounded under ML latency).
- The `nonisolated(unsafe)` / `@unchecked Sendable` escape hatch is confined to the
  single audited buffer-handoff boundary, never used as a general shortcut.
