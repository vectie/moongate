# Lepusa desktop app release handover

This is the reusable release playbook for a MoonBit application packaged as a
native desktop app with Lepusa and a Rabbita UI. It records the complete path
from an app repository to a tested GitHub release, including the product and
data-consistency checks that packaging alone cannot prove.

Use this document for the next Moon app. Replace every value inside angle
brackets. Never copy MoonGate-specific backend behavior into Lepusa: Lepusa is
the general desktop shell, lifecycle, bridge, bundling, and packaging layer;
the application owns its domain behavior.

## Definition of done

A launch is ready only when all of these are true:

- The app uses published Rabbita and Lepusa package versions in `moon.mod`.
- `lepusa.json` describes the standalone app, resources, window, capabilities,
  localhost service, icon, and signing configuration.
- The central product logo is represented in the web UI and as a padded,
  rounded macOS `.icns` icon.
- Every page, button, link, form, empty state, loading state, error state, and
  narrow layout has been exercised through the actual UI.
- Labels explain what the user can do; a guide explains every page and every
  unfamiliar phrase.
- Displayed counts, active selections, provider health, saved credentials,
  deletion, ordering, and cross-page data agree with the backend after refresh
  and restart.
- At least two materially different real integrations have passed, normally an
  OAuth provider and an API-key provider.
- The full MoonBit test gate and any integration adapter suites pass.
- Both the app service executable and `lepusa-runtime` declare the intended
  minimum macOS version.
- The DMG contains the app and an `/Applications` shortcut.
- An app copied from the DMG launches, reaches its readiness endpoint, keeps
  user data outside the app bundle, and remains code-signature-valid after
  first launch.
- The intended commit is on the intended GitHub branch; the tag points to that
  same commit; the DMG and checksum are present on the GitHub release.
- No API key, OAuth token, credential cache, private configuration, or secret
  test fixture appears in source control, logs, screenshots, templates, the
  app bundle, or release notes.

## Quick release sequence

For an experienced maintainer, the whole flow is:

1. Confirm repository scope, product identifiers, version, GitHub remote, and
   minimum macOS.
2. Finish `lepusa.json`, central-logo import, macOS icon, in-app Guide, and
   `docs/UI_GUIDE.md`.
3. Run Lepusa `publish-plan` and strict `verify`.
4. Exercise every page and action through the UI at normal and narrow widths.
5. Trace create/edit/activate/delete and all summary counts through refresh and
   restart; run two real provider/integration paths.
6. Run `moon info`, `moon fmt`, strict native check, full native tests, and
   affected adapter suites.
7. Release-build both the app and Lepusa runtime with the chosen deployment
   target; inspect both with `vtool`.
8. Materialize the bundle, release plan, package plan, DMG, and install-smoke
   plan.
9. Mount the DMG, copy the app out, launch it, check readiness, user-data
   placement, process cleanup, and pre/post-launch signatures.
10. Review, commit, and push only intentional files to the actual GitHub remote.
11. Generate the checksum, publish the GitHub release, and confirm branch/tag
    hashes and uploaded asset digests.
12. Preserve evidence and move exact temporary directories to Trash.

The remaining sections define each gate and its failure conditions.

## 1. Keep the architecture boundary clear

The app repository owns:

- domain behavior and localhost service;
- UI pages and application terminology;
- provider templates and integrations;
- application storage and migrations;
- app-specific tests and documentation;
- `lepusa.json` and bundled resources.

Lepusa owns only general desktop concerns:

- native window and system WebView lifecycle;
- localhost-service supervision and readiness waiting;
- bridge, plugin, and capability enforcement;
- bundle manifests and resource copying;
- platform packaging, signing, notarization hooks, and install-smoke plans.

Rabbita owns the reusable UI/runtime vocabulary used by the application. Keep
published Rabbita and Lepusa dependencies in the app's `moon.mod`. A nearby
Lepusa checkout may be used temporarily to build the runtime, exercise a new
packager, or validate an upstream framework fix, but must not become a local
path dependency in the released app.

## 2. Prepare the app repository

Before changing UI or packaging, record the intended values:

| Item | Example shape |
| --- | --- |
| Repository | `owner/product` |
| App identifier | `dev.company.product` |
| Product name | Human-readable title |
| Executable package | `cmd/main` |
| Service executable | `_build/native/release/build/cmd/main/main.exe` |
| Window label | Usually `main` |
| Localhost port | A stable, unclaimed port |
| Initial UI path | A human-readable app page |
| Readiness path | Usually `/health` |
| Minimum macOS | Deliberate deployment target, currently `11.0` for the Moon apps |
| GitHub remote | Verify its name; do not assume `origin` is GitHub |
| Release tag | For example `v0.1.0-preview.1` |

