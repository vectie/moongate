///|
pub fn MoonstatClient::from_suite_status(
  status : Json,
  api_key? : String? = None,
  control_token? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient? {
  match moonstat_base_url_from_suite_status(status) {
    Some(base_url) =>
      Some(
        MoonstatClient::new(base_url~, api_key~, control_token~, user_agent~),
      )
    None => None
  }
}

///|
pub async fn MoonstatClient::discover(
  path? : String = default_moonstat_suite_status_path(),
  api_key? : String? = None,
  control_token? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient {
  let content = @fsx.read_file(path) catch { _ => "" }
  if !content.is_empty() {
    let parsed = @json.parse(content) catch { _ => Json::null() }
    match
      MoonstatClient::from_suite_status(
        parsed,
        api_key~,
        control_token~,
        user_agent~,
      ) {
      Some(client) => return client
      None => ()
    }
  }
  MoonstatClient::new(api_key~, control_token~, user_agent~)
}
