///|
fn ccs_skill_test_state_path(name : String) -> String {
  @pathx.join("/tmp", "moonstat-\{name}-\{@os.unix_seconds()}.json")
}

///|
async test "ccs skill repos install toggle backup and restore" {
  let path = ccs_skill_test_state_path("skills-flow")
  let repos = ccs_get_skill_repos_json(path~)
  guard repos is Array(default_repos) else { fail("expected default repos") }
  assert_true(default_repos.length() >= 4)

  let added = ccs_add_skill_repo_json(
    {
      "owner": Json::string("vectie"),
      "name": Json::string("moonstat-skills"),
      "branch": Json::string("main"),
      "enabled": Json::boolean(true),
    }.to_json(),
    path~,
  )
  assert_eq(added, Json::boolean(true))
  guard ccs_get_skill_repos_json(path~) is Array(next_repos) else {
    fail("expected repos")
  }
  assert_true(next_repos.length() == default_repos.length() + 1)

  let installed = ccs_install_skill_unified_json(
    {
      "key": Json::string("vectie/moonstat-skills:traffic-stats"),
      "name": Json::string("Traffic Stats"),
      "description": Json::string("Moonstat skill"),
      "directory": Json::string("traffic-stats"),
      "repoOwner": Json::string("vectie"),
      "repoName": Json::string("moonstat-skills"),
      "repoBranch": Json::string("main"),
    }.to_json(),
    "codex",
    state_path=path,
  )
  guard installed is Object(installed_obj) else { fail("expected skill") }
  assert_eq(installed_obj["directory"], Json::string("traffic-stats"))
  guard installed_obj["apps"] is Object(apps) else { fail("expected apps") }
  assert_eq(apps["codex"], Json::boolean(true))
  assert_eq(apps["claude"], Json::boolean(false))

  assert_eq(
    ccs_toggle_skill_app_json("traffic-stats", "hermes", true, state_path=path),
    Json::boolean(true),
  )
  guard ccs_get_installed_skills_json(path~) is Array(skills) else {
    fail("expected installed skills")
  }
  assert_eq(skills.length(), 1)
  guard skills[0] is Object(toggled) else { fail("expected toggled skill") }
  guard toggled["apps"] is Object(toggled_apps) else {
    fail("expected toggled apps")
  }
  assert_eq(toggled_apps["hermes"], Json::boolean(true))

  guard ccs_uninstall_skill_unified_json("traffic-stats", state_path=path)
    is Object(uninstall_result) else {
    fail("expected uninstall result")
  }
  assert_true(uninstall_result["backupPath"] is String(_))
  guard ccs_get_installed_skills_json(path~) is Array(after_uninstall) else {
    fail("expected installed after uninstall")
  }
  assert_eq(after_uninstall.length(), 0)
  guard ccs_get_skill_backups_json(path~) is Array(backups) else {
    fail("expected backups")
  }
  assert_eq(backups.length(), 1)
  guard backups[0] is Object(backup) else { fail("expected backup") }
  guard backup["backupId"] is String(backup_id) else {
    fail("expected backup id")
  }

  let restored = ccs_restore_skill_backup_json(
    backup_id,
    "claude",
    state_path=path,
  )
  guard restored is Object(restored_obj) else { fail("expected restored") }
  guard restored_obj["apps"] is Object(restored_apps) else {
    fail("expected restored apps")
  }
  assert_eq(restored_apps["claude"], Json::boolean(true))
}

///|
async test "ccs skills discovery and search expose ccs compatible shapes" {
  let path = ccs_skill_test_state_path("skills-discovery")
  guard ccs_discover_available_skills_json(state_path=path) is Array(discovered) else {
    fail("expected discovered skills")
  }
  assert_true(discovered.length() >= 4)
  guard discovered[0] is Object(first) else { fail("expected skill") }
  assert_true(first["key"] is String(_))
  assert_true(first["repoOwner"] is String(_))
  assert_true(first["repoName"] is String(_))

  guard ccs_search_skills_sh_json("skill", 2, 0) is Object(search) else {
    fail("expected search object")
  }
  guard search["skills"] is Array(results) else { fail("expected results") }
  assert_eq(results.length(), 2)
  assert_eq(search["query"], Json::string("skill"))
}
