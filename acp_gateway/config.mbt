///|
pub(all) suberror BridgeError {
  BridgeError(code~ : Int32, kind~ : String, message~ : String)
} derive(Debug)

///|
pub extend BridgeError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// An explicitly configured, local ACP subprocess. No provider tokens are read
/// or copied: the agent owns its own authentication and licensing.
pub struct Bridge {
  priv command : String
  priv args : Array[String]
  priv cwd : String
  priv token : String
  priv models : Array[String]
  priv timeout_ms : Int32
  priv max_concurrent : Int32
  priv mut active : Int32
  priv mut sequence : Int32
}

///|
fn invalid_config(message : String) -> BridgeError {
  BridgeError(code=400, kind="invalid_acp_config", message~)
}

///|
fn strings(value : Json) -> Array[String]? {
  guard value is Array(items) else { return None }
  let result = []
  for item in items {
    guard item is String(text) && !text.contains("\u0000") else { return None }
    result.push(text)
  }
  Some(result)
}

///|
/// Parse a private JSON configuration. Command and cwd must be absolute paths;
/// arguments are passed directly, never interpreted by a shell. Models are an
/// allowlist, verified against each new agent session before prompting.
pub fn Bridge::from_json(config : Json) -> Bridge raise BridgeError {
  guard config
    is {
      "command": String(command),
      "args": args_json,
      "cwd": String(cwd),
      "token": String(token),
      "models": models_json,
      ..
    } else {
    raise invalid_config("Expected command, args, cwd, token and models")
  }
  guard command.has_prefix("/") &&
    cwd.has_prefix("/") &&
    !command.contains("\u0000") &&
    !cwd.contains("\u0000") else {
    raise invalid_config("command and cwd must be absolute local paths")
  }
  guard token.length() >= 16 &&
    token.length() <= 4096 &&
    token.iter().all(c => c >= '!' && c <= '~') else {
    raise invalid_config(
      "Use a local bearer token of at least 16 printable characters",
    )
  }
  guard strings(args_json) is Some(args) &&
    strings(models_json) is Some(models) &&
    !models.is_empty() &&
    models.iter().all(model => !model.is_empty()) else {
    raise invalid_config("args and nonempty models must be string arrays")
  }
  let timeout_ms = match config {
    { "timeout_ms": Number(n, ..), .. } if n >= 100 &&
      n <= 600000 &&
      n == n.to_int().to_double() => n.to_int()
    { "timeout_ms"? : None, .. } => 120000
    _ =>
      raise invalid_config("timeout_ms must be an integer from 100 to 600000")
  }
  let max_concurrent = match config {
    { "max_concurrent": Number(n, ..), .. } if n >= 1 &&
      n <= 16 &&
      n == n.to_int().to_double() => n.to_int()
    { "max_concurrent"? : None, .. } => 4
    _ => raise invalid_config("max_concurrent must be an integer from 1 to 16")
  }
  {
    command,
    args,
    cwd,
    token,
    models,
    timeout_ms,
    max_concurrent,
    active: 0,
    sequence: 0,
  }
}
