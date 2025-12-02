import atto
import atto/ops
import atto/text
import atto/text_util
import gleam/int
import gleam/list
import gleam/string

pub type Range {
  Range(start: Int, end: Int)
}

fn one_range() {
  use begin <- atto.do(text_util.decimal())
  use _ <- atto.do(atto.token("-"))
  use stop <- atto.do(text_util.decimal())

  atto.pure(Range(begin, stop))
}

pub fn parse(input: String) -> List(Range) {
  let assert Ok(ranges) =
    ops.sep(one_range(), atto.token(",")) |> atto.run(text.new(input), Nil)
  ranges
}

fn is_invalid_id(id: Int) -> Bool {
  let id_string = int.to_string(id)
  let id_length = string.length(id_string)
  case int.is_odd(id_length) {
    True -> False
    False -> {
      let half_id_length = id_length / 2
      let first_half = string.slice(id_string, 0, half_id_length)
      let second_half = string.slice(id_string, half_id_length, half_id_length)
      first_half == second_half
    }
  }
}

fn invalid_ids_in_range(range, filter_func) {
  case range {
    Range(begin, end) -> {
      list.range(begin, end) |> list.filter(filter_func)
    }
  }
}

pub fn pt_1(input: List(Range)) {
  list.flat_map(input, invalid_ids_in_range(_, is_invalid_id)) |> int.sum()
}

fn is_invalid_id_part2(id: Int) -> Bool {
  // interesting edge case not present in the test data: my real data has a range including
  // single-digit numbers. These obviously do not have any repeating patterns, but id_length / 2
  // would not have generated the proper range. So it checks manually for id_length > 1
  let id_string = int.to_string(id)
  let id_length = string.length(id_string)
  let possible_substring_sizes =
    list.range(id_length / 2, 1)
    |> list.filter(fn(n) { id_length % n == 0 && id_length > 1 })
  list.any(possible_substring_sizes, fn(substring_size) {
    let substr = string.slice(id_string, 0, substring_size)
    id_string == string.repeat(substr, id_length / substring_size)
  })
}

pub fn pt_2(input: List(Range)) {
  list.flat_map(input, invalid_ids_in_range(_, is_invalid_id_part2))
  |> int.sum()
}
