///|
fn SkillService::register_routes(
  self : SkillService,
  router : @httpx.Router,
  config : ConfigService,
) -> Unit {
  router.add_handler(Get, "/skills/installed", (_, w) => {
    self.handle_get_installed_skills(w)
  })
  router.add_handler(Get, "/skills/backups", (_, w) => {
    config.handle_get_skill_backups(w)
  })
  router.add_handler(Post, "/skills/backups/delete", (r, w) => {
    config.handle_delete_skill_backup(r, w)
  })
  router.add_handler(Post, "/skills/backups/restore", (r, w) => {
    config.handle_restore_skill_backup(r, w)
  })
  router.add_handler(Post, "/skills/install-unified", (r, w) => {
    self.handle_install_skill_unified(r, w)
  })
  router.add_handler(Post, "/skills/uninstall-unified", (r, w) => {
    self.handle_uninstall_skill_unified(r, w)
  })
  router.add_handler(Post, "/skills/toggle-app", (r, w) => {
    self.handle_toggle_skill_app(r, w)
  })
  router.add_handler(Get, "/skills/unmanaged", (_, w) => {
    self.handle_scan_unmanaged_skills(w)
  })
  router.add_handler(Post, "/skills/import-apps", (r, w) => {
    self.handle_import_skills_from_apps(r, w)
  })
  router.add_handler(Get, "/skills/discover", (_, w) => {
    self.handle_discover_available_skills(w)
  })
  router.add_handler(Get, "/skills/updates", (_, w) => {
    self.handle_check_skill_updates(w)
  })
  router.add_handler(Post, "/skills/update", (r, w) => {
    self.handle_update_skill(r, w)
  })
  router.add_handler(Post, "/skills/migrate-storage", (r, w) => {
    self.handle_migrate_skill_storage(r, w)
  })
  router.add_handler(Get, "/skills/search", (r, w) => {
    self.handle_search_skills_sh(r, w)
  })
  router.add_handler(Post, "/skills/search", (r, w) => {
    self.handle_search_skills_sh(r, w)
  })
  router.add_handler(Get, "/skills", (_, w) => self.handle_get_skills(w))
  router.add_handler(Get, "/skills/app", (_, w) => self.handle_get_skills(w))
  router.add_handler(Get, "/skills/repos", (_, w) => {
    self.handle_get_skill_repos(w)
  })
  router.add_handler(Post, "/skills/repos", (r, w) => {
    self.handle_add_skill_repo(r, w)
  })
  router.add_handler(Post, "/skills/repos/remove", (r, w) => {
    self.handle_remove_skill_repo(r, w)
  })
  router.add_handler(Post, "/skills/install-zip", (r, w) => {
    self.handle_install_skills_from_zip(r, w)
  })
}
