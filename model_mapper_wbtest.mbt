///|
test "ccs model mapping maps claude roles and default" {
  let mapping = ModelMapping::new(
    haiku_model=Some("haiku-mapped"),
    sonnet_model=Some("sonnet-mapped"),
    opus_model=Some("opus-mapped"),
    default_model=Some("default-model"),
  )
  assert_eq(mapping.map_model("claude-haiku-4-5"), "haiku-mapped")
  assert_eq(mapping.map_model("Claude-SONNET-4-6"), "sonnet-mapped")
  assert_eq(mapping.map_model("claude-opus-4-8"), "opus-mapped")
  assert_eq(mapping.map_model("some-unknown-model"), "default-model")
}

///|
test "ccs model mapping ignores empty values" {
  let mapping = ModelMapping::new(
    haiku_model=Some(" "),
    sonnet_model=None,
    opus_model=None,
    default_model=None,
  )
  assert_false(mapping.has_mapping())
  assert_eq(mapping.map_model("claude-haiku-4-5"), "claude-haiku-4-5")
}

///|
test "ccs upstream model strips one million context marker" {
  assert_eq(
    strip_one_m_suffix_for_upstream("deepseek-v4-pro[1M]"),
    "deepseek-v4-pro",
  )
  assert_eq(
    strip_one_m_suffix_for_upstream("deepseek-v4-pro [1m]"),
    "deepseek-v4-pro",
  )
  assert_eq(
    strip_one_m_suffix_for_upstream("deepseek-v4-pro"),
    "deepseek-v4-pro",
  )
}

///|
test "provider route applies ccs mapping before upstream strip" {
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="mapped",
    provider_name="Mapped",
    model_mapping=Some(
      ModelMapping::new(sonnet_model=Some("deepseek-v4-pro [1M]")),
    ),
  )
  assert_eq(
    provider.map_model_for_upstream("claude-sonnet-4-6"),
    "deepseek-v4-pro",
  )
}

///|
test "ccs copilot model normalizer rewrites claude dash versions" {
  assert_eq(
    copilot_normalize_to_upstream_id("claude-sonnet-4-6"),
    Some("claude-sonnet-4.6"),
  )
  assert_eq(
    copilot_normalize_to_upstream_id("claude-opus-4-6"),
    Some("claude-opus-4.6"),
  )
  assert_eq(
    copilot_normalize_to_upstream_id("claude-haiku-4-5"),
    Some("claude-haiku-4.5"),
  )
}

///|
test "ccs copilot model normalizer preserves one million marker as dash suffix" {
  assert_eq(
    copilot_normalize_to_upstream_id("claude-sonnet-4-6[1m]"),
    Some("claude-sonnet-4.6-1m"),
  )
  assert_eq(
    copilot_normalize_to_upstream_id("claude-sonnet-4.6[1M]"),
    Some("claude-sonnet-4.6-1m"),
  )
  assert_eq(
    copilot_normalize_to_upstream_id("claude-haiku-4-5-20251001[1m]"),
    Some("claude-haiku-4.5-1m"),
  )
}

///|
test "ccs copilot model normalizer strips trailing date suffix" {
  assert_eq(
    copilot_normalize_to_upstream_id("claude-haiku-4-5-20251001"),
    Some("claude-haiku-4.5"),
  )
  assert_eq(
    copilot_normalize_to_upstream_id("claude-sonnet-4-5-20250929"),
    Some("claude-sonnet-4.5"),
  )
}

///|
test "ccs copilot model normalizer leaves already valid and non claude ids" {
  assert_eq(copilot_normalize_to_upstream_id("claude-sonnet-4.6"), None)
  assert_eq(copilot_normalize_to_upstream_id("claude-opus-4.6-1m"), None)
  assert_eq(copilot_normalize_to_upstream_id("gpt-5"), None)
  assert_eq(copilot_normalize_to_upstream_id(""), None)
  assert_eq(copilot_normalize_to_upstream_id("claude-3-5-sonnet"), None)
  assert_eq(
    copilot_normalize_to_upstream_id("claude-3-5-sonnet-20241022"),
    None,
  )
}

