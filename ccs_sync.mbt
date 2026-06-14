///|
fn ccs_sync_default_remote_root() -> String {
  "cc-switch-sync"
}

///|
fn ccs_sync_default_profile() -> String {
  "default"
}

///|
fn ccs_sync_default_status_json() -> Json {
  Json::object({})
}

///|
fn ccs_sync_protocol_format() -> String {
  "cc-switch-webdav-sync"
}

///|
fn ccs_sync_protocol_version() -> Int {
  2
}

///|
fn ccs_sync_db_compat_version() -> Int {
  6
}

///|
fn ccs_sync_legacy_db_compat_version() -> Int {
  5
}

///|
fn ccs_sync_remote_db_sql() -> String {
  "db.sql"
}

///|
fn ccs_sync_remote_skills_zip() -> String {
  "skills.zip"
}

///|
fn ccs_sync_remote_manifest() -> String {
  "manifest.json"
}

///|
priv struct CcsSyncManifestInfo {
  format : String
  version : Int
  db_compat_version : Int?
  device_name : String
  created_at : String
  snapshot_id : String
  artifacts : Array[String]
}

///|
priv struct CcsWebDavTextResponse {
  code : Int
  body : String
}

///|
fn ccs_sync_status_json(incoming : Map[String, Json], existing : Json?) -> Json {
  match existing {
    Some(Object(existing_obj)) =>
      match existing_obj.get("status") {
        Some(Object(status)) => return Json::object(status)
        _ => ()
      }
    _ => ()
  }
  match incoming.get("status") {
    Some(Object(status)) => Json::object(status)
    _ => ccs_sync_default_status_json()
  }
}

///|
fn ccs_sync_json_string(
  obj : Map[String, Json],
  keys : Array[String],
) -> String {
  json_string_from_map_any(obj, keys).unwrap_or("").trim().to_owned()
}

///|
fn ccs_sync_json_bool(obj : Map[String, Json], keys : Array[String]) -> Bool {
  json_bool_from_map_any(obj, keys).unwrap_or(false)
}

///|
fn ccs_sync_secret_or_existing(
  obj : Map[String, Json],
  keys : Array[String],
  existing : Json?,
  preserve_empty : Bool,
) -> String {
  let incoming = ccs_sync_json_string(obj, keys)
  if !preserve_empty || !incoming.is_empty() {
    return incoming
  }
  match existing {
    Some(Object(existing_obj)) =>
      json_string_from_map_any(existing_obj, keys).unwrap_or("")
    _ => incoming
  }
}

///|
fn ccs_webdav_sync_settings_json(
  settings : Json,
  existing : Json?,
  preserve_empty_password : Bool,
) -> Json {
  guard settings is Object(obj) else {
    return ccs_webdav_sync_empty_settings_json()
  }
  let remote_root = ccs_sync_json_string(obj, ["remoteRoot", "remote_root"])
  let profile = ccs_sync_json_string(obj, ["profile"])
  {
    "enabled": Json::boolean(ccs_sync_json_bool(obj, ["enabled"])),
    "autoSync": Json::boolean(
      ccs_sync_json_bool(obj, ["autoSync", "auto_sync"]),
    ),
    "baseUrl": Json::string(ccs_sync_json_string(obj, ["baseUrl", "base_url"])),
    "username": Json::string(ccs_sync_json_string(obj, ["username"])),
    "password": Json::string(
      ccs_sync_secret_or_existing(
        obj,
        ["password"],
        existing,
        preserve_empty_password,
      ),
    ),
    "remoteRoot": Json::string(
      if remote_root.is_empty() {
        ccs_sync_default_remote_root()
      } else {
        remote_root
      },
    ),
    "profile": Json::string(
      if profile.is_empty() {
        ccs_sync_default_profile()
      } else {
        profile
      },
    ),
    "status": ccs_sync_status_json(obj, existing),
  }.to_json()
}

///|
fn ccs_webdav_sync_empty_settings_json() -> Json {
  {
    "enabled": Json::boolean(false),
    "autoSync": Json::boolean(false),
    "baseUrl": Json::string(""),
    "username": Json::string(""),
    "password": Json::string(""),
    "remoteRoot": Json::string(ccs_sync_default_remote_root()),
    "profile": Json::string(ccs_sync_default_profile()),
    "status": ccs_sync_default_status_json(),
  }.to_json()
}

