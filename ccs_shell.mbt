///|
const CCS_UPDATE_URL = "https://github.com/farion1231/cc-switch/releases/latest"

///|
const CCS_TOOL_VERSION_TIMEOUT_MS = 3000

///|
const CCS_TOOL_LIFECYCLE_TIMEOUT_MS = 600000

///|
const CCS_TOOL_PROBE_TIMEOUT_MS = 5000

///|
priv enum CcsToolLifecycleAction {
  Install
  Update
}

///|
priv struct CcsToolInstallation {
  path : String
  real : String
  version : String?
  runnable : Bool
  source : String
  is_path_default : Bool
}

///|
priv struct CcsToolInstallationReport {
  tool : String
  installs : Array[CcsToolInstallation]
  is_conflict : Bool
  needs_confirmation : Bool
  command : String
  anchored : Bool
}

///|
fn ccs_normalize_external_url(url : String) -> String {
  let trimmed = url.trim().to_owned()
  let lower = trimmed.to_lower()
  if lower.find("http://") == Some(0) || lower.find("https://") == Some(0) {
    trimmed
  } else {
    "https://\{trimmed}"
  }
}

///|
fn ccs_tool_names() -> Array[String] {
  ["claude", "codex", "gemini", "opencode", "openclaw", "hermes"]
}

///|
fn ccs_requested_tool_names(raw : String?) -> Array[String] {
  let valid = ccs_tool_names()
  let requested : Array[String] = []
  match raw {
    Some(value) =>
      for part_view in value.split(",") {
        let name = part_view.to_owned().trim().to_lower().to_owned()
        if !name.is_empty() && valid.contains(name) && !requested.contains(name) {
          requested.push(name)
        }
      }
    None => ()
  }
  if requested.is_empty() {
    valid
  } else {
    requested
  }
}

///|
fn ccs_requested_tool_names_from_json(value : Json?) -> Array[String] {
  match value {
    Some(Array(items)) => {
      let raw : Array[String] = []
      for item in items {
        if item is String(tool) {
          raw.push(tool)
        }
      }
      let joined = raw.join(",")
      ccs_requested_tool_names(Some(joined))
    }
    Some(String(value)) => ccs_requested_tool_names(Some(value))
    _ => ccs_requested_tool_names(None)
  }
}

///|
fn ccs_tool_lifecycle_action(value : String) -> CcsToolLifecycleAction? {
  match value.trim().to_lower() {
    "install" => Some(Install)
    "update" => Some(Update)
    _ => None
  }
}

///|
fn ccs_update_url() -> String {
  CCS_UPDATE_URL
}

///|
fn ccs_init_error_json() -> Json {
  Json::null()
}

///|
fn ccs_migration_result_json() -> Json {
  Json::boolean(false)
}

///|
fn ccs_skills_migration_result_json() -> Json {
  Json::null()
}

///|
fn ccs_dialog_result_json() -> Json {
  Json::null()
}

///|
async fn ccs_portable_mode() -> Bool {
  let exe = @os.executable() catch { _ => return false }
  let marker = @pathx.join(@pathx.dirname(exe), "portable.ini")
  @fsx.exists_as_file(marker) catch {
    _ => false
  }
}

///|
async fn ccs_get_tool_versions_json(tools : String?) -> Json {
  let versions : Array[Json] = []
  for tool in ccs_requested_tool_names(tools) {
    versions.push(ccs_single_tool_version_json(tool))
  }
  Json::array(versions)
}

///|
async fn ccs_single_tool_version_json(tool : String) -> Json {
  let result = @spawn.spawn(
    tool,
    ["--version"],
    timeout=CCS_TOOL_VERSION_TIMEOUT_MS,
  ) catch {
    err =>
      return ccs_tool_version_json(
        tool,
        None,
        None,
        Some(err.to_string()),
        false,
      )
  }
  let combined = if result.stdout.trim().is_empty() {
    result.stderr
  } else {
    result.stdout
  }
  let version = ccs_first_output_line(combined)
  let broken = result.status != 0
  ccs_tool_version_json(
    tool,
    version,
    None,
    if broken {
      Some(result.stderr.trim().to_owned())
    } else {
      None
    },
    broken,
  )
}