Inspect the repository first:

```sh
git status -sb
git remote -v
rg --files
```

Do not discard a dirty working tree. Existing changes belong to the user until
proven otherwise. Stage only files that belong to the launch.

## 3. Create and validate `lepusa.json`

The manifest is the standalone desktop boundary. A localhost-backed app has a
shape like this:

```json
{
  "identifier": "dev.company.product",
  "productName": "Product",
  "version": "0.1.0",
  "icon": "assets/product.icns",
  "signing": {
    "identity": "-"
  },
  "runtime": {
    "backend": "system-webview",
    "assetProtocol": "lepusa",
    "devtools": false
  },
  "bundleResources": [
    {
      "source": "public",
      "path": "public"
    },
    {
      "source": "_build/native/release/build/cmd/main/main.exe",
      "path": "product-server",
      "executable": true
    }
  ],
  "window": {
    "label": "main",
    "title": "Product",
    "width": 1180,
    "height": 780,
    "resizable": true,
    "source": {
      "localhost": {
        "port": 15721,
        "path": "/ui",
        "readinessPath": "/health",
        "command": ["product-server", "start"]
      }
    }
  },
  "plugins": [
    { "name": "localhost" },
    { "name": "serviceDiscovery" },
    { "name": "opener" }
  ],
  "capabilities": [
    {
      "name": "main",
      "windows": ["main"],
      "permissions": ["localhost", "service-discovery", "opener"]
    }
  ]
}
```

Grant only plugins and permissions the app uses. Confirm that:

- the service command names the bundled path, not a developer-machine path;
- the readiness endpoint returns success only when the service is usable;
- the initial path is a real UI page, not JSON, logs, or Prometheus text;
- every resource source exists after a release build;
- `devtools` is disabled for a public release unless intentionally required;
- the identifier is stable, because it controls macOS identity and app-data
  placement.
- the manifest version, release title, artifact name, and tag describe the same
  version; update them together.

Run Lepusa's non-writing plan early:

```sh
cd <lepusa-root>
moon run cmd/main --target native -- publish-plan macos \
  --project <app-root>/lepusa.json
moon run cmd/main --target native -- verify macos --strict \
  --project <app-root>/lepusa.json
```

## 4. Add product logos correctly

The canonical Moon product logos live in:

```text
<vectie-site-root>/docs/public/logos/<product>.svg
```

Keep three distinct assets when appropriate:

1. The canonical SVG copied into the app for web/UI use.
2. A macOS-specific 1024×1024 SVG or PNG with safe padding, rounded rectangle,
   and subtle shadow.
3. The generated `.icns` referenced by `lepusa.json`.

Do not simply stretch the canonical SVG edge-to-edge. macOS expects visual
padding and a rounded icon silhouette. The artwork itself should contain the
rounded background; Finder should not be expected to crop a square image for
the app.

Recommended visual checks:

- the outer artwork is inset by roughly 6–10% of the canvas;
- the corner radius is visually consistent with current macOS icons;
- important marks remain inside the safe area at 16×16;
- transparency exists outside the icon silhouette;
- the icon is recognizable in Finder, the Dock, the title bar, and the DMG;
- the web logo and app icon clearly belong to the same product.

One repeatable macOS conversion flow is:

```sh
APP_ROOT=<absolute-app-root>
ICON_WORK=$(mktemp -d /tmp/product-icon.XXXXXX)

qlmanage -t -s 1024 -o "$ICON_WORK" \
  "$APP_ROOT/assets/product-macos.svg"

mkdir "$ICON_WORK/product.iconset"
sips -z 16 16 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_16x16.png"
sips -z 32 32 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_16x16@2x.png"
sips -z 32 32 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_32x32.png"
sips -z 64 64 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_32x32@2x.png"
sips -z 128 128 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_128x128.png"
sips -z 256 256 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_128x128@2x.png"
sips -z 256 256 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_256x256.png"
sips -z 512 512 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_256x256@2x.png"
sips -z 512 512 "$ICON_WORK/product-macos.svg.png" \
  --out "$ICON_WORK/product.iconset/icon_512x512.png"
cp "$ICON_WORK/product-macos.svg.png" \
  "$ICON_WORK/product.iconset/icon_512x512@2x.png"
iconutil --convert icns --output "$APP_ROOT/assets/product.icns" \
  "$ICON_WORK/product.iconset"
```