///|
fn ccs_webdav_sync_settings_empty(settings : Json) -> Bool {
  guard settings is Object(obj) else { return true }
  ccs_sync_json_string(obj, ["baseUrl", "base_url"]).is_empty() &&
  ccs_sync_json_string(obj, ["username"]).is_empty() &&
  ccs_sync_json_string(obj, ["password"]).is_empty()
}

///|
fn ccs_validate_webdav_sync_settings(settings : Json) -> String? {
  guard settings is Object(obj) else { return Some("WebDAV URL is required.") }
  if ccs_sync_json_string(obj, ["baseUrl", "base_url"]).is_empty() {
    return Some("WebDAV URL is required.")
  }
  if ccs_sync_json_string(obj, ["username"]).is_empty() {
    return Some("WebDAV username is required.")
  }
  None
}

///|
fn ccs_s3_sync_settings_json(
  settings : Json,
  existing : Json?,
  preserve_empty_secret : Bool,
) -> Json {
  guard settings is Object(obj) else {
    return ccs_s3_sync_empty_settings_json()
  }
  let remote_root = ccs_sync_json_string(obj, ["remoteRoot", "remote_root"])
  let profile = ccs_sync_json_string(obj, ["profile"])
  {
    "enabled": Json::boolean(ccs_sync_json_bool(obj, ["enabled"])),
    "autoSync": Json::boolean(
      ccs_sync_json_bool(obj, ["autoSync", "auto_sync"]),
    ),
    "region": Json::string(ccs_sync_json_string(obj, ["region"])),
    "bucket": Json::string(ccs_sync_json_string(obj, ["bucket"])),
    "accessKeyId": Json::string(
      ccs_sync_json_string(obj, ["accessKeyId", "access_key_id"]),
    ),
    "secretAccessKey": Json::string(
      ccs_sync_secret_or_existing(
        obj,
        ["secretAccessKey", "secret_access_key"],
        existing,
        preserve_empty_secret,
      ),
    ),
    "endpoint": Json::string(ccs_sync_json_string(obj, ["endpoint"])),
    "remoteRoot": Json::string(
      if remote_root.is_empty() {
        ccs_sync_default_remote_root()
      } else {
        remote_root
      },
    ),
    "profile": Json::string(
      if profile.is_empty() {
        ccs_sync_default_profile()
      } else {
        profile
      },
    ),
    "status": ccs_sync_status_json(obj, existing),
  }.to_json()
}

///|
fn ccs_s3_sync_empty_settings_json() -> Json {
  {
    "enabled": Json::boolean(false),
    "autoSync": Json::boolean(false),
    "region": Json::string(""),
    "bucket": Json::string(""),
    "accessKeyId": Json::string(""),
    "secretAccessKey": Json::string(""),
    "endpoint": Json::string(""),
    "remoteRoot": Json::string(ccs_sync_default_remote_root()),
    "profile": Json::string(ccs_sync_default_profile()),
    "status": ccs_sync_default_status_json(),
  }.to_json()
}

///|
fn ccs_s3_sync_settings_empty(settings : Json) -> Bool {
  guard settings is Object(obj) else { return true }
  ccs_sync_json_string(obj, ["bucket"]).is_empty() &&
  ccs_sync_json_string(obj, ["region"]).is_empty() &&
  ccs_sync_json_string(obj, ["accessKeyId", "access_key_id"]).is_empty() &&
  ccs_sync_json_string(obj, ["secretAccessKey", "secret_access_key"]).is_empty()
}

///|
fn ccs_validate_s3_sync_settings(settings : Json) -> String? {
  guard settings is Object(obj) else { return Some("S3 bucket is required.") }
  if ccs_sync_json_string(obj, ["bucket"]).is_empty() {
    return Some("S3 bucket is required.")
  }
  if ccs_sync_json_string(obj, ["region"]).is_empty() {
    return Some("S3 region is required.")
  }
  if ccs_sync_json_string(obj, ["accessKeyId", "access_key_id"]).is_empty() {
    return Some("S3 Access Key ID is required.")
  }
  if ccs_sync_json_string(obj, ["secretAccessKey", "secret_access_key"]).is_empty() {
    return Some("S3 Secret Access Key is required.")
  }
  None
}

///|
fn ccs_app_webdav_sync_json(settings : Json) -> Json? {
  guard settings is Object(obj) else { return None }
  match obj.get("webdavSync") {
    Some(value) => Some(value)
    None => obj.get("webdav_sync")
  }
}

