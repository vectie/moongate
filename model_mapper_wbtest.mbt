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
