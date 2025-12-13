import atto
import atto/ops
import atto/text
import atto/text_util
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/string

// utilities
pub fn all_coords(width, heigth) {
  use h <- list.flat_map(list.range(0, heigth - 1))
  use w <- list.map(list.range(0, width - 1))
  #(w, h)
}

pub fn load_2d_grid_from_file(
  filecontents,
  width,
  height,
) -> dict.Dict(#(Int, Int), String) {
  let coords = all_coords(width, height)
  string.split(filecontents, "\n")
  |> string.concat
  |> string.to_graphemes
  |> list.zip(coords, _)
  |> dict.from_list
}

pub fn neighbors(point) {
  case point {
    #(w, h) -> [#(w + 1, h), #(w - 1, h), #(w, h + 1), #(w, h - 1)]
  }
}

pub fn neighbors_diagonal(point) {
  case point {
    #(w, h) -> [
      #(w - 1, h),
      #(w + 1, h),
      #(w, h - 1),
      #(w, h + 1),
      #(w + 1, h - 1),
      #(w + 1, h + 1),
      #(w - 1, h - 1),
      #(w - 1, h + 1),
    ]
  }
}

pub type Direction {
  North
  West
  South
  East
}

pub fn increment(x) {
  case x {
    option.Some(i) -> i + 1
    option.None -> 1
  }
}

pub fn increment_by(x, n) {
  case x {
    option.Some(i) -> i + n
    option.None -> n
  }
}

pub fn list_add(x, new_element) {
  case x {
    option.Some(existing_list) -> [new_element, ..existing_list]
    option.None -> [new_element]
  }
}

pub fn decrement(x) {
  case x {
    option.Some(i) -> i + 1
    // kind of weird default value here
    option.None -> 0
  }
}

pub fn toggle(x) {
  case x {
    option.Some(i) -> bool.negate(i)
    option.None -> panic as "tried to toggle wrong index"
  }
}

pub fn tally(input: List(a)) -> dict.Dict(a, Int) {
  list.fold(input, dict.new(), fn(acc, new) { dict.upsert(acc, new, increment) })
}

pub fn parse_or_panic(input: String) -> Int {
  let assert Ok(n) = int.parse(input)
  n
}

// shoelace algorithm:
fn shoelace_determinant(points) {
  let #(#(x1, y1), #(x2, y2)) = points
  { x1 * y2 } - { x2 * y1 }
}

// https://en.wikipedia.org/wiki/Shoelace_formula
pub fn shoelace(points: List(#(Int, Int))) {
  // fn shoelace(points: List(#(Int, Int))) -> Result(Int, Nil) {
  list.zip(points, list.drop(points, 1))
  |> list.map(shoelace_determinant)
  |> int.sum
  |> int.divide(2)
}

// input file parsing
pub fn file_lines(line_parser) {
  let lines = ops.sep(line_parser(), by: text_util.newline())
  let _ = atto.eof()
  lines
}

pub fn parse_file_lines(line_parser, input_string) {
  let result = atto.run(file_lines(line_parser), text.new(input_string), Nil)
  case result {
    Ok(res) -> res
    Error(err) -> {
      echo err
      panic as "parsing failed"
    }
  }
}

pub fn parse_file(some_parser, input_string) {
  let result = atto.run(some_parser, text.new(input_string), Nil)
  case result {
    Ok(res) -> res
    Error(err) -> {
      echo err
      panic as "parsing failed"
    }
  }
}
