///|
const MOONSTAT_CODING_PLAN_TOOL = "coding_plan"

///|
const MOONSTAT_TIER_WEEKLY_LIMIT = "weekly_limit"

///|
priv enum MoonCodingPlanProvider {
  Kimi
  ZhipuCn
  ZhipuEn
  MiniMaxCn
  MiniMaxEn
  ZenMux
}

///|
priv enum MoonZhipuWindow {
  FiveHour
  Weekly
}

///|
priv struct MoonZhipuEntry {
  reset_ms : Int64?
  percentage : Double
  resets_at : String?
}

///|
fn moon_detect_coding_plan_provider(
  base_url : String,
) -> MoonCodingPlanProvider? {
  let url = base_url.to_lower()
  if url.contains("api.kimi.com/coding") {
    Some(Kimi)
  } else if url.contains("open.bigmodel.cn") || url.contains("bigmodel.cn") {
    Some(ZhipuCn)
  } else if url.contains("api.z.ai") {
    Some(ZhipuEn)
  } else if url.contains("api.minimaxi.com") {
    Some(MiniMaxCn)
  } else if url.contains("api.minimax.io") {
    Some(MiniMaxEn)
  } else if url.contains("zenmux") {
    Some(ZenMux)
  } else {
    None
  }
}

///|
async fn moon_get_coding_plan_quota(
  base_url : String,
  api_key : String,
) -> SubscriptionQuota {
  if api_key.trim().is_empty() {
    return SubscriptionQuota::not_found(MOONSTAT_CODING_PLAN_TOOL)
  }
  match moon_detect_coding_plan_provider(base_url) {
    Some(Kimi) => moon_query_kimi_coding_plan(api_key)
    Some(ZhipuCn) | Some(ZhipuEn) =>
      moon_query_zhipu_coding_plan(base_url, api_key)
    Some(MiniMaxCn) => moon_query_minimax_coding_plan(api_key, true)
    Some(MiniMaxEn) => moon_query_minimax_coding_plan(api_key, false)
    Some(ZenMux) => moon_query_zenmux_coding_plan(base_url, api_key)
    None => SubscriptionQuota::not_found(MOONSTAT_CODING_PLAN_TOOL)
  }
}

///|
fn moon_coding_plan_error(message : String) -> SubscriptionQuota {
  moon_quota_error(MOONSTAT_CODING_PLAN_TOOL, Valid, message)
}

