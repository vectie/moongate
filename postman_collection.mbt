///|
priv struct GatePostmanItem {
  item : Json
  folder : String
  variables : Map[String, Json]
  auth : Json
  scripts : Bool
}

///|
fn gate_pm_scope(parent : Map[String, Json], node : Json) -> Map[String, Json] {
  let variables = parent.copy()
  for variable in gate_oas_array(gate_oas_field(node, "variable")) {
    if gate_oas_field(variable, "disabled") != Json::boolean(true) {
      let name = gate_oas_text(variable, "key")
      if !name.is_empty() {
        variables[name] = gate_oas_field(variable, "value")
      }
    }
  }
  variables
}

///|
fn gate_pm_auth(node : Json, inherited : Json) -> Json {
  match moon_json_get(node, "auth") {
    Some(Object(_) as auth) => auth
    _ => inherited
  }
}

///|
fn gate_pm_items(
  node : Json,
  folder : String,
  variables : Map[String, Json],
  auth : Json,
  scripts : Bool,
  depth : Int,
  count : Ref[Int],
  output : Array[GatePostmanItem],
) -> Result[Unit, String] {
  if depth > 32 {
    return Err("Postman folders exceed 32 levels")
  }
  guard gate_oas_field(node, "item") is Array(items) else {
    return Err("Postman collection and folders require an item array")
  }
  let variables = gate_pm_scope(variables, node)
  let auth = gate_pm_auth(node, auth)
  let scripts = scripts ||
    !gate_oas_array(gate_oas_field(node, "event")).is_empty()
  for item in items {
    count.val += 1
    if count.val > 2000 {
      return Err("Postman import is limited to 2,000 items including folders")
    }
    if moon_json_get(item, "item") is Some(_) {
      if moon_json_get(item, "request") is Some(_) {
        return Err("Postman item cannot contain both a folder and a request")
      }
      let name = gate_oas_text(item, "name")
      if name.is_empty() || name.contains("/") || !gate_har_line_safe(name) {
        return Err(
          "Postman folder names must be nonempty single-line names without /",
        )
      }
      let path = if folder.is_empty() { name } else { folder + "/" + name }
      match
        gate_pm_items(
          item,
          path,
          variables,
          auth,
          scripts,
          depth + 1,
          count,
          output,
        ) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    } else {
      output.push({
        item,
        folder,
        variables: gate_pm_scope(variables, item),
        auth,
        scripts: scripts ||
        !gate_oas_array(gate_oas_field(item, "event")).is_empty(),
      })
    }
  }
  Ok(())
}

///|
priv struct GatePostmanTemplate {
  prefix : String
  source : Map[String, Json]
  names : Map[String, String]
  declarations : Array[String]
  warnings : Array[String]
}

///|
/// Map each variable to a request-local identifier so folder defaults cannot
/// overwrite another request's values in a single HTTP-client document.
fn GatePostmanTemplate::render(
  self : GatePostmanTemplate,
  value : String,
  query? : Bool = false,
) -> String {
  let parts = value.split("{{").collect()
  let out = StringBuilder()
  let literal = fn(text : String) {
    if query {
      copilot_url_encode(text)
    } else {
      text
    }
  }
  out.write_string(literal(parts[0].to_owned()))
  for i = 1; i < parts.length(); i = i + 1 {
    let rest = parts[i].split("}}").collect()
    if rest.length() < 2 {
      self.warnings.push(
        "Unclosed variable placeholder requires manual editing.",
      )
      out.write_string(literal("{{" + parts[i].to_owned()))
      continue
    }
    let name = rest[0].to_owned()
    let target = match self.names.get(name) {
      Some(target) => target
      None => {
        let target = self.prefix + "v" + (self.names.length() + 1).to_string()
        self.names[name] = target
        let original = self.source.get(name).unwrap_or(Json::null())
        let default = match original {
          String(text) => text
          Number(_) | True | False => original.stringify()
          _ => ""
        }
        let safe = !gate_har_sensitive(name) &&
          !name.has_prefix("$") &&
          !default.is_empty() &&
          gate_har_line_safe(default) &&
          !default.contains("{{")
        self.declarations.push("# " + target + " from " + gate_oas_line(name))
        self.declarations.push(
          "@" + target + " = " + (if safe { default } else { "REPLACE_ME" }),
        )
        if !safe {
          self.warnings.push("Supply variable manually: " + gate_oas_line(name))
        }
        target
      }
    }
    out.write_string("{{" + target + "}}")
    out.write_string(literal(rest[1:].map(p => p.to_owned()).join("}}")))
  }
  out.to_string()
}

