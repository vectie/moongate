///|
priv enum CredentialStatus {
  Valid
  Expired
  NotFound
  ParseError
} derive(Eq)

///|
fn CredentialStatus::to_string(self : CredentialStatus) -> String {
  match self {
    Valid => "valid"
    Expired => "expired"
    NotFound => "not_found"
    ParseError => "parse_error"
  }
}

///|
priv struct UsageData {
  plan_name : String?
  extra : String?
  is_valid : Bool?
  invalid_message : String?
  total : Double?
  used : Double?
  remaining : Double?
  unit : String?
}

///|
fn UsageData::new(
  plan_name? : String? = None,
  extra? : String? = None,
  is_valid? : Bool? = None,
  invalid_message? : String? = None,
  total? : Double? = None,
  used? : Double? = None,
  remaining? : Double? = None,
  unit? : String? = None,
) -> UsageData {
  { plan_name, extra, is_valid, invalid_message, total, used, remaining, unit }
}

///|
fn UsageData::to_json(self : UsageData) -> Json {
  let obj : Map[String, Json] = Map([], capacity=0)
  match self.plan_name {
    Some(value) => obj.set("planName", Json::string(value))
    None => ()
  }
  match self.extra {
    Some(value) => obj.set("extra", Json::string(value))
    None => ()
  }
  match self.is_valid {
    Some(value) => obj.set("isValid", Json::boolean(value))
    None => ()
  }
  match self.invalid_message {
    Some(value) => obj.set("invalidMessage", Json::string(value))
    None => ()
  }
  match self.total {
    Some(value) => obj.set("total", Json::number(value))
    None => ()
  }
  match self.used {
    Some(value) => obj.set("used", Json::number(value))
    None => ()
  }
  match self.remaining {
    Some(value) => obj.set("remaining", Json::number(value))
    None => ()
  }
  match self.unit {
    Some(value) => obj.set("unit", Json::string(value))
    None => ()
  }
  Json::object(obj)
}

///|
fn usage_data_from_json(json : Json) -> UsageData? {
  guard json is Object(obj) else { return None }
  Some(
    UsageData::new(
      plan_name=usage_cache_json_string_any(obj, ["planName", "plan_name"]),
      extra=usage_cache_json_string(obj, "extra"),
      is_valid=usage_cache_json_bool_any(obj, ["isValid", "is_valid"]),
      invalid_message=usage_cache_json_string_any(obj, [
        "invalidMessage", "invalid_message",
      ]),
      total=usage_cache_json_number(obj, "total"),
      used=usage_cache_json_number(obj, "used"),
      remaining=usage_cache_json_number(obj, "remaining"),
      unit=usage_cache_json_string(obj, "unit"),
    ),
  )
}

///|
fn usage_data_json_has_moon_field(obj : Map[String, Json]) -> Bool {
  [
    "planName", "plan_name", "extra", "isValid", "is_valid", "invalidMessage", "invalid_message",
    "total", "used", "remaining", "unit",
  ].any(key => obj.contains(key))
}

