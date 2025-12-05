import gleam/int
import gleam/list
import gleam/order
import gleam/string
import utils

pub type SegmentTree {
  Leaf(begin: Int, end: Int)
  Node(begin: Int, end: Int, left: SegmentTree, right: SegmentTree)
}

// input parsing

fn single_range(range) {
  let assert [Ok(begin), Ok(end)] =
    list.map(string.split(range, "-"), int.parse)
  Leaf(begin, end)
}

fn parse_ranges(inputs, acc) {
  case inputs {
    [r, ..rest] -> parse_ranges(rest, [single_range(r), ..acc])
    [] -> acc
  }
}

pub fn parse(input: String) -> #(List(SegmentTree), List(Int)) {
  let assert [result_strings, ingredient_strings] = string.split(input, "\n\n")
  let ranges = parse_ranges(string.split(result_strings, "\n"), [])
  let ingredients =
    list.map(string.split(ingredient_strings, "\n"), utils.parse_or_panic)
  #(ranges, ingredients)
}

// segment tree related stuff

fn midpoint(tree) {
  case tree {
    Leaf(begin, end) -> begin + end / 2
    Node(begin, end, _l, _r) -> begin + end / 2
  }
}

fn sort_by_midpoint(input: List(SegmentTree)) -> List(SegmentTree) {
  list.sort(input, fn(a, b) { int.compare(midpoint(a), midpoint(b)) })
}

fn combine_segment_trees(trees) {
  case trees {
    [left, right] ->
      case left, right {
        // just combine into a Node. Leaves are already sorted by beginning so we should not 
        // have to check which one goes left or right
        Leaf(bl, el), Leaf(br, er) ->
          Node(int.min(bl, br), int.max(el, er), left, right)
        Leaf(_bl, _el), Node(_begin, _end, _left, _right) ->
          panic as "should never happen"
        Node(bl, el, _l, _r), Leaf(br, er) ->
          Node(int.min(bl, br), int.max(el, er), left, right)
        Node(bl, el, _ll, _rl), Node(br, er, _lr, _rr) ->
          Node(int.min(bl, br), int.max(el, er), left, right)
      }
    [tree] -> tree
    // we run this exclusively on chunks of one or two, as those come out of the sized_chunk function
    [] -> panic as "should never happen"
    [_, _, _, ..] -> panic as "should never happen"
  }
}

fn recursively_combine_segment_trees(inputs: List(SegmentTree)) -> SegmentTree {
  case inputs {
    [tree] -> tree
    trees -> {
      list.sized_chunk(trees, 2)
      |> list.map(combine_segment_trees)
      |> recursively_combine_segment_trees
    }
  }
}

fn is_point_in_tree(tree, point) -> Bool {
  case tree {
    Leaf(begin, end) -> point >= begin && point <= end
    Node(begin, end, left, right) ->
      case point >= begin, point <= end {
        // point is in range of the supernode, but perhaps not for the child nodes. Recurse and check
        True, True ->
          is_point_in_tree(left, point) || is_point_in_tree(right, point)
        // point is either smaller than the start point or bigger than the end point (or both???)
        // in any case it's not in the interval for this Node
        _, _ -> False
      }
  }
}

pub fn pt_1(input: #(List(SegmentTree), List(Int))) {
  let #(ranges, ingredients) = input
  let tree = recursively_combine_segment_trees(sort_by_midpoint(ranges))
  ingredients |> list.count(is_point_in_tree(tree, _))
}

pub type Endpoint {
  Begin(value: Int)
  End(value: Int)
}

fn range_endpoints(ranges, acc) {
  case ranges {
    [Leaf(begin, end), ..rest] ->
      range_endpoints(rest, [Begin(begin), End(end), ..acc])
    [] -> acc
    [Node(_, _, _, _), ..] -> panic
  }
}

fn find_covered_range(
  endpoints: List(Endpoint),
  start_of_current_range: Int,
  acc: Int,
  depth: Int,
) -> Int {
  case endpoints {
    [Begin(v), ..rest] ->
      case depth > 0 {
        // we were already in a range, increase current depth but nothing else
        True -> find_covered_range(rest, start_of_current_range, acc, depth + 1)
        // start of a new range, set start of current and set depth to 1
        False -> find_covered_range(rest, v, acc, 1)
      }
    [End(v), ..rest] ->
      case depth > 1 {
        // we're in more than 1 range. Decrease depth, but do nothing else
        True -> find_covered_range(rest, start_of_current_range, acc, depth - 1)
        // this ends an active range. Update acc and depth
        False -> {
          assert depth == 1
          find_covered_range(
            rest,
            0,
            acc + { { v - start_of_current_range } + 1 },
            0,
          )
        }
      }
    [] -> {
      assert depth == 0
      acc
    }
  }
}

pub fn pt_2(input: #(List(SegmentTree), List(Int))) {
  let #(ranges, _ingredients) = input
  let endpoints =
    list.sort(range_endpoints(ranges, []), fn(a, b) {
      let cmp = int.compare(a.value, b.value)
      case cmp {
        order.Gt -> order.Gt
        order.Lt -> order.Lt
        order.Eq ->
          case a, b {
            // make sure the beginnings are always before the ends, otherwise you can count a point double
            Begin(_), End(_) -> order.Lt
            End(_), Begin(_) -> order.Gt
            _, _ -> order.Eq
          }
      }
    })
  find_covered_range(endpoints, 0, 0, 0)
}
