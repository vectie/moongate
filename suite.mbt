///|
const SUITE_STATUS_FILE = "suite-status.json"

///|
fn moongate_product_state_path(root : String, product_id : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, product_id).state_path
}

///|
fn moongate_product_tmp_path(root : String, product_id : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, product_id).tmp_path
}

///|
fn moongate_product_artifact_path(
  root : String,
  product_id : String,
  relative_path : String,
) -> String {
  @moonsuite.product_artifact_for_workspace_root(
    root, product_id, relative_path,
  )
}

///|
priv struct SuiteLegacyDriftCandidate {
  product : String
  legacy_path : String
  probe_path : String
  canonical_path : String
  scope : String
  reason : String
}

///|
fn moongate_moonclaw_providers_file() -> String {
  moongate_moonclaw_providers_file_for_workspace_root(
    moongate_active_workspace_root(),
  )
}

///|
fn moongate_moonclaw_providers_file_for_workspace_root(root : String) -> String {
  @moonsuite.product_artifact_for_workspace_root(
    root, "moonclaw", "providers.json",
  )
}

///|
fn moongate_moonclaw_models_file() -> String {
  moongate_moonclaw_models_file_for_workspace_root(
    moongate_active_workspace_root(),
  )
}

///|
fn moongate_moonclaw_models_file_for_workspace_root(root : String) -> String {
  @moonsuite.product_artifact_for_workspace_root(
    root, "moonclaw", "models/models.json",
  )
}

///|
fn moongate_moonclaw_config_file() -> String {
  moongate_moonclaw_config_file_for_workspace_root(
    moongate_active_workspace_root(),
  )
}

///|
fn moongate_moonclaw_config_file_for_workspace_root(root : String) -> String {
  @moonsuite.product_artifact_for_workspace_root(
    root, "moonclaw", "config.json",
  )
}

///|
pub fn moongate_suite_manifest_json(
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
) -> Json {
  let manifest = {
    "contract": Json::string(@suite.manifest_contract()),
    "service": Json::string(@suite.service_name()),
    "project": Json::string(@suite.project_name()),
    "version": Json::string(@suite.version()),
    "role": Json::string("network-edge"),
    "defaultHost": Json::string(@suite.normalize_host(host)),
    "defaultPort": Json::number(port.to_double()),
    "baseUrl": Json::string(moongate_base_url(host, port)),
    "openaiBaseUrl": Json::string(moongate_openai_base_url(host, port)),
    "anthropicBaseUrl": Json::string(moongate_base_url(host, port)),
    "claudeDesktopBaseUrl": Json::string(
      moongate_claude_desktop_base_url(host, port),
    ),
    "defaultModel": Json::string(model),
    "statusFile": Json::string(default_moongate_suite_status_path()),
    "capabilities": moongate_suite_capabilities_json(),
    "modelsUrl": Json::string("\{moongate_openai_base_url(host, port)}/models"),
    "routes": Json::array(
      moongate_suite_routes().map(fn(route) { Json::string(route) }),
    ),
    "frameworkApps": moongate_framework_apps_json(),
    "uiSections": moongate_ui_sections_json(),
    "uiEndpoints": moongate_ui_endpoints_json(),
    "uiReadinessCards": moongate_ui_readiness_cards_json(),
    "apps": Json::array([
      suite_app_json(
        "moonclaw", "agent-runtime", "Use moongate as the OpenAI-compatible or Anthropic-compatible local edge for agent provider calls.",
      ),
      suite_app_json(
        "moonbook", "durable-output", "Store generated reports and proxy usage summaries outside moongate.",
      ),
      suite_app_json(
        "moontown", "scheduler-control-plane", "Watch moongate health/status/stats as the network edge for standing goals.",
      ),
      suite_app_json(
        "moondesk", "operator-shell", "Read the suite status file and display gateway health, model catalog, and traffic counters.",
      ),
    ]),
    "agentClients": moongate_suite_agent_clients_json(host, port, model),
    "suiteIntegrations": moongate_suite_integrations_json(host, port, model),
    "commands": moongate_suite_commands_json(port, model),
    "cli": moongate_suite_commands_json(port, model),
  }
  moongate_merge_suite_fields(
    manifest,
    moongate_suite_shared_fields(host, port),
  )
  Json::object(manifest)
}

///|
pub fn moongate_suite_status_json(
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
  status? : String = "configured",
  ready? : Bool = true,
) -> Json {
  let status_json = {
    "contract": Json::string(@suite.status_contract()),
    "modelRouteContract": Json::string(@pipeline.ModelRoute.id()),
    "runReceiptContract": Json::string(@pipeline.RunReceipt.id()),
    "service": Json::string(@suite.service_name()),
    "status": Json::string(status),
    "ready": Json::boolean(ready),
    "manifest": moongate_suite_manifest_json(host~, port~, model~),
    "statusPath": Json::string(default_moongate_suite_status_path()),
  }
  Json::object(status_json)
}

///|
pub async fn moongate_suite_drift_report_json(
  suite_root? : String = ".",
  global_tmp_root? : String = "/tmp",
) -> Json {
  let root = moongate_normalize_suite_root(suite_root)
  let global_tmp = moongate_trim_root(global_tmp_root)
  let findings = []
  for candidate in moongate_suite_legacy_drift_candidates(root, global_tmp) {
    let detected = @fsx.exists(candidate.probe_path)
    findings.push(
      moongate_suite_drift_finding_json(
        candidate.product,
        candidate.legacy_path,
        candidate.probe_path,
        candidate.canonical_path,
        candidate.scope,
        candidate.reason,
        detected,
      ),
    )
  }
  Json::object({
    "contract": Json::string("moongate.suite.drift.v1"),
    "suiteRoot": Json::string(root),
    "contractSource": Json::string("vectie/moonlib/moonsuite"),
    "role": Json::string("validator-reporter"),
    "globalTmpRoot": Json::string(global_tmp),
    "canonical": moongate_suite_canonical_paths_json(root),
    "findings": Json::array(findings),
    "summary": Json::object({
      "total": Json::number(findings.length().to_double()),
      "detected": Json::number(
        findings
        .filter(fn(finding) {
          match finding {
            Object(obj) => obj["detected"] == Json::boolean(true)
            _ => false
          }
        })
        .length()
        .to_double(),
      ),
    }),
  })
}

