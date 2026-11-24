///|
fn google_gemini_models() -> Array[String] {
  [
    "gemini-4-hydrogen", "gemini-4-neon", "gemini-4-carbon", "gemini-4-argon", "gemini-3.8-flash",
    "gemini-3.5-flash-lite",
  ]
}

///|
fn ProviderRouteTarget::is_google_gemini(self : ProviderRouteTarget) -> Bool {
  self.base_url
  .unwrap_or("")
  .has_prefix("https://generativelanguage.googleapis.com/")
}

///|
fn google_provider_model_catalog(
  provider : ProviderRouteTarget,
  fallback : String,
) -> Json? {
  if !provider.enabled || !provider.is_google_gemini() {
    return None
  }
  let models = google_gemini_models()
  let default_model = provider.binding_model(fallback)
  if default_model != "" && !models.contains(default_model) {
    models.insert(0, default_model)
  }
  // Supported routing choices, not account quota or a generation receipt.
  // No upstream call is needed on UI polling.
  Some({
    "object": "list",
    "data": Json::array(
      models.map(model => {
        "id": model,
        "object": "model",
        "owned_by": "google",
        "input_modalities": ["text", "image"],
      }),
    ),
  })
}

///|
fn google_compatible_provider_request(
  provider : ProviderRouteTarget,
  request : Json,
) -> Json {
  if !provider.is_google_gemini() {
    return request
  }
  guard request is Object(fields) else { return request }
  // Google's OpenAI endpoint rejects OpenAI's prompt-cache routing hints.
  // Keep the caller's original request intact for retries to other providers.
  let fields = fields.copy()
  fields.remove("prompt_cache_key")
  fields.remove("prompt_cache_retention")
  if fields.get("model") is Some(String(model)) &&
    (model.has_prefix("gemini-3") || model.has_prefix("gemini-4")) &&
    fields.get("reasoning_effort") == Some(Json("none")) {
    // Thinking cannot be disabled on these models. Use the lowest effort
    // shared by Gemini 3/4 instead of forwarding an invalid OpenAI value.
    fields["reasoning_effort"] = Json("low")
  }
  Json::object(fields)
}
