import gleam/erlang/atom
import gleam/int
import gleam/list
import gleam/pair
import gleam/result
import gleam/set
import gleam/string
import glearray

fn find_start_location(str: String) -> set.Set(Int) {
  list.index_fold(string.to_graphemes(str), set.new(), fn(acc, new, index) {
    case new {
      "." -> acc
      _ -> set.insert(acc, index)
    }
  })
}

fn find_splitter_locations(str: String) -> glearray.Array(String) {
  str |> string.to_graphemes |> glearray.from_list
}

fn drop_all_even_lines(lines: List(a), even: Bool, acc: List(a)) -> List(a) {
  case lines {
    [] -> list.reverse(acc)
    [n, ..rest] ->
      case even {
        False -> drop_all_even_lines(rest, True, [n, ..acc])
        True -> drop_all_even_lines(rest, False, acc)
      }
  }
}

fn split_existing_beams(splits_and_beams, splitters) -> #(Int, set.Set(Int)) {
  let #(_num_splits, existing_beams) = splits_and_beams
  set.fold(existing_beams, #(0, set.new()), fn(accs, beam) {
    let #(s, acc) = accs
    let beam_hits_splitter =
      glearray.get_or_default(splitters, beam, ".") != "."
    case beam_hits_splitter {
      // beam continues as is
      False -> #(s, set.insert(acc, beam))
      // split!
      True -> {
        #(s + 1, set.insert(acc, beam - 1) |> set.insert(beam + 1))
      }
    }
  })
}

pub fn pt_1(input) {
  let #(start_location, splitters) = input

  list.scan(splitters, #(0, start_location), split_existing_beams)
  |> list.map(pair.first)
  |> int.sum
}

fn count_timelines(
  remaining_layers: List(glearray.Array(String)),
  remaining_layer_count: Int,
  location: Int,
  cache_handle,
) -> Int {
  let cache_key = #(remaining_layer_count, location)
  use <- memoize(cache_handle, cache_key)
  case remaining_layers {
    [] -> 1
    [current_layer, ..rest] -> {
      let split_this_layer =
        glearray.get_or_default(current_layer, location, ".") == "^"
      case split_this_layer {
        False ->
          count_timelines(
            rest,
            remaining_layer_count - 1,
            location,
            cache_handle,
          )
        True ->
          count_timelines(
            rest,
            remaining_layer_count - 1,
            location - 1,
            cache_handle,
          )
          + count_timelines(
            rest,
            remaining_layer_count - 1,
            location + 1,
            cache_handle,
          )
      }
    }
  }
}

fn memoize(cache, key, computation) {
  let is_cached = lookup(cache, key)
  case is_cached {
    Ok(value) -> value
    Error(_) -> {
      let answer = computation()
      insert(cache, [#(key, answer)])
      answer
    }
  }
}

@external(erlang, "ets", "insert")
pub fn insert(table: atom.Atom, tuple: List(#(k, v))) -> Nil

@external(erlang, "ets", "lookup")
pub fn ets_lookup(table: atom.Atom, key: k) -> List(#(k, v))

fn lookup(tablename, key) -> Result(b, Nil) {
  let results = ets_lookup(tablename, key)
  case results {
    [] -> Error(Nil)
    [#(_key, value), ..] -> Ok(value)
  }
}

@external(erlang, "ets_binding", "new_table")
pub fn new_table(name: atom.Atom) -> Result(atom.Atom, Nil)

pub fn parse(input: String) {
  let inputs = string.split(input, "\n") |> drop_all_even_lines(False, [])
  let start_location =
    inputs
    |> list.first
    |> result.unwrap("")
    |> find_start_location

  let splitters = list.drop(inputs, 1) |> list.map(find_splitter_locations)
  #(start_location, splitters)
}

pub fn pt_2(input) {
  let #(start_location_set, splitters) = input
  let start_location =
    start_location_set
    |> set.to_list
    |> list.first
    |> result.unwrap(-1)

  // create ets table for the memoization
  let tablename = atom.create("cache_table")
  let my_table = new_table(tablename) |> result.lazy_unwrap(fn() { panic })

  count_timelines(splitters, list.length(splitters), start_location, my_table)
}
