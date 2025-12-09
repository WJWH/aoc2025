import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/pair
import gleam/result
import gleam/string
import utils

pub type Vec3 {
  Vec3(Int, Int, Int)
}

fn single_vec3(str) -> Vec3 {
  let values = string.split(str, ",")
  case values {
    [x, y, z] ->
      Vec3(
        utils.parse_or_panic(x),
        utils.parse_or_panic(y),
        utils.parse_or_panic(z),
      )
    _ -> panic as "invalid vec3 parse"
  }
}

// no need to compute real distances, we only care about the order
fn distance(a: Vec3, b: Vec3) -> Int {
  case a, b {
    Vec3(ax, ay, az), Vec3(bx, by, bz) -> {
      let dx = ax - bx
      let dy = ay - by
      let dz = az - bz
      dx * dx + dy * dy + dz * dz
    }
  }
}

pub fn parse(input: String) -> List(Vec3) {
  string.split(input, "\n")
  |> list.map(single_vec3)
}

fn sorted_edges(nodes) {
  list.combination_pairs(nodes)
  |> list.map(fn(x) {
    let #(a, b) = x
    #(a, b, distance(a, b))
  })
  |> list.sort(fn(a, b) {
    let #(_, _, d1) = a
    let #(_, _, d2) = b
    int.compare(d1, d2)
  })
  |> list.map(fn(x) {
    let #(a, b, _d) = x
    #(a, b)
  })
}

// graph stuff

// node to its neighbors
type Graph =
  dict.Dict(Vec3, List(Vec3))

fn construct_graph(edges: List(#(Vec3, Vec3))) {
  list.fold(edges, dict.new(), fn(acc, new) {
    let #(from, to) = new
    let acc =
      dict.upsert(acc, from, fn(existing_edges) {
        case existing_edges {
          None -> [to]
          Some(edges) -> [to, ..edges]
        }
      })
    dict.upsert(acc, to, fn(existing_edges) {
      case existing_edges {
        None -> [from]
        Some(edges) -> [from, ..edges]
      }
    })
  })
}

fn neighbors(graph, node) {
  dict.get(graph, node) |> result.unwrap([])
}

fn recursive_add_component(
  graph: Graph,
  nodes_to_visit: List(Vec3),
  component_id,
  components,
) -> dict.Dict(Vec3, Int) {
  case nodes_to_visit {
    [] -> components
    [node, ..rest] -> {
      let node_already_has_component = dict.has_key(components, node)
      case node_already_has_component {
        True -> recursive_add_component(graph, rest, component_id, components)
        False -> {
          let new_components = dict.insert(components, node, component_id)
          let extra_nodes_to_visit = neighbors(graph, node)
          recursive_add_component(
            graph,
            list.append(extra_nodes_to_visit, rest),
            component_id,
            new_components,
          )
        }
      }
    }
  }
}

fn components(graph: Graph) -> dict.Dict(Vec3, Int) {
  let nodes = dict.keys(graph)
  let empty_components = dict.new()
  list.index_fold(nodes, empty_components, fn(acc, new, index) {
    recursive_add_component(graph, [new], index, acc)
  })
}

fn sorted_circuit_sizes(graph_components: dict.Dict(Vec3, Int)) {
  dict.to_list(graph_components)
  |> list.group(pair.second)
  |> dict.values
  |> list.map(list.length)
  |> list.sort(fn(a, b) { order.negate(int.compare(a, b)) })
}

pub fn pt_1(input: List(Vec3)) {
  let edges =
    sorted_edges(input)
    |> list.take(1000)
  let graph = construct_graph(edges)
  let graph_components = components(graph)

  sorted_circuit_sizes(graph_components)
  |> list.take(3)
  |> list.fold(1, int.multiply)
}

fn add_edges_until_all_nodes_reached(
  edges,
  node_to_component,
  component_to_node,
) {
  case edges {
    [] -> panic as "couldn't make graph fully connected"
    [edge, ..rest] -> {
      let #(from, to) = edge
      let assert Ok(from_component_id) = dict.get(node_to_component, from)
      let assert Ok(to_component_id) = dict.get(node_to_component, to)
      case from_component_id == to_component_id {
        False -> {
          let assert Ok(nodes_in_from_component) =
            dict.get(component_to_node, from_component_id)
          let assert Ok(nodes_in_to_component) =
            dict.get(component_to_node, to_component_id)
          let all_nodes_in_new_component =
            list.append(nodes_in_from_component, nodes_in_to_component)
          // consolidate all these nodes into from component
          let new_component_to_node =
            dict.insert(
              component_to_node,
              from_component_id,
              all_nodes_in_new_component,
            )
          let new_component_to_node =
            dict.delete(new_component_to_node, to_component_id)
          // all the nodes in the "to" component need to know they're now in the from component
          let new_node_to_component =
            list.fold(nodes_in_to_component, node_to_component, fn(acc, new) {
              dict.insert(acc, new, from_component_id)
            })
          // now finally, check if the new components dict has only 1 element
          let num_components = dict.size(new_component_to_node)
          case num_components {
            // this was the edge that reduced it to one component
            1 -> edge
            _ ->
              add_edges_until_all_nodes_reached(
                rest,
                new_node_to_component,
                new_component_to_node,
              )
          }
        }
        // nothing relevant is done by adding this edge, just move on
        True ->
          add_edges_until_all_nodes_reached(
            rest,
            node_to_component,
            component_to_node,
          )
      }
    }
  }
}

fn extract_answer_from_edge(edge) {
  let #(from, to) = edge
  let Vec3(x1, _, _) = from
  let Vec3(x2, _, _) = to
  x1 * x2
}

pub fn pt_2(input: List(Vec3)) {
  let edges = sorted_edges(input)
  // no edges exist yet, so every node is its own island
  let initial_components = list.index_fold(input, dict.new(), dict.insert)
  let reverse_components =
    list.index_fold(input, dict.new(), fn(acc, new, index) {
      dict.insert(acc, index, [new])
    })

  let final_edge =
    add_edges_until_all_nodes_reached(
      edges,
      initial_components,
      reverse_components,
    )
  extract_answer_from_edge(final_edge)
}
