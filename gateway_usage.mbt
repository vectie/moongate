///|
async fn Gateway::record_success_usage(
  self : Gateway,
  usage : TokenUsage,
  response_bytes : Int,
) -> Unit {
  self.record_provider_result(true)
  self.usage.stats.record_success_usage_with_pricing(
    usage,
    response_bytes,
    self.pricing_override_rows(),
    self.usage.pricing_deleted_model_ids,
  )
  self.usage.stats.save_persistent_store()
}

///|
async fn Gateway::record_success_stream_usage(
  self : Gateway,
  usage : TokenUsage?,
  response_bytes : Int,
  record_provider? : Bool = true,
  first_token_ms? : Int? = None,
  skip_empty_usage? : Bool = false,
) -> Unit {
  if record_provider {
    self.record_provider_result(true)
  }
  if skip_empty_usage {
    match usage {
      Some(usage) if usage.has_billable_tokens() => ()
      _ => {
        self.usage.stats.record_success_without_usage_log(response_bytes)
        self.usage.stats.save_persistent_store()
        return
      }
    }
  }
  self.usage.stats.record_success_usage_with_pricing(
    usage.unwrap_or(TokenUsage::empty()),
    response_bytes,
    self.pricing_override_rows(),
    self.usage.pricing_deleted_model_ids,
    first_token_ms~,
  )
  self.usage.stats.save_persistent_store()
}

///|
fn UsageService::stats_json(self : UsageService) -> Json {
  self.stats.to_json()
}

///|
fn UsageService::metrics_text(self : UsageService) -> String {
  self.stats.prometheus_metrics()
}

///|
async fn UsageService::usage_logs_json(
  self : UsageService,
  filters : RequestLogFilters,
  page : Int,
  page_size : Int,
  pricing_overrides : Array[ModelPricing],
) -> Json {
  let backfilled = self.stats.backfill_missing_usage_costs(
    pricing_overrides,
    self.pricing_deleted_model_ids,
  )
  if backfilled > 0 {
    self.stats.save_persistent_store()
  }
  self.stats.usage_logs_paginated_json(
    filters,
    page~,
    page_size~,
    pricing_overrides~,
    deleted_model_ids=self.pricing_deleted_model_ids,
  )
}

///|
fn UsageService::summary_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.usage_summary_filtered_json(start_date~, end_date~, app_type~)
}

///|
fn UsageService::summary_by_app_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
) -> Json {
  self.stats.usage_summary_by_app_filtered_json(start_date~, end_date~)
}

///|
fn UsageService::trends_json(
  self : UsageService,
  start_ts? : Int? = None,
  end_ts? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.usage_trends_json(start_ts~, end_ts~, app_type~)
}

///|
fn UsageService::provider_limit_status_json(
  self : UsageService,
  provider_id : String,
  app_type : String,
  daily_limit_usd? : String? = None,
  monthly_limit_usd? : String? = None,
) -> Json {
  self.stats.provider_limit_status_json(
    provider_id,
    app_type,
    daily_limit_usd~,
    monthly_limit_usd~,
  )
}

///|
fn UsageService::provider_stats_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.provider_stats_filtered_json(start_date~, end_date~, app_type~)
}

///|
fn UsageService::model_stats_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.model_stats_filtered_json(start_date~, end_date~, app_type~)
}

///|
fn UsageService::data_sources_json(self : UsageService) -> Json {
  self.stats.usage_data_sources_json()
}

///|
async fn UsageService::request_detail_json(
  self : UsageService,
  request_id : String,
  pricing_overrides : Array[ModelPricing],
) -> Json {
  let backfilled = self.stats.backfill_missing_usage_costs(
    pricing_overrides,
    self.pricing_deleted_model_ids,
  )
  if backfilled > 0 {
    self.stats.save_persistent_store()
  }
  match
    self.stats.request_detail_json_with_pricing(
      request_id,
      pricing_overrides,
      self.pricing_deleted_model_ids,
    ) {
    Some(detail) => detail
    None => Json::null()
  }
}

///|
async fn Gateway::handle_stats(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.usage.stats_json().stringify(indent=2))
  w.flush()
}

///|
async fn Gateway::handle_metrics(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
  w.write_header(@status.Ok)
  w.write(self.usage.metrics_text())
  w.flush()
}

///|
async fn Gateway::handle_usage_logs(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  let body = proxy_json_body(r)
  let filters = usage_request_log_filters_from_request(r.path, body)
  let pricing_overrides = self.pricing_override_rows()
  w.write(
    self.usage
    .usage_logs_json(
      filters,
      usage_int_from_request(r.path, body, ["page"]).unwrap_or(0),
      usage_int_from_request(r.path, body, ["page_size", "pageSize"]).unwrap_or(
        20,
      ),
      pricing_overrides,
    )
    .stringify(indent=2),
  )
  w.flush()
}