///|
fn moongate_trim_root(root : String) -> String {
  let trimmed = root.trim().to_owned()
  if trimmed == "" {
    "."
  } else {
    trimmed
  }
}

///|
fn moongate_normalize_suite_root(root : String) -> String {
  let workspace_root = moongate_trim_root(root)
  @moonsuite.suite_root_for_workspace_root(workspace_root)
}

///|
fn moongate_suite_canonical_paths_json(root : String) -> Json {
  let suite_root = moongate_normalize_suite_root(root)
  Json::object({
    "suiteState": Json::string(@moonsuite.state_dir(suite_root)),
    "books": Json::string(@moonsuite.books_root(suite_root)),
    "tmp": Json::string(@moonsuite.tmp_root(suite_root)),
    "productRegistry": Json::string(
      @moonsuite.product_registry_path(suite_root),
    ),
    "moondeskHome": Json::string(
      moongate_product_state_path(suite_root, "moondesk"),
    ),
    "moonbookHome": Json::string(
      moongate_product_state_path(suite_root, "moonbook"),
    ),
    "moonwikiHome": Json::string(
      moongate_product_state_path(suite_root, "moonwiki"),
    ),
    "mooncodeHome": Json::string(
      moongate_product_state_path(suite_root, "mooncode"),
    ),
    "moongateHome": Json::string(
      moongate_product_state_path(suite_root, "moongate"),
    ),
    "moonclawHome": Json::string(
      moongate_product_state_path(suite_root, "moonclaw"),
    ),
    "moontownHome": Json::string(
      moongate_product_state_path(suite_root, "moontown"),
    ),
    "moonroboHome": Json::string(
      moongate_product_state_path(suite_root, "moonrobo"),
    ),
    "moonfishHome": Json::string(
      moongate_product_state_path(suite_root, "moonfish"),
    ),
    "moonmoonHome": Json::string(
      moongate_product_state_path(suite_root, "moonmoon"),
    ),
    "moonchatHome": Json::string(
      moongate_product_state_path(suite_root, "moonchat"),
    ),
    "moonvisHome": Json::string(
      moongate_product_state_path(suite_root, "moonvis"),
    ),
    "bookkeeperHome": Json::string(
      moongate_product_state_path(suite_root, "bookkeeper"),
    ),
    "lepusaHome": Json::string(
      moongate_product_state_path(suite_root, "lepusa"),
    ),
    "rabbitaHome": Json::string(
      moongate_product_state_path(suite_root, "rabbita"),
    ),
    "moonroboGatewayCommands": Json::string(
      moongate_product_artifact_path(suite_root, "moonrobo", "gateway-commands"),
    ),
    "moonroboRoboLoops": Json::string(
      moongate_product_artifact_path(suite_root, "moonrobo", "robo-loops"),
    ),
    "moonroboProofSessions": Json::string(
      moongate_product_artifact_path(suite_root, "moonrobo", "proof-sessions"),
    ),
    "moonroboSdkE1Snapshot": Json::string(
      @pathx.join(
        moongate_product_tmp_path(suite_root, "moonrobo"),
        "sdk-e1/snapshot.json",
      ),
    ),
    "moonroboSdkE1Command": Json::string(
      @pathx.join(
        moongate_product_tmp_path(suite_root, "moonrobo"),
        "sdk-e1/command.json",
      ),
    ),
    "moonclawProviders": Json::string(
      moongate_product_artifact_path(suite_root, "moonclaw", "providers.json"),
    ),
    "moonclawModels": Json::string(
      moongate_product_artifact_path(
        suite_root, "moonclaw", "models/models.json",
      ),
    ),
    "moonclawConfig": Json::string(
      moongate_product_artifact_path(suite_root, "moonclaw", "config.json"),
    ),
    "mooncodeSessions": Json::string(
      moongate_product_artifact_path(
        suite_root, "moonclaw", "mooncode/sessions",
      ),
    ),
  })
}

