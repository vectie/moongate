# Stage app connection changes

In the gateway dashboard Setup app table, choose an existing enabled provider
and press **Stage change** on each installed automatic-binding app. The staged
connections panel shows the old and proposed provider for each app. Staging
makes no request and never retains provider credential fields.

**Apply staged changes** re-reads app/provider configuration and applies the
reviewed changes in order through the existing binding endpoint. It stops on
stale configuration or an uncertain write. Completed changes stay completed;
this is not an atomic multi-app transaction and does not automatically roll back.
The controller blocks repeated Apply, Stage, and direct Bind/Disconnect while
applying. Direct changes to an uncertain app remain blocked until reconciliation.

**Reconcile uncertain changes** only reads configuration. A matching binding is
marked verified without another write; a different binding requires refresh
and explicit staging again. Unavailable reads remain uncertain. Discard removes
reviewed plan rows but preserves unresolved uncertainty. Applied binding does
not establish model availability, credentials validity, authority, or live health.

The plan is tab-local and not persisted. After closing/reloading a tab following
an interrupted write, refresh the current bindings and inspect the actual state
before making another change. The backend has no compare-and-swap transaction;
an external actor can change configuration between recheck and write. Existing
server validation remains authoritative. No provider calls are made by this plan.