///|
fn gate_pm_url(
  request : Json,
  template : GatePostmanTemplate,
) -> Result[String, String] {
  let source = gate_oas_field(request, "url")
  let raw = match source {
    String(text) => text
    _ => gate_oas_text(source, "raw")
  }
  if raw.is_empty() ||
    !gate_har_line_safe(raw) ||
    raw.contains(" ") ||
    (
      !raw.has_prefix("http://") &&
      !raw.has_prefix("https://") &&
      !raw.has_prefix("{{")
    ) {
    return Err(
      "Postman request requires an HTTP(S) or variable-based raw URL without whitespace",
    )
  }
  let without_fragment = raw.split("#").collect()[0].to_owned()
  let parts = without_fragment.split("?").collect()
  let base = parts[0].to_owned()
  // Literal user-info credentials are never retained. Variable defaults still
  // need review, as this importer does not claim general secret redaction.
  let authority = base.split("/").collect()
  if authority.length() > 2 && authority[2].contains("@") {
    return Err("Postman URL contains embedded credentials")
  }
  let pairs : Array[String] = []
  if moon_json_get(source, "query") is Some(query) {
    guard query is Array(entries) else {
      return Err("Postman URL query must be an array")
    }
    for entry in entries {
      if gate_oas_field(entry, "disabled") == Json::boolean(true) {
        continue
      }
      let name = gate_oas_text(entry, "key")
      let key = template.render(name, query=true)
      let value = if gate_har_sensitive(name) || name.contains("%") {
        template.warnings.push("Query value withheld: " + gate_oas_line(name))
        "REPLACE_ME"
      } else {
        template.render(gate_oas_text(entry, "value"), query=true)
      }
      pairs.push(key + "=" + value)
    }
  } else if parts.length() > 1 {
    for pair in parts[1:].map(p => p.to_owned()).join("?").split("&") {
      let name = pair.split("=").collect()[0].to_owned()
      if gate_har_sensitive(name) || name.contains("%") {
        pairs.push(name + "=REPLACE_ME")
        template.warnings.push("Query value withheld: " + gate_oas_line(name))
      } else {
        pairs.push(template.render(pair.to_owned()))
      }
    }
  }
  let path_parts = base
    .split("/")
    .map(fn(part) {
      let text = part.to_owned()
      if text.has_prefix(":") && text.length() > 1 {
        "{{" + text[1:].to_owned() + "}}"
      } else {
        text
      }
    })
    .collect()
  let url = template.render(path_parts.join("/"))
  Ok(url + (if pairs.is_empty() { "" } else { "?" + pairs.join("&") }))
}

