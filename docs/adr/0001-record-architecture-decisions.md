# 1. Record architecture decisions

Status: accepted

## Context

We want a durable record of the significant choices behind Apace — not just what the
code does, but why it's shaped the way it is. Decisions made implicitly tend to be
re-litigated or quietly eroded.

## Decision

We will keep lightweight Architecture Decision Records in `docs/adr/`, one file per
decision, numbered sequentially. Each captures Context, Decision, and Consequences.
A decision, once accepted, is not edited; if it changes we add a new record that
supersedes it.

## Consequences

- New contributors (and future-us) can understand the reasoning at a glance.
- The cost is a few minutes per significant decision — cheap relative to the clarity.
