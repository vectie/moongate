///|
// Catalog discovery is an operator read. It never changes provider health,
// selects a route, binds an app, or sends a completion request.
async fn ProxyService::handle_saved_provider_models(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Cache-Control", "no-store")
  guard provider_app_from_request(r.path, None) is Some(app_type) else {
    write_usage_bad_request(w, "Choose a saved provider request type.")
    return
  }
  guard provider_route_provider_id_from_request(r.path, None)
    is Some(provider_id) else {
    write_usage_bad_request(
      w, "Choose a saved provider before refreshing models.",
    )
    return
  }
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    write_usage_bad_request(
      w, "Saved provider not found. Refresh the provider list.",
    )
    return
  }
  match saved_provider_models(provider) {
    Ok(models) =>
      write_usage_json(w, {
        "appType": app_type,
        "providerId": provider_id,
        "models": fetched_models_to_json(models),
        "source": "provider_catalog",
        "inferencePerformed": false,
      })
    Err(message) => write_usage_bad_request(w, message)
  }
}

///|
async fn saved_provider_models(
  provider : ProviderRouteTarget,
) -> Result[Array[FetchedModel], String] {
  if provider.is_builtin_route() ||
    provider.provider_type == Some("codex_oauth") ||
    provider.provider_type == Some("github_copilot") ||
    provider.provider_type == Some("gemini_cli") ||
    stream_check_api_format(provider) == "gemini_native" {
    return Err(
      "Model discovery supports saved OpenAI-compatible and Anthropic API-key providers. Enter the model ID manually for this provider.",
    )
  }
  guard provider.base_url is Some(base_url) && !base_url.trim().is_empty() else {
    return Err("Save a provider Base URL before refreshing models.")
  }
  guard provider.api_key is Some(api_key) && !api_key.trim().is_empty() else {
    return Err(
      "This saved provider has no API key. Save its credential before refreshing models.",
    )
  }
  let candidates = match
    build_models_url_candidates(base_url, provider.is_full_url, None) {
    Ok(urls) => urls
    Err(_) =>
      return Err(
        "Cannot derive a model catalog from the saved Base URL. Check the provider address or enter a model ID manually.",
      )
  }
  let result = @async.with_timeout(10_000, () => {
    for url in candidates {
      let target = match models_url_target(url) {
        Ok(target) => target
        Err(_) =>
          return Err(
            "The saved model catalog URL is invalid. Check the provider address.",
          )
      }
      let headers = claude_compatible_provider_headers(
        api_key,
        stream_check_api_format(provider),
        custom_user_agent=provider_custom_user_agent(provider),
        provider_type=provider.provider_type,
      )
      let client = @http.Client::Client(target.origin, headers~)
      defer client.close()
      let response = client.get(target.path)
      if response.code == 404 || response.code == 405 {
        continue
      }
      if response.code < 200 || response.code >= 300 {
        // Upstream error bodies can echo credentials. Do not return them.
        return Err(
          "Model catalog returned HTTP \{response.code}. Check the saved provider credential and address, then refresh again.",
        )
      }
      let bytes : Array[Byte] = []
      for ;; {
        match client.read_some(max_len=8192) {
          None => break
          Some(chunk) => {
            if bytes.length() + chunk.length() > 1_048_576 {
              return Err(
                "Model catalog is too large. Enter the model ID manually.",
              )
            }
            for byte in chunk {
              bytes.push(byte)
            }
          }
        }
      }
      let body = @encoding/utf8.decode(Bytes::from_array(bytes)) catch {
        _ =>
          return Err(
            "Model catalog is not valid UTF-8. Enter a model ID manually or repair the provider response.",
          )
      }
      return saved_provider_models_from_body(body, api_key)
    }
    Err(
      "This provider has no supported model catalog endpoint. Enter the model ID manually.",
    )
  }) catch {
    _ =>
      return Err(
        "Could not refresh models within 10 seconds. Check the saved provider connection and try again.",
      )
  }
  result
}

///|
fn saved_provider_models_from_body(
  body : String,
  api_key : String,
) -> Result[Array[FetchedModel], String] {
  let value = @json.parse(body) catch {
    _ =>
      return Err(
        "Model catalog returned invalid JSON. Try again or enter a model ID manually.",
      )
  }
  guard value is Object(fields) && fields.get("data") is Some(Array(_)) else {
    return Err(
      "Model catalog has no supported model list. Enter the model ID manually.",
    )
  }
  let models = match parse_models_response(value) {
    Ok(models) => models
    Err(_) =>
      return Err(
        "Model catalog contains an invalid model entry. Enter the model ID manually.",
      )
  }
  if models.length() > 2000 {
    return Err(
      "Model catalog has more than 2000 entries. Enter the model ID manually.",
    )
  }
  let unique : Array[FetchedModel] = []
  let seen : Map[String, Bool] = Map([])
  for model in models {
    if !saved_catalog_model_id_valid(model.id) ||
      (!api_key.is_empty() && model.id.contains(api_key)) {
      return Err(
        "Model catalog contains an invalid model ID. Enter the model ID manually.",
      )
    }
    if !seen.contains(model.id) {
      seen[model.id] = true
      // IDs are the only catalog field the picker needs. Discard arbitrary
      // upstream metadata instead of passing it through the host boundary.
      unique.push({ id: model.id, owned_by: None, })
    }
  }
  Ok(unique)
}

///|
fn saved_catalog_model_id_valid(id : String) -> Bool {
  if id.is_empty() || id.length() > 256 || id != id.trim().to_owned() {
    return false
  }
  for ch in id {
    if ch.to_int() <= 32 ||
      ch.to_int() == 127 ||
      ch.is_whitespace() ||
      ch == '\u{FEFF}' {
      return false
    }
  }
  true
}
