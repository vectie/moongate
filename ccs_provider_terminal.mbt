///|
fn ccs_import_default_config_json(
  router : ProviderRouter,
  app_type : String,
) -> Json {
  Json::boolean(router.import_live_providers(app_type) > 0)
}

///|
async fn ccs_open_provider_terminal_json(
  router : ProviderRouter,
  app_type : String,
  provider_id : String,
  cwd : String?,
) -> Result[Json, String] {
  guard router.provider_by_id(app_type, provider_id) is Some(provider) else {
    return Err("提供商 \{provider_id} 不存在")
  }
  let cwd = ccs_resolve_terminal_cwd(cwd)
  let command = ccs_provider_terminal_command(
    ccs_provider_terminal_env(provider, app_type),
    cwd,
  )
  let result = @spawn.spawn("osascript", ["-e", command], timeout=5000) catch {
    err => return Err("启动终端失败: \{err}")
  }
  if result.status == 0 {
    Ok(Json::boolean(true))
  } else {
    let detail = if result.stderr.trim().is_empty() {
      result.stdout.trim()
    } else {
      result.stderr.trim()
    }
    Err(
      if detail.is_empty() {
        "启动终端失败"
      } else {
        detail.to_owned()
      },
    )
  }
}

///|
async fn ccs_resolve_terminal_cwd(cwd : String?) -> String? {
  match cwd {
    Some(value) if !value.trim().is_empty() => {
      if value.contains("\n") || value.contains("\r") {
        return None
      }
      let resolved = @fsx.resolve(value) catch { _ => return None }
      Some(resolved)
    }
    _ => None
  }
}

///|
fn ccs_provider_terminal_env(
  provider : ProviderRouteTarget,
  app_type : String,
) -> Map[String, String] {
  let env : Map[String, String] = {}
  match provider.settings_config {
    Some(Object(obj)) => {
      match obj.get("env") {
        Some(Object(raw_env)) =>
          for key in raw_env.keys() {
            if raw_env.get(key) is Some(String(value)) {
              env[key] = value
            }
          }
        _ => ()
      }
      if app_type == "codex" {
        match obj.get("auth") {
          Some(String(value)) if !value.trim().is_empty() =>
            env["OPENAI_API_KEY"] = value
          _ => ()
        }
      }
      if app_type == "gemini" {
        match obj.get("api_key") {
          Some(String(value)) if !value.trim().is_empty() =>
            env["GEMINI_API_KEY"] = value
          _ => ()
        }
      }
    }
    _ => ()
  }
  match provider.base_url {
    Some(value) if !value.trim().is_empty() =>
      match app_type {
        "claude" | "claude-desktop" => env["ANTHROPIC_BASE_URL"] = value
        "gemini" => env["GOOGLE_GEMINI_BASE_URL"] = value
        "codex" => env["OPENAI_BASE_URL"] = value
        _ => ()
      }
    _ => ()
  }
  match provider.api_key {
    Some(value) if !value.trim().is_empty() =>
      match app_type {
        "claude" | "claude-desktop" => env["ANTHROPIC_AUTH_TOKEN"] = value
        "gemini" => env["GEMINI_API_KEY"] = value
        "codex" => env["OPENAI_API_KEY"] = value
        _ => ()
      }
    _ => ()
  }
  env
}

///|
fn ccs_provider_terminal_command(
  env : Map[String, String],
  cwd : String?,
) -> String {
  let lines : Array[String] = []
  match cwd {
    Some(path) => lines.push("cd \{ccs_shell_single_quote(path)}")
    None => ()
  }
  for key in env.keys() {
    guard env.get(key) is Some(value) else { continue }
    if ccs_is_safe_env_key(key) {
      lines.push("export \{key}=\{ccs_shell_single_quote(value)}")
    }
  }
  lines.push("exec $SHELL -l")
  "tell application \"Terminal\" to do script \{ccs_applescript_string(lines.join("; "))}"
}

///|
fn ccs_is_safe_env_key(key : String) -> Bool {
  if key.is_empty() {
    return false
  }
  for i in 0..<key.length() {
    let ch = key[i]
    let ok = (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_'
    if !ok {
      return false
    }
  }
  true
}

///|
fn ccs_applescript_string(value : String) -> String {
  "\"" +
  value.replace_all(old="\\", new="\\\\").replace_all(old="\"", new="\\\"") +
  "\""
}
