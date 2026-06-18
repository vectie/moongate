///|
fn moon_default_copilot_optimizer_config_json() -> Json {
  {
    "enabled": Json::boolean(true),
    "requestClassification": Json::boolean(true),
    "toolResultMerging": Json::boolean(true),
    "compactDetection": Json::boolean(true),
    "deterministicRequestId": Json::boolean(true),
    "subagentDetection": Json::boolean(true),
    "warmupDowngrade": Json::boolean(true),
    "warmupModel": Json::string("gpt-5-mini"),
    "stripThinking": Json::boolean(true),
  }.to_json()
}

///|
fn moon_copilot_optimizer_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  moon_json_config_from_request(path, body, current, [
    ("enabled", ["enabled"], "bool"),
    ("requestClassification", ["requestClassification"], "bool"),
    ("toolResultMerging", ["toolResultMerging"], "bool"),
    ("compactDetection", ["compactDetection"], "bool"),
    ("deterministicRequestId", ["deterministicRequestId"], "bool"),
    ("subagentDetection", ["subagentDetection"], "bool"),
    ("warmupDowngrade", ["warmupDowngrade"], "bool"),
    ("warmupModel", ["warmupModel"], "string"),
    ("stripThinking", ["stripThinking"], "bool"),
  ])
}

///|
async fn ConfigService::handle_get_copilot_optimizer_config(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.copilot_optimizer_config_json)
}

///|
async fn ConfigService::handle_set_copilot_optimizer_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.copilot_optimizer_config_json = moon_copilot_optimizer_config_from_request(
    r.path,
    body,
    self.copilot_optimizer_config_json,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
fn copilot_github_domain_request(path : StringView, body : Json?) -> String? {
  proxy_string_request(path, body, ["githubDomain"])
}

///|
fn copilot_account_id_request(path : StringView, body : Json?) -> String? {
  proxy_string_request(path, body, ["accountId"])
}

///|
async fn AuthService::handle_copilot_poll_for_account(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["deviceCode"]) is Some(device_code) else {
    write_usage_bad_request(w, "missing_device_code")
    return
  }
  match
    copilot_poll_for_account(
      device_code,
      copilot_github_domain_request(r.path, body),
    ) {
    Ok(Some(account)) => write_usage_json(w, account)
    Ok(None) => write_usage_json(w, Json::null())
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_copilot_list_accounts(
  self : AuthService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, copilot_list_accounts())
}

///|
async fn AuthService::handle_copilot_remove_account(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard copilot_account_id_request(r.path, body) is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match copilot_remove_account(account_id) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_copilot_set_default_account(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard copilot_account_id_request(r.path, body) is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match copilot_set_default_account(account_id) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_copilot_get_models(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_get_models(copilot_account_id_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_copilot_get_usage(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_get_usage(copilot_account_id_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn moon_copilot_usage_result_from_json(usage : Json) -> UsageResult {
  guard usage is Object(obj) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard obj.get("quota_snapshots") is Some(Object(quota_snapshots)) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard quota_snapshots.get("premium_interactions") is Some(Object(premium)) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard moon_json_double_from_map(premium, "entitlement") is Some(total) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard moon_json_double_from_map(premium, "remaining") is Some(remaining) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some(json_string_from_map(obj, "copilot_plan").unwrap_or("")),
        remaining=Some(remaining),
        total=Some(total),
        used=Some(total - remaining),
        unit=Some("requests"),
        is_valid=Some(true),
        extra=Some(
          "Reset: \{json_string_from_map(obj, "quota_reset_date").unwrap_or("")}",
        ),
      ),
    ]),
  )
}