///|
async fn ccs_run_tool_lifecycle_action_json(
  tools : Array[String],
  action : String,
) -> Result[Json, String] {
  guard ccs_tool_lifecycle_action(action) is Some(action) else {
    return Err("Unsupported tool action: \{action}")
  }
  let requested = ccs_requested_tool_names(Some(tools.join(",")))
  if requested.is_empty() {
    return Err("No supported tools selected")
  }
  let command = ccs_build_tool_lifecycle_command(requested, action)
  if command.trim().is_empty() {
    return Err("No supported tool command available")
  }
  let result = @spawn.spawn(
    "bash",
    ["-lc", command],
    timeout=CCS_TOOL_LIFECYCLE_TIMEOUT_MS,
  ) catch {
    err => return Err("启动安装进程失败: \{err}")
  }
  if result.status == 0 {
    Ok(Json::boolean(true))
  } else {
    let raw = if result.stderr.trim().is_empty() {
      result.stdout.trim()
    } else {
      result.stderr.trim()
    }
    let detail = ccs_last_lines(raw.to_owned(), 8)
    Err(
      if detail.is_empty() {
        "命令执行失败 (exit code: \{result.status})"
      } else {
        detail
      },
    )
  }
}

///|
async fn ccs_probe_tool_installations_json(
  tools : Array[String],
) -> Result[Json, String] {
  let requested = ccs_requested_tool_names(Some(tools.join(",")))
  if requested.is_empty() {
    return Err("No supported tools selected")
  }
  let reports : Array[Json] = []
  for tool in requested {
    reports.push(ccs_tool_installation_report(tool).to_json())
  }
  Ok(Json::array(reports))
}

///|
fn CcsToolInstallation::to_json(self : CcsToolInstallation) -> Json {
  {
    "path": Json::string(self.path),
    "real": Json::string(self.real),
    "version": optional_string_json(self.version),
    "runnable": Json::boolean(self.runnable),
    "source": Json::string(self.source),
    "is_path_default": Json::boolean(self.is_path_default),
  }.to_json()
}

///|
fn CcsToolInstallationReport::to_json(self : CcsToolInstallationReport) -> Json {
  {
    "tool": Json::string(self.tool),
    "installs": Json::array(self.installs.map(fn(item) { item.to_json() })),
    "is_conflict": Json::boolean(self.is_conflict),
    "needs_confirmation": Json::boolean(self.needs_confirmation),
    "command": Json::string(self.command),
    "anchored": Json::boolean(self.anchored),
  }.to_json()
}

///|
async fn ccs_tool_installation_report(
  tool : String,
) -> CcsToolInstallationReport {
  let installs = ccs_enumerate_tool_installations(tool)
  let command = ccs_tool_update_command(tool, installs)
  CcsToolInstallationReport::{
    tool,
    installs,
    is_conflict: ccs_tool_installations_conflict(installs),
    needs_confirmation: installs.length() >= 2,
    command,
    anchored: ccs_default_installation(installs) is Some(_),
  }
}

///|
async fn ccs_enumerate_tool_installations(
  tool : String,
) -> Array[CcsToolInstallation] {
  let installs : Array[CcsToolInstallation] = []
  let seen : Map[String, Bool] = {}
  match ccs_command_path(tool) {
    Some(path) => {
      let real = @fsx.resolve(path) catch { _ => path }
      installs.push(CcsToolInstallation::{
        path,
        real,
        version: ccs_probe_tool_version_at(path),
        runnable: true,
        source: ccs_install_source(path),
        is_path_default: true,
      })
      seen[path] = true
    }
    None => ()
  }
  for path in ccs_common_tool_paths(tool) {
    if seen.get(path) is Some(_) {
      continue
    }
    let exists = @fsx.exists_as_file(path) catch { _ => false }
    if exists {
      let real = @fsx.resolve(path) catch { _ => path }
      installs.push(CcsToolInstallation::{
        path,
        real,
        version: ccs_probe_tool_version_at(path),
        runnable: true,
        source: ccs_install_source(path),
        is_path_default: false,
      })
      seen[path] = true
    }
  }
  installs
}

