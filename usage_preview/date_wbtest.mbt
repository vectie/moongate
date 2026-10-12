///|
test "existing usage day normalization" {
  assert_eq(usage_file_day("2026-10-07T01:30:00+08:00"), "2026-10-06")
  assert_eq(usage_file_day("2026-10-07T23:00:00Z"), "2026-10-07")
  assert_eq(usage_file_day("2026-10-07T23:00:00"), "")
}
