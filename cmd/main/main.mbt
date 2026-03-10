///|
pub async fn start(args : ArrayView[String]) -> Unit {
  let arr = args.to_array()
  match arr[1:] {
    ["start", ..] => start_gateway(arr)
    ["login", ..] => do_login(arr)
    ["install", ..] => install_hijack(arr)
    ["uninstall"] | ["remove"] => uninstall_hijack()
    ["status"] => check_status()
    ["health", ..] => check_health(arr)
    ["help"] | ["--help"] | ["-h"] => print_help()
    ["version"] | ["--version"] | ["-v"] => println("hijack v0.1.0")
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
  println("Hijack - Anthropic to OpenAI Codex OAuth Gateway (Auto Hijack Mode)")
  println("")
  println("Usage: hijack <command> [options]")
  println("")
  println("Commands:")
  println("  start       Start the gateway server")
  println("  install     Install hosts hijack (requires sudo)")
  println("  uninstall   Remove hosts hijack (requires sudo)")
  println("  status      Check hijack status")
  println("  login       Login to OpenAI Codex OAuth")
  println("  health      Check gateway health")
  println("  version     Show version")
  println("  help        Show this help message")
  println("")
  println("Start options:")
  println("  --port <port>      Port to listen on (default: 80)")
  println("  --model <model>    Codex model to use (default: gpt-4o)")
  println("")
  println("Examples:")
  println("  sudo hijack install          # Install hosts hijack")
  println("  hijack start --port 80       # Start gateway on port 80")
  println("  claude                       # Use Claude CLI (auto-hijacked)")
  println("  hijack uninstall             # Remove hosts hijack")
}

///|
async fn start_gateway(args : Array[String]) -> Unit {
  let logger = @pino.logger("hijack", @pino.Transport::console())
  let port = parse_int_arg(args, "--port", default=80)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-4o")
  logger.info("Starting Hijack Gateway on port \{port}")
  logger.info("Using Codex model: \{model}")
  let gateway = @hij.Gateway::new(port~, model~)
  logger.info("Gateway started on port \{gateway.port()}")
  gateway.start()
}

///|
async fn do_login(args : Array[String]) -> Unit {
  let logger = @pino.logger("hijack", @pino.Transport::console())
  logger.info("Starting OpenAI Codex OAuth login flow...")
  try {
    let creds = @codex.start_oauth_flow()
    logger.info("Login successful!")
    logger.info("Email: \{@codex.extract_token_claims(creds.idToken).email}")
    @codex.save_credentials(creds)
    logger.info("Credentials saved to ~/.moonclaw/codex-credentials.json")
  } catch {
    err => logger.error("Login failed: \{err}")
  }
}

///|
async fn check_health(args : Array[String]) -> Unit {
  let logger = @pino.logger("hijack", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:80")
  let client = @http.Client::new(url, headers={})
  defer client.close()
  let response = client.get("/health")
  if response.code == 200 {
    let body = client.read_all().text()
    println("Gateway health: \{body}")
  } else {
    logger.error("Health check failed: \{response.code}")
  }
}

///|
async fn check_status() -> Unit {
  let logger = @pino.logger("hijack", @pino.Transport::console())
  
  // 检查 hosts 劫持状态
  let hosts_installed = @hosts.is_hijack_installed()
  if hosts_installed {
    logger.info("Hosts hijack is installed")
  } else {
    logger.warn("Hosts hijack is NOT installed")
  }
  
  // 检查网关是否在运行
  let client = @http.Client::new("http://localhost:80", headers={})
  defer client.close()
  let response = client.get("/health")
  if response.code == 200 {
    let body = client.read_all().text()
    logger.info("Gateway is running: \{body}")
  } else {
    logger.warn("Gateway is NOT running")
  }
  
  // 检查凭据
  let creds_result : Result[@codex.Credentials, Error] = try? @codex.load_credentials()
  match creds_result {
    Ok(_) => logger.info("Credentials loaded")
    Err(_) => logger.warn("Credentials NOT loaded, please run: hijack login")
  }
}

///|
async fn install_hijack(args : Array[String]) -> Unit {
  let logger = @pino.logger("hijack", @pino.Transport::console())
  let port = parse_int_arg(args, "--port", default=80)
  
  logger.info("Installing hosts hijack for port \{port}...")
  let result = @hosts.install_and_flush(port)
  match result {
    Ok(_) => {
      logger.info("Hosts hijack installed successfully!")
      logger.info("Now you can use: hijack start --port \{port}")
      logger.info("Then all Anthropic API requests will be auto-hijacked!")
    }
    Err(e) => logger.error("Failed to install: \{e}")
  }
}

///|
async fn uninstall_hijack() -> Unit {
  let logger = @pino.logger("hijack", @pino.Transport::console())
  
  logger.info("Removing hosts hijack...")
  let result = @hosts.uninstall_and_flush()
  match result {
    Ok(_) => logger.info("Hosts hijack removed successfully!")
    Err(e) => logger.error("Failed to uninstall: \{e}")
  }
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
