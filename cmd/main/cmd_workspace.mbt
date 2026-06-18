///|
async fn set_openclaw_default_model(args : Array[String]) -> Unit {
  guard openclaw_default_model_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --primary")
    return
  }
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn set_openclaw_agents_defaults(args : Array[String]) -> Unit {
  let path = match
    suite_json_config_path(args, "/openclaw/agents-defaults", "--defaults") {
    Some(path) => Some(path)
    None =>
      openclaw_default_model_path_with_base(args, "/openclaw/agents-defaults")
  }
  guard path is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --defaults or --primary")
    return
  }
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn set_openclaw_env(args : Array[String]) -> Unit {
  let path = match suite_json_config_path(args, "/openclaw/env", "--env") {
    Some(path) => Some(path)
    None => openclaw_key_value_path(args, "/openclaw/env")
  }
  guard path is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --env or --key")
    return
  }
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn set_openclaw_tools(args : Array[String]) -> Unit {
  let path = suite_json_config_path(args, "/openclaw/tools", "--tools").unwrap_or(
    openclaw_tools_path(args),
  )
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn write_workspace_content(
  args : Array[String],
  base_path : String,
  label : String,
) -> Unit {
  guard workspace_content_path(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --filename and --content")
    return
  }
  check_json_post_endpoint(args, path, label)
}

///|
async fn delete_workspace_resource(
  args : Array[String],
  base_path : String,
  label : String,
) -> Unit {
  guard workspace_filename_path_optional(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --filename")
    return
  }
  check_json_delete_endpoint(args, path, label)
}

///|
async fn check_hermes_memory(args : Array[String]) -> Unit {
  guard hermes_kind_path(args, "/hermes/memory") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --kind memory|user")
    return
  }
  check_json_endpoint(args, path, "Hermes")
}

///|
async fn set_hermes_memory(args : Array[String]) -> Unit {
  guard hermes_memory_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --kind and --content")
    return
  }
  check_json_post_endpoint(args, path, "Hermes")
}

///|
async fn set_hermes_memory_enabled(args : Array[String]) -> Unit {
  guard hermes_memory_enabled_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --kind and --enabled")
    return
  }
  check_json_post_endpoint(args, path, "Hermes")
}

///|
async fn import_prompt_from_file(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    prompt_file_path(args, "/prompts/import-file"),
    "Prompt",
  )
}

///|
fn openclaw_default_model_path(args : Array[String]) -> String? {
  openclaw_default_model_path_with_base(args, "/openclaw/default-model")
}

///|
fn openclaw_default_model_path_with_base(
  args : Array[String],
  base_path : String,
) -> String? {
  guard parse_string_arg(args, "--primary") is Some(primary) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("primary", primary)]
  match parse_string_arg(args, "--fallbacks") {
    Some(fallbacks) => query.push(cli_query_pair("fallbacks", fallbacks))
    None => ()
  }
  Some("\{base_path}?\{query.join("&")}")
}

///|
fn openclaw_key_value_path(args : Array[String], base_path : String) -> String? {
  guard parse_string_arg(args, "--key") is Some(key) else { return None }
  let value = parse_string_arg(args, "--value").unwrap_or("")
  Some(
    "\{base_path}?\{cli_query_pair("key", key)}&\{cli_query_pair("value", value)}",
  )
}

///|
fn openclaw_tools_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--profile") {
    Some(profile) => query.push(cli_query_pair("profile", profile))
    None => ()
  }
  match parse_string_arg(args, "--allow") {
    Some(allow) => query.push(cli_query_pair("allow", allow))
    None => ()
  }
  match parse_string_arg(args, "--deny") {
    Some(deny) => query.push(cli_query_pair("deny", deny))
    None => ()
  }
  cli_path_with_query("/openclaw/tools", query)
}

///|
fn hermes_kind_path(args : Array[String], base_path : String) -> String? {
  guard parse_string_arg(args, "--kind") is Some(kind) else { return None }
  Some("\{base_path}?\{cli_query_pair("kind", kind)}")
}

