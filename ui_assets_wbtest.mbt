///|
async test "moonstat ui assets expose operator dashboard at public root" {
  let html = @fsx.read_file("public/index.html")
  assert_true(html.contains("<title>Moonstat</title>"))
  assert_true(html.contains("/assets/moonstat.css"))
  assert_true(html.contains("/assets/moonstat.js"))
  assert_true(html.contains("Provider Health"))
  assert_true(html.contains("Request Log"))
}

///|
async test "moonstat ui fetches current backend route surface" {
  let js = @fsx.read_file("public/assets/moonstat.js")
  let required = [
    "/health", "/status", "/proxy/status", "/usage/summary", "/usage/summary/by-app",
    "/usage/model-stats", "/usage/logs?limit=8",
  ]
  for route in required {
    assert_true(js.contains(route))
  }
  assert_true(js.contains("fetch(path"))
  assert_true(js.contains("setInterval"))
}

///|
async test "moonstat lepusa manifest uses published package boundary shape" {
  let manifest = @fsx.read_file("lepusa.json")
  assert_true(manifest.contains("\"identifier\": \"dev.vectie.moonstat\""))
  assert_true(manifest.contains("\"localhost\""))
  assert_true(
    manifest.contains(
      "\"command\": [\"moon\", \"run\", \"cmd/main\", \"--\", \"start\"]",
    ),
  )
  assert_true(manifest.contains("\"readinessPath\": \"/health\""))
  assert_true(manifest.contains("\"serviceDiscovery\""))
  assert_false(manifest.contains("../lepusa"))
  assert_false(manifest.contains("../rba"))
}
