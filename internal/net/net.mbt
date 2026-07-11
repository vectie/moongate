///|
extern "c" fn tcp_localhost_port_open(port : Int, timeout_ms : Int) -> Int = "moonbit_moongate_net_tcp_localhost_port_open"

///|
pub fn localhost_port_open(port : Int, timeout_ms? : Int = 100) -> Bool {
  if port <= 0 || port > 65535 {
    return false
  }
  tcp_localhost_port_open(port, timeout_ms) == 1
}

///|
test "localhost port probe rejects invalid ports" {
  assert_false(localhost_port_open(0))
  assert_false(localhost_port_open(65536))
}
