///|
fn moongate_rabbita_nav_icon(page : String) -> @html.Html {
  @html.img(
    class="nav-icon",
    src="/assets/nav/\{page}.svg",
    alt="",
    width=20,
    height=20,
    attrs=@html.Attrs::build().aria_hidden("true"),
  )
}
