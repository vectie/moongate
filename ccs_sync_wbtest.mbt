///|
test "ccs webdav sync settings normalize and preserve password" {
  let existing = {
    "enabled": Json::boolean(true),
    "baseUrl": Json::string("https://dav.example.com"),
    "username": Json::string("alice"),
    "password": Json::string("secret"),
    "status": { "lastError": Json::string("previous") }.to_json(),
  }.to_json()
  let incoming = {
    "enabled": Json::boolean(true),
    "auto_sync": Json::boolean(true),
    "base_url": Json::string(" https://dav.example.com/root "),
    "username": Json::string(" alice "),
    "password": Json::string(""),
    "remote_root": Json::string(""),
    "profile": Json::string(""),
  }.to_json()
  guard ccs_webdav_sync_settings_json(incoming, Some(existing), true)
    is Object(obj) else {
    fail("expected webdav settings object")
  }
  assert_eq(
    json_string_from_map(obj, "baseUrl"),
    Some("https://dav.example.com/root"),
  )
  assert_eq(json_string_from_map(obj, "username"), Some("alice"))
  assert_eq(json_string_from_map(obj, "password"), Some("secret"))
  assert_eq(json_string_from_map(obj, "remoteRoot"), Some("cc-switch-sync"))
  assert_eq(json_string_from_map(obj, "profile"), Some("default"))
  guard obj.get("status") is Some(Object(status)) else {
    fail("expected preserved status")
  }
  assert_eq(json_string_from_map(status, "lastError"), Some("previous"))
  assert_eq(ccs_validate_webdav_sync_settings(Json::object(obj)), None)
}

///|
test "ccs webdav sync validation and guard messages match ccs" {
  assert_eq(
    ccs_validate_webdav_sync_settings(
      { "username": Json::string("alice") }.to_json(),
    ),
    Some("WebDAV URL is required."),
  )
  let settings = {
    "webdavSync": {
      "enabled": Json::boolean(false),
      "baseUrl": Json::string("https://dav.example.com"),
      "username": Json::string("alice"),
    }.to_json(),
  }.to_json()
  assert_eq(
    ccs_webdav_sync_required_error(settings),
    Some("WebDAV sync is disabled."),
  )
  assert_eq(
    ccs_webdav_sync_required_error(Json::object({})),
    Some("WebDAV sync is not configured."),
  )
}

///|
test "ccs s3 sync settings normalize and preserve secret" {
  let existing = {
    "secretAccessKey": Json::string("SECRET"),
    "status": { "lastRemoteEtag": Json::string("etag-1") }.to_json(),
  }.to_json()
  let incoming = {
    "enabled": Json::boolean(true),
    "autoSync": Json::boolean(true),
    "region": Json::string(" us-east-1 "),
    "bucket": Json::string(" moonstat "),
    "access_key_id": Json::string(" AKID "),
    "secret_access_key": Json::string(""),
    "endpoint": Json::string(" https://s3.example.com "),
    "remoteRoot": Json::string(""),
  }.to_json()
  guard ccs_s3_sync_settings_json(incoming, Some(existing), true) is Object(obj) else {
    fail("expected s3 settings object")
  }
  assert_eq(json_string_from_map(obj, "region"), Some("us-east-1"))
  assert_eq(json_string_from_map(obj, "bucket"), Some("moonstat"))
  assert_eq(json_string_from_map(obj, "accessKeyId"), Some("AKID"))
  assert_eq(json_string_from_map(obj, "secretAccessKey"), Some("SECRET"))
  assert_eq(
    json_string_from_map(obj, "endpoint"),
    Some("https://s3.example.com"),
  )
  assert_eq(json_string_from_map(obj, "remoteRoot"), Some("cc-switch-sync"))
  guard obj.get("status") is Some(Object(status)) else {
    fail("expected preserved status")
  }
  assert_eq(json_string_from_map(status, "lastRemoteEtag"), Some("etag-1"))
  assert_eq(ccs_validate_s3_sync_settings(Json::object(obj)), None)
}