///|
async fn moongate_suite_legacy_drift_candidates(
  root : String,
  global_tmp_root : String,
) -> Array[SuiteLegacyDriftCandidate] {
  let candidates = [
    moongate_suite_root_drift_candidate(
      root,
      "moontown",
      ".moontown",
      moongate_product_state_path(root, "moontown"),
      "MoonTown runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moondesk",
      ".moondesk",
      moongate_product_state_path(root, "moondesk"),
      "MoonDesk runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonbook",
      ".moonbook",
      moongate_product_state_path(root, "moonbook"),
      "MoonBook runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonwiki",
      ".moonwiki",
      moongate_product_state_path(root, "moonwiki"),
      "MoonWiki runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "mooncode",
      ".mooncode",
      moongate_product_state_path(root, "mooncode"),
      "MoonCode runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonclaw",
      ".moonclaw",
      moongate_product_state_path(root, "moonclaw"),
      "MoonClaw runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moondesk",
      ".moontown/moondesk-daemon",
      moongate_product_state_path(root, "moondesk"),
      "MoonDesk daemon state belongs under the MoonDesk product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonclaw",
      "moonclaw-jobs",
      moongate_product_artifact_path(root, "moonclaw", "jobs"),
      "MoonClaw jobs belong under the MoonClaw product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moongate",
      "moongate",
      moongate_product_state_path(root, "moongate"),
      "MoonGate state belongs under the MoonGate product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonfish",
      ".moonfish",
      moongate_product_state_path(root, "moonfish"),
      "MoonFish runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonmoon",
      ".moonmoon",
      moongate_product_state_path(root, "moonmoon"),
      "MoonMoon runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonchat",
      ".moonchat",
      moongate_product_state_path(root, "moonchat"),
      "MoonChat runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonvis",
      ".moonvis",
      moongate_product_state_path(root, "moonvis"),
      "MoonVis runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "bookkeeper",
      ".bookkeeper",
      moongate_product_state_path(root, "bookkeeper"),
      "Bookkeeper runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "lepusa",
      ".lepusa",
      moongate_product_state_path(root, "lepusa"),
      "Lepusa runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "rabbita",
      ".rabbita",
      moongate_product_state_path(root, "rabbita"),
      "Rabbita runtime state belongs under the MoonSuite product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonrobo",
      "runs/gateway-commands",
      moongate_product_artifact_path(root, "moonrobo", "gateway-commands"),
      "MoonRobo gateway commands belong under the MoonRobo product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonrobo",
      "runs/robo-loops",
      moongate_product_artifact_path(root, "moonrobo", "robo-loops"),
      "MoonRobo loop artifacts belong under the MoonRobo product home.",
    ),
    moongate_suite_root_drift_candidate(
      root,
      "moonrobo",
      "runs/proof-sessions",
      moongate_product_artifact_path(root, "moonrobo", "proof-sessions"),
      "MoonRobo proof sessions belong under the MoonRobo product home.",
    ),
    moongate_suite_global_tmp_drift_candidate(
      global_tmp_root,
      "moonrobo",
      "moonrobo-sdk-e1-bridge-snapshot-test.json",
      @pathx.join(
        moongate_product_tmp_path(root, "moonrobo"),
        "sdk-e1/snapshot.json",
      ),
      "MoonRobo SDK E1 snapshots belong under the suite product tmp home.",
    ),
    moongate_suite_global_tmp_drift_candidate(
      global_tmp_root,
      "moonrobo",
      "moonrobo-sdk-e1-bridge-command-test.json",
      @pathx.join(
        moongate_product_tmp_path(root, "moonrobo"),
        "sdk-e1/command.json",
      ),
      "MoonRobo SDK E1 commands belong under the suite product tmp home.",
    ),
  ]
  for candidate in moongate_suite_book_drift_candidates(root) {
    candidates.push(candidate)
  }
  candidates
}

///|
async fn moongate_suite_book_drift_candidates(
  root : String,
) -> Array[SuiteLegacyDriftCandidate] {
  let books_root = @moonsuite.books_root(root)
  if !@fsx.exists(books_root) {
    return []
  }
  let entries = @fsx.list_directory(books_root) catch { _ => return [] }
  let candidates : Array[SuiteLegacyDriftCandidate] = []
  for entry in entries {
    let book_root = entry.path
    let book_id = @pathx.basename(book_root).to_owned()
    candidates.push(
      moongate_suite_book_drift_candidate(
        book_root,
        book_id,
        "moonclaw",
        ".moonclaw/providers.json",
        @moonsuite.product_artifact_for_workspace_root(
          book_root, "moonclaw", "providers.json",
        ),
        "Book-local MoonClaw provider manifests belong under the MoonClaw product home.",
      ),
    )
    candidates.push(
      moongate_suite_book_drift_candidate(
        book_root,
        book_id,
        "moonclaw",
        ".moonclaw/mooncode/sessions",
        @moonsuite.product_artifact_for_workspace_root(
          book_root, "moonclaw", "mooncode/sessions",
        ),
        "Book-local MoonCode sidecar sessions belong under the MoonClaw product home.",
      ),
    )
  }
  candidates
}

///|
fn moongate_suite_book_drift_candidate(
  book_root : String,
  book_id : String,
  product : String,
  legacy_relative_path : String,
  canonical_path : String,
  reason : String,
) -> SuiteLegacyDriftCandidate {
  let legacy_path = @pathx.join(
    @pathx.join("books", book_id),
    legacy_relative_path,
  )
  {
    product,
    legacy_path,
    probe_path: @pathx.join(book_root, legacy_relative_path),
    canonical_path,
    scope: "book-root",
    reason,
  }
}

///|
fn moongate_suite_root_drift_candidate(
  root : String,
  product : String,
  legacy_path : String,
  canonical_path : String,
  reason : String,
) -> SuiteLegacyDriftCandidate {
  {
    product,
    legacy_path,
    probe_path: @pathx.join(root, legacy_path),
    canonical_path,
    scope: "suite-root",
    reason,
  }
}

///|
fn moongate_suite_global_tmp_drift_candidate(
  global_tmp_root : String,
  product : String,
  legacy_filename : String,
  canonical_path : String,
  reason : String,
) -> SuiteLegacyDriftCandidate {
  let probe_path = @pathx.join(global_tmp_root, legacy_filename)
  {
    product,
    legacy_path: probe_path,
    probe_path,
    canonical_path,
    scope: "global-tmp",
    reason,
  }
}

///|
fn moongate_suite_drift_finding_json(
  product : String,
  legacy_path : String,
  probe_path : String,
  canonical_path : String,
  scope : String,
  reason : String,
  detected : Bool,
) -> Json {
  Json::object({
    "product": Json::string(product),
    "status": Json::string(if detected { "drift" } else { "clear" }),
    "detected": Json::boolean(detected),
    "legacyPath": Json::string(legacy_path),
    "probePath": Json::string(probe_path),
    "canonicalPath": Json::string(canonical_path),
    "scope": Json::string(scope),
    "source": Json::string("moongate"),
    "contractSource": Json::string("vectie/moonlib/moonsuite"),
    "reason": Json::string(reason),
  })
}

