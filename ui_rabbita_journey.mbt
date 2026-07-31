///|
fn moongate_rabbita_goal_step(
  id : String,
  icon : String,
  label : String,
) -> @html.Html {
  @html.li(id="goal-step-\{id}", class="goal-step waiting", [
    @html.img(
      class="goal-step-icon",
      src="/assets/nav/\{icon}.svg",
      alt="",
      width=18,
      height=18,
      attrs=@html.Attrs::build().aria_hidden("true"),
    ),
    @html.span(label),
    @html.small(id="goal-step-\{id}-status", "Waiting"),
  ])
}

///|
fn moongate_rabbita_goal_compass() -> @html.Html {
  @html.section(
    id="goal-compass",
    class="goal-compass",
    attrs=@html.Attrs::build().aria_label("Connect an app journey"),
    [
      @html.div(class="goal-copy", [
        @html.p(class="eyebrow", "Current goal"),
        @html.h2("Connect one app to a healthy provider"),
        @html.p(
          id="goal-next-detail",
          attrs=@html.Attrs::build().aria_live("polite"),
          "MoonGate is checking the local gateway before choosing the next safe action.",
        ),
      ]),
      @html.ol(class="goal-steps", [
        moongate_rabbita_goal_step("provider", "providers", "Provider"),
        moongate_rabbita_goal_step("routing", "connections", "Routing"),
        moongate_rabbita_goal_step("app", "bindings", "App"),
        moongate_rabbita_goal_step("observe", "usage", "Observe"),
      ]),
      @html.div(class="goal-action", [
        @html.button(
          id="primary-next-action",
          type_="button",
          attrs=@html.Attrs::build().aria_describedby("goal-next-detail"),
          [
            @html.span(id="primary-next-action-label", "Check readiness"),
            @html.img(
              class="goal-action-icon",
              src="/assets/nav/connect.svg",
              alt="",
              width=18,
              height=18,
              attrs=@html.Attrs::build().aria_hidden("true"),
            ),
          ],
        ),
        @html.p(
          id="goal-recovery",
          class="goal-recovery",
          hidden=true,
          attrs=@html.Attrs::build().aria_live("assertive"),
          "",
        ),
      ]),
    ],
  )
}
