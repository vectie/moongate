# MoonGate UI-to-UI use cases

## MG-UI-001 — Connect and inspect a provider safely

1. Open the published MoonGate operator application.
2. Confirm the first viewport asks the single goal **Connect one app to a
   healthy provider**, shows Provider → Routing → App → Observe with icon and
   text states, and gives one dominant next action.
3. Follow that action to add or select a provider using a host secret reference;
   never paste a secret
   into retained browser evidence.
4. Run the bounded connection check.
5. Inspect the exact provider/model, latency, failure, circuit, and cost status.
6. Break the endpoint or withhold credentials and require an actionable
   unavailable state rather than a false running badge. If the gateway itself
   is unavailable, the goal panel must say what is blocked and offer **Retry
   gateway check** without resetting the selected setup context.

## MG-UI-002 — Resolve one pack capability

1. Select an installed pack operation.
2. Inspect manifest version, schemas, authority, claim ceiling, adapter, and
   health expiry through progressive disclosure.
3. Resolve it once and correlate the returned record.
4. Expire or version-drift the health input and require denial.

## MG-UI-003 — Restart and reconcile operational truth

1. Record provider and suite state.
2. Stop and restart the service over the same data root.
3. Confirm durable configuration and usage remain, while live reachability is
   freshly observed rather than replayed as healthy.

Fixture provider success proves UI and policy behavior only. Production
acceptance requires real credentials, provider terms, redaction review, signed
distribution, and clean-machine lifecycle evidence.
