///|
priv struct ProviderTemplateSeed {
  id : String
  name : String
  base_url : String
  api_format : String
  provider_type : String
  default_model : String
  website_url : String
  api_key_url : String
  category : String
  icon : String
}

///|
priv struct ProviderTemplateTarget {
  id : String
  label : String
  provider_app_type : String
  priority : Int
}

///|
fn moon_provider_template_targets() -> Array[ProviderTemplateTarget] {
  [
    {
      id: "moondesk",
      label: "MoonDesk",
      provider_app_type: "codex",
      priority: 0,
    },
    {
      id: "moonclaw",
      label: "MoonClaw",
      provider_app_type: "openclaw",
      priority: 10,
    },
    {
      id: "moonbook",
      label: "MoonBook",
      provider_app_type: "openclaw",
      priority: 20,
    },
    {
      id: "moontown",
      label: "MoonTown",
      provider_app_type: "openclaw",
      priority: 30,
    },
    {
      id: "claude",
      label: "Claude Code",
      provider_app_type: "claude",
      priority: 100,
    },
    {
      id: "claude-desktop",
      label: "Claude Desktop",
      provider_app_type: "claude-desktop",
      priority: 100,
    },
    { id: "codex", label: "Codex", provider_app_type: "codex", priority: 100 },
    {
      id: "gemini",
      label: "Gemini",
      provider_app_type: "gemini",
      priority: 100,
    },
    {
      id: "opencode",
      label: "OpenCode",
      provider_app_type: "opencode",
      priority: 100,
    },
    {
      id: "openclaw",
      label: "OpenClaw",
      provider_app_type: "openclaw",
      priority: 100,
    },
    {
      id: "hermes",
      label: "Hermes",
      provider_app_type: "hermes",
      priority: 100,
    },
  ]
}

///|
fn moon_provider_template_seeds() -> Array[ProviderTemplateSeed] {
  [
    {
      id: "deepseek-official",
      name: "DeepSeek",
      base_url: "https://api.deepseek.com/v1",
      api_format: "openai_chat",
      provider_type: "openai-compatible",
      default_model: "deepseek-v4-pro",
      website_url: "https://platform.deepseek.com",
      api_key_url: "https://platform.deepseek.com/api_keys",
      category: "official",
      icon: "deepseek",
    },
    {
      id: "openrouter",
      name: "OpenRouter",
      base_url: "https://openrouter.ai/api/v1",
      api_format: "openai_chat",
      provider_type: "openrouter",
      default_model: "openai/gpt-5.6-sol",
      website_url: "https://openrouter.ai",
      api_key_url: "https://openrouter.ai/workspaces/default/keys",
      category: "aggregator",
      icon: "openrouter",
    },
    {
      id: "openrouter-free",
      name: "OpenRouter Free Models Router",
      base_url: "https://openrouter.ai/api/v1",
      api_format: "openai_chat",
      provider_type: "openrouter",
      default_model: "openrouter/free",
      website_url: "https://openrouter.ai/models?max_price=0",
      api_key_url: "https://openrouter.ai/workspaces/default/keys",
      category: "free",
      icon: "openrouter",
    },
    {
      id: "openrouter-ling-free",
      name: "OpenRouter Ling 3.0 Flash (Free)",
      base_url: "https://openrouter.ai/api/v1",
      api_format: "openai_chat",
      provider_type: "openrouter",
      default_model: "inclusionai/ling-3.0-flash:free",
      website_url: "https://openrouter.ai/inclusionai/ling-3.0-flash",
      api_key_url: "https://openrouter.ai/workspaces/default/keys",
      category: "free",
      icon: "openrouter",
    },
    {
      id: "openrouter-nemotron-ultra-free",
      name: "OpenRouter Nemotron 3 Ultra (Free)",
      base_url: "https://openrouter.ai/api/v1",
      api_format: "openai_chat",
      provider_type: "openrouter",
      default_model: "nvidia/nemotron-3-ultra-550b-a55b:free",
      website_url: "https://openrouter.ai/nvidia/nemotron-3-ultra-550b-a55b",
      api_key_url: "https://openrouter.ai/workspaces/default/keys",
      category: "free",
      icon: "openrouter",
    },
    {
      id: "openrouter-laguna-free",
      name: "OpenRouter Laguna M.1 (Free)",
      base_url: "https://openrouter.ai/api/v1",
      api_format: "openai_chat",
      provider_type: "openrouter",
      default_model: "poolside/laguna-m.1:free",
      website_url: "https://openrouter.ai/poolside/laguna-m.1",
      api_key_url: "https://openrouter.ai/workspaces/default/keys",
      category: "free",
      icon: "openrouter",
    },
    {
      id: "fireworks",
      name: "Fireworks AI",
      base_url: "https://api.fireworks.ai/inference/v1",
      api_format: "openai_chat",
      provider_type: "openai-compatible",
      default_model: "accounts/fireworks/models/deepseek-v4-pro",
      website_url: "https://fireworks.ai",
      api_key_url: "https://app.fireworks.ai/settings/users/api-keys",
      category: "aggregator",
      icon: "fireworks",
    },
    {
      id: "siliconflow",
      name: "SiliconFlow",
      base_url: "https://api.siliconflow.cn/v1",
      api_format: "openai_chat",
      provider_type: "openai-compatible",
      default_model: "deepseek-ai/DeepSeek-V4-Pro",
      website_url: "https://siliconflow.cn",
      api_key_url: "https://cloud.siliconflow.cn/me/account/ak",
      category: "aggregator",
      icon: "siliconflow",
    },
    {
      id: "qwen-token-plan",
      name: "Qwen Token Plan",
      base_url: "https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
      api_format: "openai_chat",
      provider_type: "openai-compatible",
      default_model: "deepseek-v4-pro",
      website_url: "https://platform.qianwenai.com/pricing/token-plan",
      api_key_url: "https://platform.qianwenai.com/pricing/token-plan",
      category: "official",
      icon: "qwen",
    },
    {
      id: "qwen-pay-as-you-go",
      name: "Qwen Pay-As-You-Go",
      base_url: "https://dashscope.aliyuncs.com/compatible-mode/v1",
      api_format: "openai_chat",
      provider_type: "openai-compatible",
      default_model: "kimi/kimi-k3",
      website_url: "https://www.qianwenai.com/models",
      api_key_url: "https://platform.qianwenai.com/docs/api-reference/preparation/api-key",
      category: "official",
      icon: "qwen",
    },
    {
      id: "google-gemini",
      name: "Google Gemini",
      base_url: "https://generativelanguage.googleapis.com",
      api_format: "gemini_native",
      provider_type: "gemini",
      default_model: "gemini-3.6-flash",
      website_url: "https://ai.google.dev/gemini-api",
      api_key_url: "https://aistudio.google.com/api-keys",
      category: "official",
      icon: "gemini",
    },
    {
      id: "anthropic-official",
      name: "Anthropic",
      base_url: "https://api.anthropic.com/v1",
      api_format: "anthropic",
      provider_type: "anthropic-compatible",
      default_model: "claude-sonnet-5",
      website_url: "https://www.anthropic.com",
      api_key_url: "https://platform.claude.com/settings/keys",
      category: "official",
      icon: "anthropic",
    },
    {
      id: "openai-official",
      name: "OpenAI",
      base_url: "https://api.openai.com/v1",
      api_format: "openai",
      provider_type: "openai-compatible",
      default_model: "gpt-5.5",
      website_url: "https://openai.com",
      api_key_url: "https://platform.openai.com/api-keys",
      category: "official",
      icon: "openai",
    },
    {
      id: "zhipu-glm",
      name: "Z.AI (GLM)",
      base_url: "https://open.bigmodel.cn/api/paas/v4",
      api_format: "openai_chat",
      provider_type: "openai-compatible",
      default_model: "glm-5.2",
      website_url: "https://z.ai",
      api_key_url: "https://open.bigmodel.cn/apikey/platform",
      category: "official",
      icon: "zhipu",
    },
    {
      id: "moonshot-kimi",
      name: "Moonshot (Kimi)",
      base_url: "https://api.moonshot.cn/v1",
      api_format: "openai_chat",
      provider_type: "openai-compatible",
      default_model: "kimi-k3",
      website_url: "https://platform.kimi.com",
      api_key_url: "https://platform.kimi.com/console/api-keys",
      category: "official",
      icon: "kimi",
    },
  ]
}

