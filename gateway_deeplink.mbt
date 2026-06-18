///|
async fn Gateway::handle_parse_deeplink(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["url"]) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  match moon_parse_deeplink_url_json(url) {
    Some(request) => write_usage_json(w, request)
    None => write_usage_bad_request(w, "invalid_deeplink")
  }
}

///|
async fn Gateway::handle_import_from_deeplink(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  legacy~ : Bool,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_deeplink_request_payload(r.path, body) is Some(request) else {
    write_usage_bad_request(w, "invalid_deeplink")
    return
  }
  match self.moon_import_from_deeplink_json(request) {
    Some(Object(obj)) =>
      if legacy {
        match obj.get("id") {
          Some(String(id)) => write_usage_json(w, Json::string(id))
          _ => write_usage_bad_request(w, "invalid_deeplink_import")
        }
      } else {
        write_usage_json(w, Json::object(obj))
      }
    Some(result) =>
      if legacy {
        write_usage_bad_request(w, "invalid_deeplink_import")
      } else {
        write_usage_json(w, result)
      }
    None => write_usage_bad_request(w, "invalid_deeplink_import")
  }
}