Open or render the final `.icns` and inspect it. A successful `iconutil`
command proves only that the file structure is valid, not that the icon looks
correct.

## 5. Make every screen understandable

Every released app should contain both:

- an in-app **Guide** reachable from the main navigation; and
- a repository document such as `docs/UI_GUIDE.md`.

For every page, document:

- the question the page answers;
- the normal first action;
- what each metric or status means;
- what changes when a button succeeds;
- which controls are advanced and when they are useful;
- where data comes from and how fresh it is;
- what an empty state means;
- how to recover from an error.

Avoid internal nouns when a user-facing phrase exists. For example, “Detected
command-line apps” is clearer than “Tools” when the UI means installed programs.
If a technical term must remain, add a one-sentence explanation beside it and a
longer glossary entry. Distinguish similarly named concepts, such as installed
tools versus model-callable AI tools.

Machine-readable endpoints must not masquerade as app pages. Metrics, logs,
developer JSON, and status files should normally have **Copy URL** or
**Download** actions. Clicking a normal navigation or summary card must remain
inside the app and provide a way back.

## 6. Test the UI from UI to UI

Source-level tests are necessary but do not replace interacting with the real
app. Start the packaged UI or its exact localhost equivalent, then use browser
or computer control to exercise it as a user would.

Create a page inventory before testing:

| Page | Purpose understood | All actions | Empty/error state | Refresh/restart | Narrow width |
| --- | --- | --- | --- | --- | --- |
| Page 1 | ☐ | ☐ | ☐ | ☐ | ☐ |
| Page 2 | ☐ | ☐ | ☐ | ☐ | ☐ |
| Guide | ☐ | ☐ | ☐ | ☐ | ☐ |

For every page:

1. Navigate through visible UI controls, never by typing the destination URL.
2. Confirm exactly one page and one navigation item are active.
3. Click every button, link, row action, menu, tab, disclosure, and card.
4. Confirm success feedback describes what actually changed.
5. Trigger validation and service errors deliberately; confirm the UI remains
   usable and explains recovery.
6. Use browser Back and Forward after internal navigation.
7. Refresh the page and restart the service; confirm saved state returns.
8. Test a narrow desktop viewport, currently 720×900, and confirm there is no
   document-level horizontal overflow.
9. Capture screenshots of the primary page, guide, and narrow layout.
10. Inspect the browser console and failed network requests.

For every form:

- test create, cancel, edit, save, and delete;
- test blank, malformed, duplicate, and valid values;
- confirm keyboard focus and disabled/loading states;
- click Save twice and confirm idempotent behavior;
- verify secrets persist without being returned to the UI;
- confirm a destructive action disappears from every relevant page after a
  re-fetch, not merely from the current DOM.

For every displayed value:

- identify its source endpoint or stored record;
- compare the UI value with the backend response;
- define whether it is live, cached, estimated, or historical;
- check singular/plural and zero-state wording;
- check sorting and tie-breaking are deterministic;
- ensure a summary count is derived from the same records shown in its detail
  list.

The test is not complete when “the button clicked.” It is complete when the
resulting state is correct, persistent, understandable, and consistent on all
pages that consume it.

## 7. Provider and integration truthfulness

Apps that configure external providers require additional invariants:

- The provider count includes saved providers only, not built-in templates.
- Lists have a deterministic product-relevant order; priority products appear
  first when the product direction requires it.
- The active provider is visibly marked and agrees with routing and overview.
- Editing shows that a credential is stored without returning the secret.
- Deleting a provider removes it, updates counts and routes, and survives
  refresh and restart.
- “Test provider” sends a real upstream request. Form validation or a local
  route check must not be reported as a successful provider test.
- Test results show enough evidence to be trusted: live/failed, HTTP status,
  requested model, latency, and a useful error summary.
- Templates populate only non-secret fields and choose the correct protocol.
- OpenAI-style and Anthropic-style templates remain distinct even when a
  provider offers both at the same base address.
- JSON template bootstrapping and hot-loading reject malformed, duplicate, or
  secret-bearing templates and give clear feedback.

Run at least two real backend tests:

1. An OAuth-backed integration, using a current supported model.
2. An API-key-backed integration, using a different provider and protocol.