///|
async fn Gateway::handle_usage_summary(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.usage.summary_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
      app_type=usage_string_from_request(r.path, body, ["app_type", "appType"]),
    ),
  )
}

///|
async fn Gateway::handle_usage_summary_by_app(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.usage.summary_by_app_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
    ),
  )
}

///|
async fn Gateway::handle_usage_trends(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let start_ts = usage_int_from_request(r.path, body, [
    "start_date", "startDate",
  ])
  let end_ts = usage_int_from_request(r.path, body, ["end_date", "endDate"])
  let app_type = usage_string_from_request(r.path, body, ["app_type", "appType"])
  write_usage_json(w, self.usage.trends_json(start_ts~, end_ts~, app_type~))
}

///|
async fn Gateway::handle_usage_provider_limits(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard usage_string_from_request(r.path, body, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard usage_string_from_request(r.path, body, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  let daily_limit_usd = usage_string_from_request(r.path, body, [
    "daily_limit_usd", "dailyLimitUsd",
  ])
  let monthly_limit_usd = usage_string_from_request(r.path, body, [
    "monthly_limit_usd", "monthlyLimitUsd",
  ])
  let provider_limits = self.provider_limit_config_for_provider(
    provider_id, app_type,
  )
  let daily_limit_usd = usage_limit_override_or_provider_limit(
    daily_limit_usd,
    provider_limits.map(fn(config) { config.daily_limit_usd }),
  )
  let monthly_limit_usd = usage_limit_override_or_provider_limit(
    monthly_limit_usd,
    provider_limits.map(fn(config) { config.monthly_limit_usd }),
  )
  write_usage_json(
    w,
    self.usage.provider_limit_status_json(
      provider_id,
      app_type,
      daily_limit_usd~,
      monthly_limit_usd~,
    ),
  )
}

///|
async fn Gateway::handle_usage_provider_stats(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.usage.provider_stats_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
      app_type=usage_string_from_request(r.path, body, ["app_type", "appType"]),
    ),
  )
}

///|
async fn Gateway::handle_usage_model_stats(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.usage.model_stats_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
      app_type=usage_string_from_request(r.path, body, ["app_type", "appType"]),
    ),
  )
}

///|
async fn Gateway::handle_usage_data_sources(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.usage.data_sources_json())
}

///|
async fn Gateway::handle_query_provider_usage(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, config, ["app", "app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(
    w,
    self.query_provider_usage_standalone(app_type, provider_id).to_json(),
  )
}

///|
async fn Gateway::query_provider_usage_standalone(
  self : Gateway,
  app_type : String,
  provider_id : String,
) -> UsageResult {
  match self.usage.usage_cache.get_script(app_type, provider_id) {
    Some(result) => return result
    None => ()
  }
  match self.proxy.provider_router.provider_by_id(app_type, provider_id) {
    Some(provider) =>
      match moon_provider_balance_query_credentials(provider) {
        Some((base_url, api_key)) => return moon_get_balance(base_url, api_key)
        None => ()
      }
    None => ()
  }
  UsageResult::new(false, error=Some("Usage query is disabled"))
}

///|
async fn Gateway::handle_test_usage_script(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, config, ["app", "app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  let result = match usage_result_from_request(r.path, body) {
    Some(result) => result
    None =>
      match test_usage_script_template_result(r.path, body) {
        Some(result) => result
        None =>
          UsageResult::new(
            false,
            error=Some(
              "Usage script execution is unavailable in standalone Moonstat; provide a ccs UsageResult JSON object as result or scriptCode.",
            ),
          )
      }
  }
  self.usage.usage_cache.put_script(app_type, provider_id, result)
  write_usage_json(w, result.to_json())
}

///|
async fn Gateway::handle_usage_sync_session(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let claude_projects_dir = usage_query_value_any(
    r.path,
    "projects_dir",
    "projectsDir",
  ).unwrap_or(default_claude_projects_dir())
  let codex_dir = usage_query_value_any(r.path, "codex_dir", "codexDir").unwrap_or(
    default_codex_config_dir(),
  )
  let gemini_dir = usage_query_value_any(r.path, "gemini_dir", "geminiDir").unwrap_or(
    default_gemini_dir(),
  )
  let opencode_export_path = usage_query_value_any(
    r.path,
    "opencode_export_path",
    "opencodeExportPath",
  ).unwrap_or(default_opencode_export_path())
  let opencode_db_path = usage_query_value_any(
    r.path,
    "opencode_db_path",
    "opencodeDbPath",
  ).unwrap_or(default_opencode_db_path())
  let result = self.usage.stats.sync_session_logs(
    claude_projects_dir~,
    codex_dir~,
    gemini_dir~,
    opencode_db_path~,
    opencode_export_path~,
  )
  self.usage.stats.save_persistent_store()
  write_usage_json(w, result.to_json())
}