///|
fn ccs_app_s3_sync_json(settings : Json) -> Json? {
  guard settings is Object(obj) else { return None }
  match obj.get("s3Sync") {
    Some(value) => Some(value)
    None => obj.get("s3_sync")
  }
}

///|
fn ccs_app_settings_with_sync(
  settings : Json,
  key : String,
  sync_settings : Json,
) -> Json {
  match settings {
    Object(obj) => {
      obj[key] = sync_settings
      Json::object(obj)
    }
    _ => {
      let obj : Map[String, Json] = {}
      obj[key] = sync_settings
      Json::object(obj)
    }
  }
}

///|
fn ccs_sync_settings_request(path : StringView, body : Json?) -> Json? {
  match ccs_json_request(path, body, ["settings", "config"]) {
    Some(value) => Some(value)
    None => body
  }
}

///|
fn ccs_sync_preserve_empty_password_request(
  path : StringView,
  body : Json?,
) -> Bool {
  proxy_bool_request(path, body, [
    "preserveEmptyPassword", "preserve_empty_password",
  ]).unwrap_or(true)
}

///|
fn ccs_sync_password_touched_request(path : StringView, body : Json?) -> Bool {
  proxy_bool_request(path, body, ["passwordTouched", "password_touched"]).unwrap_or(
    false,
  )
}

///|
fn ccs_webdav_sync_required_error(settings : Json) -> String? {
  match ccs_app_webdav_sync_json(settings) {
    None => Some("WebDAV sync is not configured.")
    Some(raw) => {
      let normalized = ccs_webdav_sync_settings_json(raw, None, false)
      if ccs_webdav_sync_settings_empty(normalized) {
        return Some("WebDAV sync is not configured.")
      }
      guard normalized is Object(obj) else {
        return Some("WebDAV sync is not configured.")
      }
      if !ccs_sync_json_bool(obj, ["enabled"]) {
        return Some("WebDAV sync is disabled.")
      }
      ccs_validate_webdav_sync_settings(normalized)
    }
  }
}

///|
fn ccs_s3_sync_required_error(settings : Json) -> String? {
  match ccs_app_s3_sync_json(settings) {
    None => Some("S3 sync is not configured.")
    Some(raw) => {
      let normalized = ccs_s3_sync_settings_json(raw, None, false)
      if ccs_s3_sync_settings_empty(normalized) {
        return Some("S3 sync is not configured.")
      }
      guard normalized is Object(obj) else {
        return Some("S3 sync is not configured.")
      }
      if !ccs_sync_json_bool(obj, ["enabled"]) {
        return Some("S3 sync is disabled.")
      }
      ccs_validate_s3_sync_settings(normalized)
    }
  }
}

///|
fn ccs_sync_path_segments(path : String) -> Array[String] {
  let result : Array[String] = []
  for part in path.split("/") {
    let part = part.trim()
    if !part.is_empty() {
      result.push(part.to_owned())
    }
  }
  result
}

///|
fn ccs_sync_remote_dir_segments(
  remote_root : String,
  profile : String,
  layout : String,
) -> Array[String] {
  let segs = ccs_sync_path_segments(remote_root)
  segs.push("v\{ccs_sync_protocol_version()}")
  if layout == "current" {
    segs.push("db-v\{ccs_sync_db_compat_version()}")
  }
  for part in ccs_sync_path_segments(profile) {
    segs.push(part)
  }
  segs
}

///|
fn ccs_sync_remote_dir_display(
  remote_root : String,
  profile : String,
  layout : String,
) -> String {
  "/\{ccs_sync_remote_dir_segments(remote_root, profile, layout).join("/")}"
}

///|
fn ccs_sync_remote_file_path(
  remote_root : String,
  profile : String,
  layout : String,
  file_name : String,
) -> String {
  let segs = ccs_sync_remote_dir_segments(remote_root, profile, layout)
  for part in ccs_sync_path_segments(file_name) {
    segs.push(part)
  }
  segs.join("/")
}

///|
fn ccs_webdav_encode_path_segment(segment : String) -> String {
  let bytes = @encoding/utf8.encode(segment)
  let builder = StringBuilder::new()
  for i in 0..<bytes.length() {
    let value = bytes[i].to_int()
    if ccs_webdav_is_unreserved_path_byte(value) {
      builder.write_char(value.unsafe_to_char())
    } else {
      builder.write_char('%')
      builder.write_char(ccs_webdav_hex_digit(value / 16))
      builder.write_char(ccs_webdav_hex_digit(value % 16))
    }
  }
  builder.to_string()
}

