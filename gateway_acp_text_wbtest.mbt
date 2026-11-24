///|
test "ACP provider checks use the explicit minimal text contract" {
  let request = acp_text_check_request("fixture-model", "Reply hello")
  assert_true(
    request
    is {
      "model": "fixture-model",
      "messages": [{ "role": "user", "content": "Reply hello", .. }],
      "stream": False,
      ..
    },
  )
  let provider = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="acp",
    provider_name="ACP text",
    origin="user",
    provider_type=Some("acp_text"),
    model_mapping=Some(ModelMapping::new(default_model=Some("default"))),
  )
  assert_eq(provider.map_model_for_upstream("other-model"), "other-model")
}

///|
async test "unavailable ACP catalog retains text-only semantics without claiming verification" {
  let provider = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="acp",
    provider_name="ACP text",
    origin="user",
    provider_type=Some("acp_text"),
    model_mapping=Some(ModelMapping::new(default_model=Some("fixture-model"))),
  )
  let catalog = acp_text_provider_model_catalog(provider)
  assert_true(
    catalog
    is Some(
      {
        "data": [
          {
            "id": "fixture-model",
            "moongate": { "text_only": True, "verified": False, .. },
            ..
          },
        ],
        ..
      }
    ),
  )
}
