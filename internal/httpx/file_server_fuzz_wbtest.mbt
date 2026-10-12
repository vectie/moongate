///|
priv struct FilePathFuzzer {
  mut state : Int64
}

///|
fn FilePathFuzzer::new(seed : Int64) -> FilePathFuzzer {
  { state: seed, }
}

///|
fn FilePathFuzzer::next(self : FilePathFuzzer, bound : Int) -> Int {
  self.state = self.state * 48_271L % 2_147_483_647L
  (self.state % bound.to_int64()).to_int()
}

///|
fn FilePathFuzzer::label(self : FilePathFuzzer) -> String {
  "asset-\{self.next(1_000_000)}"
}

///|
test "fuzz static file paths preserve safe generated paths" {
  let fuzz = FilePathFuzzer::new(0x46494c45L)
  for iteration in 0..<5_000 {
    let segments : Array[String] = ["assets"]
    for _ in 0..<(1 + fuzz.next(8)) {
      segments.push(fuzz.label())
    }
    let path = "/\{segments.join("/")}.js"
    let query = "?v=\{fuzz.next(1_000_000)}&cache=\{fuzz.next(1_000_000)}"
    match static_request_path("\{path}\{query}") {
      Some(parsed) if parsed == path => ()
      other =>
        fail(
          "seed=0x46494c45 iteration=\{iteration} path=\{path} parsed=\{Repr(other)}",
        )
    }
  }
}

///|
test "fuzz static file paths reject traversal insertion" {
  let fuzz = FilePathFuzzer::new(0x54524156L)
  let hostile = [
    ".", "..", "%2e", "%2E%2E", "%252e%252e", "..\\..", "a#b", "a%b",
  ]
  for iteration in 0..<5_000 {
    let candidate = "/assets/\{fuzz.label()}/\{hostile[fuzz.next(hostile.length())]}/\{fuzz.label()}.js"
    if static_request_path(candidate) is Some(_) {
      fail("seed=0x54524156 iteration=\{iteration} accepted=\{candidate}")
    }
  }
}

///|
test "adversarial static file path rejects oversized input" {
  assert_true(static_request_path("/assets/\{"a".repeat(8_193)}") is None)
}
