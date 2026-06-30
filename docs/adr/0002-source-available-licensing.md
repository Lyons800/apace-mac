# 2. Source-available, proprietary licensing

Status: accepted

## Context

Apace is a commercial product, but we want the code public so users can read and
trust it (privacy claims are only credible if auditable). "Public" must not mean
"free to fork, modify, and ship as a competitor." We surveyed the source-available
landscape: bespoke "all rights reserved", PolyForm, the Functional Source License
(FSL), the Business Source License (BUSL), and the Elastic License v2.

## Decision

License under **PolyForm Strict 1.0.0**. It is a lawyer-drafted, peer-reviewed,
SPDX-recognised license that grants essentially nothing beyond reading and personal/
noncommercial use — explicitly no distribution and no derivative works.

We reject:

- **FSL / BUSL** — they time-bomb to a permissive open-source license (MIT/Apache)
  after a fixed window. We do not want the code to become free.
- **Elastic License v2** — too permissive; it only blocks offering the software as a
  managed service, which is no protection for a downloadable app.
- **A bespoke "all rights reserved" license** — legally valid but draws diligence
  skepticism and lacks PolyForm's patent and clarity language.

## Consequences

- The repo is labelled "source-available, proprietary — not open source."
- We do not accept external code contributions (reflected in `CONTRIBUTING.md`).
- GitHub displays the recognised license, which is itself a credibility signal.
