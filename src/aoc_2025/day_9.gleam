import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import utils

fn one_pair(str) -> #(Int, Int) {
  let assert [x, y] = string.split(str, ",")
  #(utils.parse_or_panic(x), utils.parse_or_panic(y))
}

pub fn parse(input: String) -> List(#(Int, Int)) {
  input |> string.split("\n") |> list.map(one_pair)
}

fn rectangle_size_tuple(points) -> Int {
  let #(#(x1, y1), #(x2, y2)) = points
  { int.absolute_value(x2 - x1) + 1 } * { int.absolute_value(y2 - y1) + 1 }
}

// idea: if you have a current best guess for a rectangle with a top left and bottom right point, then if you
// can find a new point that is both further down AND further right than the current bottom right, you can replace the
// current bottom right point and always get a bigger rectangle?
// filter_dominators_topleft laat een punt niet toe tot de set als er al een punt in zit dat zowel meer top als meer left is?
// omgekeerd moet een punt dat meer top en meer left is dan alle huidige punten die andere punten uit de set schoppen

// helemaal gewoon uitbreiden zolang het groter wordt werkt niet zo te zien?

pub fn pt_1(input: List(#(Int, Int))) {
  input
  |> list.combination_pairs
  |> list.map(rectangle_size_tuple)
  |> list.max(int.compare)
}

fn path_passes_through_rectangle(path, rect) -> Bool {
  // ways a line can intersect a polygon:
  // starts inside, ends outside, start > left && start < right, end maakt eigenlijk niet uit
  // starts outside, ends inside, end > left && end < right
  // starts outside, ends outside, but begin < left en end > right

  let #(#(x1, y1), #(x2, y2)) = rect
  let left = int.min(x1, x2)
  let right = int.max(x1, x2)
  let top = int.min(y1, y2)
  let bottom = int.max(y1, y2)
  let #(p1, p2) = path
  let #(px1, py1) = p1
  let #(px2, py2) = p2
  case px1 == px2 {
    // horizontal line
    False -> {
      assert py1 == py2
      // must be within range of rect
      let vertical_ok = py1 > top && py1 < bottom
      let start_inside = px1 >= left && px1 < right
      let end_inside = px2 >= left && px2 <= right
      let crosses =
        { px1 <= left && px2 >= right } || { px2 <= left && px1 >= right }
      vertical_ok && { start_inside || end_inside || crosses }
    }
    // vertical line
    True -> {
      assert px1 == px2
      // must be within range of rect
      let horizontal_ok = px1 > left && px1 < right
      let start_inside = py1 >= top && py1 <= bottom
      let end_inside = py2 >= top && py2 <= bottom
      let crosses =
        { py1 <= top && py2 >= bottom } || { py2 <= top && py1 >= bottom }
      horizontal_ok && { start_inside || end_inside || crosses }
    }
  }
}

fn any_path_passes_through_rectangle(paths, rect) {
  list.any(paths, fn(path) { path_passes_through_rectangle(path, rect) })
}

pub fn pt_2(input: List(#(Int, Int))) {
  let cycled_list =
    list.append(list.drop(input, 1), [
      list.first(input) |> result.lazy_unwrap(fn() { panic }),
    ])
  let all_paths_in_polygon = list.zip(input, cycled_list)

  input
  |> list.combination_pairs
  |> list.filter(fn(rect) {
    bool.negate(any_path_passes_through_rectangle(all_paths_in_polygon, rect))
  })
  |> list.map(rectangle_size_tuple)
  |> list.max(int.compare)
}
