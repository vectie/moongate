///|
const MOONGATE_PROXY_STORE_FILE = "proxy.json"

///|
fn moon_proxy_store_path() -> String {
  @pathx.join(moon_app_config_dir(), MOONGATE_PROXY_STORE_FILE)
}

///|
async fn ProxyService::save_proxy_store(
  self : ProxyService,
  path? : String = moon_proxy_store_path(),
) -> Unit raise Error {
  let parent = @pathx.dirname(path)
  if !parent.is_empty() && parent != "." {
    @fsx.make_directory(parent, recursive=true, exists_ok=true)
  }
  atomic_write_store_file(
    path,
    self.moon_export_proxy_json().stringify(indent=2) + "\n",
  )
}

///|
async fn ProxyService::load_proxy_store(
  self : ProxyService,
  path? : String = moon_proxy_store_path(),
) -> Unit raise Error {
  if !@fsx.exists_as_file(path) {
    return
  }
  guard @json.parse(@fsx.read_file(path)) is Object(proxy) else {
    raise Failure::Failure("Invalid MoonGate proxy store")
  }
  self.moon_apply_import_proxy(proxy)
}

///|
async fn ProxyService::persist_proxy_store_or_error(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Bool {
  self.save_proxy_store() catch {
    error => {
      moongate_write_json_error(
        w,
        @status.InternalServerError,
        "moongate_proxy_store_write_failed",
        "Failed to persist MoonGate proxy settings: \{error}",
      )
      return false
    }
  }
  true
}
