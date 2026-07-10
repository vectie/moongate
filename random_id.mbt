///|
let moonstat_random_id_fallback_counter : Ref[Int] = Ref(0)

///|
fn moonstat_random_id() -> String {
  let randomer = @rand.chacha8() catch {
    _ => {
      moonstat_random_id_fallback_counter.val += 1
      return "\{@async.now()}-\{moonstat_random_id_fallback_counter.val}"
    }
  }
  @uuid.generator(randomer).v4().to_string()
}
