# 4. One local Swift package, not multi-package or a project generator

Status: accepted

## Context

We want compiler-enforced module boundaries (folder groups give none) and fast,
isolated SwiftUI previews, without paying for tooling a solo project doesn't need.

## Decision

Put all logic in **one local Swift package (`ApaceKit`) with layered targets**, under
a thin `.app` Xcode target. Do **not** split into a package-per-feature, and do
**not** adopt Tuist/XcodeGen on day one.

A single package with many targets scales cleanly well past the size this app will
reach for years; project generators and multi-package layouts exist to tame
multi-team `.xcodeproj` conflicts and implicit-dependency flakiness we don't have.

## Consequences

- Each module has an enforced `internal` wall — the main defence against a solo
  codebase rotting into a ball of mud.
- Small targets build and preview fast, which is the real day-to-day bottleneck.
- Clear upgrade trigger: revisit a multi-package or Tuist setup only if build times
  balloon and we want binary caching.
