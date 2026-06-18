///|
test "ccs backup filenames are filesystem safe" {
  assert_eq(moon_backup_filename("nested/name:one"), "nested-name-one.db")
  assert_eq(moon_backup_filename("ready.db"), "ready.db")
  assert_eq(moon_backup_filename("snapshot.json"), "snapshot.json")
}

///|
test "ccs database backup filenames reject invalid restore targets" {
  assert_true(moon_valid_db_backup_filename("db_backup_20260614_010203.db"))
  assert_false(moon_valid_db_backup_filename("nested/name.db"))
  assert_false(moon_valid_db_backup_filename("nested\\name.db"))
  assert_false(moon_valid_db_backup_filename("../escape.db"))
  assert_false(moon_valid_db_backup_filename("snapshot.json"))
  assert_eq(
    moon_db_backup_filename_error("../escape.db"),
    Some("Invalid backup filename"),
  )
  assert_eq(moon_db_backup_filename_error("safe.db"), None)
}

///|
test "ccs database backup rename normalizes new name like desktop" {
  assert_eq(moon_db_backup_new_filename("renamed"), Ok("renamed.db"))
  assert_eq(moon_db_backup_new_filename("renamed.db"), Ok("renamed.db"))
  assert_eq(moon_db_backup_new_filename("  "), Err("New name cannot be empty"))
  assert_eq(
    moon_db_backup_new_filename("../escape"),
    Err("Invalid characters in new name"),
  )
  assert_eq(
    moon_db_backup_new_filename("nested/name"),
    Err("Invalid characters in new name"),
  )
}

///|
test "ccs database backup entries sort newest first" {
  let rows = [
    MoonDbBackupEntry::{ filename: "old.db", size_bytes: 1, created_at: 1L },
    { filename: "new.db", size_bytes: 2, created_at: 3L },
    { filename: "mid.db", size_bytes: 3, created_at: 2L },
  ]
  moon_sort_db_backup_entries(rows)
  assert_eq(rows[0].filename, "new.db")
  assert_eq(rows[1].filename, "mid.db")
  assert_eq(rows[2].filename, "old.db")
}

///|
test "ccs import proxy ints accept camel and snake case keys" {
  guard Json::object({ "listenPort": Json::number(123.0) }) is Object(camel) else {
    fail("expected object")
  }
  guard Json::object({ "listen_port": Json::number(456.0) }) is Object(snake) else {
    fail("expected object")
  }
  assert_eq(moon_json_int_from_map_any(camel, ["listenPort"]), Some(123))
  assert_eq(
    moon_json_int_from_map_any(snake, ["listenPort", "listen_port"]),
    Some(456),
  )
  assert_eq(moon_json_int_from_map_any(camel, ["missing"]), None)
}