///|
fn hermes_memory_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--kind") is Some(kind) else { return None }
  let content = match parse_string_arg(args, "--content") {
    Some(value) => value
    None =>
      match parse_string_arg(args, "--value") {
        Some(value) => value
        None => parse_string_arg(args, "--text").unwrap_or("")
      }
  }
  Some(
    "/hermes/memory?\{cli_query_pair("kind", kind)}&\{cli_query_pair("content", content)}",
  )
}

///|
fn hermes_memory_enabled_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--kind") is Some(kind) else { return None }
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  Some(
    "/hermes/memory-enabled?\{cli_query_pair("kind", kind)}&\{cli_query_pair("enabled", enabled)}",
  )
}

///|
fn hermes_web_ui_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--path") {
    Some(path) => query.push(cli_query_pair("path", path))
    None => ()
  }
  match parse_string_arg(args, "--port") {
    Some(port) => query.push(cli_query_pair("port", port))
    None => ()
  }
  cli_path_with_query("/hermes/web-ui", query)
}

///|
fn workspace_filename_arg(args : Array[String]) -> String? {
  parse_string_arg_any(args, "--filename", "--file")
}

///|
fn workspace_filename_path(args : Array[String], base_path : String) -> String {
  workspace_filename_path_optional(args, base_path).unwrap_or(base_path)
}

///|
fn workspace_filename_path_optional(
  args : Array[String],
  base_path : String,
) -> String? {
  match workspace_filename_arg(args) {
    Some(filename) =>
      Some("\{base_path}?\{cli_query_pair("filename", filename)}")
    None => None
  }
}

///|
fn workspace_content_path(args : Array[String], base_path : String) -> String? {
  guard workspace_filename_arg(args) is Some(filename) else { return None }
  guard parse_string_arg(args, "--content") is Some(content) else {
    return None
  }
  Some(
    "\{base_path}?\{cli_query_pair("filename", filename)}&\{cli_query_pair("content", content)}",
  )
}

///|
fn workspace_query_path(args : Array[String], base_path : String) -> String {
  match parse_string_arg(args, "--query") {
    Some(query) => "\{base_path}?\{cli_query_pair("query", query)}"
    None => base_path
  }
}

///|
fn workspace_subdir_path(args : Array[String], base_path : String) -> String {
  match parse_string_arg(args, "--subdir") {
    Some(subdir) => "\{base_path}?\{cli_query_pair("subdir", subdir)}"
    None => base_path
  }
}

///|
fn save_file_dialog_path(args : Array[String]) -> String {
  match parse_string_arg_any(args, "--default-name", "--defaultName") {
    Some(name) => "/save_file_dialog?\{cli_query_pair("defaultName", name)}"
    None => "/save_file_dialog"
  }
}

///|
fn config_file_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--file-path", "--filePath") {
    Some(file_path) => query.push(cli_query_pair("filePath", file_path))
    None =>
      match parse_string_arg(args, "--path") {
        Some(file_path) => query.push(cli_query_pair("filePath", file_path))
        None => ()
      }
  }
  cli_path_with_query(base_path, query)
}

///|
fn db_backup_filename_arg(args : Array[String]) -> String? {
  match parse_string_arg_any(args, "--filename", "--fileName") {
    Some(filename) => Some(filename)
    None => parse_string_arg(args, "--name")
  }
}

///|
fn db_backup_filename_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match db_backup_filename_arg(args) {
    Some(filename) => query.push(cli_query_pair("filename", filename))
    None => ()
  }
  cli_path_with_query(base_path, query)
}

///|
fn prompt_file_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = [cli_query_pair("app", config_app_arg(args))]
  match parse_string_arg(args, "--path") {
    Some(path) => query.push(cli_query_pair("path", path))
    None => ()
  }
  cli_path_with_query(base_path, query)
}
