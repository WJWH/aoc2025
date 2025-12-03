import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import parallel_map.{WorkerAmount}

fn assert_parse(str: String) -> Int {
  let parsed = int.parse(str)
  case parsed {
    Error(_) -> panic as "parse error"
    Ok(num) -> num
  }
}

fn parse_line(str: String) -> List(Int) {
  string.to_graphemes(str) |> list.map(assert_parse)
}

pub fn parse(input: String) -> List(List(Int)) {
  input |> string.split("\n") |> list.map(parse_line)
}

fn max_with_index(input: List(Int)) -> #(Int, Int) {
  list.index_fold(input, #(-1, -1), fn(acc, new_value, new_index) {
    let #(old_max, _old_index) = acc
    case new_value > old_max {
      True -> #(new_value, new_index)
      False -> acc
    }
  })
}

fn biggest_joltage(batteries: List(Int)) -> Int {
  let input_size = list.length(batteries)
  let init = list.take(batteries, input_size - 1)
  let #(biggest, index_biggest) = max_with_index(init)
  let second_biggest =
    list.max(list.drop(batteries, index_biggest + 1), int.compare)
  case second_biggest {
    Error(_) -> panic as "no digits in second list"
    Ok(num) -> biggest * 10 + num
  }
}

pub fn pt_1(input: List(List(Int))) {
  input
  |> parallel_map.list_pmap(biggest_joltage, WorkerAmount(15), 15)
  |> result.values
  |> int.sum
}

fn biggest_joltage_n(batteries: List(Int), num_left: Int, acc: Int) -> Int {
  use <- bool.guard(num_left == 0, acc)
  let input_size = list.length(batteries)
  let init = list.take(batteries, input_size - num_left + 1)
  let #(biggest, index_biggest) = max_with_index(init)
  let batteries_remainder = list.drop(batteries, index_biggest + 1)
  biggest_joltage_n(batteries_remainder, num_left - 1, acc * 10 + biggest)
}

pub fn pt_2(input: List(List(Int))) {
  input
  |> parallel_map.list_pmap(biggest_joltage_n(_, 12, 0), WorkerAmount(15), 15)
  |> result.values
  |> int.sum
}
// Results from adding parallel_map to do all the input lines in parallel:
// Without parallel_map:
//   Part 1: _ (in 2.135 ms)
//   Part 2: _ (in 2.217 ms)
// After adding parallel_map:
//   Part 1: _ (in 2.272 ms)
//   Part 2: _ (in 1.211 ms)