///|
pub async fn write_moongate_suite_status(
  path? : String = default_moongate_suite_status_path(),
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
  status? : String = "configured",
  ready? : Bool = true,
) -> String {
  let dir = @pathx.dirname(path)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let json = moongate_suite_status_json(host~, port~, model~, status~, ready~).stringify(
    indent=2,
  )
  @fsx.write_to_file(path, json)
  path
}

///|
pub fn default_moongate_suite_status_path() -> String {
  default_moongate_suite_status_path_for_workspace_root(
    moongate_active_workspace_root(),
  )
}

///|
pub fn default_moongate_suite_status_path_for_workspace_root(
  root : String,
) -> String {
  @pathx.join(
    @moonsuite.state_dir(@moonsuite.suite_root_for_workspace_root(root)),
    SUITE_STATUS_FILE,
  )
}

///|
fn default_moongate_dir() -> String {
  moongate_product_home_for_workspace_root(moongate_active_workspace_root())
}

///|
fn moongate_active_workspace_root() -> String {
  let configured = @os.getenv("MOONSUITE_WORKSPACE_ROOT") catch { _ => None }
  match configured {
    Some(root) if !root.trim().is_empty() => root
    _ => @os.cwd() catch { _ => "." }
  }
}

///|
pub fn moongate_product_home_for_workspace_root(root : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, "moongate").state_path
}

///|
fn moongate_suite_capabilities_json() -> Json {
  Json::array(
    moongate_suite_capabilities().map(fn(capability) {
      Json::string(capability)
    }),
  )
}

///|
fn moongate_suite_shared_fields(host : String, port : Int) -> Map[String, Json] {
  let base_url = moongate_base_url(host, port)
  {
    "healthUrl": Json::string("\{base_url}/health"),
    "statusUrl": Json::string("\{base_url}/status"),
    "statsUrl": Json::string("\{base_url}/stats"),
    "metricsUrl": Json::string("\{base_url}/metrics"),
    "dashboardUrl": Json::string("\{base_url}/"),
    "usageLogsUrl": Json::string("\{base_url}/usage/logs"),
    "usageSummaryUrl": Json::string("\{base_url}/usage/summary"),
    "usageSummaryByAppUrl": Json::string("\{base_url}/usage/summary/by-app"),
    "usageTrendsUrl": Json::string("\{base_url}/usage/trends"),
    "usageProviderLimitsUrl": Json::string("\{base_url}/usage/provider-limits"),
    "usageProviderStatsUrl": Json::string("\{base_url}/usage/provider-stats"),
    "usageModelStatsUrl": Json::string("\{base_url}/usage/model-stats"),
    "usageDataSourcesUrl": Json::string("\{base_url}/usage/data-sources"),
    "usageSyncSessionUrl": Json::string("\{base_url}/usage/sync-session"),
    "usageModelPricingUrl": Json::string("\{base_url}/usage/model-pricing"),
    "providerPresetsUrl": Json::string("\{base_url}/providers/presets"),
    "usageRequestDetailUrl": Json::string(
      "\{base_url}/usage/request-detail/{request_id}",
    ),
    "streamCheckProviderUrl": Json::string(
      "\{base_url}/proxy/stream-check/provider",
    ),
    "streamCheckAllProvidersUrl": Json::string(
      "\{base_url}/proxy/stream-check/all",
    ),
    "streamCheckConfigUrl": Json::string(
      "\{base_url}/proxy/stream-check/config",
    ),
    "configStatusUrl": Json::string("\{base_url}/config/status"),
    "usageStoreDir": Json::string(default_moongate_stats_dir()),
    "usageRequestLogsFile": Json::string(
      @pathx.join(default_moongate_stats_dir(), MOONGATE_REQUEST_LOGS_FILE),
    ),
    "usageSessionSyncFile": Json::string(
      @pathx.join(default_moongate_stats_dir(), MOONGATE_SESSION_SYNC_FILE),
    ),
    "usageModelPricingFile": Json::string(
      @pathx.join(default_moongate_stats_dir(), MOONGATE_MODEL_PRICING_FILE),
    ),
    "usageOpencodeDbFile": Json::string(default_opencode_db_path()),
    "usageOpencodeExportFile": Json::string(default_opencode_export_path()),
  }
}

///|
fn moongate_merge_suite_fields(
  target : Map[String, Json],
  fields : Map[String, Json],
) -> Unit {
  for key in fields.keys() {
    match fields.get(key) {
      Some(value) => target[key] = value
      None => ()
    }
  }
}

///|
fn moongate_base_url(host : String, port : Int) -> String {
  @suite.base_url(host, port)
}

///|
fn moongate_openai_base_url(host : String, port : Int) -> String {
  @suite.openai_base_url(host, port)
}

///|
fn moongate_claude_desktop_base_url(host : String, port : Int) -> String {
  @suite.claude_desktop_base_url(host, port)
}

///|
fn suite_app_json(id : String, role : String, usage : String) -> Json {
  Json::object({
    "id": Json::string(id),
    "role": Json::string(role),
    "usage": Json::string(usage),
  })
}

