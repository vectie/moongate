///|
pub fn moongate_models_from_json(
  json : Json,
) -> Result[Array[MoonGateModel], String] {
  let rows = match json {
    Object(obj) =>
      match obj.get("models") {
        Some(Array(models)) => models
        Some(Object(models)) => models.values().to_array()
        Some(_) => return Err("moongate models field is not an array or object")
        None =>
          match obj.get("data") {
            Some(Array(models)) => models
            Some(_) => return Err("moongate data field is not an array")
            None => return Err("moongate models response has no models")
          }
      }
    Array(models) => models
    _ => return Err("moongate models response is not an object or array")
  }
  let parsed : Array[MoonGateModel] = []
  for row in rows {
    match MoonGateModel::from_json(row) {
      Ok(model) => parsed.push(model)
      Err(err) => return Err(err)
    }
  }
  Ok(parsed)
}

///|
pub fn MoonGateModel::from_json(json : Json) -> Result[MoonGateModel, String] {
  let obj = match json {
    Object(obj) => obj
    _ => return Err("moongate model entry is not an object")
  }
  let id = match moongate_json_string_field(obj, "id") {
    Some(value) => value
    None =>
      match moongate_json_string_field(obj, "slug") {
        Some(value) => value
        None =>
          match moongate_json_string_field(obj, "name") {
            Some(value) => value
            None => return Err("moongate model entry has no id")
          }
      }
  }
  Ok({
    id,
    owner: moongate_json_string_field(obj, "owned_by"),
    context_window: moongate_json_int_field(obj, "context_window"),
  })
}

///|
pub fn MoonGateUsageSummary::from_json(
  json : Json,
) -> Result[MoonGateUsageSummary, String] {
  let obj = match json {
    Object(obj) => obj
    _ => return Err("moongate usage summary is not an object")
  }
  Ok({
    total_requests: moongate_json_int_field(obj, "totalRequests").unwrap_or(0),
    total_cost: moongate_json_string_field(obj, "totalCost").unwrap_or("0"),
    total_input_tokens: moongate_json_int64_field(obj, "totalInputTokens").unwrap_or(
      0L,
    ),
    total_output_tokens: moongate_json_int64_field(obj, "totalOutputTokens").unwrap_or(
      0L,
    ),
    total_cache_creation_tokens: moongate_json_int64_field(
      obj, "totalCacheCreationTokens",
    ).unwrap_or(0L),
    total_cache_read_tokens: moongate_json_int64_field(
      obj, "totalCacheReadTokens",
    ).unwrap_or(0L),
    real_total_tokens: moongate_json_int64_field(obj, "realTotalTokens").unwrap_or(
      0L,
    ),
    success_rate: moongate_json_double_field(obj, "successRate").unwrap_or(0.0),
    cache_hit_rate: moongate_json_double_field(obj, "cacheHitRate").unwrap_or(
      0.0,
    ),
  })
}

///|
pub fn moongate_agent_clients_from_suite_status(
  status : Json,
) -> Result[Array[MoonGateAgentClient], String] {
  let obj = match status {
    Object(obj) if moongate_suite_status_contract_valid(obj) => obj
    _ => return Err("moongate suite status contract is invalid")
  }
  match obj.get("manifest") {
    Some(Object(manifest)) if moongate_suite_manifest_contract_valid(manifest) =>
      moongate_agent_clients_from_manifest(Json::object(manifest))
    _ => Err("moongate suite status has no valid manifest")
  }
}

///|
pub fn moongate_agent_clients_from_manifest(
  manifest : Json,
) -> Result[Array[MoonGateAgentClient], String] {
  let obj = match manifest {
    Object(obj) if moongate_suite_manifest_contract_valid(obj) => obj
    _ => return Err("moongate suite manifest contract is invalid")
  }
  let rows = match obj.get("agentClients") {
    Some(Array(rows)) => rows
    Some(_) => return Err("moongate agentClients field is not an array")
    None => return Err("moongate suite manifest has no agentClients")
  }
  let clients : Array[MoonGateAgentClient] = []
  for row in rows {
    match MoonGateAgentClient::from_json(row) {
      Ok(client) => clients.push(client)
      Err(err) => return Err(err)
    }
  }
  Ok(clients)
}

///|
pub fn MoonGateAgentClient::from_json(
  json : Json,
) -> Result[MoonGateAgentClient, String] {
  let obj = match json {
    Object(obj) => obj
    _ => return Err("moongate agent client entry is not an object")
  }
  let id = match moongate_json_string_field(obj, "id") {
    Some(value) => value
    None => return Err("moongate agent client entry has no id")
  }
  let app_type = match moongate_json_string_field(obj, "appType") {
    Some(value) => value
    None => return Err("moongate agent client entry has no appType")
  }
  let protocol = match moongate_json_string_field(obj, "protocol") {
    Some(value) => value
    None => return Err("moongate agent client entry has no protocol")
  }
  let base_url = match moongate_json_string_field(obj, "baseUrl") {
    Some(value) => moongate_client_normalize_base_url(value)
    None => return Err("moongate agent client entry has no baseUrl")
  }
  let primary_route = match moongate_json_string_field(obj, "primaryRoute") {
    Some(value) => value
    None => return Err("moongate agent client entry has no primaryRoute")
  }
  Ok({
    id,
    app_type,
    protocol,
    base_url,
    primary_route,
    setup_command: moongate_json_string_field(obj, "setupCommand"),
    usage: moongate_json_string_field(obj, "usage"),
  })
}

///|
fn moongate_json_string_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) if !value.trim().is_empty() => Some(value)
    _ => None
  }
}

///|
fn moongate_json_double_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value)
    _ => None
  }
}

///|
fn moongate_json_int_field(obj : Map[String, Json], key : String) -> Int? {
  match moongate_json_double_field(obj, key) {
    Some(value) => Some(value.trunc().to_int())
    None => None
  }
}

///|
fn moongate_json_int64_field(obj : Map[String, Json], key : String) -> Int64? {
  match moongate_json_double_field(obj, key) {
    Some(value) => Some(value.trunc().to_int64())
    None => None
  }
}

///|
pub fn moongate_base_url_from_suite_status(status : Json) -> String? {
  match status {
    Object(obj) if moongate_suite_status_contract_valid(obj) =>
      moongate_base_url_from_suite_status_object(obj)
    _ => None
  }
}

///|
fn moongate_suite_status_contract_valid(obj : Map[String, Json]) -> Bool {
  moongate_json_string_field(obj, "contract") == Some(@suite.status_contract()) &&
  moongate_json_string_field(obj, "service") == Some(@suite.service_name())
}

///|
fn moongate_base_url_from_suite_status_object(
  obj : Map[String, Json],
) -> String? {
  match obj.get("manifest") {
    Some(Object(manifest)) if moongate_suite_manifest_contract_valid(manifest) =>
      moongate_base_url_from_json_object(manifest)
    _ => None
  }
}

///|
fn moongate_suite_manifest_contract_valid(obj : Map[String, Json]) -> Bool {
  moongate_json_string_field(obj, "contract") ==
  Some(@suite.manifest_contract()) &&
  moongate_json_string_field(obj, "service") == Some(@suite.service_name())
}

///|
fn moongate_base_url_from_json_object(obj : Map[String, Json]) -> String? {
  match obj.get("baseUrl") {
    Some(String(url)) if !url.trim().is_empty() =>
      Some(moongate_client_normalize_base_url(url))
    _ => None
  }
}
