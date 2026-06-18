///|
async fn SkillService::handle_get_installed_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_get_installed_skills_json())
}

///|
async fn SkillService::handle_install_skill_unified(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let skill = match moon_skill_request_payload(body) {
    Some(skill) => Some(skill)
    None =>
      match proxy_string_request(r.path, body, ["directory"]) {
        Some(directory) => {
          let install_name = moon_skill_install_name(directory)
          if install_name.is_empty() {
            None
          } else {
            Some(
              {
                "key": Json::string("local:\{install_name}"),
                "name": Json::string(
                  proxy_string_request(r.path, body, ["name"]).unwrap_or(
                    install_name,
                  ),
                ),
                "description": Json::string(
                  proxy_string_request(r.path, body, ["description"]).unwrap_or(
                    "",
                  ),
                ),
                "directory": Json::string(install_name),
              }.to_json(),
            )
          }
        }
        None => None
      }
  }
  guard skill is Some(skill) else {
    write_usage_bad_request(w, "missing_skill")
    return
  }
  let current_app = proxy_string_request(r.path, body, ["currentApp"]).unwrap_or(
    "claude",
  )
  write_usage_json(w, moon_install_skill_unified_json(skill, current_app))
}

///|
async fn SkillService::handle_uninstall_skill_unified(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  write_usage_json(w, moon_uninstall_skill_unified_json(id))
}

///|
async fn SkillService::handle_toggle_skill_app(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  guard proxy_string_request(r.path, body, ["appType"]) is Some(app) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  write_usage_json(w, moon_toggle_skill_app_json(id, app, enabled))
}

///|
async fn SkillService::handle_scan_unmanaged_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_scan_unmanaged_skills_json())
}

///|
async fn SkillService::handle_import_skills_from_apps(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let imports = match body {
    Some(Object(obj)) =>
      match obj.get("imports") {
        Some(Array(items)) => Json::array(items)
        _ => Json::array([])
      }
    Some(Array(items)) => Json::array(items)
    _ => Json::array([])
  }
  write_usage_json(w, moon_import_skills_from_apps_json(imports))
}

///|
async fn SkillService::handle_discover_available_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_discover_available_skills_json())
}

///|
async fn SkillService::handle_check_skill_updates(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_check_skill_updates_json())
}

///|
async fn SkillService::handle_update_skill(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  write_usage_json(w, moon_update_skill_json(id))
}

///|
async fn SkillService::handle_migrate_skill_storage(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["target"]) is Some(target) else {
    write_usage_bad_request(w, "missing_storage_target")
    return
  }
  write_usage_json(w, moon_migrate_skill_storage_json(target))
}

///|
async fn SkillService::handle_search_skills_sh(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let query = proxy_string_request(r.path, body, ["query"]).unwrap_or("")
  let limit = proxy_int_request(r.path, body, ["limit"]).unwrap_or(20)
  let offset = proxy_int_request(r.path, body, ["offset"]).unwrap_or(0)
  write_usage_json(w, moon_search_skills_sh_json(query, limit, offset))
}

///|
async fn SkillService::handle_get_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_get_skills_json())
}

///|
async fn SkillService::handle_get_skill_repos(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_get_skill_repos_json())
}

///|
async fn SkillService::handle_add_skill_repo(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let repo = match body {
    Some(Object(obj)) =>
      match obj.get("repo") {
        Some(Object(repo_obj)) => Json::object(repo_obj)
        _ =>
          if obj.get("owner") is Some(_) && obj.get("name") is Some(_) {
            Json::object(obj)
          } else {
            match moon_skill_repo_request_json(r.path, body) {
              Some(repo) => repo
              None => {
                write_usage_bad_request(w, "missing_owner_or_name")
                return
              }
            }
          }
      }
    _ =>
      match moon_skill_repo_request_json(r.path, body) {
        Some(repo) => repo
        None => {
          write_usage_bad_request(w, "missing_owner_or_name")
          return
        }
      }
  }
  write_usage_json(w, moon_add_skill_repo_json(repo))
}

///|
fn moon_skill_repo_request_json(path : StringView, body : Json?) -> Json? {
  guard proxy_string_request(path, body, ["owner"]) is Some(owner) else {
    return None
  }
  guard proxy_string_request(path, body, ["name"]) is Some(name) else {
    return None
  }
  Some(
    {
      "owner": Json::string(owner),
      "name": Json::string(name),
      "branch": Json::string(
        proxy_string_request(path, body, ["branch"]).unwrap_or("main"),
      ),
      "enabled": Json::boolean(
        proxy_bool_request(path, body, ["enabled"]).unwrap_or(true),
      ),
    }.to_json(),
  )
}

///|
async fn SkillService::handle_remove_skill_repo(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["owner"]) is Some(owner) else {
    write_usage_bad_request(w, "missing_owner")
    return
  }
  guard proxy_string_request(r.path, body, ["name"]) is Some(name) else {
    write_usage_bad_request(w, "missing_name")
    return
  }
  write_usage_json(w, moon_remove_skill_repo_json(owner, name))
}

///|
async fn SkillService::handle_install_skills_from_zip(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filePath"]) is Some(file_path) else {
    write_usage_bad_request(w, "missing_file_path")
    return
  }
  let current_app = proxy_string_request(r.path, body, ["currentApp"]).unwrap_or(
    "claude",
  )
  write_usage_json(w, moon_install_skills_from_zip_json(file_path, current_app))
}
