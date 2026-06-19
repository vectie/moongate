///|
// Keep private white-box test helpers visible to the unused-value checker.
fn init {
  ignore(fn(
    stats : TrafficStats,
    session_id : String,
    message_id : String,
    data : String,
  ) {
    stats.ingest_opencode_message_json(session_id~, message_id~, data~)
  })
  ignore(TrafficStats::record_upstream_error)
  ignore(TrafficStats::record_success)
  ignore(TrafficStats::record_success_usage)
  ignore(fn(stats : TrafficStats) { stats.usage_logs_json() })
  ignore(fn(stats : TrafficStats) { stats.usage_summary_json() })
  ignore(TrafficStats::usage_summary_by_app_json)
  ignore(fn(stats : TrafficStats) { stats.provider_stats_json() })
  ignore(fn(stats : TrafficStats) { stats.model_stats_json() })
  ignore(TrafficStats::request_detail_json)
  ignore(SubscriptionQuota::error)
  ignore(fn(cache : UsageCache, app_type : String) {
    cache.with_subscription(app_type, fn(quota) { quota.success })
  })
  ignore(fn(cache : UsageCache, app_type : String, provider_id : String) {
    cache.with_script(app_type, provider_id, fn(result) { result.success })
  })
  ignore(UsageCache::invalidate_script)
  ignore(UsageCache::invalidate_subscription)
}
