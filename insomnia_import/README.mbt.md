# Offline Insomnia v4 conversion

`import_collection` returns a derived JSON receipt with editable HTTP text,
resource IDs, inventory and omissions. Retain the original export separately.
No network, scripts, template expansion or referenced-file reads are performed.

```mbt check
///|
test "prepare a literal saved workspace" {
  let result = @insomnia_import.import_collection(
    "{\"__export_format\":4,\"resources\":[{\"_id\":\"wrk_one\",\"_type\":\"workspace\",\"name\":\"Example\",\"parentId\":null},{\"_id\":\"req_one\",\"_type\":\"request\",\"parentId\":\"wrk_one\",\"name\":\"Models\",\"method\":\"GET\",\"url\":\"https://example.invalid/models\"}]}",
    request_id="req_one",
  )
  assert_true(
    result is Object(fields) &&
    fields.get("selectedRequests") == Some(Json::number(1)),
  )
}
```

See the repository's `docs/INSOMNIA_IMPORT.md` for the supported subset and CLI.
