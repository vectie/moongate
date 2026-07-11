# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Current Product Direction

- MoonGate is in a feature-testing phase. Prefer testing real proxy, usage,
  suite discovery, install/config, and failure workflows before broad structural
  cleanup.

- Preserve active framework integrations. Codex/OpenAI-compatible clients,
  Claude/Anthropic-compatible clients, Claude Desktop, OpenClaw, Hermes, Gemini,
  OpenCode-style logs, GitHub Copilot, and MoonClaw/MoonBook/MoonTown/MoonDesk
  adapters are supported features, not stale compatibility.

- Cleanup should target stale old-version aliases, deprecated command shims,
  dead local probes, and unnecessary compatibility paths. Do not remove active
  framework support unless explicitly requested.

- Lepusa is the frontend/desktop framework for MoonGate. The checked-in
  `lepusa.json` is the standalone app boundary and should wrap MoonGate's
  localhost gateway until a deeper Lepusa/Rabbita UI rewrite is worth doing.
  Backend, suite, proxy, usage, and test coverage work can continue without
  replacing the current gateway-served dashboard payload.

- Use published Rabbita and Lepusa packages in `moon.mod`. Do not wire MoonGate
  to local `../rba` or `../lepusa` workspaces except for temporary inspection
  or upstream validation.

- Known structural cleanup backlog: split remaining large files such as
  `cmd/main/cmd_misc.mbt`, `gateway_provider.mbt`,
  `gateway_claude_anthropic.mbt`, and `gateway_usage.mbt` when tests expose
  friction or during release hardening.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. For solid, well-defined results (e.g. scientific computations),
  prefer assertion tests. You can use `moon coverage analyze > uncovered.log` to
  see which parts of your code are not covered by tests.

## Feature Test Matrix

- Core validation: `moon info`, `moon fmt`,
  `moon check --target native --deny-warn`, and
  `moon test --target native --deny-warn`.

- Suite adapter validation when touching discovery/contracts:
  `../moonclaw` `moon test plugin/moonstat --target native --deny-warn`,
  `../moondesk` `moon test plugin/moonstat --target native --deny-warn`,
  `../moontown` `moon test src/plugin/moonstat --target native --deny-warn`,
  and `../moonbook` `moon test plugins/moonstat --target native --deny-warn`.

- Feature areas to exercise: proxy routing, streaming, usage accounting,
  provider management, suite status discovery, install/config flows, and
  failure handling.
