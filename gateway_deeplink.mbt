///|
async fn ConfigService::handle_parse_deeplink(
  self : ConfigService,
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
async fn ConfigService::handle_import_from_deeplink(
  self : ConfigService,
  proxy : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_deeplink_request_payload(r.path, body) is Some(request) else {
    write_usage_bad_request(w, "invalid_deeplink")
    return
  }
  match self.moon_import_from_deeplink_json(proxy, request) {
    Some(result) => write_usage_json(w, result)
    None => write_usage_bad_request(w, "invalid_deeplink_import")
  }
}
