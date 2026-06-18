///|
async fn ProxyService::handle_test_api_endpoints(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let timeout_secs = provider_endpoint_sanitize_timeout_secs(
    proxy_int_request(r.path, body, "timeoutSecs"),
  )
  let urls = provider_endpoint_urls_from_request(r.path, body)
  write_usage_json(
    w,
    provider_endpoint_latency_results_json(urls, timeout_secs),
  )
}

///|
async fn ProxyService::handle_get_custom_endpoints(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  write_usage_json(
    w,
    self.provider_router.custom_endpoints_json(app_type, provider_id),
  )
}

///|
async fn ProxyService::handle_add_custom_endpoint(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard provider_url_from_request(r.path, body) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  if !self.provider_router.add_custom_endpoint(app_type, provider_id, url) {
    write_usage_bad_request(w, "invalid_url")
    return
  }
  write_usage_json(w, Json::null())
}

///|
async fn ProxyService::handle_remove_custom_endpoint(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard provider_url_from_request(r.path, body) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  self.provider_router.remove_custom_endpoint(app_type, provider_id, url)
  write_usage_json(w, Json::null())
}

///|
async fn ProxyService::handle_update_endpoint_last_used(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard provider_url_from_request(r.path, body) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  self.provider_router.update_endpoint_last_used(app_type, provider_id, url)
  write_usage_json(w, Json::null())
}
