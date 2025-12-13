import gleam/int
import gleam/list
import gleam/string
import utils

pub type Problem {
  Problem(x: Int, y: Int, blocks_needed: List(Int))
}

fn tile_size(str) {
  str |> string.to_graphemes |> list.count(fn(x) { x == "#" })
}

fn problem(str) {
  let assert [size_part, count_part] = string.split(str, ": ")
  let assert [x_part, y_part] =
    string.split(size_part, "x") |> list.map(utils.parse_or_panic)
  let counts = string.split(count_part, " ") |> list.map(utils.parse_or_panic)
  Problem(x_part, y_part, counts)
}

pub fn parse(input: String) -> #(List(Int), List(Problem)) {
  let tiles_and_problems = string.split(input, "\n\n")
  let tiles = list.take(tiles_and_problems, 6)
  let assert [problem_strings] = list.drop(tiles_and_problems, 6)
  let tile_sizes = list.map(tiles, tile_size)
  let problems = list.map(string.split(problem_strings, "\n"), problem)
  #(tile_sizes, problems)
}

pub fn counting_problem_solver(tile_sizes, problems, acc) {
  case problems {
    [] -> acc
    [Problem(x, y, tiles_needed), ..rest] -> {
      let total_tiles_available = x * y
      let total_tiles_needed =
        list.map2(tile_sizes, tiles_needed, int.multiply) |> int.sum
      let total_tiles_needed_worstcase =
        tile_sizes |> int.sum |> int.multiply(9)
      case Nil {
        // even with hypothetical perfect tiling this would not be possible
        Nil if total_tiles_needed > total_tiles_available ->
          counting_problem_solver(tile_sizes, rest, acc)
        // obviously possible, there's a 3x3 square available for each of the needed tiles
        // so we don't need to do any tiling at all
        Nil if total_tiles_needed_worstcase <= total_tiles_available ->
          counting_problem_solver(tile_sizes, rest, acc + 1)
        // we might be able to do this if we tile some presents more optimally
        Nil -> panic as "undecided problem encountered"
      }
    }
  }
}

pub fn pt_1(input: #(List(Int), List(Problem))) {
  let #(tile_sizes, problems) = input
  counting_problem_solver(tile_sizes, problems, 0)
}

pub fn pt_2(input: #(List(Int), List(Problem))) {
  let #(tile_sizes, problems) = input
  counting_problem_solver(tile_sizes, problems, 0)
}
// VM warmup is real lol:
// Part 1: 587 (in 1.660 ms)
// Part 2: 587 (in 146 µs)