///|
async fn Gateway::handle_usage_request_detail(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let request_id = usage_request_detail_id_from_request(r.path, body)
  let pricing_overrides = self.pricing_override_rows()
  write_usage_json(
    w,
    self.usage.request_detail_json(request_id, pricing_overrides),
  )
}

///|
async fn write_usage_json(w : @httpx.ResponseWriter, body : Json) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(body.stringify(indent=2))
  w.flush()
}

///|
async fn write_usage_bad_request(
  w : @httpx.ResponseWriter,
  error : String,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.BadRequest)
  w.write({ "error": Json::string(error) }.to_json().stringify(indent=2))
  w.flush()
}

///|
fn usage_request_detail_id(path : String) -> String {
  match usage_query_value_any(path, "request_id", "requestId") {
    Some(request_id) => return request_id
    None => ()
  }
  let prefix = "/usage/request-detail/"
  let raw = if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    path
  }
  let without_query = match raw.find("?") {
    Some(question_index) => raw[:question_index].to_owned()
    None => raw
  }
  usage_url_decode(without_query[:])
}

///|
fn usage_request_detail_id_from_request(
  path : StringView,
  body : Json?,
) -> String {
  match usage_string_from_request(path, body, ["request_id", "requestId"]) {
    Some(request_id) => request_id
    None => usage_request_detail_id(path.to_owned())
  }
}

///|
fn usage_limit_override_or_provider_limit(
  explicit_limit : String?,
  provider_limit : String??,
) -> String? {
  match explicit_limit {
    Some(value) => Some(value)
    None =>
      match provider_limit {
        Some(Some(value)) => Some(value)
        _ => None
      }
  }
}

///|
fn usage_request_log_filters_from_request(
  path : StringView,
  body : Json?,
) -> RequestLogFilters {
  let filter_body = usage_filter_body(body)
  RequestLogFilters::new(
    app_type=usage_string_from_request(path, filter_body, [
      "app_type", "appType",
    ]),
    provider_name=usage_string_from_request(path, filter_body, [
      "provider_name", "providerName",
    ]),
    model=usage_string_from_request(path, filter_body, ["model"]),
    status_code=usage_int_from_request(path, filter_body, [
      "status_code", "statusCode",
    ]),
    start_date=usage_int_from_request(path, filter_body, [
      "start_date", "startDate",
    ]),
    end_date=usage_int_from_request(path, filter_body, ["end_date", "endDate"]),
  )
}

///|
fn usage_filter_body(body : Json?) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get("filters") {
        Some(Object(filters)) => Some(Json::object(filters))
        _ => body
      }
    _ => body
  }
}

///|
fn usage_string_from_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> String? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  match body {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(String(value)) if !value.is_empty() => return Some(value)
          Some(Number(value, ..)) => return Some(value.to_string())
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn usage_int_from_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> Int? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        try @string.parse_int(value, base=10) catch {
          _ => ()
        } noraise {
          parsed => return Some(parsed)
        }
      None => ()
    }
  }
  match body {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(Number(value, ..)) => return Some(value.trunc().to_int())
          Some(String(value)) =>
            try @string.parse_int(value, base=10) catch {
              _ => ()
            } noraise {
              parsed => return Some(parsed)
            }
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn usage_query_value_any(
  path : StringView,
  left_key : String,
  right_key : String,
) -> String? {
  match usage_query_value(path, left_key) {
    Some(value) => Some(value)
    None => usage_query_value(path, right_key)
  }
}

///|
fn usage_query_int_any(
  path : StringView,
  left_key : String,
  right_key : String,
) -> Int? {
  match usage_query_value_any(path, left_key, right_key) {
    Some(value) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    None => None
  }
}

///|
fn usage_query_double_any(
  path : StringView,
  left_key : String,
  right_key : String,
) -> Double? {
  match usage_query_value_any(path, left_key, right_key) {
    Some(value) => parse_non_negative_decimal_to_double(value)
    None => None
  }
}

///|
fn usage_query_int(path : StringView, key : String) -> Int? {
  match usage_query_value(path, key) {
    Some(value) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    None => None
  }
}

///|
fn usage_query_value(path : StringView, key : String) -> String? {
  let text = path.to_owned()
  guard text.find("?") is Some(question_index) else { return None }
  let query = text[question_index + 1:]
  for pair_view in query.split("&") {
    let pair = pair_view.to_owned()
    guard pair.find("=") is Some(equal_index) else { continue }
    let pair_key = usage_url_decode(pair[:equal_index])
    if pair_key == key {
      let value = usage_url_decode(pair[equal_index + 1:])
      if value.is_empty() {
        return None
      }
      return Some(value)
    }
  }
  None
}

///|
fn usage_url_decode(value : StringView) -> String {
  let builder = StringBuilder::new()
  let chars = value.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '%' && i + 2 < chars.length() {
      match (usage_hex_value(chars[i + 1]), usage_hex_value(chars[i + 2])) {
        (Some(high), Some(low)) => {
          builder.write_char(((high << 4) | low).unsafe_to_char())
          i += 3
          continue
        }
        _ => ()
      }
    } else if ch == '+' {
      builder.write_char(' ')
      i += 1
      continue
    }
    builder.write_char(ch)
    i += 1
  }
  builder.to_string()
}

