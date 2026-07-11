///|
test "cost calculator keeps claude cache semantics" {
  let pricing = ModelPricing::{
    model_id: "claude-sonnet-4-6",
    display_name: "Claude Sonnet 4.6",
    input_cost_per_million: "3.0",
    output_cost_per_million: "15.0",
    cache_read_cost_per_million: "0.3",
    cache_creation_cost_per_million: "3.75",
  }
  let usage = TokenUsage::new(
    input_tokens=1000,
    output_tokens=500,
    cache_read_tokens=200,
    cache_creation_tokens=100,
  )
  let cost = calculate_cost_for_app("claude", usage, pricing)
  assert_eq(cost.input_cost_usd, "0.003")
  assert_eq(cost.output_cost_usd, "0.0075")
  assert_eq(cost.cache_read_cost_usd, "0.00006")
  assert_eq(cost.cache_creation_cost_usd, "0.000375")
  assert_eq(cost.total_cost_usd, "0.010935")
}

///|
test "cost calculator subtracts cached input for codex and gemini" {
  let pricing = ModelPricing::{
    model_id: "gpt-5",
    display_name: "GPT-5",
    input_cost_per_million: "3.0",
    output_cost_per_million: "15.0",
    cache_read_cost_per_million: "0.3",
    cache_creation_cost_per_million: "3.75",
  }
  let usage = TokenUsage::new(
    input_tokens=1000,
    output_tokens=500,
    cache_read_tokens=200,
    cache_creation_tokens=100,
  )
  let codex = calculate_cost_for_app("codex", usage, pricing)
  let gemini = calculate_cost_for_app("gemini", usage, pricing)
  assert_eq(codex.input_cost_usd, "0.0024")
  assert_eq(codex.total_cost_usd, "0.010335")
  assert_eq(gemini.input_cost_usd, "0.0024")
  assert_eq(gemini.total_cost_usd, "0.010335")
}

///|
test "cost calculator applies multiplier only to total" {
  let pricing = ModelPricing::{
    model_id: "unit",
    display_name: "Unit",
    input_cost_per_million: "3.0",
    output_cost_per_million: "15.0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  }
  let usage = TokenUsage::new(input_tokens=1000, output_tokens=0)
  let cost = calculate_cost_for_app(
    "claude",
    usage,
    pricing,
    cost_multiplier="1.5",
  )
  assert_eq(cost.input_cost_usd, "0.003")
  assert_eq(cost.total_cost_usd, "0.0045")
}

///|
test "cost calculator preserves small decimal rates" {
  let pricing = ModelPricing::{
    model_id: "tiny",
    display_name: "Tiny",
    input_cost_per_million: "0.075",
    output_cost_per_million: "0.3",
    cache_read_cost_per_million: "0.01875",
    cache_creation_cost_per_million: "0.075",
  }
  let usage = TokenUsage::new(
    input_tokens=1,
    output_tokens=1,
    cache_read_tokens=1,
    cache_creation_tokens=1,
  )
  let cost = calculate_cost_for_app("claude", usage, pricing)
  assert_eq(cost.input_cost_usd, "0.000000075")
  assert_eq(cost.output_cost_usd, "0.0000003")
  assert_eq(cost.cache_read_cost_usd, "0.000000019")
  assert_eq(cost.cache_creation_cost_usd, "0.000000075")
  assert_eq(cost.total_cost_usd, "0.000000469")
}

///|
test "model pricing lookup mirrors moongate normalization cases" {
  assert_eq(
    find_static_model_pricing("claude-sonnet-4-5-20250929").unwrap().model_id,
    "claude-sonnet-4-5-20250929",
  )
  assert_eq(
    find_static_model_pricing("moonshotai/kimi-k2-0905:exa").unwrap().model_id,
    "kimi-k2-0905",
  )
  assert_eq(
    find_static_model_pricing("gpt-5.2-codex@low").unwrap().model_id,
    "gpt-5.2-codex-low",
  )
  assert_eq(
    find_static_model_pricing("OpenAI/GPT-5.5@HIGH").unwrap().model_id,
    "gpt-5.5-high",
  )
  assert_eq(
    find_static_model_pricing("OpenAI/GPT-5.5-2026-05-14").unwrap().model_id,
    "gpt-5.5",
  )
  assert_eq(
    find_static_model_pricing("google/gemini-3-pro-preview-20260514").unwrap().model_id,
    "gemini-3-pro-preview",
  )
  assert_eq(
    find_static_model_pricing("claude-haiku-4-5").unwrap().model_id,
    "claude-haiku-4-5-20251001",
  )
  assert_eq(
    find_static_model_pricing("anthropic/claude-opus-4.8").unwrap().model_id,
    "claude-opus-4-8",
  )
  assert_eq(
    find_static_model_pricing("claude-gpt-5.5").unwrap().model_id,
    "gpt-5.5",
  )
  assert_eq(
    find_static_model_pricing("global.anthropic.claude-haiku-4-5-20251001-v1:0").unwrap().model_id,
    "claude-haiku-4-5-20251001",
  )
  assert_eq(
    find_static_model_pricing("global.anthropic.claude-opus-4-8-v1:0").unwrap().model_id,
    "claude-opus-4-8",
  )
  assert_eq(
    find_static_model_pricing("global.anthropic.claude-gpt-5.5-v1:0").unwrap().model_id,
    "gpt-5.5",
  )
  assert_eq(
    find_static_model_pricing("claude-opus-4-8@20260527").unwrap().model_id,
    "claude-opus-4-8",
  )
  assert_eq(
    find_static_model_pricing("gpt-5.4@low").unwrap().model_id,
    "gpt-5.4",
  )
  assert_eq(
    find_static_model_pricing("claude-sonnet-4-6 [1M]").unwrap().model_id,
    "claude-sonnet-4-6-20260217",
  )
  assert_true(find_static_model_pricing("kimi-for-coding") is None)
  assert_true(find_static_model_pricing("unknown-model-123") is None)
  assert_true(find_static_model_pricing("unknown") is None)
  assert_true(find_static_model_pricing("gpt-[1m]-5") is None)
}

///|
test "static model pricing json uses moongate field names" {
  let pricing = static_model_pricing_json()
  guard pricing is Array(rows) else { fail("expected pricing array") }
  guard rows[0] is Object(first) else { fail("expected pricing row") }
  assert_eq(first["modelId"], Json::string("claude-fable-5"))
  assert_eq(first["displayName"], Json::string("Claude Fable 5"))
  assert_eq(first["inputCostPerMillion"], Json::string("10"))
  assert_eq(first["outputCostPerMillion"], Json::string("50"))
  assert_eq(first["cacheReadCostPerMillion"], Json::string("1.00"))
  assert_eq(first["cacheCreationCostPerMillion"], Json::string("12.50"))
}

///|
test "model pricing json merges moongate overrides and delete tombstones" {
  let deleted : Map[String, Bool] = Map([], capacity=0)
  deleted.set("gpt-5", true)
  let pricing = model_pricing_json(
    [mp("custom-model", "A Custom Model", "1", "2", "0.1", "0")],
    deleted,
  )
  guard pricing is Array(rows) else { fail("expected pricing array") }
  let found_custom = rows.any(fn(row) {
    match row {
      Object(obj) =>
        obj["modelId"] == Json::string("custom-model") &&
        obj["displayName"] == Json::string("A Custom Model")
      _ => false
    }
  })
  let found_deleted = rows.any(fn(row) {
    match row {
      Object(obj) => obj["modelId"] == Json::string("gpt-5")
      _ => false
    }
  })
  assert_true(found_custom)
  assert_false(found_deleted)
}
