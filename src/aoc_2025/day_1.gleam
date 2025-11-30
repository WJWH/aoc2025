import atto
import atto/text
import atto/text_util
import gleam/dict
import gleam/int
import gleam/list
import gleam/pair
import gleam/result

// import gleam/result
import utils

fn one_line() {
  use x <- atto.do(text_util.decimal())
  use <- atto.drop(text.match("   "))
  use y <- atto.do(text_util.decimal())
  atto.pure(#(x, y))
}

pub fn parse(input: String) -> List(#(Int, Int)) {
  utils.parse_file_lines(one_line, input)
}

fn fold_func(acc, new: #(Int, Int)) {
  acc + { new.1 - new.0 }
  // acc + int.absolute_value(new.1 - new.0)
}

pub fn pt_1(input: List(#(Int, Int))) {
  let first_list_sorted =
    list.map(input, pair.first) |> list.sort(by: int.compare)
  let second_list_sorted =
    list.map(input, pair.second) |> list.sort(by: int.compare)
  let pairs = list.zip(first_list_sorted, second_list_sorted)
  list.fold(pairs, 0, fold_func)
}

pub fn pt_2(input: List(#(Int, Int))) {
  let second_list_tallied = list.map(input, pair.second) |> utils.tally()
  list.fold(list.map(input, pair.first), 0, fn(acc, new) {
    acc + { new * { dict.get(second_list_tallied, new) |> result.unwrap(0) } }
  })
}
