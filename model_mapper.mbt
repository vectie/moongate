///|
const ONE_M_CONTEXT_MARKER = "[1M]"

///|
pub struct ModelMapping {
  haiku_model : String?
  sonnet_model : String?
  opus_model : String?
  default_model : String?
}

///|
pub fn ModelMapping::new(
  haiku_model? : String? = None,
  sonnet_model? : String? = None,
  opus_model? : String? = None,
  default_model? : String? = None,
) -> ModelMapping {
  {
    haiku_model: clean_model_mapping_value(haiku_model),
    sonnet_model: clean_model_mapping_value(sonnet_model),
    opus_model: clean_model_mapping_value(opus_model),
    default_model: clean_model_mapping_value(default_model),
  }
}

///|
pub fn ModelMapping::has_mapping(self : ModelMapping) -> Bool {
  self.haiku_model is Some(_) ||
  self.sonnet_model is Some(_) ||
  self.opus_model is Some(_) ||
  self.default_model is Some(_)
}

///|
pub fn ModelMapping::map_model(
  self : ModelMapping,
  original_model : String,
) -> String {
  let model_lower = original_model.to_lower()
  if model_lower.contains("haiku") {
    if self.haiku_model is Some(model) {
      return model
    }
  }
  if model_lower.contains("opus") {
    if self.opus_model is Some(model) {
      return model
    }
  }
  if model_lower.contains("sonnet") {
    if self.sonnet_model is Some(model) {
      return model
    }
  }
  match self.default_model {
    Some(model) => model
    None => original_model
  }
}

///|
pub fn ModelMapping::to_json(self : ModelMapping) -> Json {
  {
    "haikuModel": optional_model_mapping_string_json(self.haiku_model),
    "sonnetModel": optional_model_mapping_string_json(self.sonnet_model),
    "opusModel": optional_model_mapping_string_json(self.opus_model),
    "defaultModel": optional_model_mapping_string_json(self.default_model),
  }.to_json()
}

///|
pub fn ProviderRouteTarget::map_model_for_upstream(
  self : ProviderRouteTarget,
  original_model : String,
) -> String {
  match self.model_mapping {
    Some(mapping) if mapping.has_mapping() =>
      strip_one_m_suffix_for_upstream(mapping.map_model(original_model))
    _ => strip_one_m_suffix_for_upstream(original_model)
  }
}

///|
pub fn strip_one_m_suffix_for_upstream(model : String) -> String {
  let trimmed = model.trim_end().to_owned()
  if trimmed.length() < ONE_M_CONTEXT_MARKER.length() {
    return model
  }
  let start = trimmed.length() - ONE_M_CONTEXT_MARKER.length()
  let suffix = trimmed[start:].to_owned()
  if suffix.to_lower() == ONE_M_CONTEXT_MARKER.to_lower() {
    trimmed[:start].to_owned().trim_end().to_owned()
  } else {
    model
  }
}

///|
fn clean_model_mapping_value(value : String?) -> String? {
  match value {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed.is_empty() {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn optional_model_mapping_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}