///|
async fn ccs_command_path(tool : String) -> String? {
  let result = @spawn.spawn(
    "bash",
    ["-lc", "command -v \{ccs_shell_single_quote(tool)}"],
    timeout=CCS_TOOL_PROBE_TIMEOUT_MS,
  ) catch {
    _ => return None
  }
  if result.status != 0 {
    return None
  }
  ccs_first_output_line(result.stdout)
}

///|
async fn ccs_probe_tool_version_at(path : String) -> String? {
  let result = @spawn.spawn(
    path,
    ["--version"],
    timeout=CCS_TOOL_PROBE_TIMEOUT_MS,
  ) catch {
    _ => return None
  }
  if result.status != 0 {
    return None
  }
  let output = if result.stdout.trim().is_empty() {
    result.stderr
  } else {
    result.stdout
  }
  ccs_first_output_line(output)
}

///|
fn ccs_common_tool_paths(tool : String) -> Array[String] {
  let paths : Array[String] = []
  let home = @os.home() catch { _ => "" }
  for
    dir in [
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/usr/bin",
      "/bin",
      @pathx.join(home, ".local/bin"),
      @pathx.join(home, ".npm-global/bin"),
      @pathx.join(home, ".volta/bin"),
    ] {
    paths.push(@pathx.join(dir, tool))
  }
  paths
}

///|
fn ccs_install_source(path : String) -> String {
  let lower = path.to_lower()
  if lower.contains("/.volta/") {
    "volta"
  } else if lower.contains("/.bun/") {
    "bun"
  } else if lower.contains("/.nvm/") {
    "nvm"
  } else if lower.contains("/.local/share/claude/") {
    "claude-native"
  } else if lower.contains("/homebrew/") ||
    lower.contains("/cellar/") ||
    lower.contains("/opt/homebrew/") {
    "homebrew"
  } else if lower.contains("/npm") || lower.contains("/node") {
    "npm"
  } else {
    "system"
  }
}

///|
fn ccs_default_installation(
  installs : Array[CcsToolInstallation],
) -> CcsToolInstallation? {
  for install in installs {
    if install.is_path_default {
      return Some(install)
    }
  }
  match installs {
    [single] => Some(single)
    _ => None
  }
}

///|
fn ccs_tool_installations_conflict(
  installs : Array[CcsToolInstallation],
) -> Bool {
  if installs.length() < 2 {
    return false
  }
  let versions : Map[String, Bool] = {}
  let mut runnable_count = 0
  let mut broken_count = 0
  for install in installs {
    versions[install.version.unwrap_or("<missing>")] = true
    if install.runnable {
      runnable_count += 1
    } else {
      broken_count += 1
    }
  }
  versions.length() > 1 || (runnable_count > 0 && broken_count > 0)
}

///|
async fn ccs_build_tool_lifecycle_command(
  tools : Array[String],
  action : CcsToolLifecycleAction,
) -> String {
  let lines : Array[String] = ["set -e", "set -o pipefail"]
  for tool in tools {
    lines.push("echo ========== \{ccs_tool_display_name(tool)} ==========")
    lines.push(
      match action {
        Install => ccs_tool_install_command(tool)
        Update =>
          ccs_tool_update_command(tool, ccs_enumerate_tool_installations(tool))
      },
    )
    lines.push("")
  }
  lines.join("\n")
}

///|
fn ccs_tool_display_name(tool : String) -> String {
  match tool {
    "claude" => "Claude Code"
    "codex" => "Codex"
    "gemini" => "Gemini CLI"
    "opencode" => "OpenCode"
    "openclaw" => "OpenClaw"
    "hermes" => "Hermes"
    _ => "Unknown"
  }
}

///|
fn ccs_tool_install_command(tool : String) -> String {
  match tool {
    "claude" =>
      ccs_chain_commands(
        "bash -c 'tmp=$(mktemp) && curl -fsSL https://claude.ai/install.sh -o $tmp && bash $tmp; status=$?; rm -f $tmp; exit $status'",
        "npm i -g @anthropic-ai/claude-code@latest",
      )
    "codex" => "npm i -g @openai/codex@latest"
    "gemini" => "npm i -g @google/gemini-cli@latest"
    "opencode" =>
      ccs_chain_commands(
        "bash -c 'tmp=$(mktemp) && curl -fsSL https://opencode.ai/install -o $tmp && bash $tmp; status=$?; rm -f $tmp; exit $status'",
        "npm i -g opencode-ai@latest",
      )
    "openclaw" => "npm i -g openclaw@latest"
    "hermes" =>
      "bash -c 'tmp=$(mktemp) && curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh -o $tmp && bash $tmp; status=$?; rm -f $tmp; exit $status'"
    _ => ""
  }
}