///|
fn moongate_suite_agent_clients_json(
  host : String,
  port : Int,
  model : String,
) -> Json {
  let base_url = moongate_base_url(host, port)
  let openai_base_url = moongate_openai_base_url(host, port)
  let claude_desktop_base_url = moongate_claude_desktop_base_url(host, port)
  Json::array([
    suite_agent_client_json(
      "codex",
      "codex",
      "openai-responses",
      openai_base_url,
      "POST /v1/responses",
      "moongate codex install --port \{port} --model \{model}",
      "Codex config.toml managed provider block using the Responses API.",
    ),
    suite_agent_client_json(
      "claude-code", "claude", "anthropic-compatible", base_url, "POST /v1/messages",
      "", "Claude Code and Anthropic-compatible clients using MoonGate provider routing.",
    ),
    suite_agent_client_json(
      "claude-desktop",
      "claude-desktop",
      "anthropic-compatible",
      claude_desktop_base_url,
      "POST /claude-desktop/v1/messages",
      "moongate claude-desktop install --port \{port}",
      "Claude Desktop gateway profile with optional local bearer token.",
    ),
    suite_agent_client_json(
      "openclaw",
      "openclaw",
      "openai-compatible",
      "\{base_url}/openclaw/v1",
      "POST /openclaw/v1/chat/completions",
      "moongate provider openclaw import-live",
      "OpenClaw chat completions and OpenClaw config/provider management routes.",
    ),
    suite_agent_client_json(
      "opencode", "opencode", "openai-compatible", openai_base_url, "POST /v1/chat/completions",
      "moongate provider opencode import-live", "OpenCode provider import, proxy routing, and session usage sync.",
    ),
    suite_agent_client_json(
      "gemini",
      "gemini",
      "gemini-compatible",
      "\{base_url}/gemini",
      "ANY /gemini/v1beta/*path",
      "",
      "Gemini-compatible proxy routes with native usage accounting.",
    ),
    suite_agent_client_json(
      "github-copilot", "copilot", "copilot-auth", base_url, "GET /copilot/models",
      "moongate copilot login", "GitHub Copilot OAuth, model catalog, token, and usage endpoints.",
    ),
    suite_agent_client_json(
      "openai-compatible", "codex", "openai-compatible", openai_base_url, "POST /v1/chat/completions",
      "", "Generic OpenAI-compatible clients using MoonGate as the local provider edge.",
    ),
  ])
}

///|
fn suite_agent_client_json(
  id : String,
  app_type : String,
  protocol : String,
  base_url : String,
  primary_route : String,
  setup_command : String,
  usage : String,
) -> Json {
  Json::object({
    "id": Json::string(id),
    "appType": Json::string(app_type),
    "protocol": Json::string(protocol),
    "baseUrl": Json::string(base_url),
    "primaryRoute": Json::string(primary_route),
    "setupCommand": Json::string(setup_command),
    "usage": Json::string(usage),
  })
}

///|
fn moongate_suite_integrations_json(
  host : String,
  port : Int,
  model : String,
) -> Json {
  let base_url = moongate_base_url(host, port)
  let openai_base_url = moongate_openai_base_url(host, port)
  let anthropic_base_url = base_url
  let claude_desktop_base_url = moongate_claude_desktop_base_url(host, port)
  let moonclaw_models_file = moongate_moonclaw_models_file()
  let moonclaw_config_file = moongate_moonclaw_config_file()
  let moonclaw_providers_file = moongate_moonclaw_providers_file()
  let moonclaw_providers_write_command = "moongate suite write-moonclaw-providers --path \{moonclaw_providers_file}"
  Json::object({
    "moonclaw": Json::object({
      "role": Json::string("agent-provider-edge"),
      "openaiBaseUrl": Json::string(openai_base_url),
      "anthropicBaseUrl": Json::string(anthropic_base_url),
      "defaultModel": Json::string(model),
      "moonclawModelConfig": moonclaw_model_config_json(openai_base_url, model),
      "moonclawModelsJson": Json::array([
        moonclaw_model_config_json(openai_base_url, model),
      ]),
      "moonclawModelsPathCandidates": Json::array([
        Json::string(moonclaw_models_file),
      ]),
      "moonclawProviderName": Json::string("moongate"),
      "moonclawProviderModelId": Json::string(model),
      "moonclawProviderConfigPaths": Json::array([
        Json::string(moonclaw_models_file),
        Json::string(moonclaw_config_file),
      ]),
      "moonclawProvidersFileJson": moonclaw_providers_file_json(
        openai_base_url, model,
      ),
      "moonclawProvidersFileCommand": Json::string(
        "moongate suite moonclaw-providers",
      ),
      "moonclawProvidersFileWriteCommand": Json::string(
        moonclaw_providers_write_command,
      ),
      "healthUrl": Json::string("\{base_url}/health"),
      "dashboardUrl": Json::string("\{base_url}/"),
      "metricsUrl": Json::string("\{base_url}/metrics"),
      "usageSummaryUrl": Json::string("\{base_url}/usage/summary"),
      "usageLogsUrl": Json::string("\{base_url}/usage/logs"),
      "providerPresetsUrl": Json::string("\{base_url}/providers/presets"),
      "streamCheckAllProvidersUrl": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "env": Json::object({
        "OPENAI_BASE_URL": Json::string(openai_base_url),
        "ANTHROPIC_BASE_URL": Json::string(anthropic_base_url),
        "OPENAI_API_KEY": Json::string("moongate-local"),
      }),
    }),
    "moonbook": Json::object({
      "role": Json::string("durable-usage-output"),
      "usageSummaryUrl": Json::string("\{base_url}/usage/summary"),
      "usageLogsUrl": Json::string("\{base_url}/usage/logs"),
      "usageTrendsUrl": Json::string("\{base_url}/usage/trends"),
      "usageDataSourcesUrl": Json::string("\{base_url}/usage/data-sources"),
      "usageRequestLogsFile": Json::string(
        @pathx.join(default_moongate_stats_dir(), MOONGATE_REQUEST_LOGS_FILE),
      ),
      "usageModelPricingFile": Json::string(
        @pathx.join(default_moongate_stats_dir(), MOONGATE_MODEL_PRICING_FILE),
      ),
      "cli": Json::string("moongate"),
      "moondeskAdapterPackage": Json::string(
        "vectie/moondesk/adapters/moonbook",
      ),
      "moontownAdapterPackage": Json::string(
        "vectie/moontown/adapters/moonbook",
      ),
    }),
    "moontown": Json::object({
      "role": Json::string("scheduler-network-watch"),
      "healthUrl": Json::string("\{base_url}/health"),
      "dashboardUrl": Json::string("\{base_url}/"),
      "statusUrl": Json::string("\{base_url}/status"),
      "statsUrl": Json::string("\{base_url}/stats"),
      "metricsUrl": Json::string("\{base_url}/metrics"),
      "streamCheckAllProvidersUrl": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "usageProviderLimitsUrl": Json::string(
        "\{base_url}/usage/provider-limits",
      ),
      "suiteStatusFile": Json::string(default_moongate_suite_status_path()),
      "moonclawProviderManifestPath": Json::string(moonclaw_providers_file),
      "moonclawProviderManifestCommand": Json::string("moongate"),
      "moonclawProviderManifestArgs": Json::array([
        Json::string("suite"),
        Json::string("write-moonclaw-providers"),
        Json::string("--path"),
        Json::string(moonclaw_providers_file),
      ]),
      "moonclawProviderManifestFullCommand": Json::string(
        moonclaw_providers_write_command,
      ),
      "moonclawProviderManifestTarget": Json::string("moonbook"),
      "moonbookProviderManifestPath": Json::string(moonclaw_providers_file),
      "moonbookProviderManifestCommand": Json::string("moongate"),
      "moonbookProviderManifestArgs": Json::array([
        Json::string("suite"),
        Json::string("write-moonclaw-providers"),
        Json::string("--path"),
        Json::string(moonclaw_providers_file),
      ]),
      "moonbookProviderManifestFullCommand": Json::string(
        moonclaw_providers_write_command,
      ),
      "adapterPackages": Json::array([
        Json::string("vectie/moontown/adapters/moonclaw"),
        Json::string("vectie/moontown/adapters/moonbook"),
      ]),
    }),
    "moondesk": Json::object({
      "role": Json::string("operator-dashboard"),
      "suiteStatusFile": Json::string(default_moongate_suite_status_path()),
      "dashboardUrl": Json::string("\{base_url}/"),
      "healthUrl": Json::string("\{base_url}/health"),
      "statusUrl": Json::string("\{base_url}/status"),
      "statsUrl": Json::string("\{base_url}/stats"),
      "metricsUrl": Json::string("\{base_url}/metrics"),
      "modelsUrl": Json::string("\{openai_base_url}/models"),
      "providerPresetsUrl": Json::string("\{base_url}/providers/presets"),
      "claudeDesktopBaseUrl": Json::string(claude_desktop_base_url),
      "streamCheckProviderUrl": Json::string(
        "\{base_url}/proxy/stream-check/provider",
      ),
      "streamCheckAllProvidersUrl": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "streamCheckConfigUrl": Json::string(
        "\{base_url}/proxy/stream-check/config",
      ),
      "configStatusUrl": Json::string("\{base_url}/config/status"),
      "adapterPackages": Json::array([
        Json::string("vectie/moondesk/adapters/moonclaw"),
        Json::string("vectie/moondesk/adapters/moonbook"),
        Json::string("vectie/moondesk/adapters/moontown"),
      ]),
    }),
  })
}

