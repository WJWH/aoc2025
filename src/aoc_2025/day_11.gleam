import atomic_array
import gleam/bit_array
import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type Graph =
  dict.Dict(Int, List(Int))

fn str_id(label: String) -> Int {
  let assert <<id:size(24)>> = bit_array.from_string(label)
  id
}

fn single_line(str) {
  let assert [from, ..to] = string.split(str, " ")
  #(str_id(string.drop_end(from, 1)), list.map(to, str_id))
}

pub fn parse(input: String) -> #(Graph, atomic_array.AtomicArray) {
  let nodes = string.split(input, "\n") |> list.map(single_line)
  let graph =
    list.fold(nodes, dict.new(), fn(acc, new) {
      let #(from, to) = new
      dict.insert(acc, from, to)
    })
  let cache = atomic_array.new_unsigned(16_777_215)
  #(graph, cache)
}

// part 1
// unmemoized version, commented out so I don't get an unused function warning every time
// fn num_paths_to_out(graph, node) {
//   case node {
//     "out" -> 1
//     _ -> {
//       let paths_from_here = dict.get(graph, node) |> result.unwrap([])
//       list.map(paths_from_here, num_paths_to_out(graph, _))
//       |> int.sum()
//     }
//   }
// }

// cool attempt, threading the dict cache between calls with list.fold()
// fn num_paths_to_out_cached(cache, graph, node) -> #(Int, dict.Dict(Int, Int)) {
//   case dict.get(cache, node) {
//     Ok(n) -> #(n, cache)
//     Error(Nil) -> {
//       let paths_from_here = dict.get(graph, node) |> result.unwrap([])
//       let #(sum, cache) =
//         list.fold(paths_from_here, #(0, cache), fn(acc, next_node) {
//           let #(n, cache_acc) = acc
//           let #(extra_paths, new_cache) =
//             num_paths_to_out_cached(cache_acc, graph, next_node)
//           #(n + extra_paths, new_cache)
//         })
//       #(sum, dict.insert(cache, node, sum))
//     }
//   }
// }

fn num_paths_to_out_cached_atomic(cache, graph, node: Int) -> Int {
  case atomic_array.get(cache, node) {
    Ok(0) -> {
      case node {
        // str_id("out") == 7304564
        7_304_564 -> 1
        _ -> {
          let paths_from_here = dict.get(graph, node) |> result.unwrap([])
          let answer =
            list.map(paths_from_here, fn(next_node) {
              num_paths_to_out_cached_atomic(cache, graph, next_node)
            })
            |> int.sum
          let _ = atomic_array.set(cache, node, answer)
          answer
        }
      }
    }
    Ok(n) -> n
    Error(_) -> panic as "out of bounds"
  }
}

// with pair.first: about 1 ms. With `.0` to access the first part of the tuple:
// about 150 µs
pub fn pt_1(input: #(Graph, atomic_array.AtomicArray)) {
  let #(graph, start_cache) = input
  // let start_cache = dict.new() |> dict.insert(str_id("out"), 1)
  // num_paths_to_out_cached(start_cache, input, str_id("you")).0
  num_paths_to_out_cached_atomic(start_cache, graph, str_id("you"))
}

// str_id("out") == 7304564
// str_id("dac") == 6578531
// str_id("fft") == 6710900

fn num_paths_to_out_via_dac_fft(
  cache,
  graph: Graph,
  node: Int,
  has_visited_dac,
  has_visited_fft,
) -> #(Int, dict.Dict(#(Int, Bool, Bool), Int)) {
  case dict.get(cache, #(node, has_visited_dac, has_visited_fft)) {
    Ok(n) -> #(n, cache)
    Error(Nil) -> {
      // str_id("dac") == 6578531
      // str_id("fft") == 6710900
      let new_has_visited_dac = has_visited_dac || node == 6_578_531
      let new_has_visited_fft = has_visited_fft || node == 6_710_900
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
            )
          #(n + extra_paths, new_cache)
        })
      #(sum, dict.insert(cache, #(node, has_visited_dac, has_visited_fft), sum))
    }
  }
}

// after benchmarking, part 2 did not benefit from being rewritten to the atomic array variant
pub fn pt_2(input: #(Graph, atomic_array.AtomicArray)) {
  let #(graph, _) = input
  let start_cache = dict.new() |> dict.insert(#(str_id("out"), True, True), 1)
  num_paths_to_out_via_dac_fft(start_cache, graph, str_id("svr"), False, False).0
}
