///|
const MOONSTAT_DEFAULT_CLIENT_BASE_URL = "http://127.0.0.1:15721"

///|
pub struct MoonstatUsageQuery {
  start_date : String?
  end_date : String?
  app_type : String?
  provider_id : String?
  provider_name : String?
  model : String?
  status_code : String?
  page : Int?
  page_size : Int?
}

///|
pub fn MoonstatUsageQuery::empty() -> MoonstatUsageQuery {
  MoonstatUsageQuery::new(
    start_date=None,
    end_date=None,
    app_type=None,
    provider_id=None,
    provider_name=None,
    model=None,
    status_code=None,
    page=None,
    page_size=None,
  )
}

///|
pub fn MoonstatUsageQuery::new(
  start_date~ : String?,
  end_date~ : String?,
  app_type~ : String?,
  provider_id~ : String?,
  provider_name~ : String?,
  model~ : String?,
  status_code~ : String?,
  page~ : Int?,
  page_size~ : Int?,
) -> MoonstatUsageQuery {
  {
    start_date,
    end_date,
    app_type,
    provider_id,
    provider_name,
    model,
    status_code,
    page,
    page_size,
  }
}

///|
pub struct MoonstatSessionSyncQuery {
  projects_dir : String?
  codex_dir : String?
  gemini_dir : String?
  opencode_export_path : String?
  opencode_db_path : String?
}

///|
pub fn MoonstatSessionSyncQuery::empty() -> MoonstatSessionSyncQuery {
  MoonstatSessionSyncQuery::new(
    projects_dir=None,
    codex_dir=None,
    gemini_dir=None,
    opencode_export_path=None,
    opencode_db_path=None,
  )
}

///|
pub fn MoonstatSessionSyncQuery::new(
  projects_dir~ : String?,
  codex_dir~ : String?,
  gemini_dir~ : String?,
  opencode_export_path~ : String?,
  opencode_db_path~ : String?,
) -> MoonstatSessionSyncQuery {
  {
    projects_dir,
    codex_dir,
    gemini_dir,
    opencode_export_path,
    opencode_db_path,
  }
}

///|
pub struct MoonstatModel {
  id : String
  owner : String?
  context_window : Int?
}

///|
pub struct MoonstatUsageSummary {
  total_requests : Int
  total_cost : String
  total_input_tokens : Int64
  total_output_tokens : Int64
  total_cache_creation_tokens : Int64
  total_cache_read_tokens : Int64
  real_total_tokens : Int64
  success_rate : Double
  cache_hit_rate : Double
}

///|
pub struct MoonstatAgentClient {
  id : String
  app_type : String
  protocol : String
  base_url : String
  primary_route : String
  setup_command : String?
  usage : String?
}

///|
pub struct MoonstatClient {
  base_url : String
  api_key : String?
  user_agent : String?
}

///|
pub fn MoonstatClient::new(
  base_url? : String = MOONSTAT_DEFAULT_CLIENT_BASE_URL,
  api_key? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient {
  {
    base_url: moonstat_client_normalize_base_url(base_url),
    api_key,
    user_agent,
  }
}

///|
pub fn MoonstatClient::from_host(
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  api_key? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient {
  MoonstatClient::new(
    base_url=@suite.base_url(host, port),
    api_key~,
    user_agent~,
  )
}