///|
fn usage_script_output_result_from_json(json : Json) -> UsageResult? {
  match json {
    Array(items) => {
      let rows : Array[UsageData] = []
      for item in items {
        guard item is Object(obj) else { return None }
        if !usage_data_json_has_moon_field(obj) {
          return None
        }
        match usage_data_from_json(item) {
          Some(row) => rows.push(row)
          None => return None
        }
      }
      Some(UsageResult::new(true, data=Some(rows)))
    }
    Object(obj) => {
      if !usage_data_json_has_moon_field(obj) {
        return None
      }
      match usage_data_from_json(json) {
        Some(row) => {
          let rows : Array[UsageData] = []
          rows.push(row)
          Some(UsageResult::new(true, data=Some(rows)))
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn usage_result_or_script_output_from_json(json : Json) -> UsageResult? {
  match usage_result_from_json(json) {
    Some(result) => Some(result)
    None => usage_script_output_result_from_json(json)
  }
}

///|
priv struct UsageResult {
  success : Bool
  data : Array[UsageData]?
  error : String?
}

///|
fn UsageResult::new(
  success : Bool,
  data? : Array[UsageData]? = None,
  error? : String? = None,
) -> UsageResult {
  { success, data, error }
}

///|
fn UsageResult::to_json(self : UsageResult) -> Json {
  let obj : Map[String, Json] = { "success": Json::boolean(self.success) }
  match self.data {
    Some(rows) =>
      obj.set("data", Json::array(rows.map(fn(row) { row.to_json() })))
    None => ()
  }
  match self.error {
    Some(error) => obj.set("error", Json::string(error))
    None => ()
  }
  Json::object(obj)
}

///|
fn usage_result_from_json(json : Json) -> UsageResult? {
  guard json is Object(obj) else { return None }
  guard usage_cache_json_bool(obj, "success") is Some(success) else {
    return None
  }
  let rows : Array[UsageData] = []
  match obj.get("data") {
    Some(Array(items)) =>
      for item in items {
        match usage_data_from_json(item) {
          Some(row) => rows.push(row)
          None => return None
        }
      }
    Some(Null) | None => ()
    _ => return None
  }
  Some(
    UsageResult::new(
      success,
      data=if rows.is_empty() { None } else { Some(rows) },
      error=usage_cache_json_string(obj, "error"),
    ),
  )
}

///|
priv struct SubscriptionQuota {
  tool : String
  credential_status : CredentialStatus
  credential_message : String?
  success : Bool
  tiers : Array[Json]
  extra_usage : Json?
  error : String?
  queried_at : Int64?
}

///|
fn SubscriptionQuota::new(
  tool : String,
  credential_status? : CredentialStatus = Valid,
  credential_message? : String? = None,
  success? : Bool = true,
  tiers? : Array[Json] = [],
  extra_usage? : Json? = None,
  error? : String? = None,
  queried_at? : Int64? = None,
) -> SubscriptionQuota {
  {
    tool,
    credential_status,
    credential_message,
    success,
    tiers,
    extra_usage,
    error,
    queried_at,
  }
}

///|
fn SubscriptionQuota::not_found(tool : String) -> SubscriptionQuota {
  SubscriptionQuota::new(tool, credential_status=NotFound, success=false)
}

///|
#warnings("-unused_value")
fn SubscriptionQuota::error(
  tool : String,
  status : CredentialStatus,
  message : String,
) -> SubscriptionQuota {
  SubscriptionQuota::new(
    tool,
    credential_status=status,
    credential_message=Some(message),
    success=false,
  )
}

///|
fn SubscriptionQuota::to_json(self : SubscriptionQuota) -> Json {
  let obj : Map[String, Json] = {
    "tool": Json::string(self.tool),
    "credentialStatus": Json::string(self.credential_status.to_string()),
    "success": Json::boolean(self.success),
    "tiers": Json::array(self.tiers),
  }
  match self.credential_message {
    Some(value) => obj.set("credentialMessage", Json::string(value))
    None => ()
  }
  match self.extra_usage {
    Some(value) => obj.set("extraUsage", value)
    None => ()
  }
  match self.error {
    Some(value) => obj.set("error", Json::string(value))
    None => ()
  }
  match self.queried_at {
    Some(value) => obj.set("queriedAt", Json::number(value.to_double()))
    None => ()
  }
  Json::object(obj)
}

///|
priv struct UsageCache {
  subscription : Map[String, SubscriptionQuota]
  script : Map[String, UsageResult]
}

///|
fn UsageCache::new() -> UsageCache {
  { subscription: Map([], capacity=0), script: Map([], capacity=0) }
}

///|
fn UsageCache::put_subscription(
  self : UsageCache,
  app_type : String,
  quota : SubscriptionQuota,
) -> Unit {
  self.subscription.set(app_type, quota)
}

///|
fn UsageCache::put_script(
  self : UsageCache,
  app_type : String,
  provider_id : String,
  result : UsageResult,
) -> Unit {
  self.script.set(usage_cache_script_key(app_type, provider_id), result)
}

///|
fn UsageCache::get_subscription(
  self : UsageCache,
  app_type : String,
) -> SubscriptionQuota? {
  self.subscription.get(app_type)
}

///|
fn UsageCache::get_script(
  self : UsageCache,
  app_type : String,
  provider_id : String,
) -> UsageResult? {
  self.script.get(usage_cache_script_key(app_type, provider_id))
}

///|
#warnings("-unused_value")
fn[R] UsageCache::with_subscription(
  self : UsageCache,
  app_type : String,
  f : (SubscriptionQuota) -> R,
) -> R? {
  match self.get_subscription(app_type) {
    Some(quota) => Some(f(quota))
    None => None
  }
}

///|
#warnings("-unused_value")
fn[R] UsageCache::with_script(
  self : UsageCache,
  app_type : String,
  provider_id : String,
  f : (UsageResult) -> R,
) -> R? {
  match self.get_script(app_type, provider_id) {
    Some(result) => Some(f(result))
    None => None
  }
}

///|
#warnings("-unused_value")
fn UsageCache::invalidate_script(
  self : UsageCache,
  app_type : String,
  provider_id : String,
) -> Unit {
  self.script.remove(usage_cache_script_key(app_type, provider_id))
}

///|
#warnings("-unused_value")
fn UsageCache::invalidate_subscription(
  self : UsageCache,
  app_type : String,
) -> Unit {
  self.subscription.remove(app_type)
}

///|
fn usage_cache_script_key(app_type : String, provider_id : String) -> String {
  "\{app_type}\t\{provider_id}"
}

///|
fn usage_cache_json_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn usage_cache_json_string_any(
  obj : Map[String, Json],
  keys : Array[String],
) -> String? {
  for key in keys {
    match usage_cache_json_string(obj, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn usage_cache_json_bool(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn usage_cache_json_bool_any(
  obj : Map[String, Json],
  keys : Array[String],
) -> Bool? {
  for key in keys {
    match usage_cache_json_bool(obj, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn usage_cache_json_number(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value)
    _ => None
  }
}
