///|
priv struct ProviderConnectionCandidate {
  target : ModelsUrlTarget
  api_key : String
  model : String
}

///|
// Match the existing reviewed connection-import URL policy: HTTPS providers,
// or HTTP for exact loopback hosts. A base path is retained and normalized.
fn provider_connection_candidate_target(base_url : String) -> ModelsUrlTarget? {
  if base_url.is_empty() ||
    base_url.length() > 2048 ||
    base_url.trim() != base_url ||
    base_url.contains_char('@') ||
    base_url.contains_char('?') ||
    base_url.contains_char('#') ||
    base_url.contains_char('\\') ||
    base_url.any(c => c <= ' ' || c > '\u{7f}') ||
    base_url.has_suffix("/chat/completions") {
    return None
  }
  let scheme = if base_url.has_prefix("https://") {
    "https://"
  } else if base_url.has_prefix("http://") {
    "http://"
  } else {
    return None
  }
  let rest = base_url[scheme.length():]
  let boundary = rest.find("/").unwrap_or(rest.length())
  let authority = rest[:boundary].to_owned()
  if authority.is_empty() ||
    !authority.all(c => {
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      c.is_ascii_digit() ||
      ['.', '-', ':', '[', ']'].contains(c)
    }) {
    return None
  }
  let loopback = ["localhost", "127.0.0.1", "[::1]"].any(host => {
    authority == host ||
    (
      authority.has_prefix(host + ":") &&
      authority[host.length() + 1:].all(c => c.is_ascii_digit()) &&
      authority.length() > host.length() + 1
    )
  })
  if scheme == "http://" && !loopback {
    return None
  }
  let prefix = rest[boundary:].trim_end(chars="/").to_owned()
  match models_url_target(scheme + authority + prefix + "/models") {
    Ok(target) => Some(target)
    Err(_) => None
  }
}

///|
fn provider_connection_candidate(value : Json) -> ProviderConnectionCandidate? {
  guard value
    is {
      "appType": "openclaw",
      "api": "chat.completions",
      "baseUrl": String(base_url),
      "apiKey": String(api_key),
      "model": String(model),
      ..
    } else {
    return None
  }
  guard api_key.length() > 0 &&
    api_key.length() <= 512 &&
    api_key.all(c => c > ' ' && c <= '~') &&
    !api_key.has_prefix("api-key-") &&
    model.length() > 0 &&
    model.length() <= 256 &&
    model.all(c => c > ' ' && c <= '~') &&
    !model.contains(api_key) &&
    provider_connection_candidate_target(base_url) is Some(target) else {
    return None
  }
  Some({ target, api_key, model, })
}

///|
async fn read_provider_connection_candidate(
  body : &@io.Reader,
) -> ProviderConnectionCandidate? {
  let bytes : Array[Byte] = []
  for ;; {
    guard body.read_some(max_len=Int32::min(8193 - bytes.length(), 1024))
      is Some(chunk) else {
      break
    }
    for byte in chunk {
      bytes.push(byte)
    }
    if bytes.length() > 8192 {
      return None
    }
  }
  let value = @json.parse(@encoding/utf8.decode(Bytes::from_array(bytes))) catch {
    _ => return None
  }
  provider_connection_candidate(value)
}

///|
async fn validate_provider_connection_candidate(
  candidate : ProviderConnectionCandidate,
) -> Bool {
  let client = @http.Client::Client(
    candidate.target.origin,
    headers=to_ci_headers(model_fetch_headers(candidate.api_key, None)),
  )
  defer client.close()
  // One request, with no redirect/retry, provider registration or inference.
  let response = client.get(candidate.target.path)
  if response.code < 200 || response.code >= 300 {
    return false
  }
  let bytes : Array[Byte] = []
  for ;; {
    guard client.read_some(max_len=Int32::min(1_048_577 - bytes.length(), 8192))
      is Some(chunk) else {
      break
    }
    for byte in chunk {
      bytes.push(byte)
    }
    if bytes.length() > 1_048_576 {
      return false
    }
  }
  let text = @encoding/utf8.decode(Bytes::from_array(bytes)) catch {
    _ => return false
  }
  match saved_provider_models_from_body(text, candidate.api_key) {
    Ok(models) => models.any(model => model.id == candidate.model)
    Err(_) => false
  }
}

///|
async fn ProxyService::handle_validate_provider_connection(
  _self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Cache-Control", "no-store")
  // The gateway's control middleware authenticates before this handler reads
  // the descriptor. Both descriptor and provider response remain request-local.
  let result = @async.with_timeout(10_000, () => {
    guard read_provider_connection_candidate(r.body) is Some(candidate) else {
      return None
    }
    if validate_provider_connection_candidate(candidate) {
      Some(candidate.model)
    } else {
      None
    }
  }) catch {
    _ => None
  }
  match result {
    Some(model) =>
      write_usage_json(w, {
        "contract": "moongate.provider-connection-validation.v1",
        "valid": true,
        "model": model,
        "inferencePerformed": false,
        "persisted": false,
      })
    None =>
      moongate_write_json_error(
        w,
        @status.BadRequest,
        "moongate_provider_validation_failed",
        "Could not validate the provider connection and selected model.",
      )
  }
}
