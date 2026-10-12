///|
fn gate_oas_field(value : Json, key : String) -> Json {
  moon_json_get(value, key).unwrap_or(Json::null())
}

///|
fn gate_oas_text(value : Json, key : String) -> String {
  match gate_oas_field(value, key) {
    String(s) => s
    _ => ""
  }
}

///|
/// Local object references only. Never fetches external documents.
fn gate_oas_resolve(
  root : Json,
  value : Json,
  depth : Int,
) -> Result[Json, String] {
  let reference = gate_oas_text(value, "$ref")
  if reference.is_empty() {
    return Ok(value)
  }
  if depth >= 16 {
    return Err("Reference cycle or chain exceeds 16 links: " + reference)
  }
  if !reference.has_prefix("#/") {
    return Err("External references are unsupported: " + reference)
  }
  let mut node = root
  let parts = reference.split("/").collect()
  for i = 1; i < parts.length(); i = i + 1 {
    let key = parts[i]
      .to_owned()
      .replace(old="~1", new="/")
      .replace(old="~0", new="~")
    guard moon_json_get(node, key) is Some(next) else {
      return Err("Unresolved local reference: " + reference)
    }
    node = next
  }
  gate_oas_resolve(root, node, depth + 1)
}

///|
fn gate_oas_line(text : String) -> String {
  text.replace(old="\r", new=" ").replace(old="\n", new=" ")
}

///|
fn gate_oas_array(value : Json) -> Array[Json] {
  match value {
    Array(items) => items
    _ => []
  }
}

///|
/// Keep values as variables so query/header encoding remains an explicit edit.
fn gate_oas_variable(location : String, name : String) -> String {
  let builder = StringBuilder()
  builder.write_string(location + "_")
  for c in name {
    if c is ('a'..='z' | 'A'..='Z' | '0'..='9' | '_') {
      builder.write_char(c)
    } else {
      builder.write_char('_')
    }
  }
  builder.to_string()
}

///|
fn gate_oas_example(root : Json, value : Json) -> Result[Json?, String] {
  if moon_json_get(value, "example") is Some(example) {
    return Ok(Some(example))
  }
  if gate_oas_field(value, "examples") is Object(examples) {
    for _, example in examples {
      let resolved = match gate_oas_resolve(root, example, 0) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if moon_json_get(resolved, "value") is Some(v) {
        return Ok(Some(v))
      }
    }
  }
  let schema = match
    gate_oas_resolve(root, gate_oas_field(value, "schema"), 0) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if moon_json_get(schema, "example") is Some(v) {
    return Ok(Some(v))
  }
  if moon_json_get(schema, "default") is Some(v) {
    return Ok(Some(v))
  }
  Ok(None)
}

