///|
fn charge_output(value : Json, budget : Ref[Int]) -> Unit raise {
  let size = @utf8.encode(value.stringify()).length()
  guard size <= 8 * 1024 * 1024 - budget.val else {
    fail("Derived collection exceeds 8 MiB")
  }
  budget.val += size
}

///|
/// Prepare legacy Insomnia v4 requests for manual editing without network,
/// environment, file-reference or script execution. The caller must retain the
/// original export: this derived artifact intentionally omits unsupported data.
pub fn import_collection(
  content : String,
  workspace_id? : String = "",
  folder_id? : String = "",
  request_id? : String = "",
) -> Json raise {
  let (root, items, nodes) = resources(content)
  for
    (id, kind) in [
      (workspace_id, "workspace"),
      (folder_id, "request_group"),
      (request_id, "request"),
    ] {
    if !id.is_empty() {
      guard nodes.get(id) is Some(node) &&
        field(node, "_type") == Json::string(kind) else {
        fail("Selector does not identify a " + kind + ": " + id)
      }
    }
  }
  let inventory : Array[Json] = []
  let requests : Array[Json] = []
  let budget = Ref(0)
  let omitted : Map[String, Int] = Map([])
  let sections : Array[String] = [
    "# MoonGate offline Insomnia v4 request collection", "# Review before manually sending. No URLs fetched, requests sent, scripts run or file references read.",
    "# Keep the original export separately; this derived collection is incomplete and is not a secret scrubber.",
    "# Environments, authentication helpers, cookies, scripts, tests and runtime settings are never imported.",
    "# Other resource types are omitted; see the JSON receipt for their counts.",
  ]
  let verbs = [
    "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE",
  ]
  let mut source_requests = 0
  for index, item in items {
    let kind = text(item, "_type")
    let id = text(item, "_id")
    if !["workspace", "request_group", "request"].contains(kind) {
      omitted[kind] = omitted.get(kind).unwrap_or(0) + 1
      continue
    }
    let name = text(item, "name")
    if kind == "workspace" {
      let entry : Json = {
        "id": id.to_json(),
        "type": kind.to_json(),
        "name": name.to_json(),
      }
      charge_output(entry, budget)
      inventory.push(entry)
      continue
    }
    let place = position(item, nodes)
    let entry : Json = {
      "id": id.to_json(),
      "type": kind.to_json(),
      "name": name.to_json(),
      "workspaceId": place.workspace.to_json(),
      "folderIds": place.folders.to_json(),
      "folderPath": place.path.to_json(),
      "resourceIndex": (index + 1).to_json(),
    }
    charge_output(entry, budget)
    inventory.push(entry)
    if kind != "request" {
      continue
    }
    source_requests += 1
    if (!workspace_id.is_empty() && place.workspace != workspace_id) ||
      (!folder_id.is_empty() && !place.folders.contains(folder_id)) ||
      (!request_id.is_empty() && id != request_id) {
      continue
    }
    let verb = text(item, "method").to_upper()
    guard verbs.contains(verb) else {
      fail("Unsupported HTTP method on request: " + id)
    }
    let warnings : Array[String] = []
    let url = request_url(item, warnings)
    let headers : Array[String] = []
    let declarations : Array[String] = []
    let mut has_content_type = false
    for hindex, header in array(item, "headers") {
      if disabled(header) {
        continue
      }
      let key = text(header, "name")
      let value = text(header, "value")
      guard header_token(key) && line_safe(value) else {
        fail("Invalid header on request: " + id)
      }
      let lower = key.to_lower()
      if [
          "cookie", "host", "content-length", "connection", "transfer-encoding",
          "accept-encoding", "proxy-connection",
        ].contains(lower) {
        warnings.push("Cookie or transport header omitted: " + key)
        continue
      }
      if lower == "content-type" {
        has_content_type = true
      }
      if sensitive(key) || dynamic(value) {
        let variable = "ins_" +
          (index + 1).to_string() +
          "_header_" +
          hindex.to_string()
        declarations.push("@" + variable + " = REPLACE_ME")
        headers.push(key + ": {{" + variable + "}}")
        warnings.push(
          "Header value withheld or requires template editing: " + key,
        )
      } else {
        headers.push(key + ": " + value)
      }
    }
    if field(item, "authentication") != Json::null() &&
      field(item, "authentication") != Json::empty_object() {
      warnings.push(
        "Authentication helper omitted; configure credentials manually.",
      )
    }
    for key in ["preRequestScript", "afterResponseScript", "pathParameters"] {
      if field(item, key) != Json::null() &&
        field(item, key) != Json::string("") &&
        field(item, key) != Json::array([]) {
        warnings.push(key + " omitted; reproduce any required setup manually.")
      }
    }
    let (body, mime) = request_body(item, warnings)
    if !mime.is_empty() && !has_content_type {
      headers.push("Content-Type: " + mime)
    }
    let label = text(nodes[place.workspace], "name") +
      "/" +
      (if place.path.is_empty() { "" } else { place.path + "/" }) +
      name
    let section = "### " +
      label +
      "\n# Source resource " +
      id +
      " (index " +
      (index + 1).to_string() +
      ")\n" +
      warnings.map(w => "# " + w).join("\n") +
      "\n" +
      declarations.join("\n") +
      "\n\n" +
      verb +
      " " +
      url +
      "\n" +
      headers.join("\n") +
      "\n\n" +
      body
    charge_output(section.to_json(), budget)
    sections.push(section)
    let request : Json = {
      "sourceResourceId": id.to_json(),
      "sourceResourceIndex": (index + 1).to_json(),
      "workspaceId": place.workspace.to_json(),
      "folderIds": place.folders.to_json(),
      "folderPath": place.path.to_json(),
      "name": name.to_json(),
      "method": verb.to_json(),
      "url": url.to_json(),
      "headers": headers.to_json(),
      "body": body.to_json(),
      "variables": declarations.to_json(),
      "warnings": warnings.to_json(),
    }
    charge_output(request, budget)
    requests.push(request)
  }
  if requests.is_empty() &&
    (
      !workspace_id.is_empty() ||
      !folder_id.is_empty() ||
      !request_id.is_empty()
    ) {
    fail("Selection contains no HTTP requests; selectors are intersected")
  }
  let result : Json = {
    "schema": "moongate.insomnia-collection.v1",
    "sourceFormat": "Insomnia JSON v4",
    "originalPreservation": "Caller retains original export unchanged; output is a derived subset, not a backup.",
    "sourceExportDate": optional_text(root, "__export_date").to_json(),
    "sourceExportTool": optional_text(root, "__export_source").to_json(),
    "sourceResources": items.length().to_json(),
    "sourceRequests": source_requests.to_json(),
    "selectedRequests": requests.length().to_json(),
    "inventory": inventory.to_json(),
    "omittedResourceTypes": omitted.to_json(),
    "requests": requests.to_json(),
    "selection": {
      "workspaceId": workspace_id.to_json(),
      "folderId": folder_id.to_json(),
      "requestId": request_id.to_json(),
    },
    "http": (sections.join("\n\n") + "\n").to_json(),
  }
  guard @utf8.encode(result.stringify()).length() <= 8 * 1024 * 1024 else {
    fail("Derived collection exceeds 8 MiB")
  }
  result
}
