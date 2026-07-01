# Design: Command mode & app-specific commands

Status: proposed (milestone M7)

Command mode lets you *edit and act* by voice, not just insert text: "delete that",
"make this a bullet list", "rewrite this more formally", "send it". It has three layers
of capability the user opts into in order — on-device commands, an LLM text layer, and
an optional screen-vision layer — and it gets smarter over time through **memories** and
**app-specific behaviour**. This document sets the design so the milestone can be built
without re-litigating the fundamentals.

## Principles

1. **Explicit trigger, never per-utterance guessing.** The apps users trust for
   correctness (Wispr Flow, TypeWhisper) never infer whether speech is a command from a
   single stream — they use an explicit trigger. We already have push-to-talk, so
   command mode is a *second* modifier. This gives zero dictation-vs-command ambiguity
   for free.
2. **Local by default; the LLM is the only egress.** The common commands run entirely
   on-device and deterministically. A cloud model is reached only for free-form
   transforms, and that call is the single, visible privacy boundary — consistent with
   Apace being a truly on-device app.
3. **Always previewed, always undoable.** Command mode shows what it's about to do in
   the notch ("Making bullet list…") before acting, and every action is undoable, so a
   rare misfire is a visible, reversible event.

## Two tiers

**Tier 0 — on-device, deterministic (no network).** A small grammar of commands parsed
locally from the transcript. Fast, free, offline, private; handles ~80% of everyday use.

- Formatting: new line/paragraph, bullet/numbered list, heading, bold/italicize,
  title/upper/lower case, code block.
- Editing (on the selection or the last dictation buffer): delete that / last
  sentence / last word, scratch that, capitalize, remove filler words, fix
  spelling/punctuation, join lines.
- Navigation & control: select last sentence/paragraph/all, go to start/end of line,
  stop dictation.
- Actions (keystroke-level, still local): press enter / send it, press tab, copy,
  select all.

**Tier 1 — LLM (bring-your-own key), only in command mode.** Reached only when the
utterance leads with a reserved verb (rewrite / summarize / translate / answer / draft)
or doesn't match a Tier-0 command. Free-form transforms, generation, translation, Q&A.

Routing is deterministic: match the first verb against the Tier-0 grammar; only on a
miss (or an explicit LLM verb) do we spend an LLM call.

**Tier 2 — screen vision (opt-in, off by default).** When the user explicitly enables
it, command mode can capture the current screen the instant they speak, so a command can
act on what's actually in front of them — "add this to my calendar" from a chat, "reply
that I'm in", "what's this error and how do I fix it". This is the most powerful and the
least private layer: a screenshot leaves the device to the user's vision-capable model.
It is therefore **strictly opt-in, per-use visible, and never the default** — the pure
on-device dictation and Tier-0/Tier-1 command paths always work with it switched off.

## Selection semantics

Command mode operates on the current selection if one exists (replace it), otherwise on
the last dictation buffer, otherwise inserts at the cursor. Selection, clipboard, and
frontmost-app context are read via the macOS Accessibility APIs.

## App-specific commands

Behaviour resolves through a priority ladder (adopted from TypeWhisper, the cleanest
published model), evaluated when command mode starts:

```
App + URL   →   URL only   →   App only   →   Always (global)
```

Frontmost app comes from `NSWorkspace.frontmostApplication` (bundle id); for browsers,
the active tab URL via Accessibility. Each matched **profile** carries an appended LLM
prompt fragment, an extra local-command set / vocabulary, and default formatting.
Profiles ship as editable files so the community can add app packs. Built-ins:

- **IDE** (VS Code, Xcode, Cursor): strip trailing punctuation; commands like "add
  comments", "make this async"; prompt fragment "editing source code, return only code".
- **Mail** (Mail.app, Gmail): "draft a reply", "add greeting and signature", "make this
  more professional"; proper capitalization and paragraphs.
- **Slack/Teams**: casual tone, no signature; "make this shorter", "add a TL;DR".
- **Docs/Notion** (URL-matched): outline/heading/table commands; distinct from a generic
  browser, which stays literal.

Learn from superwhisper's known UX bug: an auto-selected profile must always be
manually overridable, with a way to switch back.

## Memories

Command mode gets better the more it's used by remembering durable facts about the user
and their world, so the LLM layers don't start cold every time. A **memory** is a short,
user-owned piece of context — "my padel crew plays Fridays at Quinta do Peru", "sign
emails as *Oisin*", "prefer British spelling", "our repo is Lyons800/apace". Memories are:

- **Local and user-owned.** Stored on-device, viewable and editable in settings, deletable
  individually. Never uploaded anywhere except, when relevant, as part of a Tier-1/Tier-2
  LLM request the user already triggered.
- **Captured explicitly or offered, never silently harvested.** The user can add a memory
  by voice ("remember that…") or in settings; the agent may *suggest* a memory after a
  command and ask to save it, but doesn't record silently.
- **Retrieved by relevance.** Only memories relevant to the current command/app are
  injected into the prompt, keeping requests small and private.
- **Scoped.** A memory can be global or bound to an app profile (an IDE memory of your
  stack, a Mail memory of your signature), composing with the app-specific ladder above.

Memories are what turn command mode from a stateless tool into something that feels like
it knows you — a differentiator none of the competitors currently offer.

## Privacy

- ASR and Tier-0 commands never touch the network; the app is fully functional offline
  apart from Tier-1 verbs.
- A Tier-1 command is a visible boundary crossing: a distinct overlay state for "sending
  to <provider>", first-run consent, and a "never send selection/clipboard" toggle.
- Minimise what leaves: only the relevant buffer/selection and the app *name*, never the
  whole document. App-context inclusion is opt-in per app.
- BYO key in the Keychain; never log prompts/responses; publish the request schema.
  Optional local redaction (emails, keys, card numbers) before any send.

## Phased rollout

- **Phase 0** — the command-mode modifier and the notch "command" state; capture
  selection/clipboard/app context; undo-safe execution. No LLM.
- **Phase 1** — the full Tier-0 on-device command set, previewed in the overlay. A
  strong, private, offline command mode with no cloud dependency.
- **Phase 2** — app-aware profiles: the priority ladder and the four built-ins as
  editable files, with manual override and switch-back.
- **Phase 3** — the Tier-1 LLM layer (BYO key): reserved verbs, per-app prompt
  injection, egress consent + boundary UI, Keychain, redaction.
- **Phase 4** — memories: the local memory store, voice/settings capture, suggest-to-save,
  relevance retrieval into the LLM layers, and app-scoped memories.
- **Phase 5** — screen vision (opt-in): screenshot capture on command, a vision-capable
  model, cross-app actions, with the per-use egress indicator and an off-by-default switch.
- **Phase 6** — full agent: keystroke/action commands and structured actions (create
  issue, capture note), each hard-gated with a confirm step for anything that sends,
  spends, or deletes.