For each backend, verify one non-streaming and one streaming request when the
app supports both, then verify request history and usage accounting. Never put
the API key in source, template JSON, shell history intended for publication,
screenshots, logs, issue text, or release notes.

## 8. Prove cross-page data consistency

Trace each important entity through all of its consumers:

```text
saved record
  -> list row
  -> summary count
  -> active route
  -> overview status
  -> request history
  -> usage grouping
  -> persisted state after restart
```

Test these transitions, not just the final snapshots:

- zero records → create one → edit it → activate it → delete it;
- healthy → failed live test → recovered live test;
- inactive route → active route → fallback route;
- no usage → one request → filtered usage → restart;
- extension/app absent → detected → configured → unavailable;
- loading → success, loading → empty, and loading → error.

If different pages disagree, fix the ownership or refresh path rather than
patching the visible number. Prefer a single canonical backend record and
explicit re-fetch after mutations.

## 9. Protect secrets and app data

The UI may return metadata such as `credentialStored: true`; it must not return
the stored credential. Provider-template JSON must never contain a real key.
Search before committing and before packaging:

```sh
rg -n '<known-secret-prefix>|api[_-]?key|access[_-]?token' . \
  --glob '!_build/**'
```

Review matches manually because documentation and field names are legitimate.
Never print a full known secret merely to prove that it is absent.

The packaged launcher sets `LEPUSA_APP_DATA_DIR`. App storage code must honor
that location, or another deliberate user-data directory, before falling back
to the current working directory. The packaged working directory may be inside
`Product.app/Contents/Resources`; writing there breaks the code signature and
can strand credentials inside the app bundle.

After first launch, verify both conditions:

```sh
test ! -e <installed-app>/Contents/Resources/.moonsuite
codesign --verify --deep --strict --verbose=2 <installed-app>
```

Also inspect the complete bundle for secret artifacts before upload.

## 10. Run the MoonBit release gate

Run commands from the app repository root. Do not accidentally build the
adjacent Lepusa repository when the app binary is the artifact being changed.

```sh
cd <app-root>
moon info
moon fmt
moon check --target native --deny-warn
moon test --target native --deny-warn
git diff --check
git status -sb
```

Review generated `.mbti` changes. A UI or private implementation change should
normally not change the public MoonBit API.

Run every supported suite/adapter contract affected by the app. If strict mode
fails only because an adjacent repository has existing warnings in a vendored
dependency, rerun without `--deny-warn` to prove the relevant tests pass and
report the strict-mode exception precisely; do not silently call the entire
gate green.

## 11. Build for the intended macOS floor

Build the app and Lepusa runtime separately, in their correct repositories:

```sh
cd <app-root>
moon clean
MACOSX_DEPLOYMENT_TARGET=11.0 \
  moon build --target native --release

cd <lepusa-root>
moon clean
MACOSX_DEPLOYMENT_TARGET=11.0 \
  moon build cmd/runtime --target native --release
```

Verify both binaries. A runtime built on a newer macOS SDK can still support an
older macOS release only when its load command declares that lower deployment
target.

```sh
vtool -show-build \
  <app-root>/_build/native/release/build/cmd/main/main.exe
vtool -show-build \
  <lepusa-root>/_build/native/release/build/cmd/runtime/runtime.exe
```

Check the `minos` line for both. Do not infer compatibility from the machine on
which the app happened to launch.

## 12. Materialize the Lepusa bundle and DMG

The following flow uses a local Lepusa checkout only as release tooling. The
app still depends on published packages.

```sh
APP_ROOT=<absolute-app-root>
LEPUSA_ROOT=<absolute-lepusa-root>
RELEASE_ROOT=$(mktemp -d /tmp/product-release.XXXXXX)

cd "$LEPUSA_ROOT"
LEPUSA_RUNTIME_EXECUTABLE="$LEPUSA_ROOT/_build/native/release/build/cmd/runtime/runtime.exe" \
  moon run cmd/main --target native -- bundle-write macos \
  "$RELEASE_ROOT/bundle" --project "$APP_ROOT/lepusa.json" --json

DISTRIBUTION_MANIFEST=$(find "$RELEASE_ROOT/bundle" \
  -path '*/Contents/Resources/lepusa/distribution.json' -print -quit)
test -n "$DISTRIBUTION_MANIFEST"

moon run cmd/main --target native -- bundle-package-write \
  "$DISTRIBUTION_MANIFEST" "$RELEASE_ROOT/package" --json

moon run cmd/main --target native -- bundle-release-write \
  "$DISTRIBUTION_MANIFEST" "$RELEASE_ROOT/release"

BUNDLE_ROOT="$RELEASE_ROOT/bundle" \
  sh "$RELEASE_ROOT/package/package.sh"
```

