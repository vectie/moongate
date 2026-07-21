///|
test "static file server sends SVG with an image MIME type" {
  assert_eq(static_content_type("assets/moongate.svg"), "image/svg+xml")
  assert_eq(
    static_content_type("assets/moongate.bin"),
    "application/octet-stream",
  )
}
