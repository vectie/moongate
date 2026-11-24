///|
fn google_compatible_provider_request(
  provider : ProviderRouteTarget,
  request : Json,
) -> Json {
  if !provider.base_url
    .unwrap_or("")
    .has_prefix("https://generativelanguage.googleapis.com/") {
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
