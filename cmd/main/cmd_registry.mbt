///|
priv struct CliCommandSpec {
  id : String
  patterns : Array[String]
}

///|
fn registered_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "login", patterns: ["login"] },
    {
      id: "auth_start_login",
      patterns: ["auth start-login", "auth_start_login", "auth-start-login"],
    },
    {
      id: "auth_poll_for_account",
      patterns: [
        "auth poll", "auth poll-for-account", "auth_poll_for_account", "auth-poll-for-account",
      ],
    },
    {
      id: "auth_list_accounts",
      patterns: [
        "auth list", "auth list-accounts", "auth_list_accounts", "auth-list-accounts",
      ],
    },
    {
      id: "auth_get_status",
      patterns: ["auth status", "auth_get_status", "auth-get-status"],
    },
    {
      id: "auth_remove_account",
      patterns: [
        "auth remove", "auth remove-account", "auth_remove_account", "auth-remove-account",
      ],
    },
    {
      id: "auth_set_default_account",
      patterns: [
        "auth default", "auth set-default-account", "auth_set_default_account", "auth-set-default-account",
      ],
    },
    {
      id: "auth_logout",
      patterns: ["auth logout", "auth_logout", "auth-logout"],
    },
    {
      id: "copilot_start_device_flow",
      patterns: [
        "copilot start-device-flow", "copilot_start_device_flow", "copilot-start-device-flow",
      ],
    },
    {
      id: "copilot_poll_for_account",
      patterns: [
        "copilot poll", "copilot poll-for-account", "copilot_poll_for_account", "copilot-poll-for-account",
      ],
    },
    {
      id: "copilot_poll_for_auth",
      patterns: [
        "copilot poll-for-auth", "copilot_poll_for_auth", "copilot-poll-for-auth",
      ],
    },
    {
      id: "copilot_list_accounts",
      patterns: [
        "copilot list", "copilot list-accounts", "copilot_list_accounts", "copilot-list-accounts",
      ],
    },
    {
      id: "copilot_get_auth_status",
      patterns: [
        "copilot auth-status", "copilot status", "copilot_get_auth_status", "copilot-get-auth-status",
      ],
    },
    {
      id: "copilot_is_authenticated",
      patterns: [
        "copilot is-authenticated", "copilot_is_authenticated", "copilot-is-authenticated",
      ],
    },
    {
      id: "copilot_logout",
      patterns: ["copilot logout", "copilot_logout", "copilot-logout"],
    },
    {
      id: "copilot_remove_account",
      patterns: [
        "copilot remove", "copilot remove-account", "copilot_remove_account", "copilot-remove-account",
      ],
    },
    {
      id: "copilot_set_default_account",
      patterns: [
        "copilot default", "copilot set-default-account", "copilot_set_default_account",
        "copilot-set-default-account",
      ],
    },
    {
      id: "copilot_get_token",
      patterns: ["copilot token", "copilot_get_token", "copilot-get-token"],
    },
    {
      id: "copilot_get_token_for_account",
      patterns: [
        "copilot_get_token_for_account", "copilot-get-token-for-account",
      ],
    },
    {
      id: "copilot_get_models",
      patterns: ["copilot models", "copilot_get_models", "copilot-get-models"],
    },
    {
      id: "copilot_get_models_for_account",
      patterns: [
        "copilot_get_models_for_account", "copilot-get-models-for-account",
      ],
    },
    {
      id: "copilot_get_usage",
      patterns: ["copilot usage", "copilot_get_usage", "copilot-get-usage"],
    },
    {
      id: "copilot_get_usage_for_account",
      patterns: [
        "copilot_get_usage_for_account", "copilot-get-usage-for-account",
      ],
    },
    {
      id: "stream_check_provider",
      patterns: [
        "stream-check provider", "stream-check stream-check-provider", "stream_check_provider",
        "stream-check-provider",
      ],
    },
    {
      id: "stream_check_all_providers",
      patterns: [
        "stream-check all", "stream-check stream-check-all-providers", "stream_check_all_providers",
        "stream-check-all-providers",
      ],
    },
    {
      id: "save_stream_check_config",
      patterns: [
        "stream-check config set", "stream-check save-stream-check-config", "save_stream_check_config",
        "save-stream-check-config",
      ],
    },
    {
      id: "get_stream_check_config",
      patterns: [
        "stream-check config", "stream-check get-stream-check-config", "get_stream_check_config",
        "get-stream-check-config",
      ],
    },
    { id: "suite_manifest", patterns: ["suite manifest"] },
    { id: "suite_status", patterns: ["suite status"] },
    { id: "suite_write_status", patterns: ["suite write-status"] },
    {
      id: "suite_moonclaw_providers",
      patterns: ["suite moonclaw-providers", "suite provider-manifest"],
    },
    {
      id: "suite_write_moonclaw_providers",
      patterns: [
        "suite write-moonclaw-providers", "suite write-provider-manifest",
      ],
    },
    { id: "status", patterns: ["status"] },
    { id: "health", patterns: ["health"] },
    { id: "stats", patterns: ["stats"] },
  ]
}

