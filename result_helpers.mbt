///|
#warnings("-result_error_return")
fn[T] moon_result(f : () -> T raise Error) -> Result[T, Error] {
  try f() catch {
    error => Err(error)
  } noraise {
    value => Ok(value)
  }
}

///|
#warnings("-result_error_return")
async fn[T] moon_async_result(
  f : async () -> T raise Error,
) -> Result[T, Error] {
  try f() catch {
    error => Err(error)
  } noraise {
    value => Ok(value)
  }
}

///|
fn to_ci_headers(
  headers : Map[String, String],
) -> Map[@http.CaseInsensitiveString, String] {
  let out : Map[@http.CaseInsensitiveString, String] = Map([])
  for k, v in headers {
    out[@http.CaseInsensitiveString(k)] = v
  }
  out
}

///|
fn from_ci_headers(
  headers : Map[@http.CaseInsensitiveString, String],
) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for k, v in headers {
    out[k.0] = v
  }
  out
}