///|
fn usage_hex_value(ch : Char) -> Int? {
  match ch {
    '0'..='9' => Some(ch.to_int() - '0'.to_int())
    'A'..='F' => Some(ch.to_int() - 'A'.to_int() + 10)
    'a'..='f' => Some(ch.to_int() - 'a'.to_int() + 10)
    _ => None
  }
}

///|
fn usage_decimal_validation_error_from_request(
  path : StringView,
  body : Json?,
  label : String,
  keys : Array[String],
) -> String? {
  let value = usage_string_from_request(path, body, keys).unwrap_or("")
  usage_decimal_validation_error(label, value)
}

///|
fn usage_decimal_validation_error(label : String, value : String) -> String? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return Some("\{label} price is invalid: \{value}")
  }
  if trimmed.has_prefix("-") {
    return Some("\{label} price must be non-negative: \{value}")
  }
  if !usage_non_negative_decimal(value) {
    return Some("\{label} price is invalid: \{value}")
  }
  None
}

///|
fn usage_result_from_request(path : StringView, body : Json?) -> UsageResult? {
  for key in ["result", "usageResult", "scriptCode", "script_code"] {
    match usage_query_value(path, key) {
      Some(value) =>
        match usage_result_from_string(value) {
          Some(result) => return Some(result)
          None => ()
        }
      None => ()
    }
  }
  match body {
    Some(json) => {
      match usage_result_from_json(json) {
        Some(result) => return Some(result)
        None => ()
      }
      guard json is Object(obj) else { return None }
      for key in ["result", "usageResult"] {
        match obj.get(key) {
          Some(value) =>
            match usage_result_or_script_output_from_json(value) {
              Some(result) => return Some(result)
              None => ()
            }
          None => ()
        }
      }
      for key in ["scriptCode", "script_code"] {
        match obj.get(key) {
          Some(String(value)) =>
            match usage_result_from_string(value) {
              Some(result) => return Some(result)
              None => ()
            }
          Some(value) =>
            match usage_result_or_script_output_from_json(value) {
              Some(result) => return Some(result)
              None => ()
            }
          _ => ()
        }
      }
      None
    }
    None => None
  }
}

///|
async fn test_usage_script_template_result(
  path : StringView,
  body : Json?,
) -> UsageResult? {
  let template_type = proxy_string_request(path, body, [
    "templateType", "template_type",
  ]).unwrap_or("")
  match template_type {
    "github_copilot" =>
      match copilot_get_usage(copilot_account_id_request(path, body)) {
        Ok(usage) => Some(moon_copilot_usage_result_from_json(usage))
        Err(error) => Some(UsageResult::new(false, error=Some(error)))
      }
    "balance" => {
      guard proxy_string_request(path, body, ["baseUrl", "base_url"])
        is Some(base_url) else {
        return Some(moon_balance_error("Base URL is empty"))
      }
      let api_key = proxy_string_request(path, body, ["apiKey", "api_key"]).unwrap_or(
        "",
      )
      Some(moon_get_balance(base_url, api_key))
    }
    "token_plan" => {
      let base_url = proxy_string_request(path, body, ["baseUrl", "base_url"]).unwrap_or(
        "",
      )
      let api_key = proxy_string_request(path, body, ["apiKey", "api_key"]).unwrap_or(
        "",
      )
      Some(
        moon_token_plan_usage_result_from_quota(
          moon_get_coding_plan_quota(base_url, api_key),
        ),
      )
    }
    "official_subscription" => {
      let app_type = proxy_string_request(path, body, [
        "app", "appType", "app_type", "tool",
      ]).unwrap_or("")
      Some(
        moon_subscription_usage_result_from_quota(
          moon_get_subscription_quota(app_type),
        ),
      )
    }
    _ => None
  }
}

