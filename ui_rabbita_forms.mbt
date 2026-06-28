///|
fn moonstat_rabbita_status_value(label : String, id : String) -> @html.Html {
  @html.div([@html.span(label), @html.strong(id~, "-")])
}

///|
fn moonstat_rabbita_input_label(
  label : String,
  id : String,
  placeholder : String,
  required : Bool,
  class? : String,
  inputmode? : String,
) -> @html.Html {
  @html.label(class?, [
    @html.span(label),
    match inputmode {
      Some(mode) => @html.input(id~, placeholder~, required~, inputmode=mode)
      None => @html.input(id~, placeholder~, required~)
    },
  ])
}

///|
fn moonstat_rabbita_password_label(label : String, id : String) -> @html.Html {
  @html.label([@html.span(label), @html.input(input_type=Password, id~)])
}

///|
fn moonstat_rabbita_select_label(
  label : String,
  id : String,
  options : Array[(String, String)],
) -> @html.Html {
  @html.label([
    @html.span(label),
    @html.select(
      id~,
      options.map(fn(option) {
        let (value, text) = option
        @html.option(value~, text)
      }),
    ),
  ])
}

///|
fn moonstat_rabbita_check_label(
  id : String,
  label : String,
  checked : Bool,
) -> @html.Html {
  @html.label([
    @html.input(input_type=Checkbox, id~, checked~),
    @html.text(" \{label}"),
  ])
}
