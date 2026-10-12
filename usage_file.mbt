///|
/// Stateless usage-file preview; see the dependency-light usage_preview package.
pub fn moongate_preview_usage_file_json(
  content : String,
  source_name? : String = "Pasted usage",
  app? : String = "",
  provider? : String = "",
  model? : String = "",
  start_day? : String = "",
  end_day? : String = "",
) -> Result[Json, String] {
  @usage_preview.moongate_preview_usage_file_json(
    content, source_name~, app~, provider~, model~, start_day~, end_day~,
  )
}

///|
async fn handle_usage_file_preview(
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard proxy_json_body(r) is Some(Object(obj)) &&
    obj.get("content") is Some(String(content)) else {
    write_usage_bad_request(w, "Missing usage file content")
    return
  }
  let field = key => json_string_from_map(obj, key).unwrap_or("")
  match
    moongate_preview_usage_file_json(
      content,
      source_name=field("sourceName"),
      app=field("app"),
      provider=field("provider"),
      model=field("model"),
      start_day=field("startDay"),
      end_day=field("endDay"),
    ) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}