///|
fn moonclaw_providers_file_json(
  openai_base_url : String,
  model : String,
) -> Json {
  Json::object({
    "providers": Json::object({
      "moongate": Json::object({
        "baseUrl": Json::string(openai_base_url),
        "api": Json::string("openai"),
        "apiKey": Json::string("moongate-local"),
        "models": Json::array([
          Json::object({
            "id": Json::string(model),
            "name": Json::string("moongate/\{model}"),
            "reasoning": Json::boolean(true),
            "input": Json::array([Json::string("text"), Json::string("image")]),
          }),
        ]),
      }),
    }),
  })
}

///|
pub fn moongate_moonclaw_providers_file_json(
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
) -> Json {
  moonclaw_providers_file_json(moongate_openai_base_url(host, port), model)
}

///|
pub async fn write_moongate_moonclaw_providers_file(
  path? : String = default_moongate_moonclaw_providers_file_path(),
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
) -> String {
  let dir = @pathx.dirname(path)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let json = moongate_moonclaw_providers_file_json(host~, port~, model~).stringify(
    indent=2,
  )
  @fsx.write_to_file(path, json)
  path
}

///|
pub fn default_moongate_moonclaw_providers_file_path() -> String {
  moongate_moonclaw_providers_file()
}

///|
pub fn default_moongate_moonclaw_providers_file_path_for_workspace_root(
  root : String,
) -> String {
  moongate_moonclaw_providers_file_for_workspace_root(root)
}

///|
fn moonclaw_model_config_json(openai_base_url : String, model : String) -> Json {
  Json::object({
    "name": Json::string("moongate/\{model}"),
    "description": Json::string(
      "MoonGate local OpenAI-compatible proxy model for the Moon suite.",
    ),
    "model_name": Json::string(model),
    "model_type": Json::string("saas/openai"),
    "api_key": Json::string("moongate-local"),
    "base_url": Json::string(openai_base_url),
    "safe_zone_tokens": Json::number(200000.0),
  })
}

///|
fn moongate_suite_capabilities() -> Array[String] {
  [
    "openai-compatible-proxy", "anthropic-compatible-proxy", "claude-desktop-gateway",
    "gemini-compatible-proxy", "moongate-usage-statistics", "moongate-stream-check",
    "session-usage-sync", "provider-model-catalog", "provider-presets", "moongate-skills-management",
    "suite-discovery", "codex-config-install",
  ]
}

