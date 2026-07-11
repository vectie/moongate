# CCS Parity Ledger

MoonGate tracks CC Switch behavior deliberately. This ledger records the
reviewed upstream commit, the corresponding MoonGate implementation, and
intentional differences. It is not a commitment to copy CCS UI architecture or
remove MoonGate's additional framework and Moon suite integrations.

## Reviewed Baseline

- Canonical repository: `farion1231/cc-switch`
- Canonical `main`: `98ccde0050f33a1bc8b16b96287a0b6f582c5d12`
- Configured fork `vectie/ccs` `main`: same commit
- Reviewed: 2026-07-10
- CCS version at baseline: `3.16.5`

## Recent Changes

| CCS commit | Behavior | MoonGate disposition | MoonGate evidence |
| --- | --- | --- | --- |
| `98ccde00` | Persist usage dashboard refresh interval | Implemented. Settings persist atomically and the Rabbita dashboard accepts `0`, `5000`, `10000`, `30000`, or `60000` ms. A deeper selector remains UI-deferred for Lepusa. | `22667f3`, settings and UI asset tests |
| `95c917b3` | Zhipu Team Plan quota | Implemented with explicit `zhipu_team`, required organization/project IDs, `?type=2`, and BigModel headers. | `69989c8`, `coding_plan_wbtest.mbt` |
| `3538b392` | Claude fallback model 1M option | Backend capability already supported across Claude model mapping and 1M normalization. Presentation control remains Lepusa-deferred. | Claude provider/model tests |
| `88d5ffba` | Parse and merge Codex common config with a real TOML implementation | Open gap. MoonGate's focused MCP TOML reader must be replaced by a structured parser before broader Codex config writes are release-safe. | Phase 3/4 backlog |
| `94fc1cc0`, `11c173c7`, `8b1ce764` | Isolate MCP import failures and fail closed on invalid Codex TOML | Open gap. MoonGate imports Claude, Codex, and Gemini sequentially but does not return a per-app result report. | Phase 4 backlog |
| `1f36f0cf`, `6d2ee247`, `473c2aaa`, `93f56198` | Codex common-config and MCP reprojection correctness | Needs behavior-level comparison after structured TOML parsing lands. | Phase 4 backlog |
| `e78aa8a7`, `e191af4a` | Keep OpenClaw, Hermes, and OpenCode live-provider state synchronized | Supported integrations are preserved. More process-level takeover/import tests are required before claiming exact parity. | Existing provider/live routes and adapter tests |
| `2df2212c` | Retry transient quota failures and retain last good data | Implemented server-side with a ten-minute scoped last-good window for network errors, timeouts, 429, and 5xx failures. Authentication and parse failures remain immediate. | `fff93cc`, `usage_cache_wbtest.mbt` |
| `468c93d4` | Harden release supply chain | Partially covered by warning-denied CI. Signing, provenance, packaged Lepusa smoke, and release artifact verification remain open. | `.github/workflows/ci.yml`, Phase 4 backlog |
| `52534618` | Media fallback for GLM image rejection | MoonGate has media fallback and rectifier controls; exact GLM 5.2 process-level parity remains to be tested. | Claude media tests, Phase 4 backlog |
| `8f018a2d` through `9f7642cc` | Project profile snapshots and takeover-safe switching | Intentional product difference for now. MoonGate uses provider routes, live config, import/export, and Moon suite state instead of copying CCS project-profile UI. | Provider/config/suite contracts |

## Review Procedure

1. Fetch canonical CCS into `../ccs` without changing its working branch.
2. Record the new canonical commit and list commits since the baseline above.
3. Classify each change as implemented, intentionally different, UI-deferred,
   obsolete compatibility, or open correctness work.
4. Port behavior and failure semantics, not React/Tauri structure.
5. Add MoonBit tests and update this ledger in the same commit.

Active framework support remains a product feature: Codex/OpenAI-compatible,
Claude/Anthropic-compatible, Claude Desktop, OpenClaw, Hermes, Gemini,
OpenCode, GitHub Copilot, and MoonClaw/MoonBook/MoonTown/MoonDesk adapters.
