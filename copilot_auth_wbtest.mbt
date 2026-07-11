///|
test "copilot auth status json exposes moongate-compatible unauthenticated shape" {
  let status = copilot_auth_status_json(None)
  guard status is Object(obj) else { fail("expected status object") }
  assert_eq(obj["provider"], Json::string("github_copilot"))
  assert_eq(obj["authenticated"], Json::boolean(false))
  assert_eq(obj["default_account_id"], Json::null())
  assert_eq(obj["migration_error"], Json::null())
  assert_eq(obj["accounts"], Json::array([]))
  assert_eq(obj["username"], Json::null())
  assert_eq(obj["expires_at"], Json::null())
}

///|
test "copilot auth status json exposes authenticated account" {
  let credentials = CopilotCredentials::{
    github_token: "gho_test",
    copilot_token: "copilot-token",
    copilot_token_expires_at: 1234L,
    account_id: "1001",
    login: "octo",
    avatar_url: Some("https://avatars.example/octo.png"),
    authenticated_at: 42L,
    github_domain: "github.com",
  }
  let status = copilot_auth_status_json(Some(credentials))
  guard status is Object(obj) else { fail("expected status object") }
  assert_eq(obj["authenticated"], Json::boolean(true))
  assert_eq(obj["default_account_id"], Json::string("1001"))
  assert_eq(obj["username"], Json::string("octo"))
  assert_eq(obj["expires_at"], Json::number(1234.0))
  guard obj["accounts"] is Array(accounts) else {
    fail("expected accounts array")
  }
  assert_eq(accounts.length(), 1)
  guard accounts[0] is Object(account) else { fail("expected account object") }
  assert_eq(account["id"], Json::string("1001"))
  assert_eq(account["provider"], Json::string("github_copilot"))
  assert_eq(account["login"], Json::string("octo"))
  assert_eq(
    account["avatar_url"],
    Json::string("https://avatars.example/octo.png"),
  )
  assert_eq(account["is_default"], Json::boolean(true))
  assert_eq(account["github_domain"], Json::string("github.com"))
}

///|
test "copilot domain normalization accepts urls and rejects invalid hosts" {
  assert_eq(copilot_normalize_domain(None), "github.com")
  assert_eq(
    copilot_normalize_domain(Some("https://ghe.example.com/org?x=1")),
    "ghe.example.com",
  )
  assert_eq(
    copilot_normalize_domain(Some("user@ghe.example.com")),
    "github.com",
  )
}
