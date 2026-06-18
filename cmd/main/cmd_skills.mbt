///|
fn skill_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "get_installed_skills", patterns: ["skills installed"] },
    { id: "get_skill_backups", patterns: ["skills backups"] },
    { id: "delete_skill_backup", patterns: ["skills backup delete"] },
    { id: "restore_skill_backup", patterns: ["skills backup restore"] },
    { id: "install_skill_unified", patterns: ["skills install-unified"] },
    { id: "uninstall_skill_unified", patterns: ["skills uninstall-unified"] },
    { id: "toggle_skill_app", patterns: ["skills toggle-app"] },
    { id: "scan_unmanaged_skills", patterns: ["skills scan-unmanaged"] },
    { id: "import_skills_from_apps", patterns: ["skills import-apps"] },
    { id: "discover_available_skills", patterns: ["skills discover"] },
    { id: "check_skill_updates", patterns: ["skills check-updates"] },
    { id: "update_skill", patterns: ["skills update"] },
    { id: "migrate_skill_storage", patterns: ["skills migrate-storage"] },
    { id: "search_skills_sh", patterns: ["skills search"] },
    { id: "get_skills", patterns: ["skills list"] },
    { id: "get_skills_for_app", patterns: ["skills app"] },
    { id: "get_skill_repos", patterns: ["skills repos"] },
    { id: "add_skill_repo", patterns: ["skills repo add"] },
    { id: "remove_skill_repo", patterns: ["skills repo remove"] },
    { id: "install_skills_from_zip", patterns: ["skills install-zip"] },
  ]
}

///|
fn cli_skill_command_id(command_id : String) -> Bool {
  cli_command_id_in_specs(command_id, skill_cli_commands())
}

///|
async fn run_skill_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "get_installed_skills" => check_usage_endpoint(args, "/skills/installed")
    "get_skill_backups" => check_usage_endpoint(args, "/skills/backups")
    "delete_skill_backup" =>
      check_json_post_endpoint(
        args,
        skill_backup_id_path(args, "/skills/backups/delete"),
        "Skills",
      )
    "restore_skill_backup" =>
      check_json_post_endpoint(args, skill_restore_backup_path(args), "Skills")
    "install_skill_unified" =>
      check_json_post_endpoint(
        args,
        skill_install_path(args, "/skills/install-unified"),
        "Skills",
      )
    "uninstall_skill_unified" =>
      check_json_post_endpoint(
        args,
        skill_id_path(args, "/skills/uninstall-unified"),
        "Skills",
      )
    "toggle_skill_app" =>
      check_json_post_endpoint(args, skill_toggle_app_path(args), "Skills")
    "scan_unmanaged_skills" => check_usage_endpoint(args, "/skills/unmanaged")
    "import_skills_from_apps" => import_skills_from_apps(args)
    "discover_available_skills" =>
      check_usage_endpoint(args, "/skills/discover")
    "check_skill_updates" => check_usage_endpoint(args, "/skills/updates")
    "update_skill" =>
      check_json_post_endpoint(
        args,
        skill_id_path(args, "/skills/update"),
        "Skills",
      )
    "migrate_skill_storage" => migrate_skill_storage(args)
    "search_skills_sh" => check_usage_endpoint(args, skill_search_path(args))
    "get_skills" => check_usage_endpoint(args, "/skills")
    "get_skills_for_app" =>
      check_usage_endpoint(args, skill_app_path(args, "/skills/app"))
    "get_skill_repos" => check_usage_endpoint(args, "/skills/repos")
    "add_skill_repo" =>
      check_json_post_endpoint(args, skill_repo_add_path(args), "Skills")
    "remove_skill_repo" =>
      check_json_post_endpoint(args, skill_repo_remove_path(args), "Skills")
    "install_skills_from_zip" =>
      check_json_post_endpoint(args, skill_zip_install_path(args), "Skills")
    _ => ()
  }
}
