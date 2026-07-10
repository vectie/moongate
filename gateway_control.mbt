///|
const MOONSTAT_CONTROL_TOKEN_FILE = "control-token"

///|
const MOONSTAT_CONTROL_TOKEN_HEADER = "x-moonstat-control-token"

///|
pub fn default_moonstat_control_token_path() -> String {
  @pathx.join(default_moonstat_dir(), MOONSTAT_CONTROL_TOKEN_FILE)
}

///|
async fn ControlPlaneAuth::initialize(
  self : ControlPlaneAuth,
  path? : String = default_moonstat_control_token_path(),
) -> Unit raise Error {
  let configured_token = @os.getenv("MOONSTAT_CONTROL_TOKEN") catch {
    _ => None
  }
  match configured_token {
    Some(token) if !token.trim().is_empty() => {
      self.token = Some(token.trim().to_owned())
      return
    }
    _ => ()
  }
  let parent = @pathx.dirname(path).to_owned()
  if !parent.is_empty() && parent != "." {
    @fsx.make_directory(parent, recursive=true, exists_ok=true)
  }
  if @fsx.exists_as_file(path) {
    let existing = @fsx.read_file(path).trim().to_owned()
    if !existing.is_empty() {
      @fs.chmod(path, 0o600)
      self.token = Some(existing)
      return
    }
  }
  let token = "mst_\{generate_request_log_id()}_\{generate_request_log_id()}"
  atomic_write_store_file(path, token + "\n")
  @fs.chmod(path, 0o600)
  self.token = Some(token)
}

///|
fn ControlPlaneAuth::authorized(
  self : ControlPlaneAuth,
  headers : Map[String, String],
) -> Bool {
  guard self.token is Some(expected) else { return false }
  guard headers.get(MOONSTAT_CONTROL_TOKEN_HEADER) is Some(actual) else {
    return false
  }
  actual == expected
}

///|
async fn ControlPlaneAuth::write_bootstrap(
  self : ControlPlaneAuth,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.token is Some(token) else {
    moonstat_write_json_error(
      w,
      @status.ServiceUnavailable,
      "moonstat_control_token_unavailable",
      "Moonstat control token is unavailable",
    )
    return
  }
  w.header().set("Content-Type", "application/json")
  w.header().set("Cache-Control", "no-store")
  w.write_header(@status.Ok)
  w.write({ "token": Json::string(token) }.to_json().stringify())
  w.flush()
}