///|
fn ProviderTemplateSeed::model_mapping_json(
  self : ProviderTemplateSeed,
  app_type : String,
) -> Json {
  let mapping : Map[String, Json] = {
    "defaultModel": Json::string(self.default_model),
  }
  if app_type == "claude" || app_type == "claude-desktop" {
    mapping["sonnetModel"] = Json::string(self.default_model)
    mapping["haikuModel"] = Json::string(self.default_model)
    mapping["opusModel"] = Json::string(self.default_model)
  }
  Json::object(mapping)
}

///|
fn ProviderTemplateSeed::preset_json(
  self : ProviderTemplateSeed,
  target : ProviderTemplateTarget,
) -> Json {
  let form = {
    "templateLabel": Json::string("\{self.name} / \{self.default_model}"),
    "appType": Json::string(target.provider_app_type),
    "id": Json::string(self.id),
    "name": Json::string(self.name),
    "providerType": Json::string(self.provider_type),
    "baseUrl": Json::string(self.base_url),
    "apiFormat": Json::string(self.api_format),
    "enabled": Json::boolean(true),
    "modelMapping": self.model_mapping_json(target.provider_app_type),
  }.to_json()
  {
    "appType": Json::string(target.id),
    "providerAppType": Json::string(target.provider_app_type),
    "targetAppLabel": Json::string(target.label),
    "targetPriority": Json::number(target.priority.to_double()),
    "id": Json::string("\{target.id}:catalog:\{self.id}"),
    "name": Json::string(self.name),
    "websiteUrl": Json::string(self.website_url),
    "apiKeyUrl": Json::string(self.api_key_url),
    "category": Json::string(self.category),
    "isOfficial": Json::boolean(self.category == "official"),
    "icon": Json::string(self.icon),
    "form": form,
  }.to_json()
}

///|
fn moon_ready_provider_template_catalog() -> Array[Json] {
  let presets : Array[Json] = []
  for target in moon_provider_template_targets() {
    for seed in moon_provider_template_seeds() {
      presets.push(seed.preset_json(target))
    }
  }
  presets
}
