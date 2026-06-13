///|
fn fake_quota() -> SubscriptionQuota {
  SubscriptionQuota::new("claude", queried_at=Some(0))
}

///|
fn fake_usage_result() -> UsageResult {
  UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some("Pro"),
        total=Some(100.0),
        used=Some(25.0),
        remaining=Some(75.0),
        unit=Some("usd"),
      ),
    ]),
  )
}

///|
test "usage result parses ccs usage script json" {
  let json = @json.parse(
    (
      #|{
      #|  "success": true,
      #|  "data": [
      #|    {
      #|      "planName": "Team",
      #|      "total": 100,
      #|      "used": 40,
      #|      "remaining": 60,
      #|      "unit": "%",
      #|      "isValid": true,
      #|      "extra": "resets tomorrow"
      #|    }
      #|  ]
      #|}
    ),
  )
  guard usage_result_from_json(json) is Some(result) else {
    fail("expected usage result")
  }
  assert_true(result.success)
  guard result.data is Some(rows) else { fail("expected data") }
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].plan_name, Some("Team"))
  assert_eq(rows[0].unit, Some("%"))
  assert_eq(rows[0].remaining, Some(60.0))
}

///|
test "usage cache subscription round trip matches ccs" {
  let cache = UsageCache::new()
  assert_true(
    cache.with_subscription("claude", fn(quota) { quota.success }) is None,
  )
  cache.put_subscription("claude", fake_quota())
  assert_eq(
    cache.with_subscription("claude", fn(quota) { quota.success }),
    Some(true),
  )
  assert_true(
    cache.with_subscription("codex", fn(quota) { quota.success }) is None,
  )
}

///|
test "usage cache script round trip and invalidate match ccs" {
  let cache = UsageCache::new()
  assert_true(
    cache.with_script("codex", "pid", fn(result) { result.success }) is None,
  )
  cache.put_script("codex", "pid", fake_usage_result())
  assert_eq(
    cache.with_script("codex", "pid", fn(result) { result.success }),
    Some(true),
  )
  cache.invalidate_script("codex", "pid")
  assert_true(
    cache.with_script("codex", "pid", fn(result) { result.success }) is None,
  )
}

///|
test "usage cache script keys are isolated by app type like ccs" {
  let cache = UsageCache::new()
  cache.put_script("claude", "same", fake_usage_result())
  assert_true(cache.get_script("claude", "same") is Some(_))
  assert_true(cache.get_script("codex", "same") is None)
}

///|
test "usage cache subscription invalidation matches ccs" {
  let cache = UsageCache::new()
  cache.put_subscription("claude", fake_quota())
  assert_true(cache.get_subscription("claude") is Some(_))
  cache.invalidate_subscription("claude")
  assert_true(cache.get_subscription("claude") is None)
  cache.invalidate_subscription("claude")
  assert_true(cache.get_subscription("claude") is None)
}

///|
test "usage cache result json matches ccs usage result shape" {
  guard fake_usage_result().to_json() is Object(result) else {
    fail("expected usage result object")
  }
  assert_eq(result["success"], Json::boolean(true))
  guard result["data"] is Array(data) else { fail("expected usage data") }
  guard data[0] is Object(plan) else { fail("expected usage plan") }
  assert_eq(plan["planName"], Json::string("Pro"))
  assert_eq(plan["total"], Json::number(100.0))
  assert_eq(plan["used"], Json::number(25.0))
  assert_eq(plan["remaining"], Json::number(75.0))
  assert_eq(plan["unit"], Json::string("usd"))
  assert_true(result.get("error") is None)

  guard SubscriptionQuota::error(
      "codex",
      CredentialStatus::Expired,
      "refresh required",
    ).to_json()
    is Object(quota) else {
    fail("expected quota object")
  }
  assert_eq(quota["tool"], Json::string("codex"))
  assert_eq(quota["credentialStatus"], Json::string("expired"))
  assert_eq(quota["credentialMessage"], Json::string("refresh required"))
  assert_eq(quota["success"], Json::boolean(false))
  assert_eq(quota["tiers"], Json::array([]))
  assert_true(quota.get("extraUsage") is None)
}
