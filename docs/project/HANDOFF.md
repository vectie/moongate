# MoonGate project handoff

## Cluster Mac UI and branding — 2026-11-24

Working style and UI/UX guidance now matches MoonTown's rules, with MoonGate's
own stylesheet path. Preserve the existing framework adapters and app boundary.
The overview retains the real next action and gateway/routing states, while
technical summaries and the setup-progress rail are collapsed disclosures.
Their existing IDs and handlers remain intact. The new Technical details label
has a Chinese translation. At narrow widths, the primary action must reset its
desktop grid position; otherwise it creates an implicit overflowing column.
The narrow sidebar clips its outer overflow while its navigation still scrolls.

`lepusa.rabbita.json` embeds generated root HTML. Regenerate it with the built
CLI's `suite lepusa-rabbita --write` after view changes; otherwise manifest
parity tests correctly fail. Native tests: 1,209 passed, including 13 UI asset
tests. Existing compiler warning debt remains; this is not a warning-free gate.

Installed on the M4/macOS 15 cluster Mac at 192.168.2.195 from clean `ebf4e1a`
plus this focused UI delta, excluding unrelated provider/chat worktree edits.
The service and Lepusa runtime target macOS 15. Strict deep signature checks
pass. Prior app copies and receipts are in the remote user's
`moonsuite-install-20261124` directory. Database/provider credentials were not
changed, and no external model request or app binding was performed.

The app icon is generated from `assets/moongate-macos.svg` with transparent
padding. Quick Look thumbnails can flatten that padding to white even when a
PNG has an alpha channel. Use `rsvg-convert` with no background color. The
sibling Mooncast `scripts/generate_macos_icon.mbtx` checks all four corner alpha
values at all ten ICNS sizes; installed icon hashes matched these verified
outputs. Do not infer transparency from `hasAlpha` alone.

Mac native Lepusa windows can remain alive after SIGTERM stops their services.
Quit before replacing a bundle. The scoped installer stops only its own four
app process trees, preserves rollback bundles, and never treats an absent
service as proof that the native window exited. Remote served UI was checked
through SSH forwarding; direct interaction with the remote WKWebView was not
available from this machine.

Launchpad follow-up: its database contained a second MoonGate entry bookmarked
to the old `backups/MoonGate.app`. Staged, rollback and old disk-image copies
were unregistered from LaunchServices; the canonical apps were re-registered
and Dock restarted without resetting layout. LaunchServices now lists only
the canonical copies, but Launchpad retained its duplicate database row at the
follow-up check. Do not claim visible cache/duplicate cleanup without a remote
screenshot. Backups and Launchpad layout were preserved; the installed ICNS
hash still matches the verified transparent output.
