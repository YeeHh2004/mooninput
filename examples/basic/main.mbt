///|
fn main {
  let phone = @input.Editor::new(@input.pattern("### #### ####").unwrap())
    .unwrap()
    .insert("13800138000")
    .unwrap()
  println(phone.display())
  println(phone.value().unwrap())
  let amount = @input.Editor::new(
    @input.decimal().unwrap(),
    initial="9007199254740993.10",
  ).unwrap()
  println(amount.display())
  println(amount.value().unwrap())
  let date = @input.Editor::new(@input.iso_date(), initial="20230229").unwrap()
  match date.value() {
    Ok(value) => println(value)
    Err(error) => println(error.message())
  }
  println(date.select(3, 4).unwrap().insert("4").unwrap().value().unwrap())
}
