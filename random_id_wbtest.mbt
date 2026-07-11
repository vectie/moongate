///|
test "moongate random ids remain unique across rapid generation" {
  let seen : Map[String, Bool] = Map([], capacity=128)
  for _ in 0..<100 {
    let id = moongate_random_id()
    assert_false(id.is_empty())
    assert_false(seen.contains(id))
    seen[id] = true
  }
  assert_eq(seen.length(), 100)
}
