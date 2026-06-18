///|
test "ccs balance provider detection mirrors native command" {
  assert_true(
    moon_detect_balance_provider("https://api.deepseek.com/v1")
    is Some(DeepSeek),
  )
  assert_true(
    moon_detect_balance_provider("https://api.stepfun.ai/v1") is Some(StepFun),
  )
  assert_true(
    moon_detect_balance_provider("https://api.siliconflow.cn/v1")
    is Some(SiliconFlow),
  )
  assert_true(
    moon_detect_balance_provider("https://api.siliconflow.com/v1")
    is Some(SiliconFlowEn),
  )
  assert_true(
    moon_detect_balance_provider("https://openrouter.ai/api/v1")
    is Some(OpenRouter),
  )
  assert_true(
    moon_detect_balance_provider("https://api.novita.ai/v3") is Some(NovitaAI),
  )
  assert_true(moon_detect_balance_provider("https://example.com") is None)
}

///|
test "ccs balance deterministic errors match UsageResult shape" {
  assert_eq(
    moon_balance_error("Unknown balance provider").to_json(),
    {
      "success": Json::boolean(false),
      "error": Json::string("Unknown balance provider"),
    }.to_json(),
  )
  assert_eq(
    moon_balance_auth_error(401).to_json(),
    {
      "success": Json::boolean(false),
      "data": Json::array([
        {
          "isValid": Json::boolean(false),
          "invalidMessage": Json::string("Authentication failed (HTTP 401)"),
        }.to_json(),
      ]),
      "error": Json::string("Authentication failed (HTTP 401)"),
    }.to_json(),
  )
}

///|
test "ccs balance parsers keep provider-specific fields" {
  assert_eq(
    moon_parse_openrouter_balance(
      {
        "data": {
          "total_credits": Json::number(10.0),
          "total_usage": Json::number(3.25),
        }.to_json(),
      }.to_json(),
    ).to_json(),
    {
      "success": Json::boolean(true),
      "data": Json::array([
        {
          "planName": Json::string("OpenRouter"),
          "isValid": Json::boolean(true),
          "total": Json::number(10.0),
          "used": Json::number(3.25),
          "remaining": Json::number(6.75),
          "unit": Json::string("USD"),
        }.to_json(),
      ]),
    }.to_json(),
  )
  assert_eq(
    moon_parse_novita_balance(
      { "availableBalance": Json::string("12500") }.to_json(),
    ).to_json(),
    {
      "success": Json::boolean(true),
      "data": Json::array([
        {
          "planName": Json::string("Novita AI"),
          "isValid": Json::boolean(true),
          "remaining": Json::number(1.25),
          "unit": Json::string("USD"),
        }.to_json(),
      ]),
    }.to_json(),
  )
}
