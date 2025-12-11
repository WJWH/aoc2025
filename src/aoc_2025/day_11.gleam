import gleam/dict
import gleam/erlang/atom.{type Atom}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type Graph =
  dict.Dict(Atom, List(Atom))

fn single_line(str) {
  let assert [from, ..to] = string.split(str, " ")
  #(atom.create(string.drop_end(from, 1)), list.map(to, atom.create))
}

pub fn parse(input: String) -> Graph {
  let nodes = string.split(input, "\n") |> list.map(single_line)
  list.fold(nodes, dict.new(), fn(acc, new) {
    let #(from, to) = new
    dict.insert(acc, from, to)
  })
}

// part 1
// unmemoized version
fn num_paths_to_out(graph, node) {
  case node {
    "out" -> 1
    _ -> {
      let paths_from_here = dict.get(graph, node) |> result.unwrap([])
      list.map(paths_from_here, num_paths_to_out(graph, _))
      |> int.sum()
    }
  }
}

fn num_paths_to_out_cached(cache, graph, node) -> #(Int, dict.Dict(Atom, Int)) {
  case dict.get(cache, node) {
    Ok(n) -> #(n, cache)
    Error(Nil) -> {
      let paths_from_here = dict.get(graph, node) |> result.unwrap([])
      let #(sum, cache) =
        list.fold(paths_from_here, #(0, cache), fn(acc, next_node) {
          let #(n, cache_acc) = acc
          let #(extra_paths, new_cache) =
            num_paths_to_out_cached(cache_acc, graph, next_node)
          #(n + extra_paths, new_cache)
        })
      #(sum, dict.insert(cache, node, sum))
    }
  }
}

// with pair.first: about 1 ms. With `.0` to access the first part of the tuple:
// about 150 µs
pub fn pt_1(input: Graph) {
  let start_cache = dict.new() |> dict.insert(atom.create("out"), 1)
  num_paths_to_out_cached(start_cache, input, atom.create("you")).0
}

fn num_paths_to_out_via_dac_fft(
  cache,
  graph: Graph,
  node: Atom,
  has_visited_dac,
  has_visited_fft,
  dac_atom,
  fft_atom,
) -> #(Int, dict.Dict(#(Atom, Bool, Bool), Int)) {
  case dict.get(cache, #(node, has_visited_dac, has_visited_fft)) {
    Ok(n) -> #(n, cache)
    Error(Nil) -> {
      let new_has_visited_dac = has_visited_dac || node == dac_atom
      let new_has_visited_fft = has_visited_fft || node == fft_atom
      let paths_from_here = case dict.get(graph, node) {
        Ok(v) -> v
        Error(Nil) -> []
      }
      let #(sum, cache) =
        list.fold(paths_from_here, #(0, cache), fn(acc, next_node) {
          let #(n, cache_acc) = acc
          let #(extra_paths, new_cache) =
            num_paths_to_out_via_dac_fft(
              cache_acc,
              graph,
              next_node,
              new_has_visited_dac,
              new_has_visited_fft,
              dac_atom,
              fft_atom,
            )
          #(n + extra_paths, new_cache)
        })
      #(sum, dict.insert(cache, #(node, has_visited_dac, has_visited_fft), sum))
    }
  }
}

pub fn pt_2(input: Graph) {
  let start_cache =
    dict.new() |> dict.insert(#(atom.create("out"), True, True), 1)
  num_paths_to_out_via_dac_fft(
    start_cache,
    input,
    atom.create("svr"),
    False,
    False,
    atom.create("dac"),
    atom.create("fft"),
  ).0
}
// this works but the ETS table for the rememo cache takes like 10 ms to spin up??
// pub fn pt_2(input: Graph) {
//   use cache <- memo.create()
//   num_paths_to_out_memoized(cache, input, "svr", False, False)
// }
