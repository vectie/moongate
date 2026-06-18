///|
test "moonstat webdav sync settings normalize and preserve password" {
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
  guard moon_webdav_sync_settings_json(incoming, Some(existing), true)
    is Object(obj) else {
    fail("expected webdav settings object")
  }
  assert_eq(
    json_string_from_map(obj, "baseUrl"),
    Some("https://dav.example.com/root"),
  )
  assert_eq(json_string_from_map(obj, "username"), Some("alice"))
  assert_eq(json_string_from_map(obj, "password"), Some("secret"))
  assert_eq(json_string_from_map(obj, "remoteRoot"), Some("moonstat-sync"))
  assert_eq(json_string_from_map(obj, "profile"), Some("default"))
  guard obj.get("status") is Some(Object(status)) else {
    fail("expected preserved status")
  }
  assert_eq(json_string_from_map(status, "lastError"), Some("previous"))
  assert_eq(moon_validate_webdav_sync_settings(Json::object(obj)), None)
}

///|
test "moonstat webdav sync validation and guard messages match moonstat" {
  assert_eq(
    moon_validate_webdav_sync_settings(
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
    moon_webdav_sync_required_error(settings),
    Some("WebDAV sync is disabled."),
  )
  assert_eq(
    moon_webdav_sync_required_error(Json::object({})),
    Some("WebDAV sync is not configured."),
  )
}

///|
test "moonstat s3 sync settings normalize and preserve secret" {
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
  guard moon_s3_sync_settings_json(incoming, Some(existing), true)
    is Object(obj) else {
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
  assert_eq(json_string_from_map(obj, "remoteRoot"), Some("moonstat-sync"))
  guard obj.get("status") is Some(Object(status)) else {
    fail("expected preserved status")
  }
  assert_eq(json_string_from_map(status, "lastRemoteEtag"), Some("etag-1"))
  assert_eq(moon_validate_s3_sync_settings(Json::object(obj)), None)
}

///|
test "moonstat s3 sync validation and guard messages match moonstat" {
  assert_eq(
    moon_validate_s3_sync_settings(
      { "region": Json::string("us-east-1") }.to_json(),
    ),
    Some("S3 bucket is required."),
  )
  assert_eq(
    moon_validate_s3_sync_settings(
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
  assert_eq(moon_s3_sync_required_error(settings), Some("S3 sync is disabled."))
  assert_eq(
    moon_s3_sync_required_error(Json::object({})),
    Some("S3 sync is not configured."),
  )
}

///|
test "moonstat s3 object urls and keys match moonstat transport layout" {
  let aws = moon_s3_sync_settings_json(
    {
      "enabled": Json::boolean(true),
      "region": Json::string("us-west-2"),
      "bucket": Json::string("moonstat"),
      "accessKeyId": Json::string("AKID"),
      "secretAccessKey": Json::string("SECRET"),
      "remoteRoot": Json::string("moonstat-sync"),
      "profile": Json::string("default"),
    }.to_json(),
    None,
    false,
  )
  assert_eq(
    moon_s3_remote_file_key(aws, moon_sync_remote_manifest()),
    Ok("moonstat-sync/v2/db-v6/default/manifest.json"),
  )
  assert_eq(
    moon_s3_remote_dir_display(aws),
    Ok("moonstat-sync/v2/db-v6/default"),
  )
  assert_eq(
    moon_s3_bucket_url(aws),
    Ok("https://moonstat.s3.us-west-2.amazonaws.com/"),
  )
  assert_eq(
    moon_s3_object_url(aws, "moonstat-sync/v2/db-v6/default/manifest.json"),
    Ok(
      "https://moonstat.s3.us-west-2.amazonaws.com/moonstat-sync/v2/db-v6/default/manifest.json",
    ),
  )
  let custom = moon_s3_sync_settings_json(
    {
      "enabled": Json::boolean(true),
      "region": Json::string("us-east-1"),
      "bucket": Json::string("moonstat"),
      "accessKeyId": Json::string("AKID"),
      "secretAccessKey": Json::string("SECRET"),
      "endpoint": Json::string("http://minio.local:9000/"),
      "remoteRoot": Json::string("cc switch"),
      "profile": Json::string("team/default"),
    }.to_json(),
    None,
    false,
  )
  assert_eq(
    moon_s3_object_url(custom, "cc switch/v2/db-v6/team/default/db.sql"),
    Ok(
      "http://minio.local:9000/moonstat/cc%20switch/v2/db-v6/team/default/db.sql",
    ),
  )
}

///|
test "moonstat s3 curl requests use sigv4 and moonstat transfer timeouts" {
  let settings = moon_s3_sync_settings_json(
    {
      "enabled": Json::boolean(true),
      "region": Json::string("us-east-1"),
      "bucket": Json::string("moonstat"),
      "accessKeyId": Json::string("AKID"),
      "secretAccessKey": Json::string("SECRET"),
    }.to_json(),
    None,
    false,
  )
  let head = moon_s3_curl_head_request(
    settings, "https://moonstat.s3.us-east-1.amazonaws.com/",
  ).unwrap()
  assert_eq(head.program, "curl")
  assert_eq(head.args, [
    "-sS", "-L", "--aws-sigv4", "aws:amz:us-east-1:s3", "-u", "AKID:SECRET", "--max-time",
    "30", "-I", "-o", "/dev/null", "-w", "%{http_code}", "https://moonstat.s3.us-east-1.amazonaws.com/",
  ])
  let put = moon_s3_curl_put_request(
    settings, "https://moonstat.s3.us-east-1.amazonaws.com/moonstat-sync/v2/db-v6/default/manifest.json",
    "/tmp/manifest.json", "application/json",
  ).unwrap()
  assert_eq(put.args, [
    "-sS", "-L", "--aws-sigv4", "aws:amz:us-east-1:s3", "-u", "AKID:SECRET", "--max-time",
    "300", "-X", "PUT", "-H", "Content-Type: application/json", "--upload-file",
    "/tmp/manifest.json", "-o", "/dev/null", "-w", "%{http_code}", "https://moonstat.s3.us-east-1.amazonaws.com/moonstat-sync/v2/db-v6/default/manifest.json",
  ])
  let get = moon_s3_curl_get_request(
    settings,
    "https://moonstat.s3.us-east-1.amazonaws.com/moonstat-sync/v2/db-v6/default/manifest.json",
    "/tmp/manifest.json",
    header_path="/tmp/headers",
  ).unwrap()
  assert_eq(get.args, [
    "-sS", "-L", "--aws-sigv4", "aws:amz:us-east-1:s3", "-u", "AKID:SECRET", "--max-time",
    "300", "-o", "/tmp/manifest.json", "-w", "%{http_code}", "-D", "/tmp/headers",
    "https://moonstat.s3.us-east-1.amazonaws.com/moonstat-sync/v2/db-v6/default/manifest.json",
  ])
}

///|
test "moonstat s3 status and etag parsing match s3 transport behavior" {
  assert_true(moon_s3_status_ok(200))
  assert_true(moon_s3_status_ok(204))
  assert_true(!moon_s3_status_ok(404))
  assert_eq(
    moon_s3_etag_from_header_text(
      (
        #|HTTP/1.1 200 OK
        #|content-type: application/json
        #|ETag: "abc123"
        #|
      ),
    ),
    Some("\"abc123\""),
  )
  assert_eq(moon_s3_etag_from_header_text("HTTP/1.1 404 Not Found\n"), None)
}

///|
test "moonstat sync protocol paths match moonstat v2 current and legacy layouts" {
  assert_eq(
    moon_sync_remote_dir_segments("moonstat-sync", "default", "current"),
    ["moonstat-sync", "v2", "db-v6", "default"],
  )
  assert_eq(
    moon_sync_remote_dir_segments("/moonstat-sync/", "/team/default/", "legacy"),
    ["moonstat-sync", "v2", "team", "default"],
  )
  assert_eq(
    moon_sync_remote_file_path(
      "moonstat-sync",
      "default",
      "current",
      moon_sync_remote_manifest(),
    ),
    "moonstat-sync/v2/db-v6/default/manifest.json",
  )
  assert_eq(
    moon_sync_remote_file_path(
      "moonstat-sync",
      "default",
      "current",
      moon_sync_remote_db_sql(),
    ),
    "moonstat-sync/v2/db-v6/default/db.sql",
  )
  assert_eq(
    moon_sync_remote_file_path(
      "moonstat-sync",
      "default",
      "current",
      moon_sync_remote_skills_zip(),
    ),
    "moonstat-sync/v2/db-v6/default/skills.zip",
  )
}

///|
test "moonstat webdav remote manifest url encodes path segments like moonstat" {
  let settings = moon_webdav_sync_settings_json(
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
    moon_webdav_remote_file_url(
      settings,
      "current",
      moon_sync_remote_manifest(),
    ),
    Ok(
      "https://dav.example.com/remote.php/dav/files/demo/cc%20switch-sync/v2/db-v6/default%20profile/manifest.json",
    ),
  )
  assert_eq(
    moon_webdav_remote_file_url(settings, "legacy", moon_sync_remote_manifest()),
    Ok(
      "https://dav.example.com/remote.php/dav/files/demo/cc%20switch-sync/v2/default%20profile/manifest.json",
    ),
  )
  assert_eq(
    moon_webdav_encode_path_segment("space #?汉"),
    "space%20%23%3F%E6%B1%89",
  )
}

///|
test "moonstat webdav basic auth header matches rfc7617" {
  assert_eq(
    moon_webdav_basic_auth_header("alice", "secret"),
    "Basic YWxpY2U6c2VjcmV0",
  )
}

///|
test "moonstat webdav connection command matches moonstat methods" {
  let settings = moon_webdav_sync_settings_json(
    {
      "enabled": Json::boolean(true),
      "baseUrl": Json::string("https://dav.example.com/root/"),
      "username": Json::string("alice"),
      "password": Json::string("secret"),
      "remoteRoot": Json::string("moonstat-sync"),
      "profile": Json::string("default"),
    }.to_json(),
    None,
    false,
  )
  assert_eq(
    moon_webdav_remote_dir_url(settings, "current", 2),
    Ok("https://dav.example.com/root/moonstat-sync/v2/"),
  )
  let request = moon_webdav_curl_status_request(
    settings,
    "PROPFIND",
    "https://dav.example.com/root",
    depth_zero=true,
  ).unwrap()
  assert_eq(request.program, "curl")
  assert_eq(request.args, [
    "-sS", "-L", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "30", "-X",
    "PROPFIND", "-H", "Depth: 0", "-u", "alice:secret", "https://dav.example.com/root",
  ])
  let put = moon_webdav_curl_put_request(
    settings, "https://dav.example.com/root/db.sql", "/tmp/db.sql", "application/sql",
  ).unwrap()
  assert_eq(put.args, [
    "-sS", "-L", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "300", "-X",
    "PUT", "-H", "Content-Type: application/sql", "--upload-file", "/tmp/db.sql",
    "-u", "alice:secret", "https://dav.example.com/root/db.sql",
  ])
  let get = moon_webdav_curl_get_request(
    settings, "https://dav.example.com/root/db.sql", "/tmp/out.sql",
  ).unwrap()
  assert_eq(get.args, [
    "-sS", "-L", "-o", "/tmp/out.sql", "-w", "%{http_code}", "--max-time", "300",
    "-u", "alice:secret", "https://dav.example.com/root/db.sql",
  ])
}

///|
test "moonstat webdav status classes match moonstat connection behavior" {
  assert_true(moon_webdav_status_ok_for_propfind(207))
  assert_true(moon_webdav_status_ok_for_propfind(204))
  assert_true(moon_webdav_status_ok_for_mkcol(201))
  assert_true(moon_webdav_status_needs_propfind_verify(405))
  assert_true(moon_webdav_status_needs_propfind_verify(409))
  assert_true(moon_webdav_status_needs_propfind_verify(302))
  assert_true(!moon_webdav_status_needs_propfind_verify(500))
  assert_true(moon_webdav_status_ok_for_transfer(200))
  assert_true(moon_webdav_status_ok_for_transfer(201))
  assert_true(!moon_webdav_status_ok_for_transfer(404))
}

///|
test "moonstat sync sha256 and snapshot id match sync protocol" {
  assert_eq(
    moon_sync_sha256_hex(@encoding/utf8.encode("hello")),
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  )
  let artifacts : Map[String, MoonSyncArtifactMeta] = {}
  artifacts["skills.zip"] = { sha256: "def", size: 2 }
  artifacts["db.sql"] = { sha256: "abc", size: 1 }
  assert_eq(
    moon_sync_snapshot_id(artifacts),
    moon_sync_sha256_hex(@encoding/utf8.encode("db.sql:abc|skills.zip:def")),
  )
}

///|
test "moonstat sync manifest compatibility follows current and legacy db versions" {
  let manifest_json = {
    "format": Json::string(moon_sync_protocol_format()),
    "version": Json::number(moon_sync_protocol_version().to_double()),
    "dbCompatVersion": Json::number(moon_sync_db_compat_version().to_double()),
    "deviceName": Json::string("My MacBook"),
    "createdAt": Json::string("2026-02-12T00:00:00Z"),
    "snapshotId": Json::string("snap-1"),
    "artifacts": {
      "skills.zip": { "sha256": Json::string("def"), "size": Json::number(2) }.to_json(),
      "db.sql": { "sha256": Json::string("abc"), "size": Json::number(1) }.to_json(),
    }.to_json(),
  }.to_json()
  let manifest = moon_sync_manifest_info_from_json(manifest_json).unwrap()
  assert_eq(manifest.artifacts, ["db.sql", "skills.zip"])
  assert_true(moon_sync_validate_manifest_compat(manifest, "current") is Ok(_))
  let legacy_manifest = moon_sync_manifest_info_from_json(
    {
      "format": Json::string(moon_sync_protocol_format()),
      "version": Json::number(moon_sync_protocol_version().to_double()),
      "deviceName": Json::string("Old Mac"),
      "createdAt": Json::string("2026-02-12T00:00:00Z"),
      "snapshotId": Json::string("snap-legacy"),
      "artifacts": {
        "db.sql": { "sha256": Json::string("abc"), "size": Json::number(1) }.to_json(),
      }.to_json(),
    }.to_json(),
  ).unwrap()
  assert_eq(
    moon_sync_effective_db_compat_version(legacy_manifest, "legacy"),
    Some(moon_sync_legacy_db_compat_version()),
  )
  assert_true(
    moon_sync_validate_manifest_compat(legacy_manifest, "current") is Err(_),
  )
  let newer_manifest = moon_sync_manifest_info_from_json(
    {
      "format": Json::string(moon_sync_protocol_format()),
      "version": Json::number(moon_sync_protocol_version().to_double()),
      "dbCompatVersion": Json::number(
        (moon_sync_db_compat_version() + 1).to_double(),
      ),
      "deviceName": Json::string("Future Mac"),
      "createdAt": Json::string("2026-02-12T00:00:00Z"),
      "snapshotId": Json::string("snap-newer"),
      "artifacts": {
        "db.sql": { "sha256": Json::string("abc"), "size": Json::number(1) }.to_json(),
      }.to_json(),
    }.to_json(),
  ).unwrap()
  assert_true(
    moon_sync_validate_manifest_compat(newer_manifest, "legacy") is Err(_),
  )
}

///|
test "moonstat webdav remote info maps manifest body" {
  let settings = moon_webdav_sync_settings_json(
    {
      "enabled": Json::boolean(true),
      "baseUrl": Json::string("https://dav.example.com"),
      "username": Json::string("alice"),
      "password": Json::string("secret"),
      "remoteRoot": Json::string("moonstat-sync"),
      "profile": Json::string("default"),
    }.to_json(),
    None,
    false,
  )
  let body =
    #|{
    #|  "format": "moonstat-webdav-sync",
    #|  "version": 2,
    #|  "dbCompatVersion": 6,
    #|  "deviceName": "My MacBook",
    #|  "createdAt": "2026-02-12T00:00:00Z",
    #|  "snapshotId": "snap-1",
    #|  "artifacts": {
    #|    "skills.zip": { "sha256": "def", "size": 2 },
    #|    "db.sql": { "sha256": "abc", "size": 1 }
    #|  }
    #|}
  guard moon_webdav_remote_info_from_body(body, "current", settings)
    is Ok(Object(obj)) else {
    fail("expected webdav remote info object")
  }
  assert_eq(obj["deviceName"], Json::string("My MacBook"))
  assert_eq(obj["compatible"], Json::boolean(true))
  assert_eq(obj["layout"], Json::string("current"))
  assert_eq(obj["remotePath"], Json::string("/moonstat-sync/v2/db-v6/default"))
  assert_eq(
    obj["artifacts"],
    Json::array([Json::string("db.sql"), Json::string("skills.zip")]),
  )
}

///|
test "moonstat sync remote info response mirrors moonstat fetch remote info shape" {
  let manifest = moon_sync_manifest_info_from_json(
    {
      "format": Json::string(moon_sync_protocol_format()),
      "version": Json::number(moon_sync_protocol_version().to_double()),
      "dbCompatVersion": Json::number(moon_sync_db_compat_version().to_double()),
      "deviceName": Json::string("My MacBook"),
      "createdAt": Json::string("2026-02-12T00:00:00Z"),
      "snapshotId": Json::string("snap-1"),
      "artifacts": {
        "skills.zip": { "sha256": Json::string("def"), "size": Json::number(2) }.to_json(),
        "db.sql": { "sha256": Json::string("abc"), "size": Json::number(1) }.to_json(),
      }.to_json(),
    }.to_json(),
  ).unwrap()
  guard moon_sync_remote_info_json(
      manifest, "current", "moonstat-sync", "default",
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
  assert_eq(obj["remotePath"], Json::string("/moonstat-sync/v2/db-v6/default"))
  assert_eq(
    obj["artifacts"],
    Json::array([Json::string("db.sql"), Json::string("skills.zip")]),
  )
}
