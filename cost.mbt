///|
const DECIMAL_SCALE : Int64 = 1_000_000L

///|
const NANO_USD_SCALE : Int64 = 1_000_000_000L

///|
pub struct ModelPricing {
  model_id : String
  display_name : String
  input_cost_per_million : String
  output_cost_per_million : String
  cache_read_cost_per_million : String
  cache_creation_cost_per_million : String
}

///|
pub struct CostBreakdown {
  input_cost_usd : String
  output_cost_usd : String
  cache_read_cost_usd : String
  cache_creation_cost_usd : String
  total_cost_usd : String
}

///|
pub fn calculate_cost_for_app(
  app_type : String,
  usage : TokenUsage,
  pricing : ModelPricing,
  cost_multiplier? : String = "1.0",
) -> CostBreakdown {
  let input_includes_cache_read = app_type == "codex" || app_type == "gemini"
  let billable_input_tokens = if input_includes_cache_read {
    max_int(usage.input_tokens - usage.cache_read_tokens, 0)
  } else {
    usage.input_tokens
  }
  let input_cost_nano = calculate_token_cost_nano(
    billable_input_tokens,
    pricing.input_cost_per_million,
  )
  let output_cost_nano = calculate_token_cost_nano(
    usage.output_tokens,
    pricing.output_cost_per_million,
  )
  let cache_read_cost_nano = calculate_token_cost_nano(
    usage.cache_read_tokens,
    pricing.cache_read_cost_per_million,
  )
  let cache_creation_cost_nano = calculate_token_cost_nano(
    usage.cache_creation_tokens,
    pricing.cache_creation_cost_per_million,
  )
  let base_total_nano = input_cost_nano +
    output_cost_nano +
    cache_read_cost_nano +
    cache_creation_cost_nano
  let total_cost_nano = multiply_scaled_nano(
    base_total_nano,
    parse_decimal_scaled(cost_multiplier, DECIMAL_SCALE),
  )
  {
    input_cost_usd: format_nano_usd(input_cost_nano),
    output_cost_usd: format_nano_usd(output_cost_nano),
    cache_read_cost_usd: format_nano_usd(cache_read_cost_nano),
    cache_creation_cost_usd: format_nano_usd(cache_creation_cost_nano),
    total_cost_usd: format_nano_usd(total_cost_nano),
  }
}

///|
pub fn find_static_model_pricing(model_id : String) -> ModelPricing? {
  let candidates = model_pricing_candidates(model_id)
  let table = static_model_pricing()
  for candidate in candidates {
    for pricing in table {
      if pricing.model_id == candidate {
        return Some(pricing)
      }
    }
  }
  for candidate in candidates {
    if should_try_pricing_prefix_match(candidate) {
      let prefix = "\{candidate}-"
      let mut best : ModelPricing? = None
      for pricing in table {
        if pricing.model_id.has_prefix(prefix) {
          match best {
            Some(existing) if existing.model_id.length() <=
              pricing.model_id.length() => ()
            _ => best = Some(pricing)
          }
        }
      }
      if best is Some(_) {
        return best
      }
    }
  }
  None
}

///|
pub fn static_model_pricing_json() -> Json {
  Json::array(static_model_pricing().map(fn(pricing) { pricing.to_json() }))
}

///|
fn ModelPricing::to_json(self : ModelPricing) -> Json {
  {
    "modelId": Json::string(self.model_id),
    "displayName": Json::string(self.display_name),
    "inputCostPerMillion": Json::string(self.input_cost_per_million),
    "outputCostPerMillion": Json::string(self.output_cost_per_million),
    "cacheReadCostPerMillion": Json::string(self.cache_read_cost_per_million),
    "cacheCreationCostPerMillion": Json::string(
      self.cache_creation_cost_per_million,
    ),
  }.to_json()
}

