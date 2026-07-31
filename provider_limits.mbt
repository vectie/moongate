///|
priv struct ProviderLimitConfig {
  daily_limit_usd : String?
  monthly_limit_usd : String?
}

///|
fn ProviderLimitConfig::new(
  daily_limit_usd? : String? = None,
  monthly_limit_usd? : String? = None,
) -> ProviderLimitConfig {
  { daily_limit_usd, monthly_limit_usd }
}

///|
fn TrafficStats::set_provider_limits(
  self : TrafficStats,
  provider_id : String,
  app_type : String,
  daily_limit_usd? : String? = None,
  monthly_limit_usd? : String? = None,
) -> Unit {
  self.provider_limits.set(
    provider_limit_key(provider_id, app_type),
    ProviderLimitConfig::new(daily_limit_usd~, monthly_limit_usd~),
  )
}

///|
fn TrafficStats::provider_limit_status_json(
  self : TrafficStats,
  provider_id : String,
  app_type : String,
  daily_limit_usd? : String? = None,
  monthly_limit_usd? : String? = None,
  now_ts? : Int? = None,
) -> Json {
  let configured = self.provider_limits.get(
    provider_limit_key(provider_id, app_type),
  )
  let daily_limit = match daily_limit_usd {
    Some(limit) => Some(limit)
    None =>
      match configured {
        Some(config) => config.daily_limit_usd
        None => None
      }
  }
  let monthly_limit = match monthly_limit_usd {
    Some(limit) => Some(limit)
    None =>
      match configured {
        Some(config) => config.monthly_limit_usd
        None => None
      }
  }
  let now_ts = now_ts.unwrap_or(trend_now_seconds())
  let daily_usage_nano = self.provider_daily_usage_nano(
    provider_id, app_type, now_ts,
  )
  let monthly_usage_nano = self.provider_monthly_usage_nano(
    provider_id, app_type, now_ts,
  )
  let daily_limit_nano = daily_limit.map(fn(limit) {
    parse_decimal_scaled(limit, NANO_USD_SCALE)
  })
  let monthly_limit_nano = monthly_limit.map(fn(limit) {
    parse_decimal_scaled(limit, NANO_USD_SCALE)
  })
  {
    "providerId": Json::string(provider_id),
    "dailyUsage": Json::string(format_nano_usd_fixed_6(daily_usage_nano)),
    "dailyLimit": optional_limit_json(daily_limit_nano),
    "dailyExceeded": Json::boolean(
      limit_exceeded(daily_usage_nano, daily_limit_nano),
    ),
    "monthlyUsage": Json::string(format_nano_usd_fixed_6(monthly_usage_nano)),
    "monthlyLimit": optional_limit_json(monthly_limit_nano),
    "monthlyExceeded": Json::boolean(
      limit_exceeded(monthly_usage_nano, monthly_limit_nano),
    ),
  }.to_json()
}

///|
fn TrafficStats::provider_limit_exceeded(
  self : TrafficStats,
  provider_id : String,
  app_type : String,
  now_ts? : Int = trend_now_seconds(),
) -> Bool {
  guard self.provider_limits.get(provider_limit_key(provider_id, app_type))
    is Some(config) else {
    return false
  }
  let daily_limit = config.daily_limit_usd.map(fn(limit) {
    parse_decimal_scaled(limit, NANO_USD_SCALE)
  })
  let monthly_limit = config.monthly_limit_usd.map(fn(limit) {
    parse_decimal_scaled(limit, NANO_USD_SCALE)
  })
  limit_exceeded(
    self.provider_daily_usage_nano(provider_id, app_type, now_ts),
    daily_limit,
  ) ||
  limit_exceeded(
    self.provider_monthly_usage_nano(provider_id, app_type, now_ts),
    monthly_limit,
  )
}

///|
fn TrafficStats::provider_limit_monitor_counts(
  self : TrafficStats,
  now_ts? : Int = trend_now_seconds(),
) -> (Int, Int) {
  let mut configured_count = 0
  let mut exceeded_count = 0
  for key, config in self.provider_limits {
    if config.daily_limit_usd is None && config.monthly_limit_usd is None {
      continue
    }
    configured_count += 1
    let parts = key.split("|").to_array()
    if parts.length() != 2 {
      continue
    }
    if self.provider_limit_exceeded(
        parts[0].to_owned(),
        parts[1].to_owned(),
        now_ts~,
      ) {
      exceeded_count += 1
    }
  }
  (configured_count, exceeded_count)
}

///|
fn TrafficStats::provider_daily_usage_nano(
  self : TrafficStats,
  provider_id : String,
  app_type : String,
  now_ts : Int,
) -> Int64 {
  let today = trend_local_day_key(now_ts)
  let mut total = 0L
  for log in self.request_logs {
    if log.provider_id == provider_id &&
      log.app_type == app_type &&
      trend_local_day_key(log.created_at) == today {
      total += request_log_total_cost_nano(log)
    }
  }
  total
}

///|
fn TrafficStats::provider_monthly_usage_nano(
  self : TrafficStats,
  provider_id : String,
  app_type : String,
  now_ts : Int,
) -> Int64 {
  let month = trend_local_month_key(now_ts)
  let mut total = 0L
  for log in self.request_logs {
    if log.provider_id == provider_id &&
      log.app_type == app_type &&
      trend_local_month_key(log.created_at) == month {
      total += request_log_total_cost_nano(log)
    }
  }
  total
}

///|
fn provider_limit_key(provider_id : String, app_type : String) -> String {
  "\{provider_id}|\{app_type}"
}

///|
fn trend_local_month_key(timestamp : Int) -> String {
  @os.local_month_key(timestamp.to_int64())
}

///|
fn optional_limit_json(limit : Int64?) -> Json {
  match limit {
    Some(value) => Json::string(format_nano_usd_fixed_2(value))
    None => Json::null()
  }
}

///|
fn limit_exceeded(usage : Int64, limit : Int64?) -> Bool {
  match limit {
    Some(value) => usage >= value
    None => false
  }
}

///|
fn format_nano_usd_fixed_2(nano : Int64) -> String {
  let negative = nano < 0L
  let absolute = if negative { 0L - nano } else { nano }
  let cents = divide_rounded(absolute, 10_000_000L)
  let whole = cents / 100L
  let fraction = cents % 100L
  let sign = if negative { "-" } else { "" }
  "\{sign}\{whole}.\{left_pad_zeroes(fraction.to_string(), 2)}"
}
