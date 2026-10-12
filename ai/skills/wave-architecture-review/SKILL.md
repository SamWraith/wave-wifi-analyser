---
name: wave-architecture-review
description: Review Wave Flutter architecture and code quality, or guide an authorized substantial refactor across widgets, Riverpod state, repositories and async boundaries.
---

# Wave architecture review

Read the root `AGENTS.md` and relevant sections of `ai/rules/flutter-architecture.md`. These are the source of project invariants; do not duplicate them in reports.

## Scope and evidence

For a review request, inspect and report without editing application code. For an authorized refactor, fix the relevant findings while preserving product behavior. The skill itself does not authorize commits, pushes, deployment or expanded features.

Use git status/diff and focused reads to identify changed responsibilities. Trace callers and tests before recommending extraction. Review surrounding lifetime/persistence paths when they determine correctness; do not ingest raw APK evidence or unrelated projects.

Check widget ownership/reuse, selective provider subscriptions, repeated derived work, immutable input contracts, controller synchronization, early preference edits, storage errors, stale asynchronous replies, cancellation and chart repaint inputs. Inspect the native bridge only when its contract/lifecycle matters.

Prioritize observable bugs and concrete maintenance/performance risks. Explain why a long function mixes responsibilities; do not impose arbitrary line limits or report unmeasured jank as fact. Keep existing abstractions where they work.

## Refactor and verify

Agree file ownership when using authorized parallel agents. Publish interface changes before dependent edits. Extract coherent pages/components, move logic to the responsible layer and add behavior-based regressions for changed paths. Keep visual extraction distinct from failure-handling changes when practical.

Use `ai/scripts/check.sh [relevant test paths]`; broad refactors run the full suite. Add warranted platform/build checks and inspect the final diff. Use an independent review agent when available and authorized, otherwise state review limitation. Recheck only when a new change, failure or unresolved concern warrants it.

## Result

Provide prioritized findings with exact file/line, effect, minimal fix and needed regression coverage. Record a dated report in `docs/` when the user requests a durable review. For fixes, list which original findings are resolved and any remaining ones. State checks actually run and limits; do not call a review clean while actionable findings remain.
