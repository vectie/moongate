///|
priv struct StreamCheckConfig {
  timeout_secs : Int
  max_retries : Int
  degraded_threshold_ms : Int
  claude_model : String
  codex_model : String
  gemini_model : String
  test_prompt : String
}

///|
fn StreamCheckConfig::default() -> StreamCheckConfig {
  {
    timeout_secs: 45,
    max_retries: 2,
    degraded_threshold_ms: 6000,
    claude_model: "claude-haiku-4-5-20251001",
    codex_model: "gpt-5.5@low",
    gemini_model: "gemini-3.5-flash",
    test_prompt: "Who are you?",
  }
}

///|
fn StreamCheckConfig::to_json(self : StreamCheckConfig) -> Json {
  {
    "timeoutSecs": Json::number(self.timeout_secs.to_double()),
    "maxRetries": Json::number(self.max_retries.to_double()),
    "degradedThresholdMs": Json::number(self.degraded_threshold_ms.to_double()),
    "claudeModel": Json::string(self.claude_model),
    "codexModel": Json::string(self.codex_model),
    "geminiModel": Json::string(self.gemini_model),
    "testPrompt": Json::string(self.test_prompt),
  }.to_json()
}

///|
fn stream_check_int_request(
  path : StringView,
  obj : Map[String, Json]?,
  camel_key : String,
) -> Int? {
  match obj {
    Some(obj) => {
      let field = obj.get(camel_key)
      match field {
        Some(Number(n, ..)) => return Some(n.trunc().to_int())
        Some(String(value)) =>
          return try @string.parse_int(value, base=10) catch {
            _ => None
          } noraise {
            parsed => Some(parsed)
          }
        _ => ()
      }
    }
    None => ()
  }
  usage_query_int(path, camel_key)
}

///|
fn stream_check_string_request(
  path : StringView,
  obj : Map[String, Json]?,
  camel_key : String,
) -> String? {
  match obj {
    Some(obj) => {
      let field = obj.get(camel_key)
      match field {
        Some(String(value)) => return Some(value)
        _ => ()
      }
    }
    None => ()
  }
  usage_query_value(path, camel_key)
}

///|
fn stream_check_model_for_app(
  config : StreamCheckConfig,
  app_type : String,
) -> String {
  match app_type {
    "claude" | "claude-desktop" => config.claude_model
    "gemini" => config.gemini_model
    _ => config.codex_model
  }
}

///|
fn stream_check_reported_model_for_app(
  config : StreamCheckConfig,
  app_type : String,
) -> String {
  let model = stream_check_model_for_app(config, app_type)
  if app_type == "codex" {
    stream_check_parse_model_with_effort(model).0
  } else {
    model
  }
}

///|
fn stream_check_parse_model_with_effort(model : String) -> (String, String?) {
  let split = match model.find("@") {
    Some(index) => Some(index)
    None => model.find("#")
  }
  match split {
    Some(index) => {
      let effort = model[index + 1:]
      if !effort.is_empty() {
        (model[:index].to_owned(), Some(effort.to_owned()))
      } else {
        (model, None)
      }
    }
    None => (model, None)
  }
}
