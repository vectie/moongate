///|
fn moonstat_rabbita_shell_view(
  api_base? : String = "http://127.0.0.1:15721",
) -> @html.Html {
  @html.div(
    class="shell",
    attrs=@html.Attrs::build().data_set("moonstat-api-base", api_base),
    [
      @html.aside(class="sidebar", [
        @html.div(class="brand", [
          @html.span(class="mark", "M"),
          @html.div([
            @html.strong("Moonstat"),
            @html.span("Lepusa Rabbita shell"),
          ]),
        ]),
        @html.nav(class="nav", [
          @html.a(href="#overview", "Overview"),
          @html.a(href="#providers", "Providers"),
          @html.a(href="#frameworks", "Frameworks"),
          @html.a(href="#suite", "Suite"),
          @html.a(href="#usage", "Usage"),
        ]),
      ]),
      @html.main_(class="main", [
        @html.section(id="overview", class="topbar", [
          @html.div([
            @html.p(class="eyebrow", "Operator Console"),
            @html.h1("Proxy, providers, and spend in one place."),
          ]),
          @html.div(class="actions", [
            @html.button(id="refresh", type_="button", "Refresh"),
            @html.button(id="proxy-start", type_="button", "Start Proxy"),
            @html.button(
              id="proxy-stop",
              class="danger",
              type_="button",
              "Stop Proxy",
            ),
          ]),
        ]),
        @html.section(class="status-grid", [
          moonstat_rabbita_metric_card(
            "Gateway", "gateway-state", "gateway-detail",
          ),
          moonstat_rabbita_metric_card("Proxy", "proxy-state", "proxy-detail"),
          moonstat_rabbita_metric_card(
            "Requests", "request-total", "request-total-detail",
          ),
          moonstat_rabbita_metric_card("Spend", "cost-total", "cost-detail"),
        ]),
        @html.section(class="panel-grid", [
          moonstat_rabbita_panel(
            "frameworks", "Frameworks", "Provider Control", "framework-rows",
          ),
          moonstat_rabbita_panel(
            "providers", "Routing", "Provider Health", "provider-rows",
          ),
          moonstat_rabbita_panel(
            "suite", "Suite", "Moon Suite Integration", "suite-app-rows",
          ),
          moonstat_rabbita_panel(
            "usage", "Usage", "Usage Explorer", "app-usage",
          ),
        ]),
      ]),
    ],
  )
}

///|
fn moonstat_rabbita_metric_card(
  label : String,
  value_id : String,
  detail_id : String,
) -> @html.Html {
  @html.article(class="metric-card", [
    @html.span(label),
    @html.strong(id=value_id, "-"),
    @html.small(id=detail_id, "Waiting for data"),
  ])
}

///|
fn moonstat_rabbita_panel(
  id : String,
  eyebrow : String,
  title : String,
  target_id : String,
) -> @html.Html {
  @html.article(id~, class="panel wide", [
    @html.div(class="panel-head", [
      @html.div([@html.p(class="eyebrow", eyebrow), @html.h2(title)]),
    ]),
    @html.div(id=target_id, class="stack", [
      @html.div(class="row-card", [
        @html.strong("No data yet"),
        @html.small("Moonstat will populate this panel from the local gateway."),
      ]),
    ]),
  ])
}

///|
#warnings("-alert_unstable")
pub fn moonstat_rabbita_shell_html(
  api_base? : String = "http://127.0.0.1:15721",
) -> String {
  @rabbita.render_to_string(
    @rabbita.static_cell(moonstat_rabbita_shell_view(api_base~)),
  )
}

///|
pub fn moonstat_rabbita_lepusa_manifest_json(
  api_base? : String = "http://127.0.0.1:15721",
) -> Json {
  Json::object({
    "identifier": Json::string("dev.vectie.moonstat.rabbita"),
    "productName": Json::string("Moonstat Rabbita Preview"),
    "version": Json::string("0.1.0"),
    "rootHtml": Json::string(moonstat_rabbita_shell_html(api_base~)),
    "runtime": Json::object({
      "backend": Json::string("system-webview"),
      "assetProtocol": Json::string("lepusa"),
      "devtools": Json::boolean(false),
    }),
    "window": Json::object({
      "label": Json::string("main"),
      "title": Json::string("Moonstat"),
      "width": Json::number(1180.0),
      "height": Json::number(780.0),
      "resizable": Json::boolean(true),
    }),
    "plugins": Json::array([
      Json::object({ "name": Json::string("localhost") }),
      Json::object({ "name": Json::string("serviceDiscovery") }),
      Json::object({ "name": Json::string("opener") }),
    ]),
    "capabilities": Json::array([
      Json::object({
        "name": Json::string("main"),
        "windows": Json::array([Json::string("main")]),
        "permissions": Json::array([
          Json::string("localhost"),
          Json::string("service-discovery"),
          Json::string("opener"),
        ]),
      }),
    ]),
    "startup": Json::object({
      "effect": Json::string("connect-moonstat-rabbita-preview"),
    }),
  })
}

///|
pub fn moonstat_rabbita_lepusa_manifest(
  api_base? : String = "http://127.0.0.1:15721",
) -> String {
  moonstat_rabbita_lepusa_manifest_json(api_base~).stringify(indent=2)
}
