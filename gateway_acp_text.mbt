///|
// This is an explicit provider contract, not inference from a model name or
// localhost address. Normal API providers retain their tool/budget behavior.
async fn acp_text_provider_model_catalog(
  provider : ProviderRouteTarget,
) -> Json? {
  if !provider.enabled {
    return None
  }
  let found = @async.with_timeout(2000, () => saved_provider_models(provider)) catch {
    _ => Err("ACP catalog unavailable")
  }
  let models = match found {
    Ok(models) => models
    Err(_) => [{ id: provider.binding_model(""), owned_by: None, }]
  }
  Some({
    "object": "list",
    "data": Json::array(
      models.map(model => {
        "id": model.id,
        "object": "model",
        "owned_by": "acp",
        "input_modalities": ["text"],
        "moongate": {
          "text_only": provider.provider_type != Some("acp"),
          "acp_tools": provider.provider_type == Some("acp"),
          "verified": false,
        },
      }),
    ),
  })
}

///|
fn acp_text_check_request(model : String, prompt : String) -> Json {
  {
    "model": model,
    "messages": [{ "role": "user", "content": prompt }],
    "stream": false,
  }
}