///|
fn moongate_suite_commands_json(port : Int, model : String) -> Json {
  let moonclaw_providers_write_command = "moongate suite write-moonclaw-providers --path \{moongate_moonclaw_providers_file()}"
  Json::object({
    "start": Json::string("moongate start --port \{port}"),
    "health": Json::string("moongate health"),
    "status": Json::string("moongate status"),
    "stats": Json::string("moongate stats"),
    "usageLogs": Json::string("moongate usage logs"),
    "usageSummary": Json::string("moongate usage summary"),
    "usageApps": Json::string("moongate usage apps"),
    "usageTrends": Json::string("moongate usage trends"),
    "usageLimits": Json::string(
      "moongate usage limits --provider-id <provider_id> --app-type <app_type>",
    ),
    "usageProviders": Json::string("moongate usage providers"),
    "usageModels": Json::string("moongate usage models"),
    "usageSources": Json::string("moongate usage sources"),
    "usageSync": Json::string("moongate usage sync"),
    "usagePricing": Json::string("moongate usage pricing"),
    "usageDetail": Json::string(
      "moongate usage detail --request-id <request_id>",
    ),
    "providerPresets": Json::string(
      "moongate provider presets list --app-type <app_type>",
    ),
    "streamCheckProvider": Json::string(
      "moongate stream-check provider --app-type <app_type> --provider-id <provider_id>",
    ),
    "streamCheckAll": Json::string(
      "moongate stream-check all --app-type <app_type>",
    ),
    "streamCheckConfig": Json::string("moongate stream-check config"),
    "streamCheckConfigSet": Json::string(
      "moongate stream-check config set --timeout-secs <seconds>",
    ),
    "codexInstall": Json::string(
      "moongate codex install --port \{port} --model \{model}",
    ),
    "copilotAuthStatus": Json::string("moongate copilot status"),
    "copilotLogin": Json::string("moongate copilot login"),
    "claudeDesktopInstall": Json::string(
      "moongate claude-desktop install --port \{port}",
    ),
    "skillsList": Json::string("moongate skills installed"),
    "skillsSearch": Json::string("moongate skills search --query <query>"),
    "skillsInstall": Json::string(
      "moongate skills install-unified --directory <directory> --app-type <app_type>",
    ),
    "skillsRepos": Json::string("moongate skills repos"),
    "updateTrayMenu": Json::string("moongate runtime tray-menu update"),
    "suiteManifest": Json::string("moongate suite manifest"),
    "suiteStatus": Json::string("moongate suite status"),
    "suiteDrift": Json::string("moongate suite drift --root <suite_root>"),
    "suiteWriteStatus": Json::string("moongate suite write-status"),
    "moonclawProviders": Json::string("moongate suite moonclaw-providers"),
    "moonclawProvidersWrite": Json::string(moonclaw_providers_write_command),
  })
}

