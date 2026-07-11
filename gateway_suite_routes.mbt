///|
fn Gateway::register_suite_routes(
  self : Gateway,
  router : @httpx.Router,
  bound_port : Int,
) -> Unit {
  router.add_handler(Get, "/suite/manifest", (_, w) => {
    self.handle_suite_manifest(w, bound_port)
  })
  router.add_handler(Get, "/suite/status", (_, w) => {
    self.handle_suite_status(w, bound_port)
  })
  router.add_handler(Get, "/suite/drift", (r, w) => {
    self.handle_suite_drift(r, w)
  })
  router.add_handler(Post, "/suite/status/write", (r, w) => {
    self.handle_suite_write_status(r, w, bound_port)
  })
  router.add_handler(Get, "/suite/moonclaw-providers", (_, w) => {
    self.handle_suite_moonclaw_providers(w, bound_port)
  })
  router.add_handler(Post, "/suite/moonclaw-providers/write", (r, w) => {
    self.handle_suite_write_moonclaw_providers(r, w, bound_port)
  })
}

///|
async fn Gateway::handle_suite_manifest(
  self : Gateway,
  w : @httpx.ResponseWriter,
  bound_port : Int,
) -> Unit {
  write_usage_json(
    w,
    moongate_suite_manifest_json(
      host=self.host,
      port=bound_port,
      model=self.model,
    ),
  )
}

///|
async fn Gateway::handle_suite_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
  bound_port : Int,
) -> Unit {
  write_usage_json(
    w,
    moongate_suite_status_json(
      host=self.host,
      port=bound_port,
      model=self.model,
      status="running",
      ready=true,
    ),
  )
}

///|
async fn Gateway::handle_suite_drift(
  _self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let root = proxy_string_request(r.path, None, "root").unwrap_or(".")
  let report = moongate_suite_drift_report_json(suite_root=root)
  write_usage_json(w, report)
}

///|
async fn Gateway::handle_suite_write_status(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  bound_port : Int,
) -> Unit {
  let body = proxy_json_body(r)
  let path = proxy_string_request(r.path, body, "path").unwrap_or(
    default_moongate_suite_status_path(),
  )
  let status = proxy_string_request(r.path, body, "status").unwrap_or("running")
  let ready = proxy_bool_request(r.path, body, "ready").unwrap_or(true)
  let written = write_moongate_suite_status(
    path~,
    host=self.host,
    port=bound_port,
    model=self.model,
    status~,
    ready~,
  ) catch {
    err => {
      write_usage_bad_request(w, "\{err}")
      return
    }
  }
  write_usage_json(w, suite_write_result_json(written))
}

///|
async fn Gateway::handle_suite_moonclaw_providers(
  self : Gateway,
  w : @httpx.ResponseWriter,
  bound_port : Int,
) -> Unit {
  write_usage_json(
    w,
    moongate_moonclaw_providers_file_json(
      host=self.host,
      port=bound_port,
      model=self.model,
    ),
  )
}

///|
async fn Gateway::handle_suite_write_moonclaw_providers(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  bound_port : Int,
) -> Unit {
  let body = proxy_json_body(r)
  let path = proxy_string_request(r.path, body, "path").unwrap_or(
    default_moongate_moonclaw_providers_file_path(),
  )
  let written = write_moongate_moonclaw_providers_file(
    path~,
    host=self.host,
    port=bound_port,
    model=self.model,
  ) catch {
    err => {
      write_usage_bad_request(w, "\{err}")
      return
    }
  }
  write_usage_json(w, suite_write_result_json(written))
}

///|
fn suite_write_result_json(path : String) -> Json {
  { "success": Json::boolean(true), "path": Json::string(path) }.to_json()
}