///|
fn static_model_pricing() -> Array[ModelPricing] {
  [
    mp("claude-fable-5", "Claude Fable 5", "10", "50", "1.00", "12.50"),
    mp("claude-mythos-5", "Claude Mythos 5", "10", "50", "1.00", "12.50"),
    mp("claude-opus-4-8", "Claude Opus 4.8", "5", "25", "0.50", "6.25"),
    mp("claude-opus-4-7", "Claude Opus 4.7", "5", "25", "0.50", "6.25"),
    mp("claude-opus-4-6-20260206", "Claude Opus 4.6", "5", "25", "0.50", "6.25"),
    mp(
      "claude-sonnet-4-6-20260217", "Claude Sonnet 4.6", "3", "15", "0.30", "3.75",
    ),
    mp("claude-opus-4-5-20251101", "Claude Opus 4.5", "5", "25", "0.50", "6.25"),
    mp(
      "claude-sonnet-4-5-20250929", "Claude Sonnet 4.5", "3", "15", "0.30", "3.75",
    ),
    mp(
      "claude-haiku-4-5-20251001", "Claude Haiku 4.5", "1", "5", "0.10", "1.25",
    ),
    mp("claude-opus-4-20250514", "Claude Opus 4", "15", "75", "1.50", "18.75"),
    mp(
      "claude-opus-4-1-20250805", "Claude Opus 4.1", "15", "75", "1.50", "18.75",
    ),
    mp("claude-sonnet-4-20250514", "Claude Sonnet 4", "3", "15", "0.30", "3.75"),
    mp(
      "claude-3-5-haiku-20241022", "Claude 3.5 Haiku", "0.80", "4", "0.08", "1",
    ),
    mp(
      "claude-3-5-sonnet-20241022", "Claude 3.5 Sonnet", "3", "15", "0.30", "3.75",
    ),
    mp("gpt-5.5", "GPT-5.5", "5", "30", "0.50", "0"),
    mp("gpt-5.5-low", "GPT-5.5", "5", "30", "0.50", "0"),
    mp("gpt-5.5-medium", "GPT-5.5", "5", "30", "0.50", "0"),
    mp("gpt-5.5-high", "GPT-5.5", "5", "30", "0.50", "0"),
    mp("gpt-5.5-xhigh", "GPT-5.5", "5", "30", "0.50", "0"),
    mp("gpt-5.5-minimal", "GPT-5.5", "5", "30", "0.50", "0"),
    mp("gpt-5.4", "GPT-5.4", "2.50", "15", "0.25", "0"),
    mp("gpt-5.4-mini", "GPT-5.4 Mini", "0.75", "4.50", "0.075", "0"),
    mp("gpt-5.4-nano", "GPT-5.4 Nano", "0.20", "1.25", "0.02", "0"),
    mp("gpt-5.2", "GPT-5.2", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-low", "GPT-5.2", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-medium", "GPT-5.2", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-high", "GPT-5.2", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-xhigh", "GPT-5.2", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-codex", "GPT-5.2 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-codex-low", "GPT-5.2 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-codex-medium", "GPT-5.2 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-codex-high", "GPT-5.2 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.2-codex-xhigh", "GPT-5.2 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.3-codex", "GPT-5.3 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.3-codex-low", "GPT-5.3 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.3-codex-medium", "GPT-5.3 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.3-codex-high", "GPT-5.3 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.3-codex-xhigh", "GPT-5.3 Codex", "1.75", "14", "0.175", "0"),
    mp("gpt-5.1", "GPT-5.1", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-low", "GPT-5.1", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-medium", "GPT-5.1", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-high", "GPT-5.1", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-minimal", "GPT-5.1", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-codex", "GPT-5.1 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-codex-mini", "GPT-5.1 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-codex-max", "GPT-5.1 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-codex-max-high", "GPT-5.1 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5.1-codex-max-xhigh", "GPT-5.1 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5", "GPT-5", "1.25", "10", "0.125", "0"),
    mp("gpt-5-low", "GPT-5", "1.25", "10", "0.125", "0"),
    mp("gpt-5-medium", "GPT-5", "1.25", "10", "0.125", "0"),
    mp("gpt-5-high", "GPT-5", "1.25", "10", "0.125", "0"),
    mp("gpt-5-minimal", "GPT-5", "1.25", "10", "0.125", "0"),
    mp("gpt-5-codex", "GPT-5 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5-codex-low", "GPT-5 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5-codex-medium", "GPT-5 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5-codex-high", "GPT-5 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5-codex-mini", "GPT-5 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5-codex-mini-medium", "GPT-5 Codex", "1.25", "10", "0.125", "0"),
    mp("gpt-5-codex-mini-high", "GPT-5 Codex", "1.25", "10", "0.125", "0"),
    mp("o3", "OpenAI o3", "2", "8", "0.50", "0"),
    mp("o4-mini", "OpenAI o4-mini", "1.10", "4.40", "0.275", "0"),
    mp("gpt-4.1", "GPT-4.1", "2", "8", "0.50", "0"),
    mp("gpt-4.1-mini", "GPT-4.1 Mini", "0.40", "1.60", "0.10", "0"),
    mp("gpt-4.1-nano", "GPT-4.1 Nano", "0.10", "0.40", "0.025", "0"),
    mp("gemini-3.5-flash", "Gemini 3.5 Flash", "1.50", "9.00", "0.15", "0"),
    mp(
      "gemini-3.1-pro-preview", "Gemini 3.1 Pro Preview", "2", "12", "0.20", "0",
    ),
    mp(
      "gemini-3.1-flash-lite", "Gemini 3.1 Flash Lite", "0.25", "1.50", "0.025",
      "0",
    ),
    mp(
      "gemini-3.1-flash-lite-preview", "Gemini 3.1 Flash Lite Preview", "0.25", "1.50",
      "0.025", "0",
    ),
    mp("gemini-3-pro-preview", "Gemini 3 Pro Preview", "2", "12", "0.2", "0"),
    mp(
      "gemini-3-flash-preview", "Gemini 3 Flash Preview", "0.5", "3", "0.05", "0",
    ),
    mp("gemini-2.5-pro", "Gemini 2.5 Pro", "1.25", "10", "0.125", "0"),
    mp("gemini-2.5-flash", "Gemini 2.5 Flash", "0.3", "2.5", "0.03", "0"),
    mp(
      "gemini-2.5-flash-lite", "Gemini 2.5 Flash Lite", "0.10", "0.40", "0.01", "0",
    ),
    mp("gemini-2.0-flash", "Gemini 2.0 Flash", "0.10", "0.40", "0.025", "0"),
    mp("step-3.7-flash", "Step 3.7 Flash", "0.19", "1.13", "0.04", "0"),
    mp("step-3.5-flash", "Step 3.5 Flash", "0.10", "0.30", "0.02", "0"),
    mp(
      "step-3.5-flash-2603", "Step 3.5 Flash 2603", "0.10", "0.30", "0.02", "0",
    ),
    mp("doubao-seed-code", "Doubao Seed Code", "0.17", "1.11", "0.02", "0"),
    mp(
      "doubao-seed-2-0-pro", "Doubao Seed 2.0 Pro", "0.47", "2.37", "0.09", "0",
    ),
    mp(
      "doubao-seed-2-0-code", "Doubao Seed 2.0 Code", "0.47", "2.37", "0.09", "0",
    ),
    mp(
      "doubao-seed-2-0-code-preview-latest", "Doubao Seed 2.0 Code Preview", "0.47",
      "2.37", "0.09", "0",
    ),
    mp(
      "doubao-seed-2-0-lite", "Doubao Seed 2.0 Lite", "0.08", "0.50", "0.017", "0",
    ),
    mp(
      "doubao-seed-2-0-mini", "Doubao Seed 2.0 Mini", "0.03", "0.31", "0.0056", "0",
    ),
    mp("deepseek-v3.2", "DeepSeek V3.2", "0.28", "0.42", "0.028", "0"),
    mp("deepseek-v3.1", "DeepSeek V3.1", "0.55", "1.67", "0.055", "0"),
    mp("deepseek-v3", "DeepSeek V3", "0.28", "1.11", "0.028", "0"),
    mp("deepseek-chat", "DeepSeek Chat", "0.27", "1.10", "0.07", "0"),
    mp("deepseek-reasoner", "DeepSeek Reasoner", "0.55", "2.19", "0.14", "0"),
    mp("deepseek-v4-flash", "DeepSeek V4 Flash", "0.14", "0.28", "0.0028", "0"),
    mp("deepseek-v4-pro", "DeepSeek V4 Pro", "0.435", "0.87", "0.003625", "0"),
    mp("kimi-k2-thinking", "Kimi K2 Thinking", "0.55", "2.20", "0.10", "0"),
    mp("kimi-k2-0905", "Kimi K2", "0.55", "2.20", "0.10", "0"),
    mp("kimi-k2-turbo", "Kimi K2 Turbo", "1.11", "8.06", "0.14", "0"),
    mp("kimi-k2.5", "Kimi K2.5", "0.60", "3.00", "0.10", "0"),
    mp("kimi-k2.6", "Kimi K2.6", "0.95", "4.00", "0.16", "0"),
    mp("minimax-m2.1", "MiniMax M2.1", "0.27", "0.95", "0.03", "0"),
    mp(
      "minimax-m2.1-lightning", "MiniMax M2.1 Lightning", "0.27", "2.33", "0.03",
      "0",
    ),
    mp("minimax-m2", "MiniMax M2", "0.27", "0.95", "0.03", "0"),
    mp("minimax-m2.5", "MiniMax M2.5", "0.15", "0.95", "0.03", "0"),
    mp(
      "minimax-m2.5-lightning", "MiniMax M2.5 Lightning", "0.30", "2.40", "0.03",
      "0",
    ),
    mp("minimax-m2.7", "MiniMax M2.7", "0.30", "1.20", "0.06", "0.375"),
    mp(
      "minimax-m2.7-highspeed", "MiniMax M2.7 Highspeed", "0.60", "2.40", "0.06",
      "0.375",
    ),
    mp("minimax-m3", "MiniMax M3", "0.60", "2.40", "0.12", "0"),
    mp("glm-4.7", "GLM-4.7", "0.6", "2.2", "0.11", "0"),
    mp("glm-4.6", "GLM-4.6", "0.6", "2.2", "0.11", "0"),
    mp("glm-5", "GLM-5", "1", "3.2", "0.2", "0"),
    mp("glm-5.1", "GLM-5.1", "1.4", "4.4", "0.26", "0"),
    mp("mimo-v2-flash", "MiMo V2 Flash", "0.09", "0.29", "0.009", "0"),
    mp("mimo-v2-pro", "MiMo V2 Pro", "0.435", "0.87", "0.0036", "0"),
    mp("mimo-v2.5", "MiMo V2.5", "0.14", "0.29", "0.0028", "0"),
    mp("mimo-v2.5-pro", "MiMo V2.5 Pro", "0.435", "0.87", "0.0036", "0"),
    mp("qwen3.7-max", "Qwen3.7 Max", "2.50", "7.50", "0.25", "0"),
    mp("qwen3.7-plus", "Qwen3.7 Plus", "0.40", "1.60", "0.08", "0"),
    mp("qwen3.6-plus", "Qwen3.6 Plus", "0.325", "1.95", "0.065", "0"),
    mp("qwen3.5-plus", "Qwen3.5 Plus", "0.26", "1.56", "0.052", "0"),
    mp("qwen3-max", "Qwen3 Max", "0.78", "3.90", "0", "0"),
    mp("qwen3-235b-a22b", "Qwen3 235B-A22B", "0.70", "8.40", "0", "0"),
    mp("qwen3-coder-plus", "Qwen3 Coder Plus", "0.65", "3.25", "0.13", "0"),
    mp("qwen3-coder-480b", "Qwen3 Coder 480B", "0.65", "3.25", "0", "0"),
    mp(
      "qwen3-coder-480b-a35b-instruct", "Qwen3 Coder 480B-A35B Instruct", "0.65",
      "3.25", "0", "0",
    ),
    mp("qwen3-coder-flash", "Qwen3 Coder Flash", "0.195", "0.975", "0.039", "0"),
    mp("qwen3-coder-next", "Qwen3 Coder Next", "0.12", "0.75", "0", "0"),
    mp("qwq-plus", "QwQ Plus", "0.80", "2.40", "0", "0"),
    mp("qwq-32b", "QwQ 32B", "0.20", "0.60", "0", "0"),
    mp("qwen3-32b", "Qwen3 32B", "0.16", "0.64", "0", "0"),
    mp("grok-4.3", "Grok 4.3", "1.25", "2.50", "0.20", "0"),
    mp(
      "grok-4.20-0309-reasoning", "Grok 4.20 Reasoning", "1.25", "2.50", "0.20",
      "0",
    ),
    mp("grok-4.20-0309-non-reasoning", "Grok 4.20", "1.25", "2.50", "0.20", "0"),
    mp(
      "grok-4-1-fast-reasoning", "Grok 4.1 Fast Reasoning", "0.20", "0.50", "0.05",
      "0",
    ),
    mp(
      "grok-4-1-fast-non-reasoning", "Grok 4.1 Fast", "0.20", "0.50", "0.05", "0",
    ),
    mp("grok-4", "Grok 4", "3", "15", "0.75", "0"),
    mp(
      "grok-code-fast-1", "Grok Build 0.1 (Code Fast Alias)", "1", "2", "0.20", "0",
    ),
    mp("grok-build-0.1", "Grok Build 0.1", "1", "2", "0.20", "0"),
    mp("grok-3", "Grok 3", "3", "15", "0.75", "0"),
    mp("grok-3-mini", "Grok 3 Mini", "0.25", "0.50", "0.075", "0"),
    mp("mistral-medium-3.5", "Mistral Medium 3.5", "1.50", "7.50", "0", "0"),
    mp("mistral-small-4", "Mistral Small 4", "0.10", "0.30", "0.01", "0"),
    mp("devstral-small-2-2512", "Devstral Small 2", "0.10", "0.30", "0.01", "0"),
    mp("magistral-small", "Magistral Small", "0.50", "1.50", "0", "0"),
    mp("codestral-2508", "Codestral", "0.30", "0.90", "0.03", "0"),
    mp("devstral-small-1.1", "Devstral Small 1.1", "0.07", "0.28", "0.01", "0"),
    mp("devstral-2-2512", "Devstral 2", "0.40", "2", "0.04", "0"),
    mp("devstral-medium", "Devstral Medium", "0.40", "2", "0.04", "0"),
    mp("mistral-large-3-2512", "Mistral Large 3", "0.50", "1.50", "0.05", "0"),
    mp("mistral-medium-3.1", "Mistral Medium 3.1", "0.40", "2", "0.04", "0"),
    mp(
      "mistral-small-3.2-24b", "Mistral Small 3.2", "0.075", "0.20", "0.01", "0",
    ),
    mp("magistral-medium", "Magistral Medium", "2", "5", "0", "0"),
    mp("command-a", "Cohere Command A", "2.50", "10", "0", "0"),
    mp("command-r-plus", "Cohere Command R+", "2.50", "10", "0", "0"),
    mp("command-r", "Cohere Command R", "0.15", "0.60", "0", "0"),
    mp("o3-pro", "OpenAI o3-pro", "20", "80", "0", "0"),
    mp("o3-mini", "OpenAI o3-mini", "0.55", "2.20", "0.55", "0"),
    mp("o1", "OpenAI o1", "15", "60", "7.50", "0"),
    mp("o1-mini", "OpenAI o1-mini", "0.55", "2.20", "0.55", "0"),
    mp("codex-mini", "Codex Mini", "0.75", "3", "0.025", "0"),
    mp("gpt-5-mini", "GPT-5 Mini", "0.25", "2", "0.025", "0"),
    mp("gpt-5-nano", "GPT-5 Nano", "0.05", "0.40", "0.005", "0"),
  ]
}

///|
fn mp(
  model_id : String,
  display_name : String,
  input : String,
  output : String,
  cache_read : String,
  cache_creation : String,
) -> ModelPricing {
  {
    model_id,
    display_name,
    input_cost_per_million: input,
    output_cost_per_million: output,
    cache_read_cost_per_million: cache_read,
    cache_creation_cost_per_million: cache_creation,
  }
}

///|
fn model_pricing_candidates(model_id : String) -> Array[String] {
  let candidates : Array[String] = []
  let base = clean_model_id_for_pricing(model_id)
  ignore(push_unique_candidate(candidates, base))
  if strip_known_model_namespace(base) is Some(candidate) {
    ignore(push_unique_candidate(candidates, candidate))
  }
  if strip_claude_desktop_non_anthropic_prefix(base) is Some(candidate) {
    ignore(push_unique_candidate(candidates, candidate))
  }
  for candidate in candidates.copy() {
    if strip_bedrock_model_version_suffix(candidate) is Some(stripped) {
      ignore(push_unique_candidate(candidates, stripped))
    }
    if strip_model_date_suffix(candidate) is Some(stripped) {
      ignore(push_unique_candidate(candidates, stripped))
    }
    if strip_reasoning_effort_suffix(candidate) is Some(stripped) {
      ignore(push_unique_candidate(candidates, stripped))
    }
    if candidate.has_prefix("claude-") && candidate.contains(".") {
      ignore(
        push_unique_candidate(
          candidates,
          candidate.replace(old=".", new="-").to_string(),
        ),
      )
    }
  }
  candidates
}

///|
fn clean_model_id_for_pricing(model_id : String) -> String {
  let mut normalized = model_id.trim().to_lower().to_owned()
  if normalized.rev_find("/") is Some(index) {
    normalized = normalized[index + 1:].to_owned()
  }
  if normalized.find(":") is Some(index) {
    normalized = normalized[:index].to_owned()
  }
  normalized = normalized.replace(old="@", new="-").to_string()
  strip_one_m_context_marker(normalized).trim().to_owned()
}

///|
fn strip_one_m_context_marker(model_id : String) -> String {
  model_id.replace(old="[1m]", new="").replace(old="[1M]", new="").to_string()
}

///|
fn push_unique_candidate(
  candidates : Array[String],
  candidate : String,
) -> Bool {
  if candidate.is_empty() || candidates.contains(candidate) {
    false
  } else {
    candidates.push(candidate)
    true
  }
}

///|
fn strip_known_model_namespace(model_id : String) -> String? {
  match model_id.rev_find("claude-") {
    Some(pos) if pos > 0 => return Some(model_id[pos:].to_owned())
    _ => ()
  }
  for
    marker in [
      "openai.", "anthropic.", "google.", "moonshot.", "moonshotai.", "bedrock.",
      "global.",
    ] {
    if model_id.has_prefix(marker) {
      return Some(model_id[marker.length():].to_owned())
    }
  }
  None
}

///|
fn strip_claude_desktop_non_anthropic_prefix(model_id : String) -> String? {
  if !model_id.has_prefix("claude-") {
    return None
  }
  let rest = model_id["claude-".length():].to_owned()
  for
    marker in [
      "abab", "ark-code", "arctic", "astron", "codex", "command-r", "deepseek", "doubao",
      "ernie", "gemini", "gemma", "glm", "gpt", "grok", "hermes", "hy3", "hunyuan",
      "jamba", "kimi", "lfm", "llama", "longcat", "mercury", "mimo", "minimax", "mistral",
      "mixtral", "moonshot", "nemotron", "nova-", "openai", "qianfan", "qwen", "seed-",
      "solar", "stepfun",
    ] {
    if rest.has_prefix(marker) {
      return Some(rest)
    }
  }
  None
}

///|
fn strip_bedrock_model_version_suffix(model_id : String) -> String? {
  guard model_id.rev_find("-v") is Some(index) else { return None }
  let base = model_id[:index].to_owned()
  let suffix = model_id[index + 2:].to_owned()
  if !base.is_empty() && !suffix.is_empty() && is_ascii_digits(suffix) {
    Some(base)
  } else {
    None
  }
}

///|
fn strip_model_date_suffix(model_id : String) -> String? {
  if model_id.length() > 11 {
    let start = model_id.length() - 11
    let suffix = model_id[start:].to_owned()
    if suffix.length() == 11 &&
      suffix[0] == '-' &&
      is_ascii_digits(suffix[1:5].to_owned()) &&
      suffix[5] == '-' &&
      is_ascii_digits(suffix[6:8].to_owned()) &&
      suffix[8] == '-' &&
      is_ascii_digits(suffix[9:11].to_owned()) {
      return Some(model_id[:start].to_owned())
    }
  }
  guard model_id.rev_find("-") is Some(index) else { return None }
  let base = model_id[:index].to_owned()
  let suffix = model_id[index + 1:].to_owned()
  if !base.is_empty() && suffix.length() == 8 && is_ascii_digits(suffix) {
    Some(base)
  } else {
    None
  }
}

///|
fn strip_reasoning_effort_suffix(model_id : String) -> String? {
  for suffix in ["-minimal", "-low", "-medium", "-high", "-xhigh"] {
    if model_id.has_suffix(suffix) {
      let stripped = model_id[:model_id.length() - suffix.length()].to_owned()
      if !stripped.is_empty() {
        return Some(stripped)
      }
    }
  }
  None
}

///|
fn should_try_pricing_prefix_match(model_id : String) -> Bool {
  let dash_count = count_char(model_id, '-')
  if model_id.has_prefix("claude-") {
    return dash_count >= 3
  }
  for prefix in ["o1", "o3", "o4", "o5"] {
    if model_id.has_prefix(prefix) {
      return dash_count >= 1
    }
  }
  for
    prefix in [
      "gpt-", "gemini-", "deepseek-", "qwen-", "glm-", "kimi-", "minimax-",
    ] {
    if model_id.has_prefix(prefix) && dash_count >= 2 {
      return true
    }
  }
  false
}

///|
fn calculate_token_cost_nano(tokens : Int, rate_per_million : String) -> Int64 {
  divide_rounded(
    tokens.to_int64() * parse_decimal_scaled(rate_per_million, DECIMAL_SCALE),
    1000L,
  )
}

///|
fn multiply_scaled_nano(nano : Int64, multiplier_scaled : Int64) -> Int64 {
  divide_rounded(nano * multiplier_scaled, DECIMAL_SCALE)
}

///|
fn divide_rounded(value : Int64, divisor : Int64) -> Int64 {
  if value >= 0L {
    (value + divisor / 2) / divisor
  } else {
    (value - divisor / 2) / divisor
  }
}

///|
fn parse_decimal_scaled(value : String, scale : Int64) -> Int64 {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return 0L
  }
  let negative = trimmed.has_prefix("-")
  let unsigned = if negative { trimmed[1:].to_owned() } else { trimmed }
  let dot = unsigned.find(".")
  let whole = match dot {
    Some(index) => parse_digits(unsigned[:index].to_owned())
    None => parse_digits(unsigned)
  }
  let fraction = match dot {
    Some(index) => parse_fraction_scaled(unsigned[index + 1:].to_owned(), scale)
    None => 0
  }
  let scaled = whole * scale + fraction
  if negative {
    0L - scaled
  } else {
    scaled
  }
}

///|
fn parse_digits(value : String) -> Int64 {
  let mut result = 0L
  for ch in value {
    let code = ch.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      result = result * 10L + (code - '0'.to_int()).to_int64()
    }
  }
  result
}

