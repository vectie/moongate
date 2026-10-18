///|
// Independent limits: never truncate or substitute daily rollups for raw samples.
const COHORT_SNAPSHOT_ROW_LIMIT = 500

///|
const COHORT_SNAPSHOT_BYTE_LIMIT = 262144

///|
priv struct RetainedCohort {
  provider_id : String
  request_model : String
  mut total : Int32
  mut status_2xx : Int32
  mut status_4xx : Int32
  mut status_5xx : Int32
  mut status_other : Int32
  mut successful : Int32
  mut streaming_successful : Int32
  mut invalid_latency : Int32
  mut missing_first_event : Int32
  mut invalid_first_event : Int32
  mut first_event_invalid_elapsed : Int32
  mut oldest : Int32?
  mut newest : Int32?
  latency : Array[Int32]
  first_event : Array[Int32]
  response_models : Map[String, Int32]
  mut missing_response_model : Int32
}

///|
fn RetainedCohort::new(
  provider_id : String,
  request_model : String,
) -> RetainedCohort {
  {
    provider_id,
    request_model,
    total: 0,
    status_2xx: 0,
    status_4xx: 0,
    status_5xx: 0,
    status_other: 0,
    successful: 0,
    streaming_successful: 0,
    invalid_latency: 0,
    missing_first_event: 0,
    invalid_first_event: 0,
    first_event_invalid_elapsed: 0,
    oldest: None,
    newest: None,
    latency: [],
    first_event: [],
    response_models: {},
    missing_response_model: 0,
  }
}

///|
fn cohort_utc(seconds : Int32) -> String {
  let value = @time.unix(seconds.to_int64()).to_plain_date_time().to_string() catch {
      _ => return "unavailable"
    }
  "\{value}Z"
}

///|
fn cohort_percentiles(samples : Array[Int32]) -> Json {
  let summary = @telemetry.percentile_snapshot(samples)
  {
    "sample_count": Json(summary.sample_count),
    "p50_ms": optional_int_json(summary.p50_ms),
    "p95_ms": optional_int_json(summary.p95_ms),
    "p99_ms": optional_int_json(summary.p99_ms),
  }
}

///|
fn RetainedCohort::add(self : RetainedCohort, log : RequestLog) -> Unit {
  self.total += 1
  if log.status_code >= 200 && log.status_code < 300 {
    self.status_2xx += 1
  } else if log.status_code >= 400 && log.status_code < 500 {
    self.status_4xx += 1
  } else if log.status_code >= 500 && log.status_code < 600 {
    self.status_5xx += 1
  } else {
    self.status_other += 1
  }
  self.oldest = Some(self.oldest.unwrap_or(log.created_at).min(log.created_at))
  self.newest = Some(self.newest.unwrap_or(log.created_at).max(log.created_at))
  // An error-bearing 2xx is not a successful timing sample.
  if log.status_code < 200 ||
    log.status_code >= 300 ||
    log.error_message is Some(_) {
    return
  }
  self.successful += 1
  if log.model.is_empty() {
    self.missing_response_model += 1
  } else {
    self.response_models[log.model] = self.response_models
      .get(log.model)
      .unwrap_or(0) +
      1
  }
  if log.latency_ms > 0 {
    self.latency.push(log.latency_ms)
  } else {
    self.invalid_latency += 1
  }
  if !log.is_streaming {
    return
  }
  self.streaming_successful += 1
  if log.latency_ms <= 0 {
    self.first_event_invalid_elapsed += 1
    return
  }
  match log.first_token_ms {
    None => self.missing_first_event += 1
    Some(value) if value >= 0 && value <= log.latency_ms =>
      self.first_event.push(value)
    _ => self.invalid_first_event += 1
  }
}

///|
fn RetainedCohort::snapshot(self : RetainedCohort) -> Json {
  let models = self.response_models.keys().collect()
  models.sort()
  {
    "provider_id": Json(self.provider_id),
    "request_model": Json(self.request_model),
    "total": Json(self.total),
    "status_2xx": Json(self.status_2xx),
    "status_4xx": Json(self.status_4xx),
    "status_5xx": Json(self.status_5xx),
    "status_other": Json(self.status_other),
    "successful": Json(self.successful),
    "unsuccessful_excluded": Json(self.total - self.successful),
    "latency": cohort_percentiles(self.latency),
    "invalid_latency_excluded": Json(self.invalid_latency),
    "streaming_successful": Json(self.streaming_successful),
    "first_event": cohort_percentiles(self.first_event),
    "missing_first_event_excluded": Json(self.missing_first_event),
    "invalid_first_event_excluded": Json(self.invalid_first_event),
    "first_event_invalid_elapsed_excluded": Json(
      self.first_event_invalid_elapsed,
    ),
    "oldest_utc": optional_string_json(self.oldest.map(cohort_utc)),
    "newest_utc": optional_string_json(self.newest.map(cohort_utc)),
    "small_sample": Json(self.latency.length() < 20),
    "first_event_small_sample": Json(self.first_event.length() < 20),
    "successful_response_model_mix": Json(
      models.map(model => {
        "model": Json(model),
        "count": Json(self.response_models[model]),
      }),
    ),
    "missing_successful_response_model": Json(self.missing_response_model),
  }
}

