///|
test "managed auth status json matches moongate unauthenticated shape" {
  let status = managed_auth_status_json("codex_oauth", None)
  guard status is Object(obj) else { fail("expected auth status object") }
  assert_eq(obj["provider"], Json::string("codex_oauth"))
  assert_eq(obj["authenticated"], Json::boolean(false))
  assert_eq(obj["default_account_id"], Json::null())
  assert_eq(obj["migration_error"], Json::null())
  assert_eq(obj["accounts"], Json::array([]))
}

///|
test "managed auth account json exposes single codex account" {
  let credentials = @codex.Credentials::{
    idToken: "not-a-jwt",
    accessToken: "access",
    refreshToken: "refresh",
    accountId: "acct_1",
  }
  let status = managed_auth_status_json("codex_oauth", Some(credentials))
  guard status is Object(obj) else { fail("expected auth status object") }
  assert_eq(obj["authenticated"], Json::boolean(true))
  assert_eq(obj["default_account_id"], Json::string("acct_1"))
  guard obj["accounts"] is Array(accounts) else {
    fail("expected accounts array")
  }
  assert_eq(accounts.length(), 1)
  guard accounts[0] is Object(account) else { fail("expected account object") }
  assert_eq(account["id"], Json::string("acct_1"))
  assert_eq(account["provider"], Json::string("codex_oauth"))
  assert_eq(account["login"], Json::string("acct_1"))
  assert_eq(account["avatar_url"], Json::null())
  assert_eq(account["is_default"], Json::boolean(true))
  assert_eq(account["github_domain"], Json::string("chatgpt.com"))
}
