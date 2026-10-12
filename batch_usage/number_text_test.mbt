///|
fn raw_result(
  input : String,
  output? : String = "0",
  total? : String = "null",
  status? : String = "200",
) -> String {
  "{\"custom_id\":\"precision\",\"response\":{\"status_code\":\{status},\"body\":{\"object\":\"chat.completion\",\"model\":\"m\",\"usage\":{\"prompt_tokens\":\{input},\"completion_tokens\":\{output},\"total_tokens\":\{total}}}}}"
}

///|
test "Raw fractional underflow and out-of-range tokens cannot round into counts" {
  for
    token in [
      "9007199254740990.5", "1.0000000000000001", "1e-400", "-1e-400", "9007199254740991.1",
      "9007199254740992.0", "9007199254740992", "0.0000000000000000000001", "1e99999999999999999999",
      "-1e99999999",
    ] {
    assert_rejected(raw_result(token), "whole nonnegative")
    assert_rejected(raw_result("0", output=token), "whole nonnegative")
  }
  assert_rejected(raw_result("1", total="1.0000000000000001"), "total_tokens")
  assert_rejected(raw_result("1", status="200.0000000000000001"), "HTTP status")
}

///|
test "Exact integral decimal and exponent counts retain intended values" {
  for
    (token, expected) in [
      ("1.00", 1.0),
      ("1e3", 1000.0),
      ("1000e-3", 1.0),
      ("1.200e2", 120.0),
      ("0e-9999999999999999999999", 0.0),
      ("-0.0E400", 0.0),
      ("9007199254740991.0", 9007199254740991.0),
      ("90071992547409910e-1", 9007199254740991.0),
      ("9.007199254740991e15", 9007199254740991.0),
      ("0.9007199254740991000000e16", 9007199254740991.0),
    ] {
    let result = import_ok(raw_result(token, total=token, status="2.00e2"))
    assert_eq(get(get(result, "summary"), "tokens"), Json::number(expected))
  }
}

///|
test "Number preservation ignores strings escaped quotes and duplicate overwritten values" {
  let source = "{\"custom_id\":\"数\\\"字\\\\1e-400\",\"ignored\":[1e-400,{\"x\":9007199254740990.5}],\"response\":{\"status_code\":200,\"body\":{\"object\":\"chat.completion\",\"model\":\"m\",\"usage\":{\"prompt_tokens\":1e-400,\"prompt_tokens\":1.20e2,\"completion_tokens\":0}}}}"
  let result = import_ok(source)
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(120))
  assert_rejected(raw_result("\"120\""), "whole nonnegative")
  assert_rejected(
    raw_result("1.0").replace(
      old="\"completion_tokens\":0",
      new="\"completion_tokens\":1e-400",
    ),
    "whole nonnegative",
  )
}