///|
test "ccs s3 sync validation and guard messages match ccs" {
  assert_eq(
    ccs_validate_s3_sync_settings(
      { "region": Json::string("us-east-1") }.to_json(),
    ),
    Some("S3 bucket is required."),
  )
  assert_eq(
    ccs_validate_s3_sync_settings(
      {
        "bucket": Json::string("moonstat"),
        "region": Json::string("us-east-1"),
        "accessKeyId": Json::string("AKID"),
      }.to_json(),
    ),
    Some("S3 Secret Access Key is required."),
  )
  let settings = {
    "s3Sync": {
      "enabled": Json::boolean(false),
      "bucket": Json::string("moonstat"),
      "region": Json::string("us-east-1"),
      "accessKeyId": Json::string("AKID"),
      "secretAccessKey": Json::string("SECRET"),
    }.to_json(),
  }.to_json()
  assert_eq(ccs_s3_sync_required_error(settings), Some("S3 sync is disabled."))
  assert_eq(
    ccs_s3_sync_required_error(Json::object({})),
    Some("S3 sync is not configured."),
  )
}

///|
test "ccs sync protocol paths match ccs v2 current and legacy layouts" {
  assert_eq(
    ccs_sync_remote_dir_segments("cc-switch-sync", "default", "current"),
    ["cc-switch-sync", "v2", "db-v6", "default"],
  )
  assert_eq(
    ccs_sync_remote_dir_segments("/cc-switch-sync/", "/team/default/", "legacy"),
    ["cc-switch-sync", "v2", "team", "default"],
  )
  assert_eq(
    ccs_sync_remote_file_path(
      "cc-switch-sync",
      "default",
      "current",
      ccs_sync_remote_manifest(),
    ),
    "cc-switch-sync/v2/db-v6/default/manifest.json",
  )
  assert_eq(
    ccs_sync_remote_file_path(
      "cc-switch-sync",
      "default",
      "current",
      ccs_sync_remote_db_sql(),
    ),
    "cc-switch-sync/v2/db-v6/default/db.sql",
  )
  assert_eq(
    ccs_sync_remote_file_path(
      "cc-switch-sync",
      "default",
      "current",
      ccs_sync_remote_skills_zip(),
    ),
    "cc-switch-sync/v2/db-v6/default/skills.zip",
  )
}

///|
test "ccs webdav remote manifest url encodes path segments like ccs" {
  let settings = ccs_webdav_sync_settings_json(
    {
      "enabled": Json::boolean(true),
      "baseUrl": Json::string(
        "https://dav.example.com/remote.php/dav/files/demo/",
      ),
      "username": Json::string("alice"),
      "password": Json::string("secret"),
      "remoteRoot": Json::string("cc switch-sync"),
      "profile": Json::string("default profile"),
    }.to_json(),
    None,
    false,
  )
  assert_eq(
    ccs_webdav_remote_file_url(settings, "current", ccs_sync_remote_manifest()),
    Ok(
      "https://dav.example.com/remote.php/dav/files/demo/cc%20switch-sync/v2/db-v6/default%20profile/manifest.json",
    ),
  )
  assert_eq(
    ccs_webdav_remote_file_url(settings, "legacy", ccs_sync_remote_manifest()),
    Ok(
      "https://dav.example.com/remote.php/dav/files/demo/cc%20switch-sync/v2/default%20profile/manifest.json",
    ),
  )
  assert_eq(
    ccs_webdav_encode_path_segment("space #?汉"),
    "space%20%23%3F%E6%B1%89",
  )
}

///|
test "ccs webdav basic auth header matches rfc7617" {
  assert_eq(
    ccs_webdav_basic_auth_header("alice", "secret"),
    "Basic YWxpY2U6c2VjcmV0",
  )
}

