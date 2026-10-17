# Allocate a shadow policy across configured providers

Open Operations, choose the app, wait for its policy to load, and use **Allocate
across configured providers** in the existing Routing policy form. The new editor
reads the provider inventory already loaded by the dashboard. It makes no model
list, health-test, completion or other provider request.

1. Choose **Load allocation rows (replace row edits)**. Each configured provider
   has its exact ID, name, enabled label, weight and concurrency cap.
2. Enable an override and enter its value. Disable an override to remove its key
   from the policy map. An omitted weight defaults to 1; an omitted cap defaults
   to 0, which means no concurrency limit from this policy. An explicit 0 cap has
   the same effect but remains visible in the exact input.
3. Edit several rows, then **Preview allocations**. The full exact shadow-policy
   payload is shown, including overrides for IDs absent from the current
   inventory. Those absent-provider overrides are preserved. To remove them,
   deliberately edit the ordinary JSON field and load the rows again.
4. Choose **Save allocations as shadow**. This feeds the reviewed maps through
   the existing shadow-save action. Saving replaces the shadow draft and resets
   its shadow observation history. It does not activate routing.
5. After acknowledgement, use the existing **Observe Shadow Decision** button.
   Activation and rollback retain their separate host-issued authority workflow.

Weights must be decimal whole numbers 1–1000. Caps must be whole numbers from 0
through 2147483647, matching the underlying signed integer representation.
Negative values, signs, whitespace, fractions and exponent notation are refused.
Weights only affect routing modes that use weights. A configured provider may be
disabled, absent from the routing pool, circuit-blocked, unhealthy or otherwise
ineligible. This editor does not add a provider to the pool, override eligibility,
change credentials or promise traffic shares or live capacity.

## Edits and interruptions

Row edits live only in the current tab. They do not change the ordinary JSON
fields until the explicit save. Discarding row edits leaves those fields alone.
Loading rows deliberately replaces the row edits with the currently displayed
policy form. Reloading or closing the page loses unsaved row edits.

An app switch, changed provider inventory, changed policy draft or manual form
edit blocks a stale row save and retains the row edits for inspection. Load rows
again only when ready to replace them with the current form. A new row edit
invalidates its preceding preview. There is no automatic merge or autosave.
Only one shadow-save request can be in flight through these form actions.

A missing acknowledgement is an uncertain save, not proof of failure. The editor
will not retry it. Refresh and inspect the shadow policy, then deliberately reload
rows before another attempt. Read-back is not an atomic configuration lock; a
concurrent external actor can still modify policy after inspection. An observed
shadow choice is existing gateway evidence, not live provider qualification.

## Verification and scope

This is a bounded contribution to MG03 / MOONGATE-B06. It adds real allocation
controls to the shipped Operations controller and consumes the ordinary save and
observe actions. It is distinct from app connection bindings and transcript
inspection. It changes no MoonBit, native API, dependency or provider contract.

Run `node --test tests/moongate-routing-allocation.test.cjs`. Tests exercise the
actual shipped script and registered controls under a minimal DOM/endpoint
adapter: multi-provider edits, defaults, absent-provider map preservation,
explicit shadow save/observe, stale changes, numeric bounds, interrupted save,
duplicate clicks and literal hostile IDs. Synthetic endpoints never call a
provider. Browser layout, assistive technology, native HTTP compatibility,
actual selection effects and production activation are not qualified here.
