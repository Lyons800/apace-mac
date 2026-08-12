# Command intent router — design

**Date:** 2026-07-28
**Status:** Approved (routing approach and paste-only behavior confirmed by Oisín)

## Problem

Command mode currently has two hard-wired paths. With "Let it control my Mac" off,
every command is answered in the notch. With it on, every command drives the
multi-step computer-use loop — even "translate this message to Portuguese", which
is really one LLM call plus a paste. There is no path that reads the focused text
field, transforms its text, and inserts the result.

Target user stories:

1. Focused on a WhatsApp composer with an English draft, say *"send this message
   in Portuguese"* → the draft is replaced with the Portuguese translation.
   Apace does **not** press Enter — sending stays one keystroke away (approved:
   paste only, no auto-send, no confirm dialog).
2. Say *"open WhatsApp and send João a message that I'm running late"* → the
   computer-use loop drives the Mac (already merged; needs control enabled).
3. Say *"what does this error mean?"* → a plain answer in the notch, as today.

## Approach (approved)

A **smart router**: one LLM call classifies *and fulfills* in a single round
trip. It receives the transcribed request, the focused field's text/selection
(read via Accessibility), and a screenshot (when the provider supports images),
and replies with structured JSON:

- `{"action": "answer", "text": …}` → shown in the notch (unchanged behavior).
- `{"action": "insert", "text": …, "replace": bool}` → pasted into the focused
  field via the existing `TextInserter`; `replace: true` first selects the
  field's content (⌘A) so a transformed draft replaces the original.
- `{"action": "control"}` → escalate to the computer-use loop. If the control
  toggle is off, the notch explains how to turn it on instead.

Rejected alternatives: routing everything through computer-use (slow, costly,
moves the mouse for text edits) and local keyword rules (brittle across
phrasings and languages).

## Components

| Piece | Module | Responsibility |
| --- | --- | --- |
| `CommandDecision` | `ApaceCore` | Pure value: `answer(String)` / `insert(text:replacesDraft:)` / `control` |
| `FocusedField` + `FocusClient` | `ApaceClients` port, `SystemServices` live | Read the focused element's selected text, value (capped), and app name via AX |
| `CommandRouterClient` | `ApaceClients` port, `TextCleanup` live | Build the routing prompt, call the chosen `VisionProvider`, parse the JSON reply (pure, tested parser; tolerant of fenced/prefixed JSON) |
| `CommandController` routing | `DictationPipeline` | Replace `runAnswer` with route → act on the decision |
| Wiring | `App/Composition.swift` | `focus: .live`, `router: .live(apiKey:)`, `inserter: .live`, `control: .live` |

`CommandClients` gains `focus`, `router`, `inserter` (same `TextInserterClient`
dictation uses), and `control` (for the ⌘A select-all before a replace).

## Flow

After transcription (silence/empty gates unchanged):

1. Gather context: `focus.focusedField()` always; screenshot only when
   `usesVision && provider.supportsImages` (unchanged rule).
2. `router.route(request, field, image)`.
3. Act:
   - `.answer` → `emit(.answer(text))`.
   - `.insert` → if `replacesDraft`, `control.perform(.key ⌘A)`; then
     `inserter.insert(text)`; emit a short confirmation in the notch. Never Enter.
   - `.control` → `controlEnabled ? runControl(request) : emit(.answer("…turn on
     'Let it control my Mac' in Settings → Command."))`.
4. Any router error → fall back to the existing `vision.respond` answer path, so
   a bad JSON day never breaks plain Q&A.

## Error handling

- AX read fails / no focused field → route with `field: nil`; the model still
  has the screenshot. An `insert` decision with no focused field still pastes —
  identical risk profile to dictation itself.
- Unparseable router reply → treat the raw reply as an `answer` when it looks
  like prose; otherwise fall back as above.
- On-device provider → text-only routing (no screenshot), its own
  `LanguageModelSession` with router instructions.

## Testing

- Parser: pure JSON-extraction tests (fenced, prefixed, malformed).
- `CommandController`: fake router — insert pastes and never runs automation;
  replace issues ⌘A before pasting; control decision starts the loop only when
  enabled, otherwise explains; router failure falls back to the answer path.
- Existing suites must stay green; `FocusClient.live` is a thin AX adapter left
  to manual testing like the other live adapters.

## Out of scope (YAGNI)

Auto-send / confirm-then-send, AX `setValue` writing, multi-display capture,
per-app routing rules, streaming router replies.
