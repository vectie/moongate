///|
priv enum MoonBalanceProvider {
  DeepSeek
  StepFun
  SiliconFlow
  SiliconFlowEn
  OpenRouter
  NovitaAI
}

///|
fn moon_detect_balance_provider(base_url : String) -> MoonBalanceProvider? {
  let url = base_url.to_lower()
  if url.contains("api.deepseek.com") {
    Some(DeepSeek)
  } else if url.contains("api.stepfun.ai") || url.contains("api.stepfun.com") {
    Some(StepFun)
  } else if url.contains("api.siliconflow.cn") {
    Some(SiliconFlow)
  } else if url.contains("api.siliconflow.com") {
    Some(SiliconFlowEn)
  } else if url.contains("openrouter.ai") {
    Some(OpenRouter)
  } else if url.contains("api.novita.ai") {
    Some(NovitaAI)
  } else {
    None
  }
}

///|
fn moon_balance_error(message : String) -> UsageResult {
  UsageResult::new(false, error=Some(message))
}

///|
fn moon_balance_auth_error(status_code : Int) -> UsageResult {
  UsageResult::new(
    false,
    data=Some([
      UsageData::new(
        is_valid=Some(false),
        invalid_message=Some("Authentication failed (HTTP \{status_code})"),
      ),
    ]),
    error=Some("Authentication failed (HTTP \{status_code})"),
  )
}

///|
async fn moon_get_balance(base_url : String, api_key : String) -> UsageResult {
  if api_key.trim().is_empty() {
    return moon_balance_error("API key is empty")
  }
  let provider = match moon_detect_balance_provider(base_url) {
    Some(provider) => provider
    None => return moon_balance_error("Unknown balance provider")
  }
  match provider {
    DeepSeek => moon_query_deepseek_balance(api_key)
    StepFun => moon_query_stepfun_balance(api_key)
    SiliconFlow => moon_query_siliconflow_balance(api_key, true)
    SiliconFlowEn => moon_query_siliconflow_balance(api_key, false)
    OpenRouter => moon_query_openrouter_balance(api_key)
    NovitaAI => moon_query_novita_balance(api_key)
  }
}

///|
async fn moon_balance_fetch_json(
  url : String,
  api_key : String,
) -> Result[Json, UsageResult] {
  let target = match models_url_target(url) {
    Ok(target) => target
    Err(err) => return Err(moon_balance_error(err))
  }
  let client = @http.Client::new(target.origin, headers={
    "Authorization": "Bearer \{api_key}",
    "Accept": "application/json",
  })
  defer client.close()
  let response = client.get(target.path) catch {
    err => return Err(moon_balance_error("Network error: \{err}"))
  }
  let body = client.read_all().text()
  if response.code == 401 || response.code == 403 {
    return Err(moon_balance_auth_error(response.code))
  }
  if !(response.code is (200..=299)) {
    return Err(moon_balance_error("API error (HTTP \{response.code}): \{body}"))
  }
  try @json.parse(body) catch {
    err => Err(moon_balance_error("Failed to parse response: \{err}"))
  } noraise {
    json => Ok(json)
  }
}

///|
async fn moon_query_deepseek_balance(api_key : String) -> UsageResult {
  match
    moon_balance_fetch_json("https://api.deepseek.com/user/balance", api_key) {
    Err(result) => result
    Ok(body) => moon_parse_deepseek_balance(body)
  }
}

///|
fn moon_parse_deepseek_balance(body : Json) -> UsageResult {
  let mut is_available = true
  let data : Array[UsageData] = []
  guard body is Object(obj) else {
    return moon_balance_error("Failed to parse response: expected object")
  }
  match obj.get("is_available") {
    Some(True) => is_available = true
    Some(False) => is_available = false
    _ => ()
  }
  match obj.get("balance_infos") {
    Some(Array(infos)) =>
      for info in infos {
        guard info is Object(info_obj) else { continue }
        let currency = json_string_from_map(info_obj, "currency").unwrap_or(
          "CNY",
        )
        data.push(
          UsageData::new(
            plan_name=Some(currency),
            remaining=moon_balance_number_field(info_obj, "total_balance"),
            unit=Some(currency),
            is_valid=Some(is_available),
            invalid_message=if is_available {
              None
            } else {
              Some("Insufficient balance")
            },
          ),
        )
      }
    _ => ()
  }
  UsageResult::new(true, data=if data.is_empty() { None } else { Some(data) })
}