Read the generated JSON and checklist. Require `verified: true`, no package
blockers, a bundled runtime executable, all resources present, and the expected
system WebView dependency.

Do not assume the generated app directory's capitalization. Read it from the
output or locate its `lepusa/distribution.json` as above.

## 13. Sign and notarize appropriately

`"identity": "-"` is ad-hoc signing. It is sufficient for local integrity
testing but not for a frictionless public launch. Users may need to
Control-click → **Open** on first launch.

For a public release without that warning, install a valid **Developer ID
Application** certificate and configure Lepusa signing fields:

```json
{
  "signing": {
    "identity": "Developer ID Application: Company (TEAMID)",
    "teamId": "TEAMID",
    "entitlements": "macos/entitlements.plist",
    "notarizationProfile": "product-notary"
  }
}
```

Check available identities:

```sh
security find-identity -v -p codesigning
```

The package flow should sign the app, create the DMG, submit for notarization
when configured, and staple the result. Final verification should include:

```sh
codesign --verify --deep --strict --verbose=2 <Product.app>
spctl --assess --type execute --verbose=4 <Product.app>
xcrun stapler validate <product.dmg>
```

If no valid Developer ID exists, state that clearly in the release notes. Do
not describe an ad-hoc build as notarized.

## 14. Test the DMG like a user

Do not launch only the app inside the build directory. Mount the final DMG,
copy the app out, and test that copy:

1. Attach the DMG read-only at a unique temporary mount point.
2. Confirm an `Applications` symlink exists and points to `/Applications`.
3. Copy the app to a separate temporary install directory with `ditto`.
4. Verify the signature before launch.
5. Launch the copied app through its packaged launcher.
6. Poll the real readiness endpoint until healthy or a bounded timeout expires.
7. Exercise at least one main UI flow in the packaged window.
8. Quit the app and confirm no supervised localhost service remains.
9. Confirm no user state was written into `Contents/Resources`.
10. Verify the signature again after launch.
11. Recheck `minos` on both executables inside the copied app.
12. Detach the DMG.

Lepusa can also materialize its target-aware install-smoke checklist and script:

```sh
cd <lepusa-root>
moon run cmd/main --target native -- bundle-install-smoke-write \
  <distribution-manifest> <install-smoke-output> <temporary-install-root>
```

Use that generated gate in addition to, not instead of, the interactive UI and
post-launch storage/signature checks above.

The post-launch signature check is essential. A valid signature immediately
after packaging does not catch an app that writes credentials or databases
inside its own signed bundle on first run.

Also inspect the DMG visually: it should open a Finder window containing the
app and the Applications shortcut, making drag-and-drop installation obvious.

## 15. Commit and push intentionally

Before staging:

```sh
cd <app-root>
git status -sb
git diff --check
git diff --stat
git diff
git remote -v
```

Stage explicit paths when the tree contains mixed work. Use a terse commit that
describes the outcome. Push to the actual GitHub remote; in some workspaces
`origin` is Gitee and the GitHub remote is named `github`.

```sh
git add <intentional-files>
git diff --cached --check
git commit -m '<release outcome>'
git push <github-remote> <branch>
```

Open a pull request only when the chosen workflow calls for one. If the user
explicitly requests a direct release from `main`, do not create a surprise PR.

Confirm the remote commit:

```sh
git rev-parse HEAD
git ls-remote <github-remote> refs/heads/<branch>
```

## 16. Publish the GitHub release

Prerequisites:

```sh
gh --version
gh auth status
```

Rename the artifact clearly and generate a checksum whose recorded filename is
only the artifact basename:

```sh
cd <release-bundle-dir>
mv <generated-name>.dmg <product>-<version>-macos-arm64.dmg
shasum -a 256 <product>-<version>-macos-arm64.dmg \
  > <product>-<version>-macos-arm64.dmg.sha256
```

Create the release against the already-pushed branch:

```sh
gh release create <tag> \
  <product>-<version>-macos-arm64.dmg \
  <product>-<version>-macos-arm64.dmg.sha256 \
  --repo <owner>/<repo> \
  --target <branch> \
  --title '<Product version>' \
  --notes-file <release-notes.md>
```

