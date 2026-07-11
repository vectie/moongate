///|
fn moon_skill_test_state_path(name : String) -> String {
  @pathx.join("/tmp", "moonstat-\{name}-\{@os.unix_seconds()}.json")
}

///|
async test "moonstat skill repos install toggle backup and restore" {
  let path = moon_skill_test_state_path("skills-flow")
  let repos = moon_get_skill_repos_json(path~)
  guard repos is Array(default_repos) else { fail("expected default repos") }
  assert_true(default_repos.length() >= 4)

  let added = moon_add_skill_repo_json(
    {
      "owner": Json::string("vectie"),
      "name": Json::string("moonstat-skills"),
      "branch": Json::string("main"),
      "enabled": Json::boolean(true),
    }.to_json(),
    path~,
  )
  assert_eq(added, Json::boolean(true))
  guard moon_get_skill_repos_json(path~) is Array(next_repos) else {
    fail("expected repos")
  }
  assert_true(next_repos.length() == default_repos.length() + 1)

  let installed = moon_install_skill_unified_json(
    {
      "key": Json::string("vectie/moonstat-skills:moonstat-usage"),
      "name": Json::string("MoonGate Usage"),
      "description": Json::string("MoonGate skill"),
      "directory": Json::string("moonstat-usage"),
      "repoOwner": Json::string("vectie"),
      "repoName": Json::string("moonstat-skills"),
      "repoBranch": Json::string("main"),
    }.to_json(),
    "codex",
    state_path=path,
  )
  guard installed is Object(installed_obj) else { fail("expected skill") }
  assert_eq(installed_obj["directory"], Json::string("moonstat-usage"))
  guard installed_obj["apps"] is Object(apps) else { fail("expected apps") }
  assert_eq(apps["codex"], Json::boolean(true))
  assert_eq(apps["claude"], Json::boolean(false))

  assert_eq(
    moon_toggle_skill_app_json(
      "moonstat-usage",
      "hermes",
      true,
      state_path=path,
    ),
    Json::boolean(true),
  )
  guard moon_get_installed_skills_json(path~) is Array(skills) else {
    fail("expected installed skills")
  }
  assert_eq(skills.length(), 1)
  guard skills[0] is Object(toggled) else { fail("expected toggled skill") }
  guard toggled["apps"] is Object(toggled_apps) else {
    fail("expected toggled apps")
  }
  assert_eq(toggled_apps["hermes"], Json::boolean(true))

  guard moon_uninstall_skill_unified_json("moonstat-usage", state_path=path)
    is Object(uninstall_result) else {
    fail("expected uninstall result")
  }
  assert_true(uninstall_result["backupPath"] is String(_))
  guard moon_get_installed_skills_json(path~) is Array(after_uninstall) else {
    fail("expected installed after uninstall")
  }
  assert_eq(after_uninstall.length(), 0)
  guard moon_get_skill_backups_json(path~) is Array(backups) else {
    fail("expected backups")
  }
  assert_eq(backups.length(), 1)
  guard backups[0] is Object(backup) else { fail("expected backup") }
  guard backup["backupId"] is String(backup_id) else {
    fail("expected backup id")
  }

  let restored = moon_restore_skill_backup_json(
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
async test "moonstat skills discovery and search expose moonstat compatible shapes" {
  let path = moon_skill_test_state_path("skills-discovery")
  guard moon_discover_available_skills_json(state_path=path)
    is Array(discovered) else {
    fail("expected discovered skills")
  }
  assert_true(discovered.length() >= 4)
  guard discovered[0] is Object(first) else { fail("expected skill") }
  assert_true(first["key"] is String(_))
  assert_true(first["repoOwner"] is String(_))
  assert_true(first["repoName"] is String(_))

  guard moon_search_skills_sh_json("skill", 2, 0) is Object(search) else {
    fail("expected search object")
  }
  guard search["skills"] is Array(results) else { fail("expected results") }
  assert_eq(results.length(), 2)
  assert_eq(search["query"], Json::string("skill"))
}

///|
async test "moonstat skill storage migration moves installed directories" {
  @fsx.with_temporary_directory("moonstat-skill-storage-XXXXXX", async fn(
    tmpdir,
  ) {
    let state_path = @pathx.join(tmpdir, "skills_state.json")
    let moonstat_dir = @pathx.join(tmpdir, "moonstat-skills")
    let unified_dir = @pathx.join(tmpdir, "unified-skills")
    let movable_dir = @pathx.join(moonstat_dir, "moonstat-usage")
    let skipped_source_dir = @pathx.join(moonstat_dir, "already-there")
    let skipped_dest_dir = @pathx.join(unified_dir, "already-there")
    @fsx.make_directory(movable_dir, recursive=true, exists_ok=true)
    @fsx.make_directory(skipped_source_dir, recursive=true, exists_ok=true)
    @fsx.make_directory(skipped_dest_dir, recursive=true, exists_ok=true)
    @fsx.write_to_file(@pathx.join(movable_dir, "SKILL.md"), "# MoonGate Usage")
    @fsx.write_to_file(
      @pathx.join(skipped_source_dir, "SKILL.md"),
      "# Source copy",
    )
    @fsx.write_to_file(@pathx.join(skipped_dest_dir, "SKILL.md"), "# Existing")
    ignore(
      moon_skill_state_save(
        {
          "installed": Json::array([
            {
              "id": Json::string("local:moonstat-usage"),
              "directory": Json::string("moonstat-usage"),
              "name": Json::string("MoonGate Usage"),
            }.to_json(),
            {
              "id": Json::string("local:already-there"),
              "directory": Json::string("already-there"),
              "name": Json::string("Already There"),
            }.to_json(),
          ]),
          "repos": Json::array([]),
          "backups": Json::array([]),
          "skillStorageLocation": Json::string("moonstat"),
        }.to_json(),
        path=state_path,
      ),
    )

    guard moon_migrate_skill_storage_json(
        "unified",
        state_path~,
        moonstat_dir~,
        unified_dir~,
      )
      is Object(result) else {
      fail("expected migration result")
    }
    assert_eq(result["migratedCount"], Json::number(1.0))
    assert_eq(result["skippedCount"], Json::number(1.0))
    assert_eq(result["errors"], Json::array([]))
    assert_false(@fs.exists(movable_dir))
    assert_true(
      @fsx.exists_as_file(@pathx.join(unified_dir, "moonstat-usage/SKILL.md")),
    )
    assert_true(
      @fsx.exists_as_file(@pathx.join(skipped_source_dir, "SKILL.md")),
    )
    guard moon_skill_state_load(path=state_path) is Object(next_state) else {
      fail("expected migrated state")
    }
    assert_eq(next_state["skillStorageLocation"], Json::string("unified"))

    guard moon_migrate_skill_storage_json(
        "unified",
        state_path~,
        moonstat_dir~,
        unified_dir~,
      )
      is Object(noop) else {
      fail("expected noop migration result")
    }
    assert_eq(noop["migratedCount"], Json::number(0.0))
    assert_eq(noop["skippedCount"], Json::number(0.0))
    assert_eq(noop["errors"], Json::array([]))
  })
}

///|
async test "moonstat install skills from zip source scans and copies skill dirs" {
  @fsx.with_temporary_directory("moonstat-skill-zip-XXXXXX", async fn(tmpdir) {
    let state_path = @pathx.join(tmpdir, "skills_state.json")
    let source_dir = @pathx.join(tmpdir, "bundle")
    let nested_skill = @pathx.join(source_dir, "packs/moonstat-usage")
    let conflict_skill = @pathx.join(source_dir, "already-there")
    let moonstat_dir = @pathx.join(tmpdir, "moonstat-skills")
    let unified_dir = @pathx.join(tmpdir, "unified-skills")
    let app_dir = @pathx.join(tmpdir, "codex-skills")
    @fsx.make_directory(nested_skill, recursive=true, exists_ok=true)
    @fsx.make_directory(conflict_skill, recursive=true, exists_ok=true)
    let skill_md =
      #|---
      #|name: MoonGate Usage
      #|description: Watch traffic and usage.
      #|---
      #|
      #|# MoonGate Usage
    @fsx.write_to_file(@pathx.join(nested_skill, "SKILL.md"), skill_md)
    @fsx.write_to_file(@pathx.join(nested_skill, "notes.txt"), "usage")
    @fsx.write_to_file(@pathx.join(conflict_skill, "SKILL.md"), "# Existing")
    ignore(
      moon_skill_state_save(
        {
          "installed": Json::array([
            {
              "id": Json::string("local:already-there"),
              "directory": Json::string("already-there"),
              "name": Json::string("Already There"),
            }.to_json(),
          ]),
          "repos": Json::array([]),
          "backups": Json::array([]),
          "skillStorageLocation": Json::string("unified"),
        }.to_json(),
        path=state_path,
      ),
    )

    guard moon_install_skills_from_zip_json(
        source_dir,
        "codex",
        state_path~,
        moonstat_dir~,
        unified_dir~,
        app_dir~,
      )
      is Array(installed) else {
      fail("expected installed skill array")
    }
    assert_eq(installed.length(), 1)
    guard installed[0] is Object(skill) else { fail("expected skill object") }
    assert_eq(skill["directory"], Json::string("moonstat-usage"))
    assert_eq(skill["name"], Json::string("MoonGate Usage"))
    assert_eq(skill["description"], Json::string("Watch traffic and usage."))
    guard skill["contentHash"] is String(hash) else {
      fail("expected content hash")
    }
    assert_eq(hash.length(), 64)
    assert_true(
      @fsx.exists_as_file(@pathx.join(unified_dir, "moonstat-usage/SKILL.md")),
    )
    assert_true(
      @fsx.exists_as_file(@pathx.join(app_dir, "moonstat-usage/SKILL.md")),
    )
    assert_false(@fs.exists(@pathx.join(unified_dir, "already-there")))

    guard moon_get_installed_skills_json(path=state_path) is Array(all) else {
      fail("expected state skills")
    }
    assert_eq(all.length(), 2)
  })
}
