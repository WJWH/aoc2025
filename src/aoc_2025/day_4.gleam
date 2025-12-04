import gleam/bool
import gleam/dict
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import utils

pub fn parse(input: String) -> dict.Dict(#(Int, Int), String) {
  let strings = string.split(input, "\n")
  let first_string = list.first(strings) |> result.unwrap("")
  let width = string.length(first_string)
  let height = list.length(strings)

  utils.load_2d_grid_from_file(input, width, height)
  |> dict.filter(fn(_, str) { str == "@" })
}

fn has_less_than_4_neighboring_rolls(map, point) -> Bool {
  let neighbor_count =
    utils.neighbors_diagonal(point)
    |> list.count(fn(neighbor) { dict.has_key(map, neighbor) })
  neighbor_count < 4
}

pub fn pt_1(input: dict.Dict(#(Int, Int), String)) {
  let roll_coords =
    input
    |> dict.to_list
    |> list.map(pair.first)
  roll_coords
  |> list.count(fn(roll_coord) {
    has_less_than_4_neighboring_rolls(input, roll_coord)
  })
}

fn recursive_remove_rolls(map) {
  let new_map =
    map
    |> dict.filter(fn(roll_coord, _) {
      bool.negate(has_less_than_4_neighboring_rolls(map, roll_coord))
    })
  case dict.size(map) == dict.size(new_map) {
    True -> new_map
    False -> recursive_remove_rolls(new_map)
  }
}

pub fn pt_2(input: dict.Dict(#(Int, Int), String)) {
  let filtered_map = recursive_remove_rolls(input)
  dict.size(input) - dict.size(filtered_map)
}