Add `--prerelease` when the artifact is genuinely a preview and confirm the
published GitHub flag matches the release's intended stability.

Release notes should state:

- user-visible changes;
- important data or security fixes;
- UI and integration tests performed;
- MoonBit and adapter test totals;
- minimum macOS and architecture;
- signing/notarization status;
- first-launch instructions when ad-hoc signed;
- known limitations, without hiding them behind “preview.”

Audit the published release:

```sh
gh release view <tag> --repo <owner>/<repo> \
  --json url,tagName,name,isDraft,isPrerelease,assets
git ls-remote <github-remote> refs/heads/<branch> refs/tags/<tag>
```

The branch and tag hashes must be the intended commit. Check that the DMG size,
name, and GitHub-reported digest agree with the local artifact.

## 17. Preserve evidence and clean temporary state

Keep these release records:

- commit hash and tag;
- release URL and direct artifact URL;
- SHA-256 checksum;
- MoonBit and adapter test totals;
- real integration results with secrets removed;
- screenshots of primary, guide, and narrow layouts;
- minimum-version output for both binaries;
- pre- and post-launch signature verification;
- packaged health response;
- signing/notarization status.

Detach mounted images before cleanup. Remove only exact, validated temporary
paths. Prefer moving temporary release/install directories to Trash so mistakes
remain recoverable. If a temporary test accidentally copied a credential into
an app bundle, remove that exact sensitive artifact immediately before moving
the remaining directory.

Never delete broad paths, workspace roots, or unresolved variables.

## 18. Common failures and their real fixes

| Symptom | Likely cause | Required fix |
| --- | --- | --- |
| Clicking a metric opens a white page of text | A raw metrics/log URL is used as navigation | Navigate to a human UI page; make the raw endpoint copy-only |
| New UI is present in source but old UI appears | Static shell/assets are cached | Send an intentional no-cache policy for the app shell during active preview development |
| Provider count is nonzero before setup | Templates or built-ins are counted as saved providers | Derive the count from persisted provider records only |
| Provider test says OK too easily | Only local form/route validation ran | Require and display a real upstream response |
| API key disappears while editing | Secret is intentionally not returned, but the UI gives no stored-state signal | Persist it locally and show a truthful “credential stored” indicator without revealing it |
| Delete appears to do nothing | UI-only mutation, stale fetch, or active-route reference | Delete canonically, repair dependent routes, re-fetch, and test after restart |
| Active provider is unclear | Route state is not shown consistently | Mark it in list, routing, and overview from one canonical source |
| Provider ordering looks random | Backend/map iteration order leaks into UI | Define stable priority and tie-break sorting |
| A template chooses the wrong API shape | Provider identity is confused with protocol | Maintain explicit OpenAI/Anthropic/etc. template variants |
| App icon looks square | Raw artwork fills the canvas or lacks a rounded silhouette | Build a padded macOS-specific icon and regenerate `.icns` |
| DMG is awkward to install | No Applications shortcut | Require and test the `/Applications` symlink |
| App works on a newer Mac but not an older one | One bundled executable has a newer deployment target | Build and inspect both app service and Lepusa runtime with `vtool` |
| Signature becomes invalid after first launch | App writes state under `Contents/Resources` | Honor `LEPUSA_APP_DATA_DIR` or another external app-data directory |
| Gatekeeper still warns | Ad-hoc signing or missing notarization | Use Developer ID signing, notarization, and stapling; otherwise document Control-click Open |
| Release contains stale code | App binary was built from the wrong working directory | Build from the app root, then rebundle and install-test again |
| GitHub is missing the commit | The wrong remote was pushed | Inspect remotes and push the explicitly identified GitHub remote |

## 19. Handover summary template

Use this concise summary when transferring a release to another person or
agent:

```text
App/repository:
Branch and commit:
Release tag:
Release URL:
Artifact and SHA-256:
Minimum macOS / architecture:
Signing and notarization status:

UI pages tested:
Responsive widths tested:
Real integrations tested:
MoonBit test result:
Adapter test results:
Install-smoke result:
Pre/post-launch signature result:

Guide document:
Canonical logo source:
App icon source and generated ICNS:

Known limitations:
Required first-launch action:
Temporary artifacts cleaned:
```

This handover is incomplete if it says only “build passed.” A desktop launch is
the combination of understandable UI, truthful data, preserved secrets,
compatible binaries, an installable artifact, and a verifiable published
release.