///|
fn moongate_suite_routes() -> Array[String] {
  [
    "GET /", "GET /ui/rabbita", "GET /assets/moongate.css", "GET /assets/moongate-core.js",
    "GET /assets/moongate-frameworks.js", "GET /assets/moongate-usage.js", "GET /assets/moongate-setup.js",
    "GET /assets/moongate-suite.js", "GET /assets/moongate-resilience.js", "GET /assets/moongate.js",
    "GET /participant/register", "GET /control/bootstrap", "GET /suite/manifest",
    "GET /suite/status", "GET /suite/drift", "POST /suite/status/write", "GET /suite/moonclaw-providers",
    "POST /suite/moonclaw-providers/write", "GET /health", "GET /status", "GET /stats",
    "GET /metrics", "GET /usage/logs", "GET /usage/summary", "GET /usage/summary/by-app",
    "GET /usage/provider-stats", "GET /usage/trends", "GET /usage/provider-limits",
    "GET /usage/model-stats", "GET /usage/data-sources", "POST /usage/sync-session",
    "GET /usage/model-pricing", "POST /usage/model-pricing", "DELETE /usage/model-pricing",
    "GET /usage/request-detail/*path", "GET /usage/provider-usage", "GET /usage/balance",
    "GET /usage/subscription-quota", "GET /usage/codex-oauth-quota", "GET /usage/codex-oauth-models",
    "GET /usage/coding-plan-quota", "POST /usage/test-script", "POST /proxy/stream-check/provider",
    "POST /proxy/stream-check/all", "GET /proxy/stream-check/config", "POST /proxy/stream-check/config",
    "GET /providers/presets", "GET /v1/models", "GET /claude-desktop/v1/models",
    "POST /v1/messages", "POST /claude-desktop/v1/messages", "POST /v1/responses",
    "POST /v1/responses/compact", "POST /v1/chat/completions", "POST /openclaw/v1/chat/completions",
    "GET /auth/status", "GET /auth/accounts", "POST /auth/login", "POST /auth/poll",
    "DELETE /auth/account", "POST /auth/default-account", "POST /auth/logout", "GET /copilot/status",
    "GET /copilot/accounts", "GET /copilot/authenticated", "POST /copilot/device-flow",
    "POST /copilot/poll-auth", "POST /copilot/poll-account", "POST /copilot/logout",
    "DELETE /copilot/account", "POST /copilot/default-account", "GET /copilot/token",
    "GET /copilot/models", "GET /copilot/usage", "POST /runtime/open-external", "POST /runtime/clipboard/text",
    "POST /runtime/updates/check", "POST /runtime/tray-menu/update", "GET /runtime/portable-mode",
    "GET /tools/versions", "POST /tools/lifecycle-action", "GET /tools/probe", "POST /runtime/window-theme",
    "POST /runtime/lightweight-mode/enter", "POST /runtime/lightweight-mode/exit",
    "GET /runtime/lightweight-mode", "POST /files/dialogs/save", "POST /config/files/export",
    "POST /config/files/import", "POST /backups/db", "GET /backups/db", "POST /backups/db/restore",
    "POST /backups/db/rename", "DELETE /backups/db/delete", "GET /deeplinks/parse",
    "POST /deeplinks/merge", "POST /deeplinks/import", "POST /sync/webdav/test",
    "POST /sync/webdav/upload", "POST /sync/webdav/download", "POST /sync/webdav/settings",
    "GET /sync/webdav/remote-info", "POST /sync/s3/test", "POST /sync/s3/upload",
    "POST /sync/s3/download", "POST /sync/s3/settings", "GET /sync/s3/remote-info",
    "GET /sessions", "GET /sessions/messages", "POST /sessions/terminal", "POST /sessions/delete",
    "POST /sessions/delete-many", "GET /providers/omo/file", "GET /providers/omo/current",
    "POST /providers/omo/disable", "GET /providers/omo-slim/file", "GET /providers/omo-slim/current",
    "POST /providers/omo-slim/disable", "POST /files/dialogs/open", "POST /files/dialogs/open-zip",
    "GET /skills/installed", "GET /skills/backups", "POST /skills/backups/delete",
    "POST /skills/backups/restore", "POST /skills/install-unified", "POST /skills/uninstall-unified",
    "POST /skills/toggle-app", "GET /skills/unmanaged", "POST /skills/import-apps",
    "GET /skills/discover", "GET /skills/updates", "POST /skills/update", "POST /skills/migrate-storage",
    "GET /skills/search", "GET /skills", "GET /skills/app", "GET /skills/repos",
    "POST /skills/repos", "POST /skills/repos/remove", "POST /skills/install-zip",
    "GET /proxy/status", "POST /proxy/start", "POST /proxy/stop", "POST /proxy/stop-with-restore",
    "GET|POST /proxy/global-config", "GET|POST /proxy/global-url", "POST /proxy/test-url",
    "GET /proxy/upstream-status", "GET /proxy/local-proxies", "GET|POST /proxy/app-config",
    "GET|POST /proxy/default-cost-multiplier", "GET|POST /proxy/pricing-model-source",
    "GET /proxy/provider-health", "GET|POST /proxy/circuit-breaker-config", "GET /proxy/circuit-breaker-stats",
    "POST /proxy/reset-circuit-breaker", "GET|POST|DELETE /proxy/failover-queue",
    "GET /proxy/available-failover-providers", "GET|POST /proxy/auto-failover-enabled",
    "GET|POST /proxy/takeover-status", "GET /proxy/running", "POST /proxy/switch-provider",
    "POST /proxy/sync-current-providers-live", "POST /proxy/import-default-config",
    "GET /providers", "GET /providers/current", "POST /providers", "POST /providers/update",
    "DELETE /providers", "DELETE /providers/live", "POST /providers/switch", "GET /providers/live-settings",
    "POST /providers/terminal", "GET /providers/live-ids", "GET /providers/live-provider",
    "POST /providers/import-live", "GET /providers/universal", "GET /providers/universal/item",
    "POST /providers/universal", "DELETE /providers/universal", "POST /providers/universal/sync",
    "POST /providers/test-endpoints", "POST /providers/sort-order", "GET /providers/endpoints/list",
    "POST /providers/endpoints", "DELETE /providers/endpoints", "POST /providers/endpoints/touch",
    "GET /config/claude/status", "GET /config/status", "GET /providers/claude-desktop/status",
    "GET /providers/claude-desktop/default-routes", "POST /providers/claude-desktop/import",
    "POST /providers/claude-desktop/official", "GET /config/claude-code/path", "GET /config/dir",
    "POST /config/folder/open", "POST /files/directories/pick", "GET /config/app-path",
    "GET /config/app-folder/open", "GET /config/snippets/claude", "POST /config/snippets/claude",
    "GET /config/snippets", "POST /config/snippets", "POST /config/snippets/extract",
    "GET /config/env/conflicts", "POST /config/env/delete", "POST /config/env/restore",
    "GET /mcp/claude/status", "GET /mcp/claude/config", "POST /mcp/claude/servers",
    "DELETE /mcp/claude/servers", "GET /mcp/validate", "GET /mcp/config", "POST /mcp/config/servers",
    "DELETE /mcp/config/servers", "POST /mcp/enabled", "GET /mcp/servers", "POST /mcp/servers",
    "DELETE /mcp/servers", "POST /mcp/apps/toggle", "POST /mcp/import-apps", "GET /prompts",
    "POST /prompts", "DELETE /prompts", "POST /prompts/enable", "POST /prompts/import-file",
    "GET /prompts/current-file", "GET /settings", "POST /settings", "POST /runtime/restart",
    "POST /runtime/updates/install-restart", "GET /settings/app-config-dir", "POST /settings/app-config-dir",
    "POST /settings/auto-launch", "GET /settings/auto-launch", "GET /settings/rectifier",
    "POST /settings/rectifier", "GET /settings/optimizer", "POST /settings/optimizer",
    "GET /settings/copilot-optimizer", "POST /settings/copilot-optimizer", "GET /settings/log",
    "POST /settings/log", "GET /plugin/claude/status", "GET /plugin/claude/config",
    "POST /plugin/claude/config", "GET /plugin/claude/applied", "POST /plugin/claude/onboarding-skip",
    "POST /plugin/claude/onboarding-skip/clear", "GET /workspace/memory", "GET /workspace/memory/file",
    "POST /workspace/memory/write", "GET /workspace/memory/search", "POST /workspace/memory/delete",
    "DELETE /workspace/memory/file", "GET /workspace/files", "POST /workspace/files/read",
    "POST /workspace/files", "POST /workspace/open", "GET /openclaw/config-health",
    "GET /openclaw/default-model", "POST /openclaw/default-model", "GET /openclaw/model-catalog",
    "POST /openclaw/model-catalog", "GET /openclaw/agents-defaults", "POST /openclaw/agents-defaults",
    "GET /openclaw/env", "POST /openclaw/env", "GET /openclaw/tools", "POST /openclaw/tools",
    "GET /hermes/model-config", "GET /hermes/memory", "POST /hermes/memory", "GET /hermes/memory-limits",
    "POST /hermes/memory-enabled", "POST /hermes/web-ui", "POST /hermes/dashboard",
    "POST /config/models", "ANY /gemini/v1beta/*path", "ANY /gemini/v1/*path",
  ]
}
