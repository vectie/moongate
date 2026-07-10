///|
async fn MoonstatClient::get_json_path(
  self : MoonstatClient,
  path : String,
) -> Result[Json, String] {
  match self.get_text_path(path) {
    Ok(body) =>
      Ok(@json.parse(body)) catch {
        err => Err("Invalid JSON from moonstat: \{err}")
      }
    Err(err) => Err(err)
  }
}

///|
async fn MoonstatClient::post_json_path(
  self : MoonstatClient,
  path : String,
  request : Json,
) -> Result[Json, String] {
  let body = request.stringify()
  match self.request_text_path("POST", path, Some(body)) {
    Ok(body) =>
      Ok(@json.parse(body)) catch {
        err => Err("Invalid JSON from moonstat: \{err}")
      }
    Err(err) => Err(err)
  }
}

///|
async fn MoonstatClient::delete_json_path(
  self : MoonstatClient,
  path : String,
) -> Result[Json, String] {
  match self.request_text_path("DELETE", path, None) {
    Ok(body) =>
      Ok(@json.parse(body)) catch {
        err => Err("Invalid JSON from moonstat: \{err}")
      }
    Err(err) => Err(err)
  }
}

///|
async fn MoonstatClient::get_text_path(
  self : MoonstatClient,
  path : String,
) -> Result[String, String] {
  self.request_text_path("GET", path, None)
}

///|
async fn MoonstatClient::request_text_path(
  self : MoonstatClient,
  http_method : String,
  path : String,
  body : String?,
) -> Result[String, String] {
  let target = match models_url_target(self.endpoint(path)) {
    Ok(target) => target
    Err(err) => return Err(err)
  }
  let headers = self.headers(
    http_method,
    resolved_control_token=self.resolved_control_token(),
  )
  let client = @http.Client::Client(target.origin, headers~)
  defer client.close()
  let response = match http_method {
    "GET" =>
      client.get(target.path) catch {
        err => return Err("Network error: \{err}")
      }
    "POST" =>
      client.post(target.path, body.unwrap_or("")) catch {
        err => return Err("Network error: \{err}")
      }
    "DELETE" =>
      client..request(Delete, target.path).end_request() catch {
        err => return Err("Network error: \{err}")
      }
    _ => return Err("Unsupported moonstat client method: \{http_method}")
  }
  let response_body = client.read_all().text()
  if response.code is (200..=299) {
    Ok(response_body)
  } else {
    Err(
      "Moonstat HTTP \{response.code}: \{truncate_model_fetch_error_body(response_body)}",
    )
  }
}

///|
fn MoonstatClient::headers(
  self : MoonstatClient,
  http_method : String,
  resolved_control_token? : String? = None,
) -> Map[String, String] {
  let headers : Map[String, String] = { "Accept": "application/json" }
  match self.api_key {
    Some(api_key) if !api_key.trim().is_empty() =>
      headers["Authorization"] = "Bearer \{api_key}"
    _ => ()
  }
  match self.user_agent {
    Some(user_agent) if !user_agent.trim().is_empty() =>
      headers["User-Agent"] = user_agent.trim().to_owned()
    _ => ()
  }
  match resolved_control_token {
    Some(token) if !token.trim().is_empty() =>
      headers[MOONSTAT_CONTROL_TOKEN_HEADER] = token.trim().to_owned()
    _ => ()
  }
  if http_method == "POST" {
    headers["Content-Type"] = "application/json"
  }
  headers
}

///|
async fn MoonstatClient::resolved_control_token(
  self : MoonstatClient,
) -> String? {
  match self.control_token {
    Some(token) if !token.trim().is_empty() => return Some(token)
    _ => ()
  }
  let configured_token = @os.getenv("MOONSTAT_CONTROL_TOKEN") catch {
    _ => None
  }
  match configured_token {
    Some(token) if !token.trim().is_empty() => return Some(token)
    _ => ()
  }
  let content = @fsx.read_file(default_moonstat_control_token_path()) catch {
    _ => return None
  }
  let token = content.trim().to_owned()
  if token.is_empty() {
    None
  } else {
    Some(token)
  }
}
