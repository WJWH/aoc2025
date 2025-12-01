import atto
import atto/ops
import atto/text
import atto/text_util
import gleam/dict
import gleam/int
import gleam/list
import gleam/order
import gleam/pair
import gleam/result

// import gleam/result
import utils

pub type Instruction {
  Left(amount: Int)
  Right(amount: Int)
}

fn one_line() {
  use direction <- atto.do(ops.choice([atto.token("L"), atto.token("R")]))
  use how_far <- atto.do(text_util.decimal())

  atto.pure(case direction {
    "L" -> Left(how_far)
    "R" -> Right(how_far)
    _ -> todo
  })
}

pub fn parse(input: String) -> List(Instruction) {
  utils.parse_file_lines(one_line, input)
}

fn scan_func(acc: Int, new: Instruction) -> Int {
  let new_value = case new {
    Left(amount) -> {
      acc - amount
    }
    Right(amount) -> {
      acc + amount
    }
  }
  case { int.modulo(new_value, 100) } {
    Ok(num) -> num
    Error(_) -> todo
  }
}

pub fn pt_1(input: List(Instruction)) {
  let values_reached = list.scan(input, 50, scan_func)
  values_reached |> list.filter(fn(n) { n == 0 }) |> list.length
}

fn div_rem_100(x, y) {
  todo
}

fn count_zero_crossings(
  value: Int,
  crossings_so_far: Int,
  instuctions: List(Instruction),
) {
  case instuctions {
    [] -> crossings_so_far
    [instruction, ..rest] ->
      case instruction {
        Left(amount) -> {
          let new_value =
            int.modulo(value - amount, 100)
            |> result.lazy_unwrap(fn() { todo })
          let full_rotations = amount / 100
          let remaining_rotation = amount % 100
          let crossed_zero = case value {
            // we're at zero, so moving left from here by less than 100 will never cause a zero crossing
            0 -> 0
            n ->
              case remaining_rotation >= n {
                True -> 1
                False -> 0
              }
          }
          echo #(new_value, crossings_so_far + full_rotations + crossed_zero)
          count_zero_crossings(
            new_value,
            crossings_so_far + full_rotations + crossed_zero,
            rest,
          )
        }
        Right(amount:) -> {
          let new_value =
            int.modulo(value + amount, 100)
            |> result.lazy_unwrap(fn() { todo })
          let full_rotations = amount / 100
          let remaining_rotation = amount % 100
          let final_position = remaining_rotation + value
          let crossed_zero = case final_position >= 100 {
            True -> 1
            False -> 0
          }
          echo #(new_value, crossings_so_far + full_rotations + crossed_zero)
          count_zero_crossings(
            new_value,
            crossings_so_far + full_rotations + crossed_zero,
            rest,
          )
        }
      }
  }
}

// 6386 is too low

pub fn pt_2(input: List(Instruction)) {
  count_zero_crossings(50, 0, input)
}