///|
test "ccs copilot live model resolver exact matches after normalization" {
  assert_eq(
    copilot_resolve_against_model_ids("claude-sonnet-4-6", [
      "claude-sonnet-4.6", "claude-opus-4.6", "claude-haiku-4.5",
    ]),
    Some("claude-sonnet-4.6"),
  )
  assert_eq(
    copilot_resolve_against_model_ids("claude-sonnet-4.6", ["claude-sonnet-4.6"]),
    None,
  )
}

///|
test "ccs copilot live model resolver falls back by family and version" {
  assert_eq(
    copilot_resolve_against_model_ids("claude-opus-4.8", [
      "claude-opus-4.5", "claude-opus-4.6", "claude-sonnet-4.6",
    ]),
    Some("claude-opus-4.6"),
  )
  assert_eq(
    copilot_resolve_against_model_ids("claude-sonnet-4-6[1m]", [
      "claude-sonnet-4.6", "claude-sonnet-4.6-1m", "claude-opus-4.6",
    ]),
    Some("claude-sonnet-4.6-1m"),
  )
  assert_eq(
    copilot_resolve_against_model_ids("claude-sonnet-4-6[1m]", [
      "claude-sonnet-4.6",
    ]),
    Some("claude-sonnet-4.6"),
  )
  assert_eq(
    copilot_resolve_against_model_ids("claude-opus-4.6", [
      "claude-sonnet-4.6", "claude-haiku-4.5",
    ]),
    None,
  )
}

///|
test "ccs copilot live model resolver accepts raw models json" {
  let raw = Json::object({
    "data": Json::array([
      Json::object({
        "id": Json::string("claude-sonnet-4.4"),
        "name": Json::string("disabled"),
        "vendor": Json::string("anthropic"),
        "model_picker_enabled": Json::boolean(false),
      }),
      Json::object({
        "id": Json::string("claude-sonnet-4.6"),
        "name": Json::string("Sonnet"),
        "vendor": Json::string("anthropic"),
        "model_picker_enabled": Json::boolean(true),
      }),
    ]),
  })
  assert_eq(copilot_model_ids_from_models_json(raw), ["claude-sonnet-4.6"])
  assert_eq(
    copilot_resolve_against_models_json("claude-sonnet-4-6", raw),
    Some("claude-sonnet-4.6"),
  )
}

///|
test "ccs copilot live model resolver accepts moonstat models array" {
  let models = [
    Json::object({
      "id": Json::string("claude-opus-4.5"),
      "name": Json::string("Opus 4.5"),
      "vendor": Json::string("anthropic"),
      "model_picker_enabled": Json::boolean(true),
    }),
    Json::object({
      "id": Json::string("claude-opus-4.6"),
      "name": Json::string("Opus 4.6"),
      "vendor": Json::string("anthropic"),
      "model_picker_enabled": Json::boolean(true),
    }),
  ]
  assert_eq(
    copilot_resolve_against_models_json("claude-opus-4.8", Json::array(models)),
    Some("claude-opus-4.6"),
  )
}

///|
test "github copilot provider applies ccs upstream model normalization" {
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot",
    provider_name="GitHub Copilot",
    provider_type=Some("github_copilot"),
  )
  assert_eq(
    provider.map_model_for_upstream("claude-sonnet-4-6[1m]"),
    "claude-sonnet-4.6-1m",
  )
  let url_provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot-url",
    provider_name="GitHub Copilot URL",
    base_url=Some("https://api.githubcopilot.com/chat/completions"),
  )
  assert_eq(
    url_provider.map_model_for_upstream("claude-haiku-4-5-20251001"),
    "claude-haiku-4.5",
  )
}
