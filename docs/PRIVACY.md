# Privacy Policy

**On-device by default.** Apace collects nothing about you — no accounts, no analytics,
no servers we run that see your data. This is the canonical policy; the public version
lives at https://apace.so/privacy.

## On-device by default

Your voice is recorded, transcribed, and cleaned up entirely on your Mac. Audio never
leaves your computer. The speech models (Parakeet, Apple SpeechAnalyzer, WhisperKit) and
the default cleanup (Apple Intelligence, or a small local model) all run locally on
Apple Silicon.

## No analytics or telemetry

Apace includes no analytics SDKs, crash reporters, or telemetry. We don't know how many
people use Apace, how often, or what you say.

## Optional cloud features — opt-in, your own key

Apace lets you *choose* a cloud model for cleanup, and (in the experimental Command Mode)
for understanding your screen. **These are off by default.** If you enable one and add
your own API key, the relevant text — your transcript, or a screenshot — is sent directly
from your Mac to the provider you picked (Anthropic, Groq, OpenAI, or Google), under that
provider's privacy policy, using your key. Apace never sees it and never proxies it.
Command Mode's risky actions always ask first.

## The only automatic network requests

Even with cloud features off, Apace makes two requests: (1) downloading a speech model on
first use, and (2) checking for updates via Sparkle. Neither sends any personal data.

## Your data stays on your Mac

Transcription history is stored in `~/Library/Application Support/Apace/`; any API keys
you add live in your macOS Keychain. Delete them any time. We never see either.

## Free and open source

Apace is free and its source is public, so you can verify all of the above yourself.

_Last updated: July 2026 · hello@apace.so_
