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
fn ccs_webdav_default_timeout_ms() -> Int {
  30000
}

///|
fn ccs_webdav_transfer_timeout_ms() -> Int {
  300000
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
  artifact_meta : Map[String, CcsSyncArtifactMeta]
}

///|
priv struct CcsSyncArtifactMeta {
  sha256 : String
  size : Int
}

///|
priv struct CcsLocalSyncSnapshot {
  db_sql : Bytes
  skills_zip : Bytes
  manifest_bytes : Bytes
  manifest_hash : String
}

///|
priv struct CcsWebDavRemoteSnapshot {
  layout : String
  manifest : CcsSyncManifestInfo
  manifest_bytes : Bytes
}

///|
priv struct CcsS3RemoteSnapshot {
  manifest : CcsSyncManifestInfo
  manifest_bytes : Bytes
  etag : String?
}

///|
priv struct CcsWebDavTextResponse {
  code : Int
  body : String
}

///|
priv struct CcsWebDavCurlRequest {
  program : String
  args : Array[String]
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
fn ccs_sync_sha256_hex(bytes : Bytes) -> String {
  let digest = @crypto.sha256(bytes)
  let builder = StringBuilder::new()
  for i in 0..<digest.length() {
    let value = digest[i].to_int()
    builder.write_char(ccs_sync_hex_digit(value / 16))
    builder.write_char(ccs_sync_hex_digit(value % 16))
  }
  builder.to_string()
}

///|
fn ccs_sync_hex_digit(value : Int) -> Char {
  if value < 10 {
    ('0'.to_int() + value).unsafe_to_char()
  } else {
    ('a'.to_int() + value - 10).unsafe_to_char()
  }
}

///|
fn ccs_sync_snapshot_id(artifacts : Map[String, CcsSyncArtifactMeta]) -> String {
  let keys = artifacts.keys().collect()
  keys.sort()
  let parts : Array[String] = []
  for key in keys {
    guard artifacts.get(key) is Some(meta) else { continue }
    parts.push("\{key}:\{meta.sha256}")
  }
  ccs_sync_sha256_hex(@encoding/utf8.encode(parts.join("|")))
}

///|
fn ccs_sync_device_name() -> String {
  let configured = @os.getenv("CC_SWITCH_DEVICE_NAME") catch { _ => None }
  match configured {
    Some(value) if !value.trim().is_empty() => value.trim().to_owned()
    _ => {
      let hostname = @os.gethostname() catch { _ => "" }
      match hostname {
        "" => "Unknown Device"
        value => value.trim().to_owned()
      }
    }
  }
}

///|
fn ccs_sync_artifact_meta(bytes : Bytes) -> CcsSyncArtifactMeta {
  CcsSyncArtifactMeta::{
    sha256: ccs_sync_sha256_hex(bytes),
    size: bytes.length(),
  }
}

///|
fn ccs_sync_artifact_meta_json(meta : CcsSyncArtifactMeta) -> Json {
  {
    "sha256": Json::string(meta.sha256),
    "size": Json::number(meta.size.to_double()),
  }.to_json()
}

///|
fn ccs_sync_manifest_json(
  artifacts : Map[String, CcsSyncArtifactMeta],
  snapshot_id : String,
) -> Json {
  let artifact_json : Map[String, Json] = {}
  let keys = artifacts.keys().collect()
  keys.sort()
  for key in keys {
    guard artifacts.get(key) is Some(meta) else { continue }
    artifact_json[key] = ccs_sync_artifact_meta_json(meta)
  }
  {
    "format": Json::string(ccs_sync_protocol_format()),
    "version": Json::number(ccs_sync_protocol_version().to_double()),
    "dbCompatVersion": Json::number(ccs_sync_db_compat_version().to_double()),
    "deviceName": Json::string(ccs_sync_device_name()),
    "createdAt": Json::string(@os.unix_seconds().to_string()),
    "artifacts": Json::object(artifact_json),
    "snapshotId": Json::string(snapshot_id),
  }.to_json()
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
  let remote_segments = match
    ccs_webdav_remote_dir_segments_from_settings(settings, layout) {
    Ok(segs) => segs
    Err(error) => return Err(error)
  }
  for part in ccs_sync_path_segments(file_name) {
    remote_segments.push(part)
  }
  ccs_webdav_remote_url(settings, remote_segments)
}

///|
fn ccs_webdav_remote_dir_url(
  settings : Json,
  layout : String,
  depth : Int,
) -> Result[String, String] {
  let remote_segments = match
    ccs_webdav_remote_dir_segments_from_settings(settings, layout) {
    Ok(segs) => segs
    Err(error) => return Err(error)
  }
  if depth <= 0 {
    return ccs_webdav_remote_url(settings, [])
  }
  let limit = if depth > remote_segments.length() {
    remote_segments.length()
  } else {
    depth
  }
  let segs = remote_segments[:limit].to_owned()
  match ccs_webdav_remote_url(settings, segs) {
    Ok(url) => Ok(if url.has_suffix("/") { url } else { "\{url}/" })
    Err(error) => Err(error)
  }
}

///|
fn ccs_webdav_remote_dir_segments_from_settings(
  settings : Json,
  layout : String,
) -> Result[Array[String], String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  guard json_string_from_map(obj, "remoteRoot") is Some(remote_root) else {
    return Err("WebDAV remote root is required.")
  }
  guard json_string_from_map(obj, "profile") is Some(profile) else {
    return Err("WebDAV profile is required.")
  }
  Ok(ccs_sync_remote_dir_segments(remote_root, profile, layout))
}

///|
fn ccs_webdav_remote_url(
  settings : Json,
  segments : Array[String],
) -> Result[String, String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  guard json_string_from_map(obj, "baseUrl") is Some(base_url) else {
    return Err("WebDAV URL is required.")
  }
  let base_url = trim_end_slashes(base_url.trim().to_owned())
  if base_url.is_empty() {
    return Err("WebDAV URL is required.")
  }
  if segments.is_empty() {
    Ok(base_url)
  } else {
    Ok("\{base_url}/\{ccs_webdav_encoded_path(segments)}")
  }
}

///|
fn ccs_webdav_basic_auth_header(username : String, password : String) -> String {
  let token = @base64.encode(@encoding/utf8.encode("\{username}:\{password}"))
  "Basic \{token}"
}

///|
fn ccs_s3_is_aws_endpoint(endpoint : String) -> Bool {
  endpoint.is_empty() || endpoint.contains("amazonaws.com")
}

///|
fn ccs_s3_split_scheme_host(endpoint : String) -> (String, String) {
  let trimmed = trim_end_slashes(endpoint.trim().to_owned())
  if trimmed.has_prefix("http://") {
    ("http", trimmed[7:].to_owned())
  } else if trimmed.has_prefix("https://") {
    ("https", trimmed[8:].to_owned())
  } else {
    ("https", trimmed)
  }
}

///|
fn ccs_s3_remote_file_key(
  settings : Json,
  file_name : String,
) -> Result[String, String] {
  guard settings is Object(obj) else {
    return Err("S3 sync is not configured.")
  }
  guard json_string_from_map(obj, "remoteRoot") is Some(remote_root) else {
    return Err("S3 remote root is required.")
  }
  guard json_string_from_map(obj, "profile") is Some(profile) else {
    return Err("S3 profile is required.")
  }
  Ok(ccs_sync_remote_file_path(remote_root, profile, "current", file_name))
}

///|
fn ccs_s3_remote_dir_display(settings : Json) -> Result[String, String] {
  guard settings is Object(obj) else {
    return Err("S3 sync is not configured.")
  }
  guard json_string_from_map(obj, "remoteRoot") is Some(remote_root) else {
    return Err("S3 remote root is required.")
  }
  guard json_string_from_map(obj, "profile") is Some(profile) else {
    return Err("S3 profile is required.")
  }
  Ok(ccs_sync_remote_dir_segments(remote_root, profile, "current").join("/"))
}

///|
fn ccs_s3_bucket_url(settings : Json) -> Result[String, String] {
  guard settings is Object(obj) else {
    return Err("S3 sync is not configured.")
  }
  let endpoint = json_string_from_map(obj, "endpoint").unwrap_or("")
  let bucket = json_string_from_map(obj, "bucket").unwrap_or("")
  let region = json_string_from_map(obj, "region").unwrap_or("")
  if bucket.is_empty() {
    return Err("S3 bucket is required.")
  }
  if region.is_empty() {
    return Err("S3 region is required.")
  }
  if ccs_s3_is_aws_endpoint(endpoint) {
    Ok("https://\{bucket}.s3.\{region}.amazonaws.com/")
  } else {
    let (scheme, host) = ccs_s3_split_scheme_host(endpoint)
    Ok("\{scheme}://\{host}/\{ccs_webdav_encode_path_segment(bucket)}/")
  }
}

///|
fn ccs_s3_object_url(settings : Json, key : String) -> Result[String, String] {
  guard settings is Object(obj) else {
    return Err("S3 sync is not configured.")
  }
  let endpoint = json_string_from_map(obj, "endpoint").unwrap_or("")
  let bucket = json_string_from_map(obj, "bucket").unwrap_or("")
  let region = json_string_from_map(obj, "region").unwrap_or("")
  if bucket.is_empty() {
    return Err("S3 bucket is required.")
  }
  if region.is_empty() {
    return Err("S3 region is required.")
  }
  let encoded_key = ccs_webdav_encoded_path(ccs_sync_path_segments(key))
  if ccs_s3_is_aws_endpoint(endpoint) {
    Ok("https://\{bucket}.s3.\{region}.amazonaws.com/\{encoded_key}")
  } else {
    let (scheme, host) = ccs_s3_split_scheme_host(endpoint)
    Ok(
      "\{scheme}://\{host}/\{ccs_webdav_encode_path_segment(bucket)}/\{encoded_key}",
    )
  }
}

///|
fn ccs_s3_curl_common_args(
  settings : Json,
  timeout_ms : Int,
) -> Result[Array[String], String] {
  guard settings is Object(obj) else {
    return Err("S3 sync is not configured.")
  }
  let region = json_string_from_map(obj, "region").unwrap_or("")
  let access_key = json_string_from_map(obj, "accessKeyId").unwrap_or("")
  let secret_key = json_string_from_map(obj, "secretAccessKey").unwrap_or("")
  if region.is_empty() {
    return Err("S3 region is required.")
  }
  if access_key.is_empty() {
    return Err("S3 Access Key ID is required.")
  }
  if secret_key.is_empty() {
    return Err("S3 Secret Access Key is required.")
  }
  Ok([
    "-sS",
    "-L",
    "--aws-sigv4",
    "aws:amz:\{region}:s3",
    "-u",
    "\{access_key}:\{secret_key}",
    "--max-time",
    (timeout_ms / 1000).to_string(),
  ])
}

///|
fn ccs_s3_curl_head_request(
  settings : Json,
  url : String,
  header_path? : String,
) -> Result[CcsWebDavCurlRequest, String] {
  let args = match
    ccs_s3_curl_common_args(settings, ccs_webdav_default_timeout_ms()) {
    Ok(args) => args
    Err(error) => return Err(error)
  }
  args.push("-I")
  args.push("-o")
  args.push("/dev/null")
  args.push("-w")
  args.push("%{http_code}")
  if header_path is Some(path) {
    args.push("-D")
    args.push(path)
  }
  args.push(url)
  Ok(CcsWebDavCurlRequest::{ program: "curl", args })
}

///|
fn ccs_s3_curl_put_request(
  settings : Json,
  url : String,
  file_path : String,
  content_type : String,
) -> Result[CcsWebDavCurlRequest, String] {
  let args = match
    ccs_s3_curl_common_args(settings, ccs_webdav_transfer_timeout_ms()) {
    Ok(args) => args
    Err(error) => return Err(error)
  }
  args.push("-X")
  args.push("PUT")
  args.push("-H")
  args.push("Content-Type: \{content_type}")
  args.push("--upload-file")
  args.push(file_path)
  args.push("-o")
  args.push("/dev/null")
  args.push("-w")
  args.push("%{http_code}")
  args.push(url)
  Ok(CcsWebDavCurlRequest::{ program: "curl", args })
}

///|
fn ccs_s3_curl_get_request(
  settings : Json,
  url : String,
  output_path : String,
  header_path? : String,
) -> Result[CcsWebDavCurlRequest, String] {
  let args = match
    ccs_s3_curl_common_args(settings, ccs_webdav_transfer_timeout_ms()) {
    Ok(args) => args
    Err(error) => return Err(error)
  }
  args.push("-o")
  args.push(output_path)
  args.push("-w")
  args.push("%{http_code}")
  if header_path is Some(path) {
    args.push("-D")
    args.push(path)
  }
  args.push(url)
  Ok(CcsWebDavCurlRequest::{ program: "curl", args })
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
fn ccs_webdav_curl_status_request(
  settings : Json,
  webdav_method : String,
  url : String,
  depth_zero? : Bool = false,
) -> Result[CcsWebDavCurlRequest, String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  let args : Array[String] = [
    "-sS", "-L", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "30", "-X",
    webdav_method,
  ]
  if depth_zero {
    args.push("-H")
    args.push("Depth: 0")
  }
  let username = json_string_from_map(obj, "username").unwrap_or("")
  if !username.is_empty() {
    args.push("-u")
    args.push(
      "\{username}:\{json_string_from_map(obj, "password").unwrap_or("")}",
    )
  }
  args.push(url)
  Ok(CcsWebDavCurlRequest::{ program: "curl", args })
}

///|
fn ccs_webdav_curl_put_request(
  settings : Json,
  url : String,
  file_path : String,
  content_type : String,
) -> Result[CcsWebDavCurlRequest, String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  let args : Array[String] = [
    "-sS",
    "-L",
    "-o",
    "/dev/null",
    "-w",
    "%{http_code}",
    "--max-time",
    (ccs_webdav_transfer_timeout_ms() / 1000).to_string(),
    "-X",
    "PUT",
    "-H",
    "Content-Type: \{content_type}",
    "--upload-file",
    file_path,
  ]
  let username = json_string_from_map(obj, "username").unwrap_or("")
  if !username.is_empty() {
    args.push("-u")
    args.push(
      "\{username}:\{json_string_from_map(obj, "password").unwrap_or("")}",
    )
  }
  args.push(url)
  Ok(CcsWebDavCurlRequest::{ program: "curl", args })
}

///|
fn ccs_webdav_curl_get_request(
  settings : Json,
  url : String,
  output_path : String,
) -> Result[CcsWebDavCurlRequest, String] {
  guard settings is Object(obj) else {
    return Err("WebDAV sync is not configured.")
  }
  let args : Array[String] = [
    "-sS",
    "-L",
    "-o",
    output_path,
    "-w",
    "%{http_code}",
    "--max-time",
    (ccs_webdav_transfer_timeout_ms() / 1000).to_string(),
  ]
  let username = json_string_from_map(obj, "username").unwrap_or("")
  if !username.is_empty() {
    args.push("-u")
    args.push(
      "\{username}:\{json_string_from_map(obj, "password").unwrap_or("")}",
    )
  }
  args.push(url)
  Ok(CcsWebDavCurlRequest::{ program: "curl", args })
}

///|
async fn ccs_webdav_run_status_request(
  request : CcsWebDavCurlRequest,
  operation : String,
) -> Result[Int, String] {
  let result = @spawn.spawn(
    request.program,
    request.args.map(fn(arg) { arg[:] }),
    timeout=ccs_webdav_default_timeout_ms(),
  ) catch {
    err => return Err("WebDAV \{operation} failed: \{err}")
  }
  if result.status != 0 {
    let detail = if result.stderr.trim().is_empty() {
      result.stdout.trim()
    } else {
      result.stderr.trim()
    }
    return Err(
      if detail.is_empty() {
        "WebDAV \{operation} failed: exit code \{result.status}"
      } else {
        "WebDAV \{operation} failed: \{detail}"
      },
    )
  }
  let status = @string.parse_int(result.stdout.trim(), base=10) catch {
    _ => return Err("WebDAV \{operation} returned an invalid HTTP status.")
  }
  Ok(status)
}

///|
async fn ccs_s3_run_status_request(
  request : CcsWebDavCurlRequest,
  operation : String,
) -> Result[Int, String] {
  let result = @spawn.spawn(
    request.program,
    request.args.map(fn(arg) { arg[:] }),
    timeout=ccs_webdav_transfer_timeout_ms(),
  ) catch {
    err => return Err("S3 \{operation} failed: \{err}")
  }
  if result.status != 0 {
    let detail = if result.stderr.trim().is_empty() {
      result.stdout.trim()
    } else {
      result.stderr.trim()
    }
    return Err(
      if detail.is_empty() {
        "S3 \{operation} failed: exit code \{result.status}"
      } else {
        "S3 \{operation} failed: \{detail}"
      },
    )
  }
  let status = @string.parse_int(result.stdout.trim(), base=10) catch {
    _ => return Err("S3 \{operation} returned an invalid HTTP status.")
  }
  Ok(status)
}

///|
fn ccs_webdav_status_ok_for_propfind(status : Int) -> Bool {
  (status >= 200 && status <= 299) || status == 207
}

///|
fn ccs_webdav_status_ok_for_mkcol(status : Int) -> Bool {
  status >= 200 && status <= 299
}

///|
fn ccs_webdav_status_needs_propfind_verify(status : Int) -> Bool {
  status == 405 || status == 409 || (status >= 300 && status <= 399)
}

///|
fn ccs_webdav_status_ok_for_transfer(status : Int) -> Bool {
  status >= 200 && status <= 299
}

///|
fn ccs_s3_status_ok(status : Int) -> Bool {
  status >= 200 && status <= 299
}

///|
async fn ccs_webdav_sync_test_connection_json(
  settings : Json,
) -> Result[Json, String] {
  let base_url = match ccs_webdav_remote_url(settings, []) {
    Ok(url) => url
    Err(error) => return Err(error)
  }
  let propfind = ccs_webdav_curl_status_request(
    settings,
    "PROPFIND",
    base_url,
    depth_zero=true,
  )
  let propfind = match propfind {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let base_status = match ccs_webdav_run_status_request(propfind, "PROPFIND") {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if !ccs_webdav_status_ok_for_propfind(base_status) {
    return Err("WebDAV PROPFIND failed: HTTP \{base_status}")
  }
  let dir_segments = match
    ccs_webdav_remote_dir_segments_from_settings(settings, "current") {
    Ok(segs) => segs
    Err(error) => return Err(error)
  }
  for depth in 1..<=dir_segments.length() {
    let dir_url = match ccs_webdav_remote_dir_url(settings, "current", depth) {
      Ok(url) => url
      Err(error) => return Err(error)
    }
    let mkcol = match
      ccs_webdav_curl_status_request(settings, "MKCOL", dir_url) {
      Ok(request) => request
      Err(error) => return Err(error)
    }
    let status = match ccs_webdav_run_status_request(mkcol, "MKCOL") {
      Ok(status) => status
      Err(error) => return Err(error)
    }
    if ccs_webdav_status_ok_for_mkcol(status) {
      continue
    }
    if ccs_webdav_status_needs_propfind_verify(status) {
      let verify = ccs_webdav_curl_status_request(
        settings,
        "PROPFIND",
        dir_url,
        depth_zero=true,
      )
      let verify = match verify {
        Ok(request) => request
        Err(error) => return Err(error)
      }
      let verify_status = match
        ccs_webdav_run_status_request(verify, "PROPFIND") {
        Ok(status) => status
        Err(error) => return Err(error)
      }
      if ccs_webdav_status_ok_for_propfind(verify_status) {
        continue
      }
    }
    return Err("WebDAV MKCOL failed: HTTP \{status}")
  }
  Ok(
    {
      "success": Json::boolean(true),
      "message": Json::string("WebDAV connection ok"),
    }.to_json(),
  )
}

///|
async fn ccs_s3_sync_test_connection_json(
  settings : Json,
) -> Result[Json, String] {
  let bucket_url = match ccs_s3_bucket_url(settings) {
    Ok(url) => url
    Err(error) => return Err(error)
  }
  let request = match ccs_s3_curl_head_request(settings, bucket_url) {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let status = match ccs_s3_run_status_request(request, "HEAD bucket") {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if ccs_s3_status_ok(status) {
    Ok(
      {
        "success": Json::boolean(true),
        "message": Json::string("S3 connection ok"),
      }.to_json(),
    )
  } else {
    Err("S3 HEAD bucket failed: HTTP \{status}")
  }
}

///|
async fn Gateway::ccs_sync_build_local_snapshot(
  self : Gateway,
) -> CcsLocalSyncSnapshot {
  let db_sql = @encoding/utf8.encode(
    self.ccs_export_snapshot_json().stringify(indent=2) + "\n",
  )
  let skills_zip = @encoding/utf8.encode(
    ccs_skill_state_load().stringify(indent=2) + "\n",
  )
  let artifacts : Map[String, CcsSyncArtifactMeta] = {}
  artifacts[ccs_sync_remote_db_sql()] = ccs_sync_artifact_meta(db_sql)
  artifacts[ccs_sync_remote_skills_zip()] = ccs_sync_artifact_meta(skills_zip)
  let snapshot_id = ccs_sync_snapshot_id(artifacts)
  let manifest_bytes = @encoding/utf8.encode(
    ccs_sync_manifest_json(artifacts, snapshot_id).stringify(indent=2) + "\n",
  )
  CcsLocalSyncSnapshot::{
    db_sql,
    skills_zip,
    manifest_bytes,
    manifest_hash: ccs_sync_sha256_hex(manifest_bytes),
  }
}

///|
fn ccs_sync_success_status_json(manifest_hash : String) -> Json {
  ccs_sync_success_status_json_with_etag(manifest_hash, None)
}

///|
fn ccs_sync_success_status_json_with_etag(
  manifest_hash : String,
  etag : String?,
) -> Json {
  {
    "lastSyncAt": Json::number(@os.unix_seconds().to_double()),
    "lastError": Json::null(),
    "lastErrorSource": Json::null(),
    "lastLocalManifestHash": Json::string(manifest_hash),
    "lastRemoteManifestHash": Json::string(manifest_hash),
    "lastRemoteEtag": match etag {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  }.to_json()
}

///|
fn ccs_sync_settings_with_status(settings : Json, status : Json) -> Json {
  guard settings is Object(obj) else { return settings }
  obj["status"] = status
  Json::object(obj)
}

///|
fn Gateway::ccs_persist_webdav_sync_success(
  self : Gateway,
  settings : Json,
  manifest_hash : String,
) -> Unit {
  let next = ccs_sync_settings_with_status(
    settings,
    ccs_sync_success_status_json(manifest_hash),
  )
  self.app_settings = ccs_app_settings_with_sync(
    self.app_settings,
    "webdavSync",
    next,
  )
}

///|
fn Gateway::ccs_persist_s3_sync_success(
  self : Gateway,
  settings : Json,
  manifest_hash : String,
  etag : String?,
) -> Unit {
  let next = ccs_sync_settings_with_status(
    settings,
    ccs_sync_success_status_json_with_etag(manifest_hash, etag),
  )
  self.app_settings = ccs_app_settings_with_sync(
    self.app_settings,
    "s3Sync",
    next,
  )
}

///|
async fn ccs_webdav_put_file(
  settings : Json,
  url : String,
  file_path : String,
  content_type : String,
  artifact_name : String,
) -> Result[Unit, String] {
  let request = match
    ccs_webdav_curl_put_request(settings, url, file_path, content_type) {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let status = match ccs_webdav_run_status_request(request, "PUT") {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if ccs_webdav_status_ok_for_transfer(status) {
    Ok(())
  } else {
    Err("WebDAV PUT \{artifact_name} failed: HTTP \{status}")
  }
}

///|
async fn ccs_webdav_get_file(
  settings : Json,
  url : String,
  output_path : String,
  artifact_name : String,
) -> Result[Int, String] {
  let request = match ccs_webdav_curl_get_request(settings, url, output_path) {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let status = match ccs_webdav_run_status_request(request, "GET") {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if status == 404 || ccs_webdav_status_ok_for_transfer(status) {
    Ok(status)
  } else {
    Err("WebDAV GET \{artifact_name} failed: HTTP \{status}")
  }
}

///|
async fn ccs_s3_put_file(
  settings : Json,
  url : String,
  file_path : String,
  content_type : String,
  artifact_name : String,
) -> Result[Unit, String] {
  let request = match
    ccs_s3_curl_put_request(settings, url, file_path, content_type) {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let status = match ccs_s3_run_status_request(request, "PUT") {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if ccs_s3_status_ok(status) {
    Ok(())
  } else {
    Err("S3 PUT \{artifact_name} failed: HTTP \{status}")
  }
}

///|
async fn ccs_s3_get_file(
  settings : Json,
  url : String,
  output_path : String,
  artifact_name : String,
  header_path? : String,
) -> Result[Int, String] {
  let request = match
    ccs_s3_curl_get_request(settings, url, output_path, header_path?) {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let status = match ccs_s3_run_status_request(request, "GET") {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if status == 404 || ccs_s3_status_ok(status) {
    Ok(status)
  } else {
    Err("S3 GET \{artifact_name} failed: HTTP \{status}")
  }
}

///|
async fn ccs_s3_head_file_etag(
  settings : Json,
  url : String,
  header_path : String,
) -> Result[String?, String] {
  let request = match ccs_s3_curl_head_request(settings, url, header_path~) {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let status = match ccs_s3_run_status_request(request, "HEAD") {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if status == 404 {
    return Ok(None)
  }
  if !ccs_s3_status_ok(status) {
    return Err("S3 HEAD failed: HTTP \{status}")
  }
  Ok(ccs_s3_etag_from_headers(header_path))
}

///|
async fn ccs_s3_etag_from_headers(header_path : String) -> String? {
  let content = @fs.read_file(header_path).text() catch { _ => return None }
  ccs_s3_etag_from_header_text(content)
}

///|
fn ccs_s3_etag_from_header_text(content : String) -> String? {
  for line_view in content.split("\n") {
    let line = line_view.to_owned()
    if line.to_lower().has_prefix("etag:") {
      let parts = line.split(":").collect()
      if parts.length() >= 2 {
        let value = parts[1].trim().to_owned()
        if !value.is_empty() {
          return Some(value)
        }
      }
    }
  }
  None
}

///|
async fn Gateway::ccs_webdav_sync_upload_json(
  self : Gateway,
  settings : Json,
) -> Result[Json, String] {
  match ccs_webdav_sync_test_connection_json(settings) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let snapshot = self.ccs_sync_build_local_snapshot()
  match
    @fsx.with_temporary_directory("moonstat-webdav-upload-XXXXXX", async fn(
      tmp_dir,
    ) {
      let db_path = @pathx.join(tmp_dir, ccs_sync_remote_db_sql())
      let skills_path = @pathx.join(tmp_dir, ccs_sync_remote_skills_zip())
      let manifest_path = @pathx.join(tmp_dir, ccs_sync_remote_manifest())
      @fsx.write_bytes_to_file(db_path, snapshot.db_sql) catch {
        error => return Err("Failed to stage db.sql: \{error}")
      }
      @fsx.write_bytes_to_file(skills_path, snapshot.skills_zip) catch {
        error => return Err("Failed to stage skills.zip: \{error}")
      }
      @fsx.write_bytes_to_file(manifest_path, snapshot.manifest_bytes) catch {
        error => return Err("Failed to stage manifest.json: \{error}")
      }
      let db_url = match
        ccs_webdav_remote_file_url(
          settings,
          "current",
          ccs_sync_remote_db_sql(),
        ) {
        Ok(url) => url
        Err(error) => return Err(error)
      }
      match
        ccs_webdav_put_file(
          settings,
          db_url,
          db_path,
          "application/sql",
          ccs_sync_remote_db_sql(),
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let skills_url = match
        ccs_webdav_remote_file_url(
          settings,
          "current",
          ccs_sync_remote_skills_zip(),
        ) {
        Ok(url) => url
        Err(error) => return Err(error)
      }
      match
        ccs_webdav_put_file(
          settings,
          skills_url,
          skills_path,
          "application/zip",
          ccs_sync_remote_skills_zip(),
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let manifest_url = match
        ccs_webdav_remote_file_url(
          settings,
          "current",
          ccs_sync_remote_manifest(),
        ) {
        Ok(url) => url
        Err(error) => return Err(error)
      }
      match
        ccs_webdav_put_file(
          settings,
          manifest_url,
          manifest_path,
          "application/json",
          ccs_sync_remote_manifest(),
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      Ok(())
    }) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  self.ccs_persist_webdav_sync_success(settings, snapshot.manifest_hash)
  Ok({ "status": Json::string("uploaded") }.to_json())
}

///|
async fn Gateway::ccs_s3_sync_upload_json(
  self : Gateway,
  settings : Json,
) -> Result[Json, String] {
  match ccs_s3_sync_test_connection_json(settings) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let snapshot = self.ccs_sync_build_local_snapshot()
  let manifest_key = match
    ccs_s3_remote_file_key(settings, ccs_sync_remote_manifest()) {
    Ok(key) => key
    Err(error) => return Err(error)
  }
  let manifest_url = match ccs_s3_object_url(settings, manifest_key) {
    Ok(url) => url
    Err(error) => return Err(error)
  }
  let mut etag : String? = None
  match
    @fsx.with_temporary_directory("moonstat-s3-upload-XXXXXX", async fn(
      tmp_dir,
    ) {
      let db_path = @pathx.join(tmp_dir, ccs_sync_remote_db_sql())
      let skills_path = @pathx.join(tmp_dir, ccs_sync_remote_skills_zip())
      let manifest_path = @pathx.join(tmp_dir, ccs_sync_remote_manifest())
      @fsx.write_bytes_to_file(db_path, snapshot.db_sql) catch {
        error => return Err("Failed to stage db.sql: \{error}")
      }
      @fsx.write_bytes_to_file(skills_path, snapshot.skills_zip) catch {
        error => return Err("Failed to stage skills.zip: \{error}")
      }
      @fsx.write_bytes_to_file(manifest_path, snapshot.manifest_bytes) catch {
        error => return Err("Failed to stage manifest.json: \{error}")
      }
      let db_key = match
        ccs_s3_remote_file_key(settings, ccs_sync_remote_db_sql()) {
        Ok(key) => key
        Err(error) => return Err(error)
      }
      let db_url = match ccs_s3_object_url(settings, db_key) {
        Ok(url) => url
        Err(error) => return Err(error)
      }
      match
        ccs_s3_put_file(
          settings,
          db_url,
          db_path,
          "application/sql",
          ccs_sync_remote_db_sql(),
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let skills_key = match
        ccs_s3_remote_file_key(settings, ccs_sync_remote_skills_zip()) {
        Ok(key) => key
        Err(error) => return Err(error)
      }
      let skills_url = match ccs_s3_object_url(settings, skills_key) {
        Ok(url) => url
        Err(error) => return Err(error)
      }
      match
        ccs_s3_put_file(
          settings,
          skills_url,
          skills_path,
          "application/zip",
          ccs_sync_remote_skills_zip(),
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      match
        ccs_s3_put_file(
          settings,
          manifest_url,
          manifest_path,
          "application/json",
          ccs_sync_remote_manifest(),
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let header_path = @pathx.join(tmp_dir, "manifest.headers")
      etag = match ccs_s3_head_file_etag(settings, manifest_url, header_path) {
        Ok(value) => value
        Err(_) => None
      }
      Ok(())
    }) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  self.ccs_persist_s3_sync_success(settings, snapshot.manifest_hash, etag)
  Ok({ "status": Json::string("uploaded") }.to_json())
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
async fn ccs_s3_fetch_manifest_snapshot(
  settings : Json,
) -> Result[CcsS3RemoteSnapshot, String]? {
  let manifest_key = match
    ccs_s3_remote_file_key(settings, ccs_sync_remote_manifest()) {
    Ok(key) => key
    Err(error) => return Some(Err(error))
  }
  let manifest_url = match ccs_s3_object_url(settings, manifest_key) {
    Ok(url) => url
    Err(error) => return Some(Err(error))
  }
  match
    @fsx.with_temporary_directory("moonstat-s3-remote-info-XXXXXX", async fn(
      tmp_dir,
    ) {
      let manifest_path = @pathx.join(tmp_dir, ccs_sync_remote_manifest())
      let header_path = @pathx.join(tmp_dir, "manifest.headers")
      let status = match
        ccs_s3_get_file(
          settings,
          manifest_url,
          manifest_path,
          ccs_sync_remote_manifest(),
          header_path~,
        ) {
        Ok(status) => status
        Err(error) => return Err(error)
      }
      if status == 404 {
        return Ok(None)
      }
      let body = @fs.read_file(manifest_path).text() catch {
        error => return Err("Failed to read remote manifest: \{error}")
      }
      let manifest_json = @json.parse(body) catch {
        _ => return Err("Remote manifest is not valid JSON.")
      }
      let manifest = match ccs_sync_manifest_info_from_json(manifest_json) {
        Ok(manifest) => manifest
        Err(error) => return Err(error)
      }
      Ok(
        Some(CcsS3RemoteSnapshot::{
          manifest,
          manifest_bytes: @encoding/utf8.encode(body),
          etag: ccs_s3_etag_from_headers(header_path),
        }),
      )
    }) {
    Ok(Some(snapshot)) => Some(Ok(snapshot))
    Ok(None) => None
    Err(error) => Some(Err(error))
  }
}

///|
async fn ccs_s3_sync_fetch_remote_info_json(
  settings : Json,
) -> Result[Json, String] {
  match ccs_s3_fetch_manifest_snapshot(settings) {
    None => Ok({ "empty": Json::boolean(true) }.to_json())
    Some(Err(error)) => Err(error)
    Some(Ok(remote)) => {
      let remote_path = match ccs_s3_remote_dir_display(settings) {
        Ok(path) => path
        Err(error) => return Err(error)
      }
      let compatible = ccs_sync_validate_manifest_compat(
          remote.manifest,
          "current",
        )
        is Ok(_)
      let db_compat_version = match
        ccs_sync_effective_db_compat_version(remote.manifest, "current") {
        Some(value) => Json::number(value.to_double())
        None => Json::null()
      }
      Ok(
        {
          "deviceName": Json::string(remote.manifest.device_name),
          "createdAt": Json::string(remote.manifest.created_at),
          "snapshotId": Json::string(remote.manifest.snapshot_id),
          "version": Json::number(remote.manifest.version.to_double()),
          "protocolVersion": Json::number(remote.manifest.version.to_double()),
          "dbCompatVersion": db_compat_version,
          "compatible": Json::boolean(compatible),
          "artifacts": Json::array(remote.manifest.artifacts.map(Json::string)),
          "layout": Json::string("current"),
          "remotePath": Json::string(remote_path),
        }.to_json(),
      )
    }
  }
}

///|
async fn ccs_webdav_fetch_manifest_snapshot(
  settings : Json,
  layout : String,
) -> Result[CcsWebDavRemoteSnapshot, String]? {
  guard settings is Object(obj) else {
    return Some(Err("WebDAV sync is not configured."))
  }
  let username = json_string_from_map(obj, "username").unwrap_or("")
  let password = json_string_from_map(obj, "password").unwrap_or("")
  let manifest_url = match
    ccs_webdav_remote_file_url(settings, layout, ccs_sync_remote_manifest()) {
    Ok(url) => url
    Err(error) => return Some(Err(error))
  }
  let response = match ccs_webdav_get_text(manifest_url, username, password) {
    Ok(response) => response
    Err(error) => return Some(Err(error))
  }
  if response.code == 404 {
    return None
  }
  if !(response.code >= 200 && response.code <= 299) {
    return Some(Err("WebDAV GET failed: HTTP \{response.code}"))
  }
  let manifest_json = @json.parse(response.body) catch {
    _ => return Some(Err("Remote manifest is not valid JSON."))
  }
  let manifest = match ccs_sync_manifest_info_from_json(manifest_json) {
    Ok(manifest) => manifest
    Err(error) => return Some(Err(error))
  }
  Some(
    Ok(CcsWebDavRemoteSnapshot::{
      layout,
      manifest,
      manifest_bytes: @encoding/utf8.encode(response.body),
    }),
  )
}

///|
async fn ccs_webdav_find_remote_snapshot(
  settings : Json,
) -> Result[CcsWebDavRemoteSnapshot, String]? {
  match ccs_webdav_fetch_manifest_snapshot(settings, "current") {
    Some(Ok(snapshot)) => return Some(Ok(snapshot))
    Some(Err(error)) => return Some(Err(error))
    None => ()
  }
  match ccs_webdav_fetch_manifest_snapshot(settings, "legacy") {
    Some(Ok(snapshot)) => Some(Ok(snapshot))
    Some(Err(error)) => Some(Err(error))
    None => None
  }
}

///|
fn ccs_sync_validate_artifact(
  bytes : Bytes,
  artifact_name : String,
  manifest : CcsSyncManifestInfo,
) -> Result[Unit, String] {
  guard manifest.artifact_meta.get(artifact_name) is Some(meta) else {
    return Err("Manifest missing artifact: \{artifact_name}")
  }
  if bytes.length() != meta.size {
    return Err(
      "Artifact \{artifact_name} size mismatch (expected: \{meta.size}, got: \{bytes.length()})",
    )
  }
  let actual_hash = ccs_sync_sha256_hex(bytes)
  if actual_hash != meta.sha256 {
    return Err("Artifact \{artifact_name} SHA256 verification failed")
  }
  Ok(())
}

///|
async fn ccs_webdav_download_artifact(
  settings : Json,
  layout : String,
  artifact_name : String,
  output_path : String,
) -> Result[Bytes, String] {
  let url = match ccs_webdav_remote_file_url(settings, layout, artifact_name) {
    Ok(url) => url
    Err(error) => return Err(error)
  }
  let status = match
    ccs_webdav_get_file(settings, url, output_path, artifact_name) {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if status == 404 {
    return Err("Remote artifact file missing: \{artifact_name}")
  }
  let content = @fs.read_file(output_path).text() catch {
    error => return Err("Failed to read downloaded \{artifact_name}: \{error}")
  }
  Ok(@encoding/utf8.encode(content))
}

///|
async fn ccs_s3_download_artifact(
  settings : Json,
  artifact_name : String,
  output_path : String,
) -> Result[Bytes, String] {
  let key = match ccs_s3_remote_file_key(settings, artifact_name) {
    Ok(key) => key
    Err(error) => return Err(error)
  }
  let url = match ccs_s3_object_url(settings, key) {
    Ok(url) => url
    Err(error) => return Err(error)
  }
  let status = match
    ccs_s3_get_file(settings, url, output_path, artifact_name) {
    Ok(status) => status
    Err(error) => return Err(error)
  }
  if status == 404 {
    return Err("Remote artifact file missing: \{artifact_name}")
  }
  let content = @fs.read_file(output_path).text() catch {
    error => return Err("Failed to read downloaded \{artifact_name}: \{error}")
  }
  Ok(@encoding/utf8.encode(content))
}

///|
async fn Gateway::ccs_apply_webdav_snapshot(
  self : Gateway,
  db_sql : Bytes,
  skills_zip : Bytes,
) -> Result[Unit, String] {
  let db_text = @encoding/utf8.decode(db_sql) catch {
    _ => return Err("Downloaded db.sql is not valid UTF-8.")
  }
  let snapshot = @json.parse(db_text) catch {
    error =>
      return Err("Downloaded db.sql is not valid Moonstat JSON: \{error}")
  }
  let skills_text = @encoding/utf8.decode(skills_zip) catch {
    _ => return Err("Downloaded skills.zip is not valid UTF-8.")
  }
  let skills = @json.parse(skills_text) catch {
    error =>
      return Err("Downloaded skills.zip is not valid Moonstat JSON: \{error}")
  }
  ignore(ccs_skill_state_save(skills))
  self.ccs_apply_import_snapshot(snapshot)
  Ok(())
}

///|
async fn Gateway::ccs_webdav_sync_download_json(
  self : Gateway,
  settings : Json,
) -> Result[Json, String] {
  let remote = match ccs_webdav_find_remote_snapshot(settings) {
    Some(Ok(remote)) => remote
    Some(Err(error)) => return Err(error)
    None => return Err("No downloadable sync data found on the remote.")
  }
  match ccs_sync_validate_manifest_compat(remote.manifest, remote.layout) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let manifest_hash = ccs_sync_sha256_hex(remote.manifest_bytes)
  match
    @fsx.with_temporary_directory("moonstat-webdav-download-XXXXXX", async fn(
      tmp_dir,
    ) {
      let db_path = @pathx.join(tmp_dir, ccs_sync_remote_db_sql())
      let skills_path = @pathx.join(tmp_dir, ccs_sync_remote_skills_zip())
      let db_sql = match
        ccs_webdav_download_artifact(
          settings,
          remote.layout,
          ccs_sync_remote_db_sql(),
          db_path,
        ) {
        Ok(bytes) => bytes
        Err(error) => return Err(error)
      }
      match
        ccs_sync_validate_artifact(
          db_sql,
          ccs_sync_remote_db_sql(),
          remote.manifest,
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let skills_zip = match
        ccs_webdav_download_artifact(
          settings,
          remote.layout,
          ccs_sync_remote_skills_zip(),
          skills_path,
        ) {
        Ok(bytes) => bytes
        Err(error) => return Err(error)
      }
      match
        ccs_sync_validate_artifact(
          skills_zip,
          ccs_sync_remote_skills_zip(),
          remote.manifest,
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      self.ccs_apply_webdav_snapshot(db_sql, skills_zip)
    }) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  self.ccs_persist_webdav_sync_success(settings, manifest_hash)
  guard settings is Object(obj) else {
    return Ok({ "status": Json::string("downloaded") }.to_json())
  }
  let remote_root = json_string_from_map(obj, "remoteRoot").unwrap_or(
    ccs_sync_default_remote_root(),
  )
  let profile = json_string_from_map(obj, "profile").unwrap_or(
    ccs_sync_default_profile(),
  )
  Ok(
    {
      "status": Json::string("downloaded"),
      "sourceLayout": Json::string(remote.layout),
      "sourcePath": Json::string(
        ccs_sync_remote_dir_display(remote_root, profile, remote.layout),
      ),
    }.to_json(),
  )
}

///|
async fn Gateway::ccs_s3_sync_download_json(
  self : Gateway,
  settings : Json,
) -> Result[Json, String] {
  let remote = match ccs_s3_fetch_manifest_snapshot(settings) {
    Some(Ok(remote)) => remote
    Some(Err(error)) => return Err(error)
    None => return Err("No downloadable sync data found on the remote.")
  }
  match ccs_sync_validate_manifest_compat(remote.manifest, "current") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let manifest_hash = ccs_sync_sha256_hex(remote.manifest_bytes)
  match
    @fsx.with_temporary_directory("moonstat-s3-download-XXXXXX", async fn(
      tmp_dir,
    ) {
      let db_path = @pathx.join(tmp_dir, ccs_sync_remote_db_sql())
      let skills_path = @pathx.join(tmp_dir, ccs_sync_remote_skills_zip())
      let db_sql = match
        ccs_s3_download_artifact(settings, ccs_sync_remote_db_sql(), db_path) {
        Ok(bytes) => bytes
        Err(error) => return Err(error)
      }
      match
        ccs_sync_validate_artifact(
          db_sql,
          ccs_sync_remote_db_sql(),
          remote.manifest,
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let skills_zip = match
        ccs_s3_download_artifact(
          settings,
          ccs_sync_remote_skills_zip(),
          skills_path,
        ) {
        Ok(bytes) => bytes
        Err(error) => return Err(error)
      }
      match
        ccs_sync_validate_artifact(
          skills_zip,
          ccs_sync_remote_skills_zip(),
          remote.manifest,
        ) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      self.ccs_apply_webdav_snapshot(db_sql, skills_zip)
    }) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  self.ccs_persist_s3_sync_success(settings, manifest_hash, remote.etag)
  let remote_path = match ccs_s3_remote_dir_display(settings) {
    Ok(path) => path
    Err(_) => ""
  }
  Ok(
    {
      "status": Json::string("downloaded"),
      "sourceLayout": Json::string("current"),
      "sourcePath": Json::string(remote_path),
    }.to_json(),
  )
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
  let artifact_meta : Map[String, CcsSyncArtifactMeta] = {}
  for name in artifacts {
    guard artifact_map.get(name) is Some(Object(meta_obj)) else {
      return Err("Remote manifest artifact \{name} is not a JSON object.")
    }
    guard json_string_from_map(meta_obj, "sha256") is Some(sha256) else {
      return Err("Remote manifest artifact \{name} is missing sha256.")
    }
    guard proxy_json_int(meta_obj, "size") is Some(size) else {
      return Err("Remote manifest artifact \{name} is missing size.")
    }
    artifact_meta[name] = CcsSyncArtifactMeta::{ sha256, size }
  }
  Ok(CcsSyncManifestInfo::{
    format,
    version,
    db_compat_version: proxy_json_int(obj, "dbCompatVersion"),
    device_name,
    created_at,
    snapshot_id,
    artifacts,
    artifact_meta,
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
