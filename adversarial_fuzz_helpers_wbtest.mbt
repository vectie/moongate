///|
/// Small deterministic generator for reproducible fuzz-style regression tests.
/// The Park-Miller state stays within Int64 range and every failing input can
/// be reproduced from the fixed seed and iteration index.
priv struct AdversarialFuzzer {
  mut state : Int64
}

///|
fn AdversarialFuzzer::new(seed : Int64) -> AdversarialFuzzer {
  let state = seed % 2_147_483_647L
  { state: if state <= 0L { state + 2_147_483_646L } else { state }, }
}

///|
fn AdversarialFuzzer::next(self : AdversarialFuzzer, bound : Int) -> Int {
  if bound <= 0 {
    abort("adversarial fuzz bound must be positive")
  }
  self.state = self.state * 48_271L % 2_147_483_647L
  (self.state % bound.to_int64()).to_int()
}

///|
fn AdversarialFuzzer::ascii(
  self : AdversarialFuzzer,
  min_length : Int,
  max_length : Int,
  alphabet? : String = "abcdefghijklmnopqrstuvwxyz0123456789-._~",
) -> String {
  let length = min_length + self.next(max_length - min_length + 1)
  let builder = StringBuilder(size_hint=length)
  for _ in 0..<length {
    builder.write_char(alphabet.get_char(self.next(alphabet.length())).unwrap())
  }
  builder.to_string()
}

///|
fn adversarial_ascii_insert(
  base : String,
  index : Int,
  value : String,
) -> String {
  "\{base[:index].to_owned()}\{value}\{base[index:].to_owned()}"
}

///|
fn AdversarialFuzzer::json(self : AdversarialFuzzer, depth : Int) -> Json {
  let kind = if depth <= 0 { self.next(4) } else { self.next(6) }
  match kind {
    0 => Json::null()
    1 => Json::boolean(self.next(2) == 0)
    2 => {
      let whole = self.next(2_000_001) - 1_000_000
      if self.next(4) == 0 {
        Json::number(whole.to_double() + 0.5)
      } else {
        Json::number(whole.to_double())
      }
    }
    3 => Json::string(self.ascii(0, 48))
    4 => {
      let values : Array[Json] = []
      for _ in 0..<self.next(6) {
        values.push(self.json(depth - 1))
      }
      Json::array(values)
    }
    _ => {
      let values : Map[String, Json] = Map([])
      for _ in 0..<self.next(6) {
        values[self.ascii(1, 16)] = self.json(depth - 1)
      }
      Json::object(values)
    }
  }
}

///|
fn adversarial_permute_json(value : Json) -> Json {
  match value {
    Object(obj) => {
      let keys = obj.keys().collect()
      let permuted : Map[String, Json] = Map([])
      let mut index = keys.length() - 1
      while index >= 0 {
        let key = keys[index]
        permuted[key] = adversarial_permute_json(obj[key])
        index -= 1
      }
      Json::object(permuted)
    }
    Array(values) => Json::array(values.map(adversarial_permute_json))
    _ => value
  }
}
