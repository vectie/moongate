///|
fn workspace_cli_commands() -> Array[CliCommandSpec] {
  [
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
async fn run_workspace_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "save_file_dialog" =>
      check_json_post_endpoint(args, save_file_dialog_path(args), "App shell")
    "open_file_dialog" =>
      check_json_post_endpoint(args, "/files/dialogs/open", "App shell")
    "open_zip_file_dialog" =>
      check_json_post_endpoint(args, "/files/dialogs/open-zip", "App shell")
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
      post_deeplink_request_endpoint(args, "/deeplinks/merge", "Deeplink")
    "import_from_deeplink" =>
      post_deeplink_request_endpoint(args, "/deeplinks/import", "Deeplink")
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
async fn import_prompt_from_file(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    prompt_file_path(args, "/prompts/import-file"),
    "Prompt",
  )
}

///|
fn workspace_filename_arg(args : Array[String]) -> String? {
  parse_string_arg(args, "--filename")
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
    None => ()
  }
  cli_path_with_query(base_path, query)
}

///|
fn db_backup_filename_arg(args : Array[String]) -> String? {
  parse_string_arg(args, "--filename")
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
  let query : Array[String] = [cli_query_pair("appType", config_app_arg(args))]
  match parse_string_arg(args, "--path") {
    Some(path) => query.push(cli_query_pair("filePath", path))
    None => ()
  }
  cli_path_with_query(base_path, query)
}
