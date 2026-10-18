///|
const TREND_HOUR_SECONDS : Int32 = 60 * 60

///|
const TREND_DAY_SECONDS : Int32 = 24 * 60 * 60

///|
fn TrafficStats::usage_trends_json(
  self : TrafficStats,
  start_ts~ : Int32? = None,
  end_ts~ : Int32? = None,
  app_type~ : String? = None,
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
  start_ts : Int32
  end_ts : Int32
  duration : Int32
}

///|
priv struct DailyStatsAccumulator {
  date : String
  mut request_count : Int32
  mut total_cost_nano : Int64
  mut total_tokens : Int32
  mut total_input_tokens : Int32
  mut total_output_tokens : Int32
  mut total_cache_creation_tokens : Int32
  mut total_cache_read_tokens : Int32
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
fn DailyStatsAccumulator::add_rollup(
  self : DailyStatsAccumulator,
  rollup : UsageDailyRollup,
) -> Unit {
  let fresh_input_tokens = usage_daily_rollup_fresh_input_tokens(rollup)
  self.request_count += rollup.request_count
  self.total_cost_nano += rollup.total_cost_nano
  self.total_tokens += fresh_input_tokens + rollup.output_tokens
  self.total_input_tokens += fresh_input_tokens
  self.total_output_tokens += rollup.output_tokens
  self.total_cache_creation_tokens += rollup.cache_creation_tokens
  self.total_cache_read_tokens += rollup.cache_read_tokens
}

///|
fn DailyStatsAccumulator::to_json(self : DailyStatsAccumulator) -> Json {
  Json({
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
  })
}

///|
fn normalize_trend_range(start_ts : Int32?, end_ts : Int32?) -> TrendRange {
  let end_ts = end_ts.unwrap_or(trend_now_seconds())
  let mut start_ts = start_ts.unwrap_or(end_ts - TREND_DAY_SECONDS)
  if start_ts >= end_ts {
    start_ts = end_ts - TREND_DAY_SECONDS
  }
  { start_ts, end_ts, duration: end_ts - start_ts, }
}

///|
fn trend_now_seconds() -> Int32 {
  @os.unix_seconds()
}

///|
fn TrafficStats::hourly_usage_trends_json(
  self : TrafficStats,
  start_ts : Int32,
  end_ts : Int32,
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
  start_ts : Int32,
  end_ts : Int32,
  app_type : String?,
) -> Json {
  let buckets : Array[DailyStatsAccumulator] = []
  let bucket_indices : Map[String, Int32] = Map([], capacity=0)
  let end_day_start = trend_local_day_start_ts(end_ts)
  let mut bucket_start = trend_local_day_start_ts(start_ts)
  while bucket_start <= end_day_start {
    let key = trend_local_day_key(bucket_start)
    bucket_indices.set(key, buckets.length())
    buckets.push(
      DailyStatsAccumulator::new(trend_timestamp_rfc3339(bucket_start)),
    )
    let next_bucket_start = trend_local_next_day_start_ts(bucket_start)
    if next_bucket_start <= bucket_start {
      break
    }
    bucket_start = next_bucket_start
  }
  if buckets.length() == 0 {
    let key = trend_local_day_key(start_ts)
    bucket_indices.set(key, 0)
    buckets.push(DailyStatsAccumulator::new(trend_timestamp_rfc3339(start_ts)))
  }
  for log in self.request_logs {
    if !self.request_log_is_effective(log) ||
      !request_log_matches_trend(log, start_ts, end_ts, app_type) {
      continue
    }
    match bucket_indices.get(trend_local_day_key(log.created_at)) {
      Some(bucket_index) => buckets[bucket_index].add(log)
      None => ()
    }
  }
  for rollup in self.daily_rollups {
    if !usage_daily_rollup_matches_aggregate(
        rollup,
        Some(start_ts),
        Some(end_ts),
        app_type,
      ) {
      continue
    }
    match bucket_indices.get(rollup.date) {
      Some(bucket_index) => buckets[bucket_index].add_rollup(rollup)
      None => ()
    }
  }
  Json::array(buckets.map(fn(bucket) { bucket.to_json() }))
}

///|
fn request_log_matches_trend(
  log : RequestLog,
  start_ts : Int32,
  end_ts : Int32,
  app_type : String?,
) -> Bool {
  log.created_at >= start_ts &&
  log.created_at <= end_ts &&
  request_log_matches_app(log, app_type)
}

///|
fn trend_bucket_count(duration : Int32, bucket_seconds : Int32) -> Int32 {
  max_int((max_int(duration, 1) + bucket_seconds - 1) / bucket_seconds, 1)
}

///|
fn floor_div_int(value : Int32, divisor : Int32) -> Int32 {
  if value >= 0 {
    value / divisor
  } else {
    (value - divisor + 1) / divisor
  }
}

///|
fn trend_local_day_start_ts(timestamp : Int32) -> Int32 {
  @os.local_day_start_seconds(timestamp)
}

///|
fn trend_local_next_day_start_ts(timestamp : Int32) -> Int32 {
  @os.local_next_day_start_seconds(timestamp)
}

///|
fn trend_local_day_key(timestamp : Int32) -> String {
  @os.local_date_key(timestamp.to_int64())
}

///|
fn trend_timestamp_rfc3339(timestamp : Int32) -> String {
  @os.local_rfc3339(timestamp.to_int64())
}
