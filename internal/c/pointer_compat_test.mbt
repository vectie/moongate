///|
test "pointer indexing retains named and indexed access" {
  let pointer : @c.Pointer[Int32] = @c.malloc(8)
  defer @c.free(pointer)
  assert_false(pointer.is_null())
  pointer.set(0, 17)
  assert_eq(pointer.at(0), 17)
  pointer[1] = 23
  assert_eq(pointer[1], 23)
  pointer.store(offset=0, 29)
  assert_eq(pointer.load(), 29)
}