///|
fn ccs_webdav_is_unreserved_path_byte(value : Int) -> Bool {
  (value >= 'A'.to_int() && value <= 'Z'.to_int()) ||
  (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
  (value >= '0'.to_int() && value <= '9'.to_int()) ||
  value == '-'.to_int() ||
  value == '.'.to_int() ||
  value == '_'.to_int() ||
  value == '~'.to_int()
}

///|
fn ccs_webdav_hex_digit(value : Int) -> Char {
  if value < 10 {
    ('0'.to_int() + value).unsafe_to_char()
  } else {
    ('A'.to_int() + value - 10).unsafe_to_char()
  }
}

///|
fn ccs_webdav_encoded_path(segments : Array[String]) -> String {
  segments.map(ccs_webdav_encode_path_segment).join("/")
}

///|
fn ccs_webdav_remote_file_url(
  settings : Json,
  layout : String,
  file_name : String,
) -> Result[String, String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  guard json_string_from_map(obj, "baseUrl") is Some(base_url) else {
    return Err("WebDAV URL is required.")
  }
  guard json_string_from_map(obj, "remoteRoot") is Some(remote_root) else {
    return Err("WebDAV remote root is required.")
  }
  guard json_string_from_map(obj, "profile") is Some(profile) else {
    return Err("WebDAV profile is required.")
  }
  let base_url = trim_end_slashes(base_url.trim().to_owned())
  if base_url.is_empty() {
    return Err("WebDAV URL is required.")
  }
  let remote_segments = ccs_sync_remote_dir_segments(
    remote_root, profile, layout,
  )
  for part in ccs_sync_path_segments(file_name) {
    remote_segments.push(part)
  }
  Ok("\{base_url}/\{ccs_webdav_encoded_path(remote_segments)}")
}

///|
fn ccs_webdav_basic_auth_header(username : String, password : String) -> String {
  let token = @base64.encode(@encoding/utf8.encode("\{username}:\{password}"))
  "Basic \{token}"
}

///|
async fn ccs_webdav_get_text(
  url : String,
  username : String,
  password : String,
) -> Result[CcsWebDavTextResponse, String] {
  let (origin, path) = split_origin_and_path(url)
  let client = @http.Client::new(origin, headers={
    "Authorization": ccs_webdav_basic_auth_header(username, password),
    "Accept": "application/json",
  })
  defer client.close()
  let response = client.get(if path.is_empty() { "/" } else { path }) catch {
    err => return Err("WebDAV GET failed: \{err}")
  }
  Ok(CcsWebDavTextResponse::{
    code: response.code,
    body: client.read_all().text(),
  })
}

///|
fn ccs_webdav_remote_info_from_body(
  body : String,
  layout : String,
  settings : Json,
) -> Result[Json, String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  let remote_root = json_string_from_map(obj, "remoteRoot").unwrap_or(
    ccs_sync_default_remote_root(),
  )
  let profile = json_string_from_map(obj, "profile").unwrap_or(
    ccs_sync_default_profile(),
  )
  let manifest_json = @json.parse(body) catch {
    _ => return Err("Remote manifest is not valid JSON.")
  }
  let manifest = match ccs_sync_manifest_info_from_json(manifest_json) {
    Ok(manifest) => manifest
    Err(error) => return Err(error)
  }
  Ok(ccs_sync_remote_info_json(manifest, layout, remote_root, profile))
}

///|
async fn ccs_webdav_sync_fetch_remote_info_json(
  settings : Json,
) -> Result[Json, String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  let username = json_string_from_map(obj, "username").unwrap_or("")
  let password = json_string_from_map(obj, "password").unwrap_or("")
  let current_url = match
    ccs_webdav_remote_file_url(settings, "current", ccs_sync_remote_manifest()) {
    Ok(url) => url
    Err(error) => return Err(error)
  }
  let current = match ccs_webdav_get_text(current_url, username, password) {
    Ok(response) => response
    Err(error) => return Err(error)
  }
  if current.code >= 200 && current.code <= 299 {
    return ccs_webdav_remote_info_from_body(current.body, "current", settings)
  }
  if current.code != 404 {
    return Err("WebDAV GET failed: HTTP \{current.code}")
  }
  let legacy_url = match
    ccs_webdav_remote_file_url(settings, "legacy", ccs_sync_remote_manifest()) {
    Ok(url) => url
    Err(error) => return Err(error)
  }
  let legacy = match ccs_webdav_get_text(legacy_url, username, password) {
    Ok(response) => response
    Err(error) => return Err(error)
  }
  if legacy.code == 404 {
    return Ok({ "empty": Json::boolean(true) }.to_json())
  }
  if legacy.code >= 200 && legacy.code <= 299 {
    return ccs_webdav_remote_info_from_body(legacy.body, "legacy", settings)
  }
  Err("WebDAV GET failed: HTTP \{legacy.code}")
}

///|
fn ccs_sync_effective_db_compat_version(
  manifest : CcsSyncManifestInfo,
  layout : String,
) -> Int? {
  match manifest.db_compat_version {
    Some(value) => Some(value)
    None =>
      if layout == "legacy" {
        Some(ccs_sync_legacy_db_compat_version())
      } else {
        None
      }
  }
}

///|
fn ccs_sync_manifest_info_from_json(
  manifest_json : Json,
) -> Result[CcsSyncManifestInfo, String] {
  guard manifest_json is Object(obj) else {
    return Err("Remote manifest is not a JSON object.")
  }
  guard json_string_from_map(obj, "format") is Some(format) else {
    return Err("Remote manifest is missing format.")
  }
  guard proxy_json_int(obj, "version") is Some(version) else {
    return Err("Remote manifest is missing protocol version.")
  }
  guard json_string_from_map_any(obj, ["deviceName", "device_name"])
    is Some(device_name) else {
    return Err("Remote manifest is missing device name.")
  }
  guard json_string_from_map_any(obj, ["createdAt", "created_at"])
    is Some(created_at) else {
    return Err("Remote manifest is missing creation time.")
  }
  guard json_string_from_map_any(obj, ["snapshotId", "snapshot_id"])
    is Some(snapshot_id) else {
    return Err("Remote manifest is missing snapshot id.")
  }
  guard obj.get("artifacts") is Some(Object(artifact_map)) else {
    return Err("Remote manifest is missing artifacts.")
  }
  let artifacts = artifact_map.keys().collect()
  artifacts.sort()
  Ok(CcsSyncManifestInfo::{
    format,
    version,
    db_compat_version: proxy_json_int(obj, "dbCompatVersion"),
    device_name,
    created_at,
    snapshot_id,
    artifacts,
  })
}

///|
fn ccs_sync_validate_manifest_compat(
  manifest : CcsSyncManifestInfo,
  layout : String,
) -> Result[Unit, String] {
  if manifest.format != ccs_sync_protocol_format() {
    return Err("Remote manifest format is incompatible: \{manifest.format}")
  }
  if manifest.version != ccs_sync_protocol_version() {
    return Err(
      "Remote manifest protocol version is incompatible: v\{manifest.version} (local v\{ccs_sync_protocol_version()})",
    )
  }
  guard ccs_sync_effective_db_compat_version(manifest, layout)
    is Some(db_compat_version) else {
    return Err("Remote manifest is missing the database compatibility version.")
  }
  if layout == "current" && db_compat_version != ccs_sync_db_compat_version() {
    return Err(
      "Remote database snapshot version is incompatible: db-v\{db_compat_version} (local db-v\{ccs_sync_db_compat_version()})",
    )
  }
  if layout == "legacy" && db_compat_version > ccs_sync_db_compat_version() {
    return Err(
      "Remote database snapshot version is incompatible: db-v\{db_compat_version} (local supports up to db-v\{ccs_sync_db_compat_version()})",
    )
  }
  Ok(())
}

///|
fn ccs_sync_remote_info_json(
  manifest : CcsSyncManifestInfo,
  layout : String,
  remote_root : String,
  profile : String,
) -> Json {
  let compatible = ccs_sync_validate_manifest_compat(manifest, layout) is Ok(_)
  let db_compat_version = match
    ccs_sync_effective_db_compat_version(manifest, layout) {
    Some(value) => Json::number(value.to_double())
    None => Json::null()
  }
  {
    "deviceName": Json::string(manifest.device_name),
    "createdAt": Json::string(manifest.created_at),
    "snapshotId": Json::string(manifest.snapshot_id),
    "version": Json::number(manifest.version.to_double()),
    "protocolVersion": Json::number(manifest.version.to_double()),
    "dbCompatVersion": db_compat_version,
    "compatible": Json::boolean(compatible),
    "artifacts": Json::array(manifest.artifacts.map(Json::string)),
    "layout": Json::string(layout),
    "remotePath": Json::string(
      ccs_sync_remote_dir_display(remote_root, profile, layout),
    ),
  }.to_json()
}