///|
fn parse_fraction_scaled(value : String, scale : Int64) -> Int64 {
  let mut result = 0L
  let mut factor = scale / 10L
  for ch in value {
    if factor == 0L {
      break
    }
    let code = ch.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      result += (code - '0'.to_int()).to_int64() * factor
      factor = factor / 10L
    } else {
      break
    }
  }
  result
}

///|
fn format_nano_usd(nano : Int64) -> String {
  if nano == 0L {
    return "0"
  }
  let negative = nano < 0L
  let absolute = if negative { 0L - nano } else { nano }
  let whole = absolute / NANO_USD_SCALE
  let fraction = absolute % NANO_USD_SCALE
  let sign = if negative { "-" } else { "" }
  if fraction == 0L {
    return "\{sign}\{whole}"
  }
  let frac = trim_trailing_zeroes(left_pad_zeroes(fraction.to_string(), 9))
  "\{sign}\{whole}.\{frac}"
}

///|
fn format_nano_usd_fixed_6(nano : Int64) -> String {
  let negative = nano < 0L
  let absolute = if negative { 0L - nano } else { nano }
  let micro = divide_rounded(absolute, 1000L)
  let whole = micro / 1_000_000L
  let fraction = micro % 1_000_000L
  let sign = if negative { "-" } else { "" }
  "\{sign}\{whole}.\{left_pad_zeroes(fraction.to_string(), 6)}"
}

///|
fn left_pad_zeroes(value : String, width : Int) -> String {
  if value.length() >= width {
    return value
  }
  let builder = StringBuilder::new()
  for _ in 0..<(width - value.length()) {
    builder.write_char('0')
  }
  builder.write_string(value)
  builder.to_string()
}

///|
fn trim_trailing_zeroes(value : String) -> String {
  let mut end = value.length()
  while end > 0 && value[end - 1] == '0' {
    end -= 1
  }
  value[:end].to_owned()
}

///|
fn is_ascii_digits(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    let code = ch.to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return false
    }
  }
  true
}

///|
fn count_char(value : String, target : Char) -> Int {
  let mut count = 0
  for ch in value {
    if ch == target {
      count += 1
    }
  }
  count
}
