///|
pub fn manifest_contract() -> String {
  "moon.suite.service.v1"
}

///|
pub fn status_contract() -> String {
  "moon.suite.status.v2"
}

///|
pub fn service_name() -> String {
  "moongate"
}

///|
pub fn product_name() -> String {
  "MoonGate"
}

///|
pub fn project_name() -> String {
  "moongate"
}

///|
pub fn version() -> String {
  "0.1.0"
}

///|
pub fn default_host() -> String {
  "127.0.0.1"
}

///|
pub fn default_port() -> Int {
  15721
}

///|
pub fn default_model() -> String {
  "gpt-5"
}

///|
pub fn ai_session_receipt(
  session_id : String,
  model : String,
  host : String,
  port : Int,
) -> Json {
  {
    "contract_id": "moonsuite.ai-session.v1",
    "session_id": session_id,
    "product_id": "moongate",
    "product_name": product_name(),
    "technical_service_id": service_name(),
    "model": model,
    "openai_base_url": openai_base_url(host, port),
    "authority": "digital-workspace",
    "capabilities": [
      "model-routing", "usage-observation", "provider-health", "bounded-ai-execution",
    ],
    "external_side_effects_authorized": false,
    "physical_actions_authorized": false,
  }
}

///|
pub fn normalize_host(host : String) -> String {
  if host == "0.0.0.0" || host == "::" {
    default_host()
  } else {
    host
  }
}

///|
pub fn base_url(host : String, port : Int) -> String {
  "http://\{normalize_host(host)}:\{port}"
}

///|
pub fn openai_base_url(host : String, port : Int) -> String {
  "\{base_url(host, port)}/v1"
}

///|
pub fn claude_desktop_base_url(host : String, port : Int) -> String {
  "\{base_url(host, port)}/claude-desktop/v1"
}