///|
/// Offline OpenAPI 3 JSON exploration and editable HTTP templates. No network,
/// provider registration, credential reads, or request execution occurs here.
pub fn moongate_openapi_collection_json(
  content : String,
  tag? : String = "",
  operation? : String = "",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("OpenAPI file exceeds 4 MiB")
  }
  guard moon_parse_json_line(content) is Some(root) else {
    return Err("Expected an OpenAPI 3 JSON document (YAML is unsupported)")
  }
  let version = gate_oas_text(root, "openapi")
  if !version.has_prefix("3.0.") && !version.has_prefix("3.1.") {
    return Err("Only OpenAPI 3.0 and 3.1 JSON documents are supported")
  }
  guard gate_oas_field(root, "paths") is Object(paths) else {
    return Err("OpenAPI paths must be an object")
  }
  let operations : Array[Json] = []
  let sections : Array[String] = [
    "# MoonGate offline OpenAPI request collection", "# Review each request, replace variables, encode query values and supply auth before manually sending.",
    "# Supplied examples are unverified. No provider was contacted.",
  ]
  let mut total = 0
  for path, raw_item in paths {
    if !path.has_prefix("/") {
      continue
    }
    let item = match gate_oas_resolve(root, raw_item, 0) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for
      verb in [
        "get", "post", "put", "patch", "delete", "head", "options", "trace",
      ] {
      guard moon_json_get(item, verb) is Some(op) else { continue }
      total += 1
      if total > 2000 {
        return Err("OpenAPI import is limited to 2,000 operations")
      }
      let id = gate_oas_text(op, "operationId")
      let tags = gate_oas_array(gate_oas_field(op, "tags"))
      if !tag.is_empty() && !tags.contains(Json::string(tag)) {
        continue
      }
      if !operation.is_empty() && id != operation {
        continue
      }
      let warnings : Array[String] = []
      let server_list = match moon_json_get(op, "servers") {
        Some(v) => v
        None =>
          match moon_json_get(item, "servers") {
            Some(v) => v
            None => gate_oas_field(root, "servers")
          }
      }
      let servers = gate_oas_array(server_list)
      let server = if servers.length() > 0 {
        gate_oas_text(servers[0], "url")
      } else {
        "/"
      }
      if servers.length() > 1 {
        warnings.push(
          "Only the first declared server is shown; edit baseUrl to choose another.",
        )
      }
      let parameters : Map[String, Json] = Map([])
      for
        raw in gate_oas_array(gate_oas_field(item, "parameters")) +
        gate_oas_array(gate_oas_field(op, "parameters")) {
        let parameter = match gate_oas_resolve(root, raw, 0) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let name = gate_oas_text(parameter, "name")
        let location = gate_oas_text(parameter, "in")
        if name.is_empty() || location.is_empty() {
          return Err("Parameter requires name and in")
        }
        parameters[location + ":" + name] = parameter
      }
      let normalized : Array[Json] = []
      let declarations : Array[String] = ["@baseUrl = REPLACE_BASE_URL"]
      let headers : Array[String] = []
      let query : Array[String] = []
      let mut request_path = path
      let names : Map[String, Bool] = Map([])
      for _, parameter in parameters {
        let name = gate_oas_text(parameter, "name")
        let location = gate_oas_text(parameter, "in")
        let variable = gate_oas_variable(location, name)
        if names.contains(variable) {
          return Err(
            "Parameter names produce duplicate template variable: " + variable,
          )
        }
        names[variable] = true
        let sensitive = name.to_lower().contains("authorization") ||
          name.to_lower().contains("key") ||
          name.to_lower().contains("token") ||
          name.to_lower().contains("cookie")
        let example = if sensitive {
          Json::null()
        } else {
          match gate_oas_example(root, parameter) {
            Ok(v) => v.unwrap_or(Json::null())
            Err(e) => return Err(e)
          }
        }
        normalized.push({
          "name": name.to_json(),
          "in": location.to_json(),
          "required": gate_oas_field(parameter, "required"),
          "example": example,
          "variable": variable.to_json(),
        })
        if example != Json::null() {
          declarations.push(
            "# " +
            variable +
            " example (encode as needed): " +
            gate_oas_line(example.stringify()),
          )
        }
        declarations.push("@" + variable + " = REPLACE_ME")
        match location {
          "path" =>
            request_path = request_path.replace(
              old="{" + name + "}",
              new="{{" + variable + "}}",
            )
          "query" => query.push(gate_oas_line(name) + "={{" + variable + "}}")
          "header" =>
            headers.push(gate_oas_line(name) + ": {{" + variable + "}}")
          _ =>
            warnings.push(
              "Parameter " +
              name +
              " in " +
              location +
              " must be added manually.",
            )
        }
        if moon_json_get(parameter, "style") is Some(_) ||
          moon_json_get(parameter, "explode") is Some(_) {
          warnings.push(
            "Review serialization style/explode for parameter " + name + ".",
          )
        }
      }
      let request_body = match
        gate_oas_resolve(root, gate_oas_field(op, "requestBody"), 0) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let mut body : Json = Json::null()
      let mut body_text = ""
      if request_body != Json::null() {
        if moon_json_get(
            gate_oas_field(request_body, "content"),
            "application/json",
          )
          is Some(media) {
          let example = match gate_oas_example(root, media) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          headers.push("Content-Type: application/json")
          body_text = if example is Some(value) {
            body = value
            value.stringify(indent=2)
          } else {
            warnings.push(
              "No JSON body example supplied; replace the empty object using the source schema.",
            )
            "{}"
          }
        } else {
          warnings.push(
            "Non-JSON request body is not generated; add it manually from the source contract.",
          )
        }
      }
      let security = match moon_json_get(op, "security") {
        Some(v) => v
        None => gate_oas_field(root, "security")
      }
      if gate_oas_array(security).length() > 0 {
        warnings.push(
          "Authentication is declared; configure it manually. No host credentials are read.",
        )
      }
      let suffix = if query.is_empty() { "" } else { "?" + query.join("&") }
      let url = "{{baseUrl}}" + gate_oas_line(request_path) + suffix
      let title = if id.is_empty() {
        verb.to_upper() + " " + path
      } else {
        id
      }
      let section = "### " +
        gate_oas_line(title) +
        "\n# " +
        gate_oas_line(gate_oas_text(op, "summary")) +
        "\n# Declared server: " +
        gate_oas_line(server) +
        "\n" +
        warnings.map(w => "# " + gate_oas_line(w)).join("\n") +
        "\n" +
        declarations.join("\n") +
        "\n\n" +
        verb.to_upper() +
        " " +
        url +
        "\n" +
        headers.join("\n") +
        "\n\n" +
        body_text
      sections.push(section)
      operations.push({
        "operationId": id.to_json(),
        "method": verb.to_upper().to_json(),
        "path": path.to_json(),
        "summary": gate_oas_field(op, "summary"),
        "tags": tags.to_json(),
        "server": server.to_json(),
        "parameters": normalized.to_json(),
        "bodyExample": body,
        "security": security,
        "warnings": warnings.to_json(),
      })
    }
  }
  Ok({
    "schema": "moongate.openapi-collection.v1",
    "title": gate_oas_field(gate_oas_field(root, "info"), "title"),
    "openapi": version.to_json(),
    "sourceOperations": total.to_json(),
    "selectedOperations": operations.length().to_json(),
    "operations": operations.to_json(),
    "http": (sections.join("\n\n") + "\n").to_json(),
  })
}
