import gleam/int
import gleam/list
import gleam/result
import gleam/string
import utils

fn compute_answer(nums: List(String), op: String) -> Int {
  let #(operator, identity_element) = case op {
    "+" -> #(int.add, 0)
    "*" -> #(int.multiply, 1)
    _ -> panic as "unknown operation"
  }

  nums
  |> list.map(utils.parse_or_panic)
  |> list.fold(identity_element, operator)
}

pub fn pt_1(input: String) {
  let inputs = string.split(input, "\n") |> list.reverse
  let numbers =
    list.drop(inputs, 1)
    |> list.map(string.split(_, " "))
    |> list.map(list.filter(_, fn(str) { str != "" }))
    |> list.transpose()
  let ops =
    list.first(inputs)
    |> result.unwrap("")
    |> string.split(" ")
    |> list.filter(fn(str) { str != "" })

  list.map2(numbers, ops, compute_answer) |> int.sum
}

fn split_on_spaces(input: List(List(String)), acc, current) {
  case input {
    [] -> [current, ..acc]
    [new, ..rest] -> {
      let new_is_all_spaces = list.all(new, fn(s) { s == " " })
      case new_is_all_spaces {
        False -> split_on_spaces(rest, acc, [new, ..current])
        True -> split_on_spaces(rest, [current, ..acc], [])
      }
    }
  }
}

fn convert_numbers(strs: List(List(String))) {
  strs
  |> list.map(fn(n) {
    list.reverse(n)
    |> string.concat
    |> string.trim
  })
}

pub fn pt_2(input: String) {
  let inputs = string.split(input, "\n") |> list.reverse
  let numbers =
    list.drop(inputs, 1)
    |> list.map(string.to_graphemes)
    |> list.transpose()
    |> split_on_spaces([], [])
    |> list.map(convert_numbers)
  let ops =
    list.first(inputs)
    |> result.unwrap("")
    |> string.split(" ")
    |> list.filter(fn(str) { str != "" })
    |> list.reverse

  list.map2(numbers, ops, compute_answer) |> int.sum
}
