///|
fn main {
  let args = @os.args()
  guard args.length() >= 2 else {
    println(
      "Usage: import_usage_csv '<CSV or JSON text>' [--app VALUE] [--provider VALUE] [--model VALUE] [--start-day YYYY-MM-DD] [--end-day YYYY-MM-DD] [--report]\nSynthetic/scrubbed text only: argv is visible. Outputs normalized preview JSON or text report; sends no requests.",
    )
    @os.exit(2)
  }
  let mut app = ""
  let mut provider = ""
  let mut model = ""
  let mut start_day = ""
  let mut end_day = ""
  let mut report = false
  for i = 2; i < args.length(); {
    let flag = args[i]
    if flag == "--report" {
      report = true
      continue i + 1
    }
    guard i + 1 < args.length() else {
      println("Missing value for \{flag}")
      @os.exit(2)
    }
    match flag {
      "--app" => app = args[i + 1]
      "--provider" => provider = args[i + 1]
      "--model" => model = args[i + 1]
      "--start-day" => start_day = args[i + 1]
      "--end-day" => end_day = args[i + 1]
      _ => {
        println("Unknown option: \{flag}")
        @os.exit(2)
      }
    }
    continue i + 2
  }
  match
    @usage_preview.moongate_preview_usage_file_json(
      args[1],
      app~,
      provider~,
      model~,
      start_day~,
      end_day~,
    ) {
    Err(error) => {
      println("Usage preview failed: \{error}")
      @os.exit(1)
    }
    Ok(result) =>
      if report {
        guard result is Object(obj) && obj.get("report") is Some(String(text)) else {
          println("Missing usage report")
          @os.exit(1)
        }
        println(text)
      } else {
        println(result.stringify())
      }
  }
}
