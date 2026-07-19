///|
test "legacy migration protects likely credential files" {
  assert_eq(migration_file_permission("auth/token.json"), 0o600)
  assert_eq(migration_file_permission("credentials/provider.json"), 0o600)
  assert_eq(migration_file_permission("sessions/run/receipt.json"), 0o644)
}

///|
test "legacy migration receipt exposes its narrow compatibility boundary" {
  let state = legacy_state_migration()
  state.copied = 2
  state.identical = 1
  let receipt = legacy_state_migration_receipt(
    "trial", "/workspace/.moonsuite/products/moonstat", "/workspace/.moonsuite/products/moongate",
    true, state,
  )
  let encoded = receipt.stringify()
  assert_true(encoded.contains("\"accepted\":true"))
  assert_true(encoded.contains("\"legacy_product_id\":\"moonstat\""))
  assert_true(encoded.contains("\"product_id\":\"moongate\""))
  assert_true(encoded.contains("\"copied_files\":2"))
}
