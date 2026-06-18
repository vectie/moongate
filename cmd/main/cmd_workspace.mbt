///|
fn workspace_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "scan_openclaw_config_health", patterns: ["openclaw config-health"] },
    {
      id: "set_openclaw_default_model",
      patterns: ["openclaw default-model set"],
    },
    { id: "get_openclaw_default_model", patterns: ["openclaw default-model"] },
    {
      id: "set_openclaw_model_catalog",
      patterns: ["openclaw model-catalog set"],
    },
    { id: "get_openclaw_model_catalog", patterns: ["openclaw model-catalog"] },
    {
      id: "set_openclaw_agents_defaults",
      patterns: ["openclaw agents-defaults set"],
    },
    {
      id: "get_openclaw_agents_defaults",
      patterns: ["openclaw agents-defaults"],
    },
    { id: "set_openclaw_env", patterns: ["openclaw env set"] },
    { id: "get_openclaw_env", patterns: ["openclaw env"] },
    { id: "set_openclaw_tools", patterns: ["openclaw tools set"] },
    { id: "get_openclaw_tools", patterns: ["openclaw tools"] },
    { id: "get_hermes_model_config", patterns: ["hermes model-config"] },
    { id: "set_hermes_memory", patterns: ["hermes memory set"] },
    { id: "get_hermes_memory", patterns: ["hermes memory"] },
    { id: "get_hermes_memory_limits", patterns: ["hermes memory-limits"] },
    { id: "set_hermes_memory_enabled", patterns: ["hermes memory-enabled set"] },
    { id: "open_hermes_web_ui", patterns: ["hermes web-ui"] },
    { id: "launch_hermes_dashboard", patterns: ["hermes dashboard"] },
    { id: "save_file_dialog", patterns: ["files save-dialog"] },
    { id: "open_file_dialog", patterns: ["files open-dialog"] },
    { id: "open_zip_file_dialog", patterns: ["files open-zip-dialog"] },
    { id: "export_config_to_file", patterns: ["config file export"] },
    { id: "import_config_from_file", patterns: ["config file import"] },
    { id: "create_db_backup", patterns: ["backups db create"] },
    { id: "list_db_backups", patterns: ["backups db list"] },
    { id: "restore_db_backup", patterns: ["backups db restore"] },
    { id: "rename_db_backup", patterns: ["backups db rename"] },
    { id: "delete_db_backup", patterns: ["backups db delete"] },
    { id: "parse_deeplink", patterns: ["deeplink parse"] },
    { id: "merge_deeplink_config", patterns: ["deeplink merge"] },
    { id: "import_from_deeplink", patterns: ["deeplink import"] },
    { id: "list_daily_memory_files", patterns: ["workspace memory list"] },
    { id: "read_daily_memory_file", patterns: ["workspace memory read"] },
    { id: "write_daily_memory_file", patterns: ["workspace memory write"] },
    { id: "search_daily_memory_files", patterns: ["workspace memory search"] },
    { id: "delete_daily_memory_file", patterns: ["workspace memory delete"] },
    { id: "read_workspace_file", patterns: ["workspace read"] },
    { id: "write_workspace_file", patterns: ["workspace write"] },
    { id: "open_workspace_directory", patterns: ["workspace open"] },
    { id: "import_prompt_from_file", patterns: ["prompt import"] },
    { id: "get_current_prompt_file_content", patterns: ["prompt current"] },
  ]
}

///|
fn cli_workspace_command_id(command_id : String) -> Bool {
  match command_id {
    "scan_openclaw_config_health"
    | "get_openclaw_default_model"
    | "set_openclaw_default_model"
    | "get_openclaw_model_catalog"
    | "set_openclaw_model_catalog"
    | "get_openclaw_agents_defaults"
    | "set_openclaw_agents_defaults"
    | "get_openclaw_env"
    | "set_openclaw_env"
    | "get_openclaw_tools"
    | "set_openclaw_tools"
    | "get_hermes_model_config"
    | "get_hermes_memory"
    | "set_hermes_memory"
    | "get_hermes_memory_limits"
    | "set_hermes_memory_enabled"
    | "open_hermes_web_ui"
    | "launch_hermes_dashboard"
    | "save_file_dialog"
    | "open_file_dialog"
    | "open_zip_file_dialog"
    | "export_config_to_file"
    | "import_config_from_file"
    | "create_db_backup"
    | "list_db_backups"
    | "restore_db_backup"
    | "rename_db_backup"
    | "delete_db_backup"
    | "parse_deeplink"
    | "merge_deeplink_config"
    | "import_from_deeplink"
    | "list_daily_memory_files"
    | "read_daily_memory_file"
    | "write_daily_memory_file"
    | "search_daily_memory_files"
    | "delete_daily_memory_file"
    | "read_workspace_file"
    | "write_workspace_file"
    | "open_workspace_directory"
    | "import_prompt_from_file"
    | "get_current_prompt_file_content" => true
    _ => false
  }
}

