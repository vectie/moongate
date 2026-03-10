///|
/// 自动 hosts 文件劫持模块
/// 通过将 api.anthropic.com 重定向到本地网关实现透明劫持

const ANTHROPIC_HOST = "api.anthropic.com"
const HIJACK_COMMENT = "# hijack-auto-hijack"

///|
/// 获取系统的 hosts 文件路径
fn get_hosts_path() -> String {
  "/etc/hosts"  // macOS/Linux，Windows 需要特殊处理
}

///|
/// 检查是否具有写入 hosts 文件的权限
pub async fn check_permission() -> Bool {
  let hosts_path = get_hosts_path()
  try {
    let _ = @fsx.read_file(hosts_path)
    // 如果能读取，尝试写入测试
    let test_line = "# hijack-permission-test\n"
    let content = @fsx.read_file(hosts_path)
    let new_content = content + test_line
    @fsx.write_to_file(hosts_path, new_content, create=0o644)
    // 移除测试行
    let content2 = @fsx.read_file(hosts_path)
    let final_content = content2.replace(old=test_line, new="")
    @fsx.write_to_file(hosts_path, final_content, create=0o644)
    true
  } catch {
    _ => false
  }
}

///|
/// 生成劫持条目
fn generate_hijack_entry(port : Int) -> String {
  "127.0.0.1 \{ANTHROPIC_HOST} \{HIJACK_COMMENT}\n"
}

///|
/// 检查是否已经安装了劫持
pub async fn is_hijack_installed() -> Bool {
  let hosts_path = get_hosts_path()
  try {
    let content = @fsx.read_file(hosts_path)
    content.contains(HIJACK_COMMENT)
  } catch {
    _ => false
  }
}

///|
/// 安装 hosts 劫持
pub async fn install_hijack(port : Int) -> Result[Unit, String] {
  let hosts_path = get_hosts_path()
  
  // 检查权限
  if not(check_permission()) {
    return Err("没有权限修改 hosts 文件，请使用 sudo 运行")
  }
  
  // 检查是否已安装
  if is_hijack_installed() {
    return Err("hosts 劫持已经安装")
  }
  
  try {
    let content = @fsx.read_file(hosts_path)
    let entry = generate_hijack_entry(port)
    let new_content = content + entry
    @fsx.write_to_file(hosts_path, new_content, create=0o644)
    Ok(())
  } catch {
    err => Err("写入 hosts 文件失败：\{err}")
  }
}

///|
/// 卸载 hosts 劫持
pub async fn uninstall_hijack() -> Result[Unit, String] {
  let hosts_path = get_hosts_path()
  
  // 检查权限
  if not(check_permission()) {
    return Err("没有权限修改 hosts 文件，请使用 sudo 运行")
  }
  
  // 检查是否已安装
  if not(is_hijack_installed()) {
    return Err("hosts 劫持未安装")
  }
  
  try {
    let content = @fsx.read_file(hosts_path)
    let lines = content.split("\n").to_array()
    let filtered_lines = lines.iter()
      .filter(fn(line) { not(line.contains(HIJACK_COMMENT)) })
      .collect()
    let new_content = filtered_lines.join("\n")
    @fsx.write_to_file(hosts_path, new_content, create=0o644)
    Ok(())
  } catch {
    err => Err("写入 hosts 文件失败：\{err}")
  }
}

///|
/// 刷新 DNS 缓存
async fn flush_dns() -> Unit {
  // macOS
  ignore(@spawn.spawn("sudo", ["dscacheutil", "-flushcache"]))
  ignore(@spawn.spawn("sudo", ["killall", "-HUP", "mDNSResponder"]))
}

///|
/// 安装并刷新 DNS
pub async fn install_and_flush(port : Int) -> Result[Unit, String] {
  let result = install_hijack(port)
  match result {
    Ok(_) => {
      flush_dns()
      Ok(())
    }
    Err(e) => Err(e)
  }
}

///|
/// 卸载并刷新 DNS
pub async fn uninstall_and_flush() -> Result[Unit, String] {
  let result = uninstall_hijack()
  match result {
    Ok(_) => {
      flush_dns()
      Ok(())
    }
    Err(e) => Err(e)
  }
}
