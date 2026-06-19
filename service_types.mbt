///|
/// AuthService handles authentication, OAuth flows, and credential management.
priv struct AuthService {
  mut credentials : @codex.Credentials?
  auth_device_user_codes : Map[String, String]
}

///|
fn AuthService::new() -> AuthService {
  { credentials: None, auth_device_user_codes: Map([], capacity=8) }
}

///|
fn AuthService::credentials_loaded(self : AuthService) -> Bool {
  self.credentials is Some(_)
}

///|
/// ProxyService handles provider routing, circuit breakers, failover, and proxy config.
priv struct ProxyService {
  provider_router : ProviderRouter
  gemini_shadow : GeminiShadowStore
  mut proxy_enabled : Bool
  mut proxy_listen_address : String
  mut proxy_listen_port : Int
  mut proxy_enable_logging : Bool
  proxy_takeover_enabled : Map[String, Bool]
  proxy_app_enabled : Map[String, Bool]
  proxy_streaming_first_byte_timeout : Map[String, Int]
  proxy_streaming_idle_timeout : Map[String, Int]
  proxy_non_streaming_timeout : Map[String, Int]
  proxy_default_cost_multipliers : Map[String, String]
  proxy_pricing_model_sources : Map[String, String]
  mut upstream_proxy_url : String?
}

///|
fn ProxyService::new(host : String, port : Int) -> ProxyService {
  {
    provider_router: moonstat_default_provider_router(),
    gemini_shadow: GeminiShadowStore::new(),
    proxy_enabled: true,
    proxy_listen_address: host,
    proxy_listen_port: port,
    proxy_enable_logging: true,
    proxy_takeover_enabled: Map([], capacity=0),
    proxy_app_enabled: Map([], capacity=0),
    proxy_streaming_first_byte_timeout: Map([], capacity=0),
    proxy_streaming_idle_timeout: Map([], capacity=0),
    proxy_non_streaming_timeout: Map([], capacity=0),
    proxy_default_cost_multipliers: Map([], capacity=0),
    proxy_pricing_model_sources: Map([], capacity=0),
    upstream_proxy_url: None,
  }
}

///|
/// UsageService handles usage tracking, cost calculation, and statistics.
priv struct UsageService {
  stats : TrafficStats
  usage_cache : UsageCache
  pricing_overrides : Map[String, ModelPricing]
  pricing_deleted_model_ids : Map[String, Bool]
}

///|
fn UsageService::new() -> UsageService {
  {
    stats: TrafficStats::new(),
    usage_cache: UsageCache::new(),
    pricing_overrides: Map([], capacity=0),
    pricing_deleted_model_ids: Map([], capacity=0),
  }
}

///|
/// ConfigService handles settings, presets, import/export, and app configuration.
priv struct ConfigService {
  mut app_settings : Json
  mut rectifier_config_json : Json
  mut optimizer_config_json : Json
  mut copilot_optimizer_config_json : Json
  mut log_config_json : Json
  config_snippets : Map[String, String]
  mcp_servers : Map[String, Json]
  prompts : Map[String, Json]
  mut lightweight_mode : Bool
  mut window_theme : String
  mut app_config_dir_override : String?
  mut auto_launch_enabled : Bool
  mut claude_plugin_config : String?
  mut claude_plugin_applied : Bool
  mut claude_onboarding_skipped : Bool
  mut stream_check_config : StreamCheckConfig
}

///|
fn ConfigService::new() -> ConfigService {
  {
    app_settings: moon_default_app_settings_json(),
    rectifier_config_json: moon_default_rectifier_config_json(),
    optimizer_config_json: moon_default_optimizer_config_json(),
    copilot_optimizer_config_json: moon_default_copilot_optimizer_config_json(),
    log_config_json: moon_default_log_config_json(),
    config_snippets: Map([], capacity=8),
    mcp_servers: Map([], capacity=16),
    prompts: Map([], capacity=16),
    lightweight_mode: false,
    window_theme: "system",
    app_config_dir_override: None,
    auto_launch_enabled: false,
    claude_plugin_config: None,
    claude_plugin_applied: false,
    claude_onboarding_skipped: false,
    stream_check_config: StreamCheckConfig::default(),
  }
}

///|
/// SessionService handles session listing, messages, and terminal management.
priv struct SessionService {
  codex_chat_history : CodexChatHistoryStore
}

///|
fn SessionService::new() -> SessionService {
  { codex_chat_history: CodexChatHistoryStore::new() }
}

///|
/// WorkspaceService handles local workspace, memory, and file-dialog endpoints.
priv struct WorkspaceService {
  _unit : Unit
}

///|
fn WorkspaceService::new() -> WorkspaceService {
  { _unit: () }
}

///|
/// RuntimeService handles app runtime status and local tool lifecycle endpoints.
priv struct RuntimeService {
  mut last_external_url : String?
}

///|
fn RuntimeService::new() -> RuntimeService {
  { last_external_url: None }
}

///|
/// SkillService handles skill discovery, install, migration, and repository endpoints.
priv struct SkillService {
  _unit : Unit
}

///|
fn SkillService::new() -> SkillService {
  { _unit: () }
}