///|
fn moon_subscription_usage_result_from_quota(
  quota : SubscriptionQuota,
) -> UsageResult {
  if !quota.success {
    return UsageResult::new(
      false,
      error=match quota.error {
        Some(error) => Some(error)
        None => quota.credential_message
      },
    )
  }
  let data : Array[UsageData] = []
  for tier in quota.tiers {
    guard tier is Object(obj) else { continue }
    let used = moon_json_double_from_map(obj, "utilization").unwrap_or(0.0)
    data.push(
      UsageData::new(
        plan_name=json_string_from_map(obj, "name"),
        remaining=Some(100.0 - used),
        total=Some(100.0),
        used=Some(used),
        unit=Some("%"),
        is_valid=Some(true),
        extra=json_string_from_map(obj, "resetsAt"),
      ),
    )
  }
  UsageResult::new(true, data=if data.is_empty() { None } else { Some(data) })
}

///|
fn usage_result_from_string(value : String) -> UsageResult? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  let parsed = @json.parse(trimmed) catch { _ => return None }
  usage_result_or_script_output_from_json(parsed)
}

///|
fn usage_non_negative_decimal(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() || trimmed.has_prefix("-") {
    return false
  }
  let mut seen_digit = false
  let mut seen_dot = false
  let mut digit_after_dot = false
  for ch in trimmed {
    let code = ch.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      seen_digit = true
      if seen_dot {
        digit_after_dot = true
      }
    } else if ch == '.' && !seen_dot && seen_digit {
      seen_dot = true
    } else {
      return false
    }
  }
  seen_digit && (!seen_dot || digit_after_dot)
}

///|
fn gemini_native_stream_anthropic_usage_json(usage : Json?) -> Json {
  let body = match usage {
    Some(usage) => Json::object({ "usageMetadata": usage })
    None => Json::object({})
  }
  token_usage_from_gemini_response(body)
  .unwrap_or(TokenUsage::empty())
  .as_anthropic_usage_json()
}

///|
fn openai_chat_zero_usage_json() -> Json {
  Json::object({
    "input_tokens": Json::number(0.0),
    "output_tokens": Json::number(0.0),
  })
}

///|
fn openai_chat_stream_anthropic_usage_json(usage : Map[String, Json]) -> Json {
  let cache_read = match json_int(usage, "cache_read_input_tokens") {
    Some(tokens) => tokens
    None =>
      match usage.get("prompt_tokens_details") {
        Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
        _ => 0
      }
  }
  let cache_creation = json_int_or_zero(usage, "cache_creation_input_tokens")
  let prompt_tokens = json_int_or_zero(usage, "prompt_tokens")
  let input_tokens = max_int(prompt_tokens - cache_read - cache_creation, 0)
  let result : Map[String, Json] = {
    "input_tokens": Json::number(input_tokens.to_double()),
    "output_tokens": Json::number(
      json_int_or_zero(usage, "completion_tokens").to_double(),
    ),
  }
  if cache_read > 0 {
    result["cache_read_input_tokens"] = Json::number(cache_read.to_double())
  }
  if cache_creation > 0 {
    result["cache_creation_input_tokens"] = Json::number(
      cache_creation.to_double(),
    )
  }
  Json::object(result)
}

///|
fn responses_stream_anthropic_usage_json(
  response_obj : Map[String, Json],
) -> Json {
  guard response_obj.get("usage") is Some(Object(usage)) else {
    return openai_chat_zero_usage_json()
  }
  let input_tokens = match json_int(usage, "input_tokens") {
    Some(n) => n
    None => json_int_or_zero(usage, "prompt_tokens")
  }
  let output_tokens = match json_int(usage, "output_tokens") {
    Some(n) => n
    None => json_int_or_zero(usage, "completion_tokens")
  }
  let mut cache_read_tokens = match usage.get("input_tokens_details") {
    Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
    _ =>
      match usage.get("prompt_tokens_details") {
        Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
        _ => 0
      }
  }
  match json_int(usage, "cache_read_input_tokens") {
    Some(n) => cache_read_tokens = n
    None => ()
  }
  let cache_creation_tokens = json_int_or_zero(
    usage, "cache_creation_input_tokens",
  )
  TokenUsage::new(
    input_tokens~,
    output_tokens~,
    cache_read_tokens~,
    cache_creation_tokens~,
  ).as_anthropic_usage_json()
}
