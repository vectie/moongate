///|
pub fn manifest_contract() -> String {
  "moon.suite.service.v1"
}

///|
pub fn status_contract() -> String {
  "moon.suite.status.v1"
}

///|
pub fn service_name() -> String {
  "moonstat"
}

///|
pub fn project_name() -> String {
  "moonstat"
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
