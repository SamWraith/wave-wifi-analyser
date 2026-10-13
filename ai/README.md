# AI guidance

The root [AGENTS.md](../AGENTS.md) is the entrypoint. This folder contains project-local guidance; it does not install global agent configuration.

| Resource | Read/use when |
| --- | --- |
| [Flutter architecture rules](rules/flutter-architecture.md) | Changing Dart/Flutter application code, including required interaction-quality checks for UI details; read relevant sections on follow-up tasks. |
| [Architecture review skill](skills/wave-architecture-review/SKILL.md) | Reviewing structure/quality or implementing a substantial refactor. |
| [Validation script](scripts/check.sh) | Running repeatable format, analysis and unit/widget checks. |

Keep rules authoritative in one place. Add a skill only for a repeated workflow needing project-specific decisions; avoid generic tutorials, duplicate rules, empty agent roles and copied manuals. Update the entrypoint/map when responsibilities move. Validation reports belong in `docs/`, not in instruction files.