///|
fn moon_coding_plan_auth_error(status_code : Int) -> SubscriptionQuota {
  SubscriptionQuota::new(
    MOONSTAT_CODING_PLAN_TOOL,
    credential_status=Expired,
    credential_message=Some("Invalid API key"),
    success=false,
    error=Some("Authentication failed (HTTP \{status_code})"),
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
async fn moon_query_kimi_coding_plan(api_key : String) -> SubscriptionQuota {
  match
    moon_fetch_json_get(
      "https://api.kimi.com/coding/v1/usages",
      { "Authorization": "Bearer \{api_key}", "Accept": "application/json" },
      expired_message="Authentication failed",
    ) {
    Err(error) =>
      if error.status == Expired {
        moon_coding_plan_auth_error(
          moon_status_code_from_message(error.message),
        )
      } else {
        moon_coding_plan_error(error.message)
      }
    Ok(body) => moon_parse_kimi_coding_plan(body)
  }
}

///|
fn moon_parse_kimi_coding_plan(body : Json) -> SubscriptionQuota {
  let tiers : Array[Json] = []
  guard body is Object(obj) else {
    return moon_coding_plan_error("Failed to parse response: expected object")
  }
  match obj.get("limits") {
    Some(Array(limits)) =>
      for item in limits {
        guard item is Object(limit_item) else { continue }
        guard limit_item.get("detail") is Some(Object(detail)) else { continue }
        let limit = moon_json_double_from_map(detail, "limit").unwrap_or(1.0)
        let remaining = moon_json_double_from_map(detail, "remaining").unwrap_or(
          0.0,
        )
        let used = (limit - remaining).max(0.0)
        tiers.push(
          moon_quota_tier_json(
            MOON_QUOTA_TIER_FIVE_HOUR,
            if limit > 0.0 {
              used / limit * 100.0
            } else {
              0.0
            },
            resets_at=moon_extract_reset_time(detail.get("resetTime")),
          ),
        )
      }
    _ => ()
  }
  match obj.get("usage") {
    Some(Object(usage)) => {
      let limit = moon_json_double_from_map(usage, "limit").unwrap_or(1.0)
      let remaining = moon_json_double_from_map(usage, "remaining").unwrap_or(
        0.0,
      )
      let used = (limit - remaining).max(0.0)
      tiers.push(
        moon_quota_tier_json(
          MOONSTAT_TIER_WEEKLY_LIMIT,
          if limit > 0.0 {
            used / limit * 100.0
          } else {
            0.0
          },
          resets_at=moon_extract_reset_time(usage.get("resetTime")),
        ),
      )
    }
    _ => ()
  }
  SubscriptionQuota::new(
    MOONSTAT_CODING_PLAN_TOOL,
    tiers~,
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
async fn moon_query_zhipu_coding_plan(
  base_url : String,
  api_key : String,
) -> SubscriptionQuota {
  let url = "\{moon_zhipu_quota_base(base_url)}/api/monitor/usage/quota/limit"
  match
    moon_fetch_json_get(
      url,
      {
        "Authorization": api_key,
        "Content-Type": "application/json",
        "Accept-Language": "en-US,en",
      },
      expired_message="Authentication failed",
    ) {
    Err(error) =>
      if error.status == Expired {
        moon_coding_plan_auth_error(
          moon_status_code_from_message(error.message),
        )
      } else {
        moon_coding_plan_error(error.message)
      }
    Ok(body) => moon_parse_zhipu_coding_plan(body)
  }
}

///|
fn moon_zhipu_quota_base(base_url : String) -> String {
  if base_url.to_lower().contains("bigmodel.cn") {
    "https://open.bigmodel.cn"
  } else {
    "https://api.z.ai"
  }
}

///|
fn moon_parse_zhipu_coding_plan(body : Json) -> SubscriptionQuota {
  guard body is Object(obj) else {
    return moon_coding_plan_error("Failed to parse response: expected object")
  }
  match obj.get("success") {
    Some(False) => {
      let msg = json_string_from_map(obj, "msg").unwrap_or("Unknown error")
      return moon_coding_plan_error("API error: \{msg}")
    }
    _ => ()
  }
  guard obj.get("data") is Some(data) else {
    return moon_coding_plan_error("Missing 'data' field in response")
  }
  let level = match data {
    Object(data_obj) => json_string_from_map(data_obj, "level")
    _ => None
  }
  SubscriptionQuota::new(
    MOONSTAT_CODING_PLAN_TOOL,
    credential_message=level,
    tiers=moon_parse_zhipu_token_tiers(data),
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
fn moon_parse_zhipu_token_tiers(data : Json) -> Array[Json] {
  let mut five_hour : MoonZhipuEntry? = None
  let mut weekly : MoonZhipuEntry? = None
  let unclassified : Array[MoonZhipuEntry] = []
  guard data is Object(data_obj) else { return [] }
  match data_obj.get("limits") {
    Some(Array(limits)) =>
      for item in limits {
        guard item is Object(limit_item) else { continue }
        let limit_type = json_string_from_map(limit_item, "type").unwrap_or("")
        if limit_type.to_lower() != "tokens_limit" {
          continue
        }
        let reset_ms = json_int64_from_map(limit_item, "nextResetTime")
        let entry : MoonZhipuEntry = {
          reset_ms,
          percentage: moon_json_double_from_map(limit_item, "percentage").unwrap_or(
            0.0,
          ),
          resets_at: match reset_ms {
            Some(ms) => Some(@os.local_rfc3339(ms / 1000L))
            None => None
          },
        }
        match moon_classify_zhipu_window(limit_item) {
          Some(FiveHour) if five_hour is None => five_hour = Some(entry)
          Some(Weekly) if weekly is None => weekly = Some(entry)
          _ => unclassified.push(entry)
        }
      }
    _ => ()
  }
  moon_sort_zhipu_entries(unclassified)
  for entry in unclassified {
    if five_hour is None {
      five_hour = Some(entry)
    } else if weekly is None {
      weekly = Some(entry)
    }
  }
  let tiers : Array[Json] = []
  match five_hour {
    Some(entry) =>
      tiers.push(
        moon_quota_tier_json(
          MOON_QUOTA_TIER_FIVE_HOUR,
          entry.percentage,
          resets_at=entry.resets_at,
        ),
      )
    None => ()
  }
  match weekly {
    Some(entry) =>
      tiers.push(
        moon_quota_tier_json(
          MOONSTAT_TIER_WEEKLY_LIMIT,
          entry.percentage,
          resets_at=entry.resets_at,
        ),
      )
    None => ()
  }
  tiers
}

///|
fn moon_classify_zhipu_window(item : Map[String, Json]) -> MoonZhipuWindow? {
  match json_int64_from_map(item, "unit") {
    Some(3L) => Some(FiveHour)
    Some(6L) => Some(Weekly)
    _ => None
  }
}

///|
fn moon_zhipu_entry_sort_key(entry : MoonZhipuEntry) -> Int64 {
  match entry.reset_ms {
    Some(ms) => ms
    None => -9223372036854775808L
  }
}

///|
fn moon_sort_zhipu_entries(entries : Array[MoonZhipuEntry]) -> Unit {
  let mut i = 0
  while i < entries.length() {
    let mut j = i + 1
    while j < entries.length() {
      if moon_zhipu_entry_sort_key(entries[j]) <
        moon_zhipu_entry_sort_key(entries[i]) {
        let current = entries[i]
        entries[i] = entries[j]
        entries[j] = current
      }
      j = j + 1
    }
    i = i + 1
  }
}

///|
async fn moon_query_minimax_coding_plan(
  api_key : String,
  is_cn : Bool,
) -> SubscriptionQuota {
  let domain = if is_cn { "api.minimaxi.com" } else { "api.minimax.io" }
  match
    moon_fetch_json_get(
      "https://\{domain}/v1/api/openplatform/coding_plan/remains",
      {
        "Authorization": "Bearer \{api_key}",
        "Content-Type": "application/json",
      },
      expired_message="Authentication failed",
    ) {
    Err(error) =>
      if error.status == Expired {
        moon_coding_plan_auth_error(
          moon_status_code_from_message(error.message),
        )
      } else {
        moon_coding_plan_error(error.message)
      }
    Ok(body) => moon_parse_minimax_coding_plan(body)
  }
}

///|
fn moon_parse_minimax_coding_plan(body : Json) -> SubscriptionQuota {
  guard body is Object(obj) else {
    return moon_coding_plan_error("Failed to parse response: expected object")
  }
  match obj.get("base_resp") {
    Some(Object(base_resp)) => {
      let status_code = json_int64_from_map(base_resp, "status_code").unwrap_or(
        -1L,
      )
      if status_code != 0L {
        let msg = json_string_from_map(base_resp, "status_msg").unwrap_or(
          "Unknown error",
        )
        return moon_coding_plan_error("API error (code \{status_code}): \{msg}")
      }
    }
    _ => ()
  }
  SubscriptionQuota::new(
    MOONSTAT_CODING_PLAN_TOOL,
    tiers=moon_parse_minimax_tiers(body),
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
fn moon_parse_minimax_tiers(body : Json) -> Array[Json] {
  guard body is Object(obj) else { return [] }
  guard obj.get("model_remains") is Some(Array(model_remains)) else {
    return []
  }
  let mut general : Map[String, Json]? = None
  for item in model_remains {
    guard item is Object(item_obj) else { continue }
    if json_string_from_map(item_obj, "model_name") == Some("general") {
      general = Some(item_obj)
      break
    }
  }
  guard general is Some(item) else { return [] }
  let tiers : Array[Json] = []
  match moon_json_double_from_map(item, "current_interval_remaining_percent") {
    Some(remain_pct) =>
      tiers.push(
        moon_quota_tier_json(
          MOON_QUOTA_TIER_FIVE_HOUR,
          100.0 - remain_pct,
          resets_at=match json_int64_from_map(item, "end_time") {
            Some(ms) => Some(@os.local_rfc3339(ms / 1000L))
            None => None
          },
        ),
      )
    None => ()
  }
  if json_int64_from_map(item, "current_weekly_status") == Some(1L) {
    match moon_json_double_from_map(item, "current_weekly_remaining_percent") {
      Some(remain_pct) =>
        tiers.push(
          moon_quota_tier_json(
            MOONSTAT_TIER_WEEKLY_LIMIT,
            100.0 - remain_pct,
            resets_at=match json_int64_from_map(item, "weekly_end_time") {
              Some(ms) => Some(@os.local_rfc3339(ms / 1000L))
              None => None
            },
          ),
        )
      None => ()
    }
  }
  tiers
}

///|
async fn moon_query_zenmux_coding_plan(
  base_url : String,
  api_key : String,
) -> SubscriptionQuota {
  match
    moon_fetch_json_get(
      base_url,
      { "Authorization": "Bearer \{api_key}", "Accept": "application/json" },
      expired_message="Authentication failed",
    ) {
    Err(error) =>
      if error.status == Expired {
        moon_coding_plan_auth_error(
          moon_status_code_from_message(error.message),
        )
      } else {
        moon_coding_plan_error(error.message)
      }
    Ok(body) => moon_parse_zenmux_coding_plan(body)
  }
}

///|
fn moon_parse_zenmux_coding_plan(body : Json) -> SubscriptionQuota {
  guard body is Object(obj) else {
    return moon_coding_plan_error("Failed to parse response: expected object")
  }
  if obj.get("success") != Some(Json::boolean(true)) {
    let msg = json_string_from_map(obj, "message").unwrap_or("Unknown error")
    return moon_coding_plan_error("API error: \{msg}")
  }
  guard obj.get("data") is Some(Object(data)) else {
    return moon_coding_plan_error("Missing 'data' field in response")
  }
  let tiers : Array[Json] = []
  match data.get("quota_5_hour") {
    Some(Object(row)) =>
      tiers.push(
        moon_quota_tier_json(
          MOON_QUOTA_TIER_FIVE_HOUR,
          moon_json_double_from_map(row, "usage_percentage").unwrap_or(0.0) *
          100.0,
          resets_at=json_string_from_map(row, "resets_at"),
          used_value_usd=moon_json_double_from_map(row, "used_value_usd"),
          max_value_usd=moon_json_double_from_map(row, "max_value_usd"),
        ),
      )
    _ => ()
  }
  match data.get("quota_7_day") {
    Some(Object(row)) =>
      tiers.push(
        moon_quota_tier_json(
          MOONSTAT_TIER_WEEKLY_LIMIT,
          moon_json_double_from_map(row, "usage_percentage").unwrap_or(0.0) *
          100.0,
          resets_at=json_string_from_map(row, "resets_at"),
          used_value_usd=moon_json_double_from_map(row, "used_value_usd"),
          max_value_usd=moon_json_double_from_map(row, "max_value_usd"),
        ),
      )
    _ => ()
  }
  let plan_tier = match data.get("plan") {
    Some(Object(plan)) => json_string_from_map(plan, "tier").unwrap_or("")
    _ => ""
  }
  let account_status = json_string_from_map(data, "account_status").unwrap_or(
    "",
  )
  let plan_info = if !plan_tier.is_empty() {
    "\{plan_tier} (\{account_status})"
  } else {
    ""
  }
  SubscriptionQuota::new(
    MOONSTAT_CODING_PLAN_TOOL,
    credential_message=if plan_info.is_empty() { None } else { Some(plan_info) },
    tiers~,
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
fn moon_extract_reset_time(value : Json?) -> String? {
  match value {
    Some(String(s)) => Some(s)
    Some(Number(n, ..)) => {
      let raw = n.to_int64()
      let ms = if raw < 1000000000000L { raw * 1000L } else { raw }
      Some(@os.local_rfc3339(ms / 1000L))
    }
    _ => None
  }
}

///|
fn moon_status_code_from_message(message : String) -> Int {
  if message.contains("HTTP 401") {
    401
  } else if message.contains("HTTP 403") {
    403
  } else {
    0
  }
}
