import atto
import atto/ops
import atto/text
import atto/text_util
import gleam/dict
import gleam/list
import gleam/option
import gleam/result
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

fn increment(x) {
  case x {
    option.Some(i) -> i + 1
    option.None -> 1
  }
}

pub fn tally(input: List(Int)) -> dict.Dict(Int, Int) {
  list.fold(input, dict.new(), fn(acc, new) { dict.upsert(acc, new, increment) })
}

// input file parsing
pub fn file_lines(line_parser) {
  let lines = ops.sep(line_parser(), by: text_util.newline())
  let _ = atto.eof()
  lines
}

pub fn parse_file_lines(line_parser, input_string) {
  atto.run(file_lines(line_parser), text.new(input_string), Nil)
  |> result.lazy_unwrap(fn() { panic as "parsing failed" })
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