///|
fn cli_args_match_pattern(args : Array[String], pattern : String) -> Bool {
  let tokens = pattern.split(" ").collect()
  if args.length() < tokens.length() + 1 {
    return false
  }
  for index in 0..<tokens.length() {
    if args[index + 1] != tokens[index].to_owned() {
      return false
    }
  }
  true
}

///|
fn cli_args_match_any_pattern(
  args : Array[String],
  patterns : Array[String],
) -> Bool {
  for pattern in patterns {
    if cli_args_match_pattern(args, pattern) {
      return true
    }
  }
  false
}

///|
fn registered_cli_command_id(args : Array[String]) -> String? {
  for command in registered_cli_commands() {
    if cli_args_match_any_pattern(args, command.patterns) {
      return Some(command.id)
    }
  }
  None
}

///|
async fn run_registered_cli_command(args : Array[String]) -> Bool {
  match registered_cli_command_id(args) {
    Some("login") => {
      do_login(args)
      true
    }
    Some("auth_start_login") => {
      auth_start_login(args)
      true
    }
    Some("auth_poll_for_account") => {
      auth_poll_for_account(args)
      true
    }
    Some("auth_list_accounts") => {
      auth_list_accounts(args)
      true
    }
    Some("auth_get_status") => {
      auth_get_status(args)
      true
    }
    Some("auth_remove_account") => {
      auth_remove_account(args)
      true
    }
    Some("auth_set_default_account") => {
      auth_set_default_account(args)
      true
    }
    Some("auth_logout") => {
      auth_logout(args)
      true
    }
    Some("copilot_start_device_flow") => {
      copilot_start_device_flow(args)
      true
    }
    Some("copilot_poll_for_account") => {
      copilot_poll_for_account(args)
      true
    }
    Some("copilot_poll_for_auth") => {
      copilot_poll_for_auth(args)
      true
    }
    Some("copilot_list_accounts") => {
      check_usage_endpoint(args, "/copilot_list_accounts")
      true
    }
    Some("copilot_get_auth_status") => {
      check_usage_endpoint(args, "/copilot_get_auth_status")
      true
    }
    Some("copilot_is_authenticated") => {
      check_usage_endpoint(args, "/copilot_is_authenticated")
      true
    }
    Some("copilot_logout") => {
      check_json_post_endpoint(args, "/copilot_logout", "Copilot")
      true
    }
    Some("copilot_remove_account") => {
      copilot_account_post(args, "/copilot_remove_account")
      true
    }
    Some("copilot_set_default_account") => {
      copilot_account_post(args, "/copilot_set_default_account")
      true
    }
    Some("copilot_get_token") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_token"),
      )
      true
    }
    Some("copilot_get_token_for_account") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_token_for_account"),
      )
      true
    }
    Some("copilot_get_models") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_models"),
      )
      true
    }
    Some("copilot_get_models_for_account") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_models_for_account"),
      )
      true
    }
    Some("copilot_get_usage") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_usage"),
      )
      true
    }
    Some("copilot_get_usage_for_account") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_usage_for_account"),
      )
      true
    }
    Some("stream_check_provider") => {
      stream_check_provider(args)
      true
    }
    Some("stream_check_all_providers") => {
      stream_check_all_providers(args)
      true
    }
    Some("get_stream_check_config") => {
      check_usage_endpoint(args, "/get_stream_check_config")
      true
    }
    Some("save_stream_check_config") => {
      save_stream_check_config(args)
      true
    }
    Some("suite_manifest") => {
      print_suite_manifest(args)
      true
    }
    Some("suite_status") => {
      print_suite_status(args)
      true
    }
    Some("suite_write_status") => {
      write_suite_status(args)
      true
    }
    Some("suite_moonclaw_providers") => {
      print_moonclaw_providers_file(args)
      true
    }
    Some("suite_write_moonclaw_providers") => {
      write_moonclaw_providers_file(args)
      true
    }
    Some("status") => {
      check_status(args)
      true
    }
    Some("health") => {
      check_health(args)
      true
    }
    Some("stats") => {
      check_stats(args)
      true
    }
    _ => false
  }
}