///|
/// Convert an exported Postman Collection v2.1 into an editable request library.
/// This is offline authoring: scripts, auth helpers and requests never execute.
pub fn moongate_postman_collection_json(
  content : String,
  folder? : String = "",
  request_method? : String = "",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("Postman file exceeds 4 MiB")
  }
  guard moon_parse_json_line(content) is Some(root) else {
    return Err("Expected a Postman Collection v2.1 JSON document")
  }
  let schema = gate_oas_text(gate_oas_field(root, "info"), "schema")
  if ![
      "https://schema.getpostman.com/json/collection/v2.1.0/collection.json", "https://schema.postman.com/json/collection/v2.1.0/collection.json",
    ].contains(schema) {
    return Err("Only Postman Collection v2.1 exports are supported")
  }
  let verbs = [
    "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE",
  ]
  let filter_method = request_method.to_upper()
  if !filter_method.is_empty() && !verbs.contains(filter_method) {
    return Err("Unsupported method filter")
  }
  let items : Array[GatePostmanItem] = []
  match gate_pm_items(root, "", {}, Json::null(), false, 0, Ref(0), items) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let requests : Array[Json] = []
  let sections : Array[String] = [
    "# MoonGate offline Postman request collection", "# Review variables, captured content and authentication before manually sending.",
    "# No scripts or requests ran. Ordinary values and bodies may contain private data.",
  ]
  for index, entry in items {
    let raw_request = gate_oas_field(entry.item, "request")
    let request : Json = match raw_request {
      String(url) => { "method": "GET", "url": url.to_json() }
      _ => raw_request
    }
    let verb = gate_oas_text(request, "method").to_upper()
    if (
        !folder.is_empty() &&
        entry.folder != folder &&
        !entry.folder.has_prefix(folder + "/")
      ) ||
      (!filter_method.is_empty() && filter_method != verb) {
      continue
    }
    if !verbs.contains(verb) {
      return Err("Postman request has an unsupported or missing method")
    }
    let name = gate_oas_text(entry.item, "name")
    if name.is_empty() || !gate_har_line_safe(name) {
      return Err("Postman request name must be nonempty and single-line")
    }
    let warnings : Array[String] = []
    if entry.scripts {
      warnings.push(
        "Postman scripts/tests were omitted; reproduce any setup they perform manually.",
      )
    }
    let template : GatePostmanTemplate = {
      prefix: "pm_" + (index + 1).to_string() + "_",
      source: gate_pm_scope(entry.variables, gate_oas_field(request, "url")),
      names: {},
      declarations: [],
      warnings,
    }
    let url = match gate_pm_url(request, template) {
      Ok(url) => url
      Err(e) => return Err(name + ": " + e)
    }
    let headers : Array[String] = []
    let mut has_auth = false
    let mut has_content_type = false
    let raw_headers = gate_oas_field(request, "header")
    if raw_headers != Json::null() && !(raw_headers is Array(_)) {
      return Err(
        name + ": header must be an array; raw header strings are unsupported",
      )
    }
    for hindex, header in gate_oas_array(raw_headers) {
      if gate_oas_field(header, "disabled") == Json::boolean(true) {
        continue
      }
      let key = gate_oas_text(header, "key")
      let value = gate_oas_text(header, "value")
      if key.is_empty() ||
        key.contains(":") ||
        key.contains(" ") ||
        !gate_har_line_safe(key) ||
        !gate_har_line_safe(value) {
        return Err(name + ": invalid header name or multiline/control value")
      }
      let lower = key.to_lower()
      if ["host", "content-length", "connection", "transfer-encoding", "cookie"].contains(
          lower,
        ) {
        warnings.push("Transport/cookie header omitted: " + key)
        continue
      }
      if lower == "authorization" {
        has_auth = true
      }
      if lower == "content-type" {
        has_content_type = true
      }
      if gate_har_sensitive(key) {
        let variable = template.prefix + "auth" + hindex.to_string()
        template.declarations.push("@" + variable + " = REPLACE_ME")
        headers.push(key + ": {{" + variable + "}}")
        warnings.push("Authentication header value withheld: " + key)
      } else {
        headers.push(key + ": " + template.render(value))
      }
    }
    let auth = gate_pm_auth(request, entry.auth)
    let auth_type = gate_oas_text(auth, "type")
    if !auth_type.is_empty() && auth_type != "noauth" {
      warnings.push(
        "Authentication helper omitted: " +
        gate_oas_line(auth_type) +
        "; supply credentials manually.",
      )
      if auth_type == "bearer" && !has_auth {
        let variable = template.prefix + "bearer"
        template.declarations.push("@" + variable + " = REPLACE_ME")
        headers.push("Authorization: Bearer {{" + variable + "}}")
      }
    }
    let body_data = gate_oas_field(request, "body")
    let mode = gate_oas_text(body_data, "mode")
    let mut body = ""
    if gate_oas_field(body_data, "disabled") != Json::boolean(true) &&
      !mode.is_empty() {
      if mode == "raw" {
        guard gate_oas_field(body_data, "raw") is String(raw) else {
          return Err(name + ": raw body must be a string")
        }
        body = template.render(raw)
        let language = gate_oas_text(
          gate_oas_field(gate_oas_field(body_data, "options"), "raw"),
          "language",
        )
        if !has_content_type && language == "json" {
          headers.push("Content-Type: application/json")
        }
      } else {
        warnings.push(
          "Body mode " +
          gate_oas_line(mode) +
          " omitted; reconstruct it manually.",
        )
      }
    }
    let label = if entry.folder.is_empty() {
      name
    } else {
      entry.folder + "/" + name
    }
    sections.push(
      "### " +
      label +
      "\n" +
      warnings.map(w => "# " + w).join("\n") +
      "\n" +
      template.declarations.join("\n") +
      "\n\n" +
      verb +
      " " +
      url +
      "\n" +
      headers.join("\n") +
      "\n\n" +
      body,
    )
    requests.push({
      "entry": (index + 1).to_json(),
      "name": name.to_json(),
      "folder": entry.folder.to_json(),
      "method": verb.to_json(),
      "url": url.to_json(),
      "headers": headers.to_json(),
      "body": body.to_json(),
      "variables": template.declarations.to_json(),
      "warnings": warnings.to_json(),
    })
  }
  Ok({
    "schema": "moongate.postman-collection.v1",
    "name": gate_oas_text(gate_oas_field(root, "info"), "name").to_json(),
    "sourceRequests": items.length().to_json(),
    "selectedRequests": requests.length().to_json(),
    "requests": requests.to_json(),
    "http": (sections.join("\n\n") + "\n").to_json(),
  })
}
