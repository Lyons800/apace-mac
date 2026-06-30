# 6. App shell as a generated Xcode project

Status: accepted

## Context

All the logic lives in the `ApaceKit` Swift package, but a menu-bar app that needs
TCC permissions, an `Info.plist`, a hardened runtime, and notarization can't ship as a
bare package — it needs a real `.app` target, which means an Xcode project.

A hand-maintained `.xcodeproj` is the usual source of merge conflicts and unreviewable
diffs (`project.pbxproj` is machine-written and opaque). We want the project to be
declarative and reviewable.

## Decision

Keep the `.app` target **thin** — only the composition root, the menu-bar scene, and
`Info.plist` — and **generate the Xcode project from a declarative `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen)**. The generated `Apace.xcodeproj`
is git-ignored; `project.yml` is the source of truth and the thing that gets reviewed.

The app is **not sandboxed** — a global `CGEvent` tap and Accessibility access aren't
available to sandboxed apps — and runs under the **hardened runtime** so it can be
notarized for distribution.

This refines [ADR-0004](0004-single-local-package.md): that decision kept the *package*
free of a generator, which still holds. The generator earns its place only at the
`.app` boundary, where `pbxproj` churn is the real cost.

## Consequences

- `project.yml` is small and human-readable; the app's configuration is reviewable in
  pull requests.
- Cloning isn't enough to open the app in Xcode — you run `xcodegen generate` first.
  This is documented in the README and wired into CI.
- The package remains the centre of gravity: the app target depends on its products
  and adds almost no code of its own.
