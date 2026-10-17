///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn text(value : Json, key : String) -> String raise {
  match field(value, key) {
    String(value) => value
    _ => fail("Expected string field: " + key)
  }
}

///|
fn optional_text(value : Json, key : String) -> String raise {
  if field(value, key) == Json::null() {
    ""
  } else {
    text(value, key)
  }
}

///|
fn array(value : Json, key : String) -> Array[Json] raise {
  match field(value, key) {
    Array(values) => values
    Null => []
    _ => fail("Expected array field: " + key)
  }
}

///|
fn line_safe(value : String) -> Bool {
  value.iter().all(c => c >= ' ' && c != '\u{7f}')
}

///|
fn identifier(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 256 &&
  value
  .iter()
  .all(c => {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_' ||
    c == '-'
  })
}

///|
fn disabled(value : Json) -> Bool raise {
  match field(value, "disabled") {
    Null | False => false
    True => true
    _ => fail("disabled must be boolean")
  }
}

///|
priv struct Position {
  workspace : String
  folders : Array[String]
  path : String
}

///|
fn position(node : Json, nodes : Map[String, Json]) -> Position raise {
  let folders : Array[String] = []
  let names : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  let mut parent = text(node, "parentId")
  for _ in 0..<33 {
    guard !seen.contains(parent) else { fail("Cyclic resource parent graph") }
    seen[parent] = true
    guard nodes.get(parent) is Some(ancestor) else {
      fail("Resource parent is missing: " + parent)
    }
    let kind = text(ancestor, "_type")
    if kind == "workspace" {
      return { workspace: parent, folders, path: names.rev().join("/"), }
    }
    guard kind == "request_group" else {
      fail("Request and folder parents must be workspace or request_group")
    }
    folders.push(parent)
    names.push(text(ancestor, "name"))
    parent = text(ancestor, "parentId")
  }
  fail("Insomnia folder nesting exceeds 32 levels")
}

///|
fn resources(content : String) -> (Json, Array[Json], Map[String, Json]) raise {
  guard @utf8.encode(content).length() <= 4 * 1024 * 1024 else {
    fail("Insomnia input exceeds 4 MiB")
  }
  let root = parse_exact_json(content)
  let format = field(root, "__export_format")
  guard format is Number(_) &&
    exact_integer(format.stringify()) == Some(4L) &&
    (
      field(root, "_type") == Json::null() ||
      field(root, "_type") == Json::string("export")
    ) else {
    fail("Expected legacy Insomnia v4 JSON export; v5 YAML is unsupported")
  }
  guard field(root, "resources") is Array(items) else {
    fail("Insomnia resources must be an array")
  }
  guard items.length() <= 2000 else {
    fail("Insomnia import is limited to 2,000 resources")
  }
  let nodes : Map[String, Json] = Map([])
  for item in items {
    let id = text(item, "_id")
    let kind = text(item, "_type")
    guard identifier(id) && identifier(kind) else {
      fail("Invalid resource ID or type")
    }
    guard !nodes.contains(id) else { fail("Duplicate resource ID: " + id) }
    nodes[id] = item
    if ["workspace", "request_group", "request"].contains(kind) {
      let name = text(item, "name")
      guard !name.is_empty() && line_safe(name) else {
        fail("Resource names must be nonempty single-line text")
      }
      if kind == "workspace" {
        guard field(item, "parentId") == Json::null() else {
          fail("Workspace parent must be null")
        }
      } else {
        guard identifier(text(item, "parentId")) else {
          fail("Invalid parent ID")
        }
      }
    }
  }
  for item in items {
    if ["request", "request_group"].contains(text(item, "_type")) {
      let place = position(item, nodes)
      if text(item, "_type") == "request_group" && place.folders.length() >= 32 {
        fail("Insomnia folder nesting exceeds 32 levels")
      }
    }
  }
  (root, items, nodes)
}
