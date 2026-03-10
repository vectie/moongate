///|
pub struct Model {
  name : String
  description : String?
  model_name : String
  model_type : Type
  api_key : String
  base_url : String
  safe_zone_tokens : Int
  supports_anthropic_prompt_caching : Bool
  supports_apply_patch : Bool
  access_token : String?
  account_id : String?
  refresh_token : String?
  id_token : String?
} derive(Show)

///|
pub(all) enum Provider {
  OpenAI
  Anthropic
  CodexOAuth
  Copilot
  Qwen
  Kimi
  KimiCoding
} derive(Eq, Show)

///|
pub(all) enum Type {
  SaaS(Provider)
} derive(Eq, Show)

///|
pub fn open_router_model(api_key : String, name : CommonModels) -> Model {
  let model_name = match name {
    Qwen3CoderPlus => "qwen/qwen3-coder-plus"
    _ => "qwen/qwen3-coder-plus"
  }
  {
    name: name.to_string(),
    description: None,
    model_name,
    model_type: SaaS(Qwen),
    api_key,
    base_url: "https://openrouter.ai/api/v1",
    safe_zone_tokens: 0,
    supports_anthropic_prompt_caching: false,
    supports_apply_patch: false,
    access_token: None,
    account_id: None,
    refresh_token: None,
    id_token: None,
  }
}

///|
pub enum CommonModels {
  Qwen3CoderPlus
} derive(Show)