///|
async fn moon_query_stepfun_balance(api_key : String) -> UsageResult {
  match
    moon_balance_fetch_json("https://api.stepfun.com/v1/accounts", api_key) {
    Err(result) => result
    Ok(body) => moon_parse_stepfun_balance(body)
  }
}

///|
fn moon_parse_stepfun_balance(body : Json) -> UsageResult {
  guard body is Object(obj) else {
    return moon_balance_error("Failed to parse response: expected object")
  }
  let balance = moon_balance_number_field(obj, "balance").unwrap_or(0.0)
  UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some("StepFun"),
        remaining=Some(balance),
        unit=Some("CNY"),
        is_valid=Some(true),
      ),
    ]),
  )
}

///|
async fn moon_query_siliconflow_balance(
  api_key : String,
  is_cn : Bool,
) -> UsageResult {
  let domain = if is_cn { "api.siliconflow.cn" } else { "api.siliconflow.com" }
  match moon_balance_fetch_json("https://\{domain}/v1/user/info", api_key) {
    Err(result) => result
    Ok(body) => moon_parse_siliconflow_balance(body, is_cn)
  }
}

///|
fn moon_parse_siliconflow_balance(body : Json, is_cn : Bool) -> UsageResult {
  guard body is Object(obj) else {
    return moon_balance_error("Failed to parse response: expected object")
  }
  guard obj.get("data") is Some(Object(data)) else {
    return moon_balance_error("Missing 'data' field in response")
  }
  let total_balance = moon_balance_number_field(data, "totalBalance").unwrap_or(
    0.0,
  )
  UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some(if is_cn { "SiliconFlow" } else { "SiliconFlow (EN)" }),
        remaining=Some(total_balance),
        unit=Some(if is_cn { "CNY" } else { "USD" }),
        is_valid=Some(true),
      ),
    ]),
  )
}

///|
async fn moon_query_openrouter_balance(api_key : String) -> UsageResult {
  match
    moon_balance_fetch_json("https://openrouter.ai/api/v1/credits", api_key) {
    Err(result) => result
    Ok(body) => moon_parse_openrouter_balance(body)
  }
}

///|
fn moon_parse_openrouter_balance(body : Json) -> UsageResult {
  guard body is Object(root) else {
    return moon_balance_error("Failed to parse response: expected object")
  }
  let data = match root.get("data") {
    Some(Object(data)) => data
    _ => root
  }
  let total = moon_balance_number_field(data, "total_credits").unwrap_or(0.0)
  let used = moon_balance_number_field(data, "total_usage").unwrap_or(0.0)
  let remaining = total - used
  UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some("OpenRouter"),
        remaining=Some(remaining),
        total=Some(total),
        used=Some(used),
        unit=Some("USD"),
        is_valid=Some(remaining > 0.0),
        invalid_message=if remaining <= 0.0 {
          Some("No credits remaining")
        } else {
          None
        },
      ),
    ]),
  )
}

///|
async fn moon_query_novita_balance(api_key : String) -> UsageResult {
  match
    moon_balance_fetch_json("https://api.novita.ai/v3/user/balance", api_key) {
    Err(result) => result
    Ok(body) => moon_parse_novita_balance(body)
  }
}

///|
fn moon_parse_novita_balance(body : Json) -> UsageResult {
  guard body is Object(obj) else {
    return moon_balance_error("Failed to parse response: expected object")
  }
  let available = moon_balance_number_field(obj, "availableBalance").unwrap_or(
      0.0,
    ) /
    10000.0
  UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some("Novita AI"),
        remaining=Some(available),
        unit=Some("USD"),
        is_valid=Some(available > 0.0),
        invalid_message=if available <= 0.0 {
          Some("No balance remaining")
        } else {
          None
        },
      ),
    ]),
  )
}

///|
fn moon_balance_number_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value)
    Some(String(value)) => parse_non_negative_decimal_to_double(value)
    _ => None
  }
}
