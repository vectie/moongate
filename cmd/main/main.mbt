///|
pub async fn start(args : ArrayView[String]) -> Unit {
  let arr = args.to_array()
  match arr[1:] {
    ["start", ..] => start_gateway(arr)
    ["login", ..] => do_login(arr)
    ["install", ..] => install_reroute(arr)
    ["uninstall"] | ["remove"] => uninstall_reroute()
    ["claude-desktop", "install", ..] => install_claude_desktop(arr)
    ["claude-desktop", "uninstall" | "remove", ..] => uninstall_claude_desktop()
    ["claude-desktop", "status", ..] => status_claude_desktop()
    ["status", ..] => check_status(arr)
    ["health", ..] => check_health(arr)
    ["stats", ..] => check_stats(arr)
    ["help"] | ["--help"] | ["-h"] => print_help()
    ["version"] | ["--version"] | ["-v"] => println("moonstat v0.1.0")
    _ => print_help()
  }
}

///|
async fn main {
  let args = @os.args()
  start(args)
}

///|
fn print_help() -> Unit {
  println("Moonstat - Anthropic to OpenAI Codex OAuth Gateway")
  println("")
  println("Usage: moonstat <command> [options]")
  println("")
  println("Commands:")
  println("  start       Start the gateway server")
  println("  install     Install hosts reroute (requires sudo)")
  println("  uninstall   Remove hosts reroute (requires sudo)")
  println(
    "  claude-desktop install    Configure Claude Desktop gateway profile",
  )
  println("  claude-desktop uninstall  Remove Claude Desktop gateway profile")
  println("  claude-desktop status     Show Claude Desktop profile status")
  println("  status      Check reroute and gateway status")
  println("  stats       Show gateway traffic statistics")
  println("  login       Login to OpenAI Codex OAuth")
  println("  health      Check gateway health")
  println("  version     Show version")
  println("  help        Show this help message")
  println("")
  println("Start options:")
  println("  --host <host>      Address to listen on (default: 127.0.0.1)")
  println("  --port <port>      Port to listen on (default: 15721)")
  println("  --model <model>    Codex model to use (default: gpt-4o)")
  println("")
  println("Examples:")
  println("  sudo moonstat install          # Install hosts reroute")
  println("  moonstat start                 # Start gateway on 127.0.0.1:15721")
  println("  moonstat start --port 80       # Start gateway on port 80")
  println("  moonstat claude-desktop install --port 15721")
  println("  claude                         # Use Claude CLI through moonstat")
  println("  moonstat stats                 # Show traffic counters")
  println("  moonstat uninstall             # Remove hosts reroute")
}

///|
async fn start_gateway(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-4o")
  logger.info("Starting Moonstat Gateway on \{host}:\{port}")
  logger.info("Using Codex model: \{model}")
  let gateway = @moonstat.Gateway::new(port~, host~, model~)
  logger.info("Gateway started on \{gateway.host()}:\{gateway.port()}")
  gateway.start()
}

///|
async fn do_login(_args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Starting OpenAI Codex OAuth login flow...")
  try {
    let creds = @codex.start_oauth_flow()
    logger.info("Login successful!")
    logger.info("Email: \{@codex.extract_token_claims(creds.idToken).email}")
    @codex.save_credentials(creds)
    logger.info("Credentials saved to ~/.moonstat/codex-credentials.json")
  } catch {
    err => logger.error("Login failed: \{err}")
  }
}

///|
async fn check_health(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/health")
    if response.code == 200 {
      let body = client.read_all().text()
      println("Gateway health: \{body}")
    } else {
      logger.error("Health check failed: \{response.code}")
    }
  } catch {
    err => logger.error("Health check failed: \{err}")
  }
}

///|
async fn check_stats(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/stats")
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("Stats check failed: \{response.code}")
    }
  } catch {
    err => logger.error("Stats check failed: \{err}")
  }
}

///|
async fn check_status(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")

  // 检查 hosts reroute 状态
  let hosts_installed = @hosts.is_reroute_installed()
  if hosts_installed {
    logger.info("Hosts reroute is installed")
  } else {
    logger.warn("Hosts reroute is NOT installed")
  }

  // 检查网关是否在运行
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/status")
    if response.code == 200 {
      let body = client.read_all().text()
      logger.info("Gateway is running: \{body}")
    } else {
      logger.warn("Gateway is NOT running")
    }
  } catch {
    _ => logger.warn("Gateway is NOT running")
  }

  // 检查凭据
  let creds_result : Result[@codex.Credentials, Error] = try? @codex.load_credentials()
  match creds_result {
    Ok(_) => logger.info("Credentials loaded")
    Err(_) => logger.warn("Credentials NOT loaded, please run: moonstat login")
  }
}

///|
async fn install_reroute(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let port = parse_int_arg(args, "--port", default=15721)

  logger.info("Installing hosts reroute for port \{port}...")
  let result = @hosts.install_and_flush(port)
  match result {
    Ok(_) => {
      logger.info("Hosts reroute installed successfully!")
      logger.info("Now you can use: moonstat start --port \{port}")
      logger.info("Then Anthropic API requests will route through moonstat.")
    }
    Err(e) => logger.error("Failed to install: \{e}")
  }
}

///|
async fn uninstall_reroute() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())

  logger.info("Removing hosts reroute...")
  let result = @hosts.uninstall_and_flush()
  match result {
    Ok(_) => logger.info("Hosts reroute removed successfully!")
    Err(e) => logger.error("Failed to uninstall: \{e}")
  }
}

///|
async fn install_claude_desktop(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let token = parse_string_arg(args, "--token")
  logger.info("Installing Claude Desktop gateway profile...")
  let result = @claude_desktop.install_proxy_profile(host, port, token~)
  match result {
    Ok(installed) => {
      logger.info("Claude Desktop profile installed")
      logger.info("Gateway base URL: \{installed.base_url}")
      logger.info("Profile: \{installed.profile_path}")
      logger.info("Token saved for Moonstat gateway auth")
    }
    Err(e) => logger.error(e)
  }
}

///|
async fn uninstall_claude_desktop() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Removing Claude Desktop gateway profile...")
  let result = @claude_desktop.uninstall_proxy_profile()
  match result {
    Ok(_) => logger.info("Claude Desktop profile removed")
    Err(e) => logger.error(e)
  }
}

///|
async fn status_claude_desktop() -> Unit {
  let status = @claude_desktop.status()
  println(
    Json::object({
      "configured": Json::boolean(status.configured),
      "profile_path": Json::string(status.profile_path),
      "meta_path": Json::string(status.meta_path),
      "token_configured": Json::boolean(status.token_configured),
    }).stringify(indent=2),
  )
}

///|
fn parse_string_arg(args : Array[String], name : String) -> String? {
  let mut i = 0
  while i < args.length() {
    if args[i] == name && i + 1 < args.length() {
      return Some(args[i + 1])
    }
    i = i + 1
  }
  None
}

///|
fn parse_int_arg(args : Array[String], name : String, default~ : Int) -> Int {
  match parse_string_arg(args, name) {
    Some(s) => {
      let result : Result[Int, Error] = try? @strconv.parse_int(s[:], base=10)
      match result {
        Ok(n) => n
        Err(_) => default
      }
    }
    None => default
  }
}