///|
// Synchronous, pure projection of immutable retained rows. No pricing backfill,
// persistence, providers, request bodies, cached row serialization, or rollups.
fn TrafficStats::retained_cohort_snapshot(
  self : TrafficStats,
  app_type : String,
  streaming : String,
  period : String,
  end_seconds : Int32,
  captured_at_ms : Int64,
) -> Result[String, String] {
  if app_type.is_empty() ||
    app_type.length() > 128 ||
    !(streaming == "all" ||
    streaming == "streaming" ||
    streaming == "non-streaming") ||
    end_seconds <= 0 ||
    end_seconds.to_int64() > captured_at_ms / 1000L {
    return Err("invalid_cohort_query")
  }
  let start_seconds = match period {
    "24h" => end_seconds - 86400
    "7d" => end_seconds - 7 * 86400
    "30d" => end_seconds - 30 * 86400
    "all" => 0
    _ => return Err("invalid_cohort_query")
  }
  if start_seconds < 0 {
    return Err("invalid_cohort_query")
  }
  if self.request_logs.length() > COHORT_SNAPSHOT_ROW_LIMIT {
    return Err("cohort_row_limit")
  }
  let groups : Map[String, Map[String, RetainedCohort]] = Map([])
  let mut matching = 0
  let mut imported = 0
  let mut outside = 0
  let mut invalid_timestamp = 0
  let mut unclassified_model = 0
  let mut unclassified_provider = 0
  let mut oldest : Int32? = None
  let mut newest : Int32? = None
  for log in self.request_logs {
    if log.app_type != app_type ||
      (streaming == "streaming" && !log.is_streaming) ||
      (streaming == "non-streaming" && log.is_streaming) {
      continue
    }
    if log.created_at <= 0 {
      invalid_timestamp += 1
      continue
    }
    if log.created_at < start_seconds || log.created_at >= end_seconds {
      outside += 1
      continue
    }
    if log.data_source != "proxy" {
      imported += 1
      continue
    }
    matching += 1
    oldest = Some(oldest.unwrap_or(log.created_at).min(log.created_at))
    newest = Some(newest.unwrap_or(log.created_at).max(log.created_at))
    guard log.request_model is Some(model) && !model.is_empty() else {
      unclassified_model += 1
      continue
    }
    if log.provider_id.is_empty() {
      unclassified_provider += 1
      continue
    }
    let provider = match groups.get(log.provider_id) {
      Some(provider) => provider
      None => {
        let provider = Map([])
        groups[log.provider_id] = provider
        provider
      }
    }
    let cohort = match provider.get(model) {
      Some(cohort) => cohort
      None => {
        let cohort = RetainedCohort::new(log.provider_id, model)
        provider[model] = cohort
        cohort
      }
    }
    cohort.add(log)
  }
  let providers = groups.keys().collect()
  providers.sort()
  let cohorts : Array[Json] = []
  for provider in providers {
    let models = groups[provider].keys().collect()
    models.sort()
    for model in models {
      cohorts.push(groups[provider][model].snapshot())
    }
  }
  let snapshot : Json = {
    "schema": "moongate.retained-cohorts.v1",
    "app_type": Json(app_type),
    "streaming": Json(streaming),
    "period": Json(period),
    "start_seconds": Json(start_seconds),
    "end_seconds": Json(end_seconds),
    "start_utc": if period == "all" {
      Json::null()
    } else {
      Json(cohort_utc(start_seconds))
    },
    "end_utc_exclusive": Json(cohort_utc(end_seconds)),
    "captured_at_ms": Json::number(captured_at_ms.to_double()),
    "captured_at_utc": Json(cohort_utc((captured_at_ms / 1000L).to_int())),
    "retained_rows": Json(self.request_logs.length()),
    "proxy_interval_rows": Json(matching),
    "imported_excluded": Json(imported),
    "outside_interval_excluded": Json(outside),
    "invalid_timestamp_excluded": Json(invalid_timestamp),
    "missing_request_model_unclassified": Json(unclassified_model),
    "missing_provider_id_unclassified": Json(unclassified_provider),
    "oldest_utc": optional_string_json(oldest.map(cohort_utc)),
    "newest_utc": optional_string_json(newest.map(cohort_utc)),
    "row_limit": Json(COHORT_SNAPSHOT_ROW_LIMIT),
    "response_byte_limit": Json(COHORT_SNAPSHOT_BYTE_LIMIT),
    "cohorts": Json(cohorts),
  }
  let encoded = snapshot.stringify()
  if @encoding/utf8.encode(encoded).length() > COHORT_SNAPSHOT_BYTE_LIMIT {
    Err("cohort_response_limit")
  } else {
    Ok(encoded)
  }
}

///|
async fn UsageService::handle_retained_cohort_snapshot(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let captured = moongate_epoch_ms()
  let result = self.stats.retained_cohort_snapshot(
    usage_string_from_request(r.path, None, "appType").unwrap_or(""),
    usage_string_from_request(r.path, None, "streaming").unwrap_or(""),
    usage_string_from_request(r.path, None, "period").unwrap_or(""),
    usage_int_from_request(r.path, None, "end").unwrap_or(0),
    captured,
  )
  w.header().set("Cache-Control", "no-store")
  match result {
    Err(code) => write_usage_bad_request(w, code)
    Ok(body) => {
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(body)
      w.flush()
    }
  }
}
