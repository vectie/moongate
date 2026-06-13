///|
const TREND_HOUR_SECONDS : Int = 60 * 60

///|
const TREND_DAY_SECONDS : Int = 24 * 60 * 60

///|
const TREND_ZONE_OFFSET_SECONDS : Int = 8 * 60 * 60

///|
pub fn TrafficStats::usage_trends_json(
  self : TrafficStats,
  start_ts? : Int? = None,
  end_ts? : Int? = None,
  app_type? : String? = None,
) -> Json {
  let normalized = normalize_trend_range(start_ts, end_ts)
  if normalized.duration <= TREND_DAY_SECONDS {
    self.hourly_usage_trends_json(
      normalized.start_ts,
      normalized.end_ts,
      app_type,
    )
  } else {
    self.daily_usage_trends_json(
      normalized.start_ts,
      normalized.end_ts,
      app_type,
    )
  }
}

///|
priv struct TrendRange {
  start_ts : Int
  end_ts : Int
  duration : Int
}

///|
priv struct DailyStatsAccumulator {
  date : String
  mut request_count : Int
  mut total_cost_nano : Int64
  mut total_tokens : Int
  mut total_input_tokens : Int
  mut total_output_tokens : Int
  mut total_cache_creation_tokens : Int
  mut total_cache_read_tokens : Int
}

///|
fn DailyStatsAccumulator::new(date : String) -> DailyStatsAccumulator {
  {
    date,
    request_count: 0,
    total_cost_nano: 0L,
    total_tokens: 0,
    total_input_tokens: 0,
    total_output_tokens: 0,
    total_cache_creation_tokens: 0,
    total_cache_read_tokens: 0,
  }
}

///|
fn DailyStatsAccumulator::add(
  self : DailyStatsAccumulator,
  log : RequestLog,
) -> Unit {
  let fresh_input_tokens = request_log_fresh_input_tokens(log)
  self.request_count += 1
  self.total_cost_nano += request_log_total_cost_nano(log)
  self.total_tokens += fresh_input_tokens + log.output_tokens
  self.total_input_tokens += fresh_input_tokens
  self.total_output_tokens += log.output_tokens
  self.total_cache_creation_tokens += log.cache_creation_tokens
  self.total_cache_read_tokens += log.cache_read_tokens
}

///|
fn DailyStatsAccumulator::to_json(self : DailyStatsAccumulator) -> Json {
  {
    "date": Json::string(self.date),
    "requestCount": Json::number(self.request_count.to_double()),
    "totalCost": Json::string(format_nano_usd_fixed_6(self.total_cost_nano)),
    "totalTokens": Json::number(self.total_tokens.to_double()),
    "totalInputTokens": Json::number(self.total_input_tokens.to_double()),
    "totalOutputTokens": Json::number(self.total_output_tokens.to_double()),
    "totalCacheCreationTokens": Json::number(
      self.total_cache_creation_tokens.to_double(),
    ),
    "totalCacheReadTokens": Json::number(
      self.total_cache_read_tokens.to_double(),
    ),
  }.to_json()
}

///|
fn normalize_trend_range(start_ts : Int?, end_ts : Int?) -> TrendRange {
  let end_ts = end_ts.unwrap_or(trend_now_seconds())
  let mut start_ts = start_ts.unwrap_or(end_ts - TREND_DAY_SECONDS)
  if start_ts >= end_ts {
    start_ts = end_ts - TREND_DAY_SECONDS
  }
  { start_ts, end_ts, duration: end_ts - start_ts }
}

///|
fn trend_now_seconds() -> Int {
  @os.unix_seconds()
}

///|
fn TrafficStats::hourly_usage_trends_json(
  self : TrafficStats,
  start_ts : Int,
  end_ts : Int,
  app_type : String?,
) -> Json {
  let bucket_count = trend_bucket_count(end_ts - start_ts, TREND_HOUR_SECONDS)
  let buckets : Array[DailyStatsAccumulator] = []
  for i in 0..<bucket_count {
    buckets.push(
      DailyStatsAccumulator::new(
        trend_timestamp_rfc3339(start_ts + i * TREND_HOUR_SECONDS),
      ),
    )
  }
  for log in self.request_logs {
    if !self.request_log_is_effective(log) ||
      !request_log_matches_trend(log, start_ts, end_ts, app_type) {
      continue
    }
    let mut bucket_index = (log.created_at - start_ts) / TREND_HOUR_SECONDS
    if bucket_index < 0 {
      continue
    }
    if bucket_index >= bucket_count {
      bucket_index = bucket_count - 1
    }
    buckets[bucket_index].add(log)
  }
  Json::array(buckets.map(fn(bucket) { bucket.to_json() }))
}

///|
fn TrafficStats::daily_usage_trends_json(
  self : TrafficStats,
  start_ts : Int,
  end_ts : Int,
  app_type : String?,
) -> Json {
  let start_day = trend_local_day_index(start_ts)
  let end_day = trend_local_day_index(end_ts)
  let bucket_count = max_int(end_day - start_day + 1, 1)
  let buckets : Array[DailyStatsAccumulator] = []
  for i in 0..<bucket_count {
    buckets.push(
      DailyStatsAccumulator::new(
        trend_timestamp_rfc3339(trend_local_day_start_ts(start_day + i)),
      ),
    )
  }
  for log in self.request_logs {
    if !self.request_log_is_effective(log) ||
      !request_log_matches_trend(log, start_ts, end_ts, app_type) {
      continue
    }
    let bucket_index = trend_local_day_index(log.created_at) - start_day
    if bucket_index >= 0 && bucket_index < bucket_count {
      buckets[bucket_index].add(log)
    }
  }
  Json::array(buckets.map(fn(bucket) { bucket.to_json() }))
}

///|
fn request_log_matches_trend(
  log : RequestLog,
  start_ts : Int,
  end_ts : Int,
  app_type : String?,
) -> Bool {
  log.created_at >= start_ts &&
  log.created_at <= end_ts &&
  request_log_matches_app(log, app_type)
}

///|
fn trend_bucket_count(duration : Int, bucket_seconds : Int) -> Int {
  max_int((max_int(duration, 1) + bucket_seconds - 1) / bucket_seconds, 1)
}

///|
fn trend_local_day_index(timestamp : Int) -> Int {
  floor_div_int(timestamp + TREND_ZONE_OFFSET_SECONDS, TREND_DAY_SECONDS)
}

///|
fn trend_local_day_start_ts(day_index : Int) -> Int {
  day_index * TREND_DAY_SECONDS - TREND_ZONE_OFFSET_SECONDS
}

///|
fn floor_div_int(value : Int, divisor : Int) -> Int {
  if value >= 0 {
    value / divisor
  } else {
    (value - divisor + 1) / divisor
  }
}

///|
fn trend_timestamp_rfc3339(timestamp : Int) -> String {
  let zone = trend_display_zone()
  try @time.unix(timestamp.to_int64(), zone~) catch {
    _ => timestamp.to_string()
  } noraise {
    zoned =>
      "\{zoned.to_plain_date_time().to_string()}\{zoned.offset().to_string()}"
  }
}

///|
fn trend_display_zone() -> @time.Zone {
  @time.fixed_zone("Asia/Shanghai", TREND_ZONE_OFFSET_SECONDS) catch {
    _ => @time.utc_zone
  }
}