///|
test "ccs sync manifest compatibility follows current and legacy db versions" {
  let manifest_json = {
    "format": Json::string(ccs_sync_protocol_format()),
    "version": Json::number(ccs_sync_protocol_version().to_double()),
    "dbCompatVersion": Json::number(ccs_sync_db_compat_version().to_double()),
    "deviceName": Json::string("My MacBook"),
    "createdAt": Json::string("2026-02-12T00:00:00Z"),
    "snapshotId": Json::string("snap-1"),
    "artifacts": {
      "skills.zip": { "sha256": Json::string("def"), "size": Json::number(2) }.to_json(),
      "db.sql": { "sha256": Json::string("abc"), "size": Json::number(1) }.to_json(),
    }.to_json(),
  }.to_json()
  let manifest = ccs_sync_manifest_info_from_json(manifest_json).unwrap()
  assert_eq(manifest.artifacts, ["db.sql", "skills.zip"])
  assert_true(ccs_sync_validate_manifest_compat(manifest, "current") is Ok(_))
  let legacy_manifest = ccs_sync_manifest_info_from_json(
    {
      "format": Json::string(ccs_sync_protocol_format()),
      "version": Json::number(ccs_sync_protocol_version().to_double()),
      "deviceName": Json::string("Old Mac"),
      "createdAt": Json::string("2026-02-12T00:00:00Z"),
      "snapshotId": Json::string("snap-legacy"),
      "artifacts": { "db.sql": Json::object({}) }.to_json(),
    }.to_json(),
  ).unwrap()
  assert_eq(
    ccs_sync_effective_db_compat_version(legacy_manifest, "legacy"),
    Some(ccs_sync_legacy_db_compat_version()),
  )
  assert_true(
    ccs_sync_validate_manifest_compat(legacy_manifest, "current") is Err(_),
  )
  let newer_manifest = ccs_sync_manifest_info_from_json(
    {
      "format": Json::string(ccs_sync_protocol_format()),
      "version": Json::number(ccs_sync_protocol_version().to_double()),
      "dbCompatVersion": Json::number(
        (ccs_sync_db_compat_version() + 1).to_double(),
      ),
      "deviceName": Json::string("Future Mac"),
      "createdAt": Json::string("2026-02-12T00:00:00Z"),
      "snapshotId": Json::string("snap-newer"),
      "artifacts": { "db.sql": Json::object({}) }.to_json(),
    }.to_json(),
  ).unwrap()
  assert_true(
    ccs_sync_validate_manifest_compat(newer_manifest, "legacy") is Err(_),
  )
}

///|
test "ccs webdav remote info maps manifest body" {
  let settings = ccs_webdav_sync_settings_json(
    {
      "enabled": Json::boolean(true),
      "baseUrl": Json::string("https://dav.example.com"),
      "username": Json::string("alice"),
      "password": Json::string("secret"),
      "remoteRoot": Json::string("cc-switch-sync"),
      "profile": Json::string("default"),
    }.to_json(),
    None,
    false,
  )
  let body =
    #|{
    #|  "format": "cc-switch-webdav-sync",
    #|  "version": 2,
    #|  "dbCompatVersion": 6,
    #|  "deviceName": "My MacBook",
    #|  "createdAt": "2026-02-12T00:00:00Z",
    #|  "snapshotId": "snap-1",
    #|  "artifacts": {
    #|    "skills.zip": {},
    #|    "db.sql": {}
    #|  }
    #|}
  guard ccs_webdav_remote_info_from_body(body, "current", settings)
    is Ok(Object(obj)) else {
    fail("expected webdav remote info object")
  }
  assert_eq(obj["deviceName"], Json::string("My MacBook"))
  assert_eq(obj["compatible"], Json::boolean(true))
  assert_eq(obj["layout"], Json::string("current"))
  assert_eq(obj["remotePath"], Json::string("/cc-switch-sync/v2/db-v6/default"))
  assert_eq(
    obj["artifacts"],
    Json::array([Json::string("db.sql"), Json::string("skills.zip")]),
  )
}

///|
test "ccs sync remote info response mirrors ccs fetch remote info shape" {
  let manifest = ccs_sync_manifest_info_from_json(
    {
      "format": Json::string(ccs_sync_protocol_format()),
      "version": Json::number(ccs_sync_protocol_version().to_double()),
      "dbCompatVersion": Json::number(ccs_sync_db_compat_version().to_double()),
      "deviceName": Json::string("My MacBook"),
      "createdAt": Json::string("2026-02-12T00:00:00Z"),
      "snapshotId": Json::string("snap-1"),
      "artifacts": {
        "skills.zip": Json::object({}),
        "db.sql": Json::object({}),
      }.to_json(),
    }.to_json(),
  ).unwrap()
  guard ccs_sync_remote_info_json(
      manifest, "current", "cc-switch-sync", "default",
    )
    is Object(obj) else {
    fail("expected remote info object")
  }
  assert_eq(obj["deviceName"], Json::string("My MacBook"))
  assert_eq(obj["snapshotId"], Json::string("snap-1"))
  assert_eq(obj["protocolVersion"], Json::number(2.0))
  assert_eq(obj["dbCompatVersion"], Json::number(6.0))
  assert_eq(obj["compatible"], Json::boolean(true))
  assert_eq(obj["layout"], Json::string("current"))
  assert_eq(obj["remotePath"], Json::string("/cc-switch-sync/v2/db-v6/default"))
  assert_eq(
    obj["artifacts"],
    Json::array([Json::string("db.sql"), Json::string("skills.zip")]),
  )
}
