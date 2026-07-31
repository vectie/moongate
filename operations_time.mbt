///|
fn moongate_epoch_ms() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
fn moongate_canonical_utc_now() -> String {
  let value = @time
    .unix(moongate_epoch_ms() / 1000L)
    .to_plain_date_time()
    .to_string() catch {
    _ => return ""
  }
  "\{value}Z"
}
