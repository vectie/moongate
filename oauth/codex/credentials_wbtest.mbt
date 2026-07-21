///|
test "codex credentials path is moongate product-owned state" {
  let path = get_credentials_path()
  let expected = @moonsuite.product_artifact_for_workspace_root(
    codex_active_workspace_root(),
    "moongate",
    "auth/codex-credentials.json",
  )
  assert_eq(path, expected)
  assert_false(path.contains("/.moonsuite/codex-credentials.json"))
}

///|
test "codex desktop storage prefers workspace then Lepusa app data" {
  assert_eq(
    codex_workspace_root_for(Some("/workspace"), Some("/app-data"), "/cwd"),
    "/workspace",
  )
  assert_eq(
    codex_workspace_root_for(None, Some("/app-data"), "/cwd"),
    "/app-data",
  )
  assert_eq(codex_workspace_root_for(None, None, "/cwd"), "/cwd")
}

///|
test "codex cli auth remains external source of truth" {
  let path = get_codex_auth_path() catch { _ => "" }
  assert_true(path == "" || path.has_suffix("/.codex/auth.json"))
}