///|
async fn run_workspace_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "scan_openclaw_config_health" =>
      check_usage_endpoint(args, "/openclaw/config-health")
    "get_openclaw_default_model" =>
      check_usage_endpoint(args, "/openclaw/default-model")
    "set_openclaw_default_model" => set_openclaw_default_model(args)
    "get_openclaw_model_catalog" =>
      check_usage_endpoint(args, "/openclaw/model-catalog")
    "set_openclaw_model_catalog" =>
      set_suite_json_config(args, "/openclaw/model-catalog", "--catalog")
    "get_openclaw_agents_defaults" =>
      check_usage_endpoint(args, "/openclaw/agents-defaults")
    "set_openclaw_agents_defaults" => set_openclaw_agents_defaults(args)
    "get_openclaw_env" => check_usage_endpoint(args, "/openclaw/env")
    "set_openclaw_env" => set_openclaw_env(args)
    "get_openclaw_tools" => check_usage_endpoint(args, "/openclaw/tools")
    "set_openclaw_tools" => set_openclaw_tools(args)
    "get_hermes_model_config" =>
      check_usage_endpoint(args, "/hermes/model-config")
    "get_hermes_memory" => check_hermes_memory(args)
    "set_hermes_memory" => set_hermes_memory(args)
    "get_hermes_memory_limits" =>
      check_usage_endpoint(args, "/hermes/memory-limits")
    "set_hermes_memory_enabled" => set_hermes_memory_enabled(args)
    "open_hermes_web_ui" => check_usage_endpoint(args, hermes_web_ui_path(args))
    "launch_hermes_dashboard" =>
      check_json_post_endpoint(args, "/hermes/dashboard", "Hermes")
    "save_file_dialog" =>
      check_usage_endpoint(args, save_file_dialog_path(args))
    "open_file_dialog" => check_usage_endpoint(args, "/files/dialogs/open")
    "open_zip_file_dialog" =>
      check_usage_endpoint(args, "/files/dialogs/open-zip")
    "export_config_to_file" =>
      check_json_post_endpoint(
        args,
        config_file_path(args, "/config/files/export"),
        "Import/export",
      )
    "import_config_from_file" =>
      check_json_post_endpoint(
        args,
        config_file_path(args, "/config/files/import"),
        "Import/export",
      )
    "create_db_backup" =>
      check_json_post_endpoint(args, "/backups/db", "Import/export")
    "list_db_backups" => check_usage_endpoint(args, "/backups/db")
    "restore_db_backup" =>
      check_json_post_endpoint(
        args,
        db_backup_filename_path(args, "/backups/db/restore"),
        "Import/export",
      )
    "rename_db_backup" =>
      check_json_post_endpoint(
        args,
        db_backup_rename_path(args),
        "Import/export",
      )
    "delete_db_backup" =>
      check_json_post_endpoint(
        args,
        db_backup_filename_path(args, "/backups/db/delete"),
        "Import/export",
      )
    "parse_deeplink" =>
      check_usage_endpoint(args, deeplink_url_path(args, "/deeplinks/parse"))
    "merge_deeplink_config" =>
      check_json_post_endpoint(
        args,
        deeplink_request_path(args, "/deeplinks/merge"),
        "Deeplink",
      )
    "import_from_deeplink" =>
      check_json_post_endpoint(
        args,
        deeplink_request_path(args, "/deeplinks/import"),
        "Deeplink",
      )
    "list_daily_memory_files" => check_usage_endpoint(args, "/workspace/memory")
    "read_daily_memory_file" =>
      check_usage_endpoint(
        args,
        workspace_filename_path(args, "/workspace/memory/file"),
      )
    "write_daily_memory_file" =>
      write_workspace_content(args, "/workspace/memory/write", "Workspace")
    "search_daily_memory_files" =>
      check_usage_endpoint(
        args,
        workspace_query_path(args, "/workspace/memory/search"),
      )
    "delete_daily_memory_file" =>
      delete_workspace_resource(args, "/workspace/memory/delete", "Workspace")
    "read_workspace_file" =>
      check_usage_endpoint(
        args,
        workspace_filename_path(args, "/workspace/files"),
      )
    "write_workspace_file" =>
      write_workspace_content(args, "/workspace/files", "Workspace")
    "open_workspace_directory" =>
      check_json_post_endpoint(
        args,
        workspace_subdir_path(args, "/workspace/open"),
        "Workspace",
      )
    "import_prompt_from_file" => import_prompt_from_file(args)
    "get_current_prompt_file_content" =>
      check_usage_endpoint(
        args,
        prompt_file_path(args, "/prompts/current-file"),
      )
    _ => ()
  }
}

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
  match parse_string_arg(args, "--default-name") {
    Some(name) => "/files/dialogs/save?\{cli_query_pair("defaultName", name)}"
    None => "/files/dialogs/save"
  }
}

///|
fn config_file_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--file-path") {
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
  match parse_string_arg(args, "--filename") {
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
    Some(path) => query.push(cli_query_pair("filePath", path))
    None => ()
  }
  cli_path_with_query(base_path, query)
}
