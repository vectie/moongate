# MoonSuite executable capability projection

## Outcome

MoonGate projects local product inventory into one fail-closed capability
contract. A repository name, canvas node, product registry row or free-form
capability label is not executable evidence.

Consumers use:

- `GET /suite/capabilities?root=<workspace-root>`
- `GET /suite/capabilities/resolve?root=<workspace-root>&productId=<id>&operationId=<id>`
- `moongate suite capabilities --root <workspace-root>`
- `moongate suite capability-resolve --root <workspace-root> --product <id> --operation <id>`

The projection contract is `moonsuite.capability-projection.v1`. Exact
resolution returns `moonsuite.capability-resolution.v1`.

## Evidence model

MoonGate reads `.moonsuite/product-registry.json` using
`moonsuite-product-registry.v1`. Inventory answers which products are
configured; it does not answer which tools can run.

An inventory product may provide:

```json
{
  "id": "moonmold",
  "repo_path": "/opt/moonsuite/packs/moonmold",
  "capability_catalog_path": "/var/lib/moonsuite/moonmold-capabilities.json"
}
```

`repo_path` resolves `pack.json` and its versioned schemas.
`capability_catalog_path` consumes the canonical compiled
`moonflow.capability-catalog.v1`. MoonFlow owns compilation from:

1. product-owned `pack.json`;
2. host-owned `moonflow.adapter-declaration.v1`;
3. expiring `moonflow.adapter-health.v1`.

This is the translation boundary: MoonGate does not invent another adapter
runtime or duplicate orchestration. It verifies that the installed manifest
still agrees with MoonFlow's compiled operation, schema, authority, version,
claim-ceiling, reconciliation and health evidence.

HTTP products may instead publish a local `service_path` using
`moonsuite.product-service.v1`:

```json
{
  "contract": "moonsuite.product-service.v1",
  "product_id": "example",
  "version": "1.0.0",
  "status": "healthy",
  "ready": true,
  "endpoint": "http://127.0.0.1:4310",
  "health_url": "http://127.0.0.1:4310/health",
  "manifest_path": "/opt/moonsuite/packs/example/pack.json",
  "operations": [
    {
      "id": "example.operation",
      "version": "1.0.0",
      "endpoint": "/v1/tools/example.operation"
    }
  ]
}
```

MoonGate deliberately does not probe arbitrary URLs from inventory. The
descriptor or MoonFlow catalog is passive local health evidence, identified by
its path and SHA-256 digest. A host that needs active checks publishes a fresh
MoonFlow health attestation and recompiles the catalog.

## Executability rules

An operation becomes executable only when:

- the inventory identity is canonical and unambiguous;
- pack and inventory product IDs agree;
- the tool owner is the pack product;
- pack and operation versions are explicit or deterministically inherited;
- input and output schemas resolve to valid versioned JSON documents inside the
  pack or suite root;
- authority is a canonical generic MoonSuite authority class;
- a MoonGate boundary defines the product-wide maximum claim ceiling, while
  the compiled adapter operation supplies its exact claim ceiling;
- a service endpoint or `moonflow.adapter.v2` binding publishes the exact
  operation;
- installed manifest and runtime operation/schema versions agree;
- the runtime is ready and reconciliation is supported.

Findings are machine-readable and include stable codes, severity, product,
operation, path, message and evidence references. MoonFlow and MoonDesk should
fail closed when resolution returns `executable: false`; they must not guess a
similar operation.

Static MoonGate boundary rows are reserved for suite products whose authority
surface is constitutional and stable. A domain pack without such a row is not
implicitly rejected: its exact operation authority and claim ceiling may derive
from a conformant compiled `moonflow.capability-catalog.v1`. The catalog remains
operation-specific, and it cannot turn repository names, descriptive
capabilities or canvas labels into operations.

MoonBook owns `bookkeeper.outcome.close` and `wiki.requirements.prepare`;
MoonWiki is only the latter functionality label. MoonClaw owns
`agent.goal.execute`; MoonCode is only a MoonClaw role/configuration. Neither
label creates a product boundary or another runtime.

MoonBook's product boundary permits `accepted-knowledge`, but only
`bookkeeper.outcome.close` may record that class after an already-bound named
review. `wiki.requirements.prepare` remains a review-pending
`digital-artifact`; preparing a requirements packet never accepts it as book
truth. MoonClaw's `agent.goal.execute` is capped at `digital-artifact` and
cannot accept its own result as knowledge.

## Identity migration

`moonstat` remains recognizable only as a retired migration alias for
`moongate`. `moonmini` remains recognizable as the Bunnia framework identity.
`moonwiki` resolves only to MoonBook functionality and `mooncode` only to a
MoonClaw role/configuration. All four identities are `callable: false` and can
never publish executable operations through their alias names.

Historical state remains available to the explicit MoonStat-to-MoonGate
migration command. No live API, manifest, canvas or runtime should create new
MoonStat state.
