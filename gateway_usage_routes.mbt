///|
fn UsageService::register_routes(
  self : UsageService,
  router : @httpx.Router,
  auth : AuthService,
  provider_router : ProviderRouter,
) -> Unit {
  router.add_handler(Get, "/usage/logs", (r, w) => {
    self.handle_usage_logs(r, w, self.pricing_override_rows())
  })
  router.add_handler(Post, "/usage/logs", (r, w) => {
    self.handle_usage_logs(r, w, self.pricing_override_rows())
  })
  router.add_handler(Get, "/usage/summary", (r, w) => {
    self.handle_usage_summary(r, w)
  })
  router.add_handler(Post, "/usage/summary", (r, w) => {
    self.handle_usage_summary(r, w)
  })
  router.add_handler(Get, "/usage/summary/by-app", (r, w) => {
    self.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(Post, "/usage/summary/by-app", (r, w) => {
    self.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(Get, "/usage/trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(Post, "/usage/trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(Get, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w, provider_router)
  })
  router.add_handler(Post, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w, provider_router)
  })
  router.add_handler(Get, "/usage/provider-stats", (r, w) => {
    self.handle_usage_provider_stats(r, w)
  })
  router.add_handler(Post, "/usage/provider-stats", (r, w) => {
    self.handle_usage_provider_stats(r, w)
  })
  router.add_handler(Get, "/usage/model-stats", (r, w) => {
    self.handle_usage_model_stats(r, w)
  })
  router.add_handler(Post, "/usage/model-stats", (r, w) => {
    self.handle_usage_model_stats(r, w)
  })
  router.add_handler(Get, "/usage/data-sources", (_, w) => {
    self.handle_usage_data_sources(w)
  })
  router.add_handler(Post, "/usage/data-sources", (_, w) => {
    self.handle_usage_data_sources(w)
  })
  router.add_handler(Get, "/usage/provider-usage", (r, w) => {
    self.handle_query_provider_usage(r, w, provider_router)
  })
  router.add_handler(Post, "/usage/provider-usage", (r, w) => {
    self.handle_query_provider_usage(r, w, provider_router)
  })
  router.add_handler(Get, "/usage/balance", (r, w) => {
    self.handle_get_balance(r, w)
  })
  router.add_handler(Post, "/usage/balance", (r, w) => {
    self.handle_get_balance(r, w)
  })
  router.add_handler(Get, "/usage/subscription-quota", (r, w) => {
    self.handle_get_subscription_quota(r, w)
  })
  router.add_handler(Post, "/usage/subscription-quota", (r, w) => {
    self.handle_get_subscription_quota(r, w)
  })
  router.add_handler(Get, "/usage/codex-oauth-quota", (r, w) => {
    auth.handle_get_codex_oauth_quota(r, w, self)
  })
  router.add_handler(Post, "/usage/codex-oauth-quota", (r, w) => {
    auth.handle_get_codex_oauth_quota(r, w, self)
  })
  router.add_handler(Get, "/usage/codex-oauth-models", (r, w) => {
    auth.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(Post, "/usage/codex-oauth-models", (r, w) => {
    auth.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(Get, "/usage/coding-plan-quota", (r, w) => {
    self.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(Post, "/usage/coding-plan-quota", (r, w) => {
    self.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(Post, "/usage/test-script", (r, w) => {
    self.handle_test_usage_script(r, w)
  })
  router.add_handler(Post, "/usage/sync-session", (r, w) => {
    self.handle_usage_sync_session(r, w)
  })
  router.add_handler(Get, "/usage/model-pricing", (_, w) => {
    self.handle_usage_model_pricing(w)
  })
  router.add_handler(Post, "/usage/model-pricing", (r, w) => {
    self.handle_usage_update_model_pricing(r, w)
  })
  router.add_handler(Delete, "/usage/model-pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(Get, "/usage/request-detail/*path", (r, w) => {
    self.handle_usage_request_detail(r, w, self.pricing_override_rows())
  })
}
