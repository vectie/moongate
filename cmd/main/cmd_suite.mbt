///|
fn suite_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "suite_manifest", patterns: ["suite manifest"] },
    { id: "suite_lepusa", patterns: ["suite lepusa"] },
    { id: "suite_lepusa_rabbita", patterns: ["suite lepusa-rabbita"] },
    { id: "suite_status", patterns: ["suite status"] },
    { id: "suite_constitution", patterns: ["suite constitution"] },
    {
      id: "suite_constitution_negative",
      patterns: ["suite constitution-negative"],
    },
    { id: "suite_drift", patterns: ["suite drift"] },
    { id: "suite_write_status", patterns: ["suite write-status"] },
    { id: "suite_session", patterns: ["suite session"] },
    {
      id: "suite_migrate_legacy_state",
      patterns: ["suite migrate-legacy-state"],
    },
    { id: "suite_moonclaw_providers", patterns: ["suite moonclaw-providers"] },
    {
      id: "suite_write_moonclaw_providers",
      patterns: ["suite write-moonclaw-providers"],
    },
  ]
}

///|
async fn run_suite_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "suite_manifest" => print_suite_manifest(args)
    "suite_lepusa" => print_lepusa_manifest(args)
    "suite_lepusa_rabbita" => print_lepusa_rabbita_manifest(args)
    "suite_status" => print_suite_status(args)
    "suite_constitution" => print_suite_constitution(args)
    "suite_constitution_negative" => print_suite_constitution_negative(args)
    "suite_drift" => print_suite_drift(args)
    "suite_write_status" => write_suite_status(args)
    "suite_session" => write_ai_session_receipt(args)
    "suite_migrate_legacy_state" => migrate_legacy_moongate_state(args)
    "suite_moonclaw_providers" => print_moonclaw_providers_file(args)
    "suite_write_moonclaw_providers" => write_moonclaw_providers_file(args)
    _ => ()
  }
}

///|
fn print_suite_constitution(args : Array[String]) -> Unit {
  let checked_at = parse_string_arg(args, "--checked-at").unwrap_or("cli")
  println(
    {
      "contractId": Json::string("moonsuite.constitution-suite-report.v1"),
      "registry": @moongate.constitutional_registry_json(),
      "selfCheck": @moongate.constitutional_registry_self_check(checked_at),
    }
    .to_json()
    .stringify(indent=2),
  )
}

///|
fn print_suite_constitution_negative(args : Array[String]) -> Unit {
  let checked_at = parse_string_arg(args, "--checked-at").unwrap_or("cli")
  println(
    {
      "physicalOverclaim": @moongate.constitutional_negative_probe(checked_at).to_json(),
      "simulationPhysicalAuthority": @moongate.constitutional_simulation_authority_probe(
        checked_at,
      ).to_json(),
    }
    .to_json()
    .stringify(indent=2),
  )
}

///|
fn safe_session_id(value : String) -> Bool {
  if value.trim().is_empty() {
    return false
  }
  for char in value {
    if !(char >= 'a' && char <= 'z') &&
      !(char >= 'A' && char <= 'Z') &&
      !(char >= '0' && char <= '9') &&
      char != '-' &&
      char != '_' {
      return false
    }
  }
  true
}

///|
async fn ensure_session_dir(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path)
  }
}

///|
async fn write_ai_session_receipt(args : Array[String]) -> Unit {
  let root = parse_string_arg(args, "--root").unwrap_or(".")
  let session_id = parse_string_arg(args, "--session").unwrap_or("default")
  if !safe_session_id(session_id) {
    fail("MoonGate session id must be a safe slug")
  }
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
  let moonsuite = root + "/.moonsuite"
  let products = moonsuite + "/products"
  // Product identity and storage use the same canonical key.
  let product = products + "/moongate"
  let sessions = product + "/sessions"
  let session = sessions + "/" + session_id
  for path in [moonsuite, products, product, sessions, session] {
    ensure_session_dir(path)
  }
  let receipt = @suite.ai_session_receipt(session_id, model, host, port)
  @fs.write_file(
    session + "/receipt.json",
    @encoding/utf8.encode(receipt.stringify(indent=2) + "\n"),
    create_mode=CreateOrTruncate,
    permission=0o600,
  )
  println(receipt.stringify(indent=2))
}

///|
async fn print_suite_drift(args : Array[String]) -> Unit {
  let root = parse_string_arg(args, "--root").unwrap_or(".")
  println(
    @moongate.moongate_suite_drift_report_json(suite_root=root).stringify(
      indent=2,
    ),
  )
}

///|
async fn set_suite_json_config(
  args : Array[String],
  base_path : String,
  flag : String,
) -> Unit {
  guard parse_string_arg(args, flag) is Some(raw) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required \{flag}")
    return
  }
  post_json_body_endpoint(args, base_path, raw, "Suite")
}

///|
fn print_suite_manifest(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
  println(
    @moongate.moongate_suite_manifest_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}

///|
fn print_lepusa_manifest(args : Array[String]) -> Unit {
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  println(@moongate.moongate_lepusa_manifest(port~))
}

///|
fn print_lepusa_rabbita_manifest(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  println(
    @moongate.moongate_rabbita_lepusa_manifest(
      api_base=@suite.base_url(host, port),
    ),
  )
}
