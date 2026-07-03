# Command mode: controlling the Mac (computer use)

The goal: command mode shouldn't only *answer* — it should *act*. "Message André that
I'm running late", "open my calendar", "reply to this". This is a computer-use agent
loop, the same shape Codex and Clicky use.

## The loop

1. **Capture** — screenshot the screen (`ScreenCaptureClient`).
2. **Think** — send the goal + screenshot to Claude with its computer-use tool. Claude
   replies with an action (click at x,y / type / key / scroll) or "done".
3. **Act** — translate the action to a `ControlAction` and execute it
   (`ComputerControlClient`, CGEvent injection).
4. **Repeat** — screenshot again, feed it back, until Claude says done or a step cap is
   hit.

```
speak → transcribe → [ screenshot → Claude → ControlAction → execute ]* → done
```

## Pieces

| Piece | Layer | Status |
|-------|-------|--------|
| `ControlAction` + `ComputerControlClient` (the "hands") | ApaceClients / SystemServices | ✅ built |
| `ScreenCaptureClient` (the "eyes") | ApaceClients / SystemServices | ✅ built |
| Computer-use agent loop (the "brain") | new `Automation` module | ▢ next |
| Confirmation gate for risky actions | Automation + notch UI | ▢ next |
| Command-mode wiring (route actionable commands to the loop) | DictationPipeline / Features | ▢ next |
| Fast paths for common apps (Messages/WhatsApp via AppleScript/URL) | SystemServices | ▢ optional |

## Decisions (locked)

- **Model:** Claude Sonnet with the computer-use tool.
- **Safety gate:** confirm before *risky/outward* actions only (send, delete, post, buy);
  navigation (open, click, scroll, type into a field) runs freely. v1 gates at the task
  level — an outward-looking goal ("message …", "reply …", "delete …", "buy …") shows a
  Run/Cancel confirmation before the loop touches anything; per-action gating can follow.

## Safety (non-negotiable)

An LLM moving the mouse can do the wrong thing. Rules baked into the loop:

- **Confirm before irreversible / outward actions** — sending a message, deleting,
  posting, purchasing. The notch shows "About to: send '…' to André" with Run / Cancel;
  nothing outward happens without a press.
- **Step cap** — a hard limit on actions per command so a confused loop can't run away.
- **Visible + interruptible** — the notch shows each step; releasing / Esc aborts.
- **Opt-in** — control is off by default and gated behind an explicit setting, separate
  from "answer" command mode.

## Cost

Each step is a Claude vision call. A 5-step task ≈ 5 calls. Use a fast model
(Sonnet-class) and cap steps. The user brings their own key.

## Model

Claude's computer-use tool (`computer_20250124`) with a Sonnet-class model. The tool
defines the action schema; we implement the executor. Screenshots go back as tool
results (base64 PNG, downscaled).
