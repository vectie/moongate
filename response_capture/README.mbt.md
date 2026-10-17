# Saved Responses captures

This pure API converts one saved response JSON object or HTTP SSE body per input
into an ordinary Usage File Explorer artifact. See the [format and outcome
guide](../docs/responses-capture-import.md) before interpreting totals.

```mbt check
///|
test "explicit incomplete consumption is retained" {
  let capture =
    #|{"object":"response","id":"resp-example","model":"fixture","status":"incomplete","usage":{"input_tokens":3,"output_tokens":2,"total_tokens":5}}
  guard @response_capture.import_response_captures_json([
      ("example.json", capture),
    ])
    is Ok(result) else {
    fail("Expected saved response")
  }
  guard result
    is { "total": Number(rows, ..), "sourceCoverageUnknown": True, .. } else {
    fail("Expected usage artifact")
  }
  assert_eq(rows, 1.0)
}
```