///|
fn ccs_tool_update_command(
  tool : String,
  installs : Array[CcsToolInstallation],
) -> String {
  match ccs_default_installation(installs) {
    Some(install) =>
      match ccs_anchored_tool_update_command(tool, install) {
        Some(command) => command
        None => ccs_static_tool_update_command(tool)
      }
    None => ccs_static_tool_update_command(tool)
  }
}

///|
fn ccs_anchored_tool_update_command(
  tool : String,
  install : CcsToolInstallation,
) -> String? {
  let quoted = ccs_quote_path_if_needed(install.path)
  match tool {
    "claude" | "codex" | "openclaw" => Some("\{quoted} update")
    "opencode" => Some("\{quoted} upgrade")
    "hermes" => Some("\{quoted} update")
    "gemini" =>
      match ccs_sibling_bin(install.path, "npm") {
        Some(npm) =>
          Some(
            "\{ccs_quote_path_if_needed(npm)} i -g @google/gemini-cli@latest",
          )
        None => None
      }
    _ => None
  }
}

///|
fn ccs_static_tool_update_command(tool : String) -> String {
  match tool {
    "claude" =>
      ccs_chain_commands(
        "claude update", "npm i -g @anthropic-ai/claude-code@latest",
      )
    "codex" =>
      ccs_chain_commands("codex update", "npm i -g @openai/codex@latest")
    "gemini" => "npm i -g @google/gemini-cli@latest"
    "opencode" =>
      ccs_chain_commands("opencode upgrade", "npm i -g opencode-ai@latest")
    "openclaw" =>
      ccs_chain_commands("openclaw update --yes", "npm i -g openclaw@latest")
    "hermes" =>
      ccs_chain_commands(
        "hermes update", "bash -c 'tmp=$(mktemp) && curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh -o $tmp && bash $tmp; status=$?; rm -f $tmp; exit $status'",
      )
    _ => ""
  }
}

///|
fn ccs_chain_commands(primary : String, fallback : String) -> String {
  if fallback.trim().is_empty() {
    primary
  } else {
    "\{primary} || \{fallback}"
  }
}

///|
fn ccs_sibling_bin(path : String, exe : String) -> String? {
  let dir = @pathx.dirname(path)
  if dir.is_empty() {
    None
  } else {
    Some(@pathx.join(dir, exe))
  }
}

///|
fn ccs_shell_single_quote(value : String) -> String {
  "'" + value.replace_all(old="'", new="'\\''") + "'"
}

///|
fn ccs_quote_path_if_needed(path : String) -> String {
  if path.contains(" ") || path.contains("'") || path.contains("\"") {
    ccs_shell_single_quote(path)
  } else {
    path
  }
}

///|
fn ccs_last_lines(text : String, n : Int) -> String {
  let lines = text.split("\n").map(fn(line) { line.to_owned() })
  let start = if lines.length() > n { lines.length() - n } else { 0 }
  lines[start:].join("\n")
}

///|
fn ccs_first_output_line(output : String) -> String? {
  for line_view in output.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if !line.is_empty() {
      return Some(line)
    }
  }
  None
}

///|
fn ccs_tool_version_json(
  name : String,
  version : String?,
  latest_version : String?,
  error : String?,
  installed_but_broken : Bool,
) -> Json {
  {
    "name": Json::string(name),
    "version": match version {
      Some(value) => Json::string(value)
      None => Json::null()
    },
    "latest_version": match latest_version {
      Some(value) => Json::string(value)
      None => Json::null()
    },
    "error": match error {
      Some(value) if !value.is_empty() => Json::string(value)
      _ => Json::null()
    },
    "installed_but_broken": Json::boolean(installed_but_broken),
    "env_type": Json::string("macos"),
    "wsl_distro": Json::null(),
  }.to_json()
}
