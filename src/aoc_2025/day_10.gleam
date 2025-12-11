import atto
import atto/ops
import atto/text_util
import child_process
import gleam/dict
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import gleam/string_tree.{type StringTree}
import iv
import parallel_map
import simplifile
import utils

pub type LampState =
  dict.Dict(Int, Bool)

pub type JoltageState =
  dict.Dict(Int, Int)

pub type Button =
  List(Int)

pub type Problem {
  Problem(target: LampState, buttons: List(Button), joltage_reqs: List(Int))
}

fn single_toggle() {
  use <- atto.drop(atto.token("("))
  use nums <- atto.do(ops.sep(text_util.decimal(), atto.token(",")))
  use <- atto.drop(atto.token(")"))
  use <- atto.drop(text_util.spaces())
  atto.pure(nums)
}

fn single_problem() {
  use <- atto.drop(atto.token("["))
  use tgt <- atto.do(ops.many(ops.choice([atto.token("."), atto.token("#")])))
  use <- atto.drop(atto.token("]"))

  use <- atto.drop(text_util.spaces())
  use toggles <- atto.do(ops.many(single_toggle()))

  use <- atto.drop(atto.token("{"))
  use joltages <- atto.do(ops.sep(text_util.decimal(), atto.token(",")))
  use <- atto.drop(atto.token("}"))

  let tgt_dict =
    list.index_fold(tgt, dict.new(), fn(acc, new, index) {
      case new {
        "." -> dict.insert(acc, index, False)
        "#" -> dict.insert(acc, index, True)
        _ -> panic
      }
    })
  atto.pure(Problem(tgt_dict, toggles, joltages))
}

pub fn parse(input: String) -> List(Problem) {
  utils.parse_file_lines(single_problem, input)
}

// idea: you need to press each button either zero, or one times. It's never useful to press a button twice because then you can just not press it at all
pub type PartiallySolvedProblem1 {
  PSP1(
    target: LampState,
    current_state: LampState,
    buttons_pressed: Int,
    buttons_available: dict.Dict(List(Int), Int),
  )
}

pub type PartiallySolvedProblem2 {
  PSP2(
    target: JoltageState,
    current_state: JoltageState,
    buttons_pressed: Int,
    buttons_available: List(Button),
  )
}

fn apply_button1(psp, button: Button) -> PartiallySolvedProblem1 {
  let PSP1(target, current_state, buttons_pressed, buttons_available) = psp
  let button_presses_left = dict.get(buttons_available, button)
  let new_buttons_available = case button_presses_left {
    Ok(2) -> dict.insert(buttons_available, button, 1)
    Ok(1) -> dict.delete(buttons_available, button)
    _ -> panic as "button_presses_left was not 1 or 2"
  }
  let filtered_buttons_available =
    dict.filter(new_buttons_available, fn(k, _v) {
      compare_buttons(k, button) == order.Lt
    })
  let new_buttons_pressed = buttons_pressed + 1
  // toggle or increase all the indices
  let new_current_state =
    list.fold(button, current_state, fn(acc, lamp_index) {
      dict.upsert(acc, lamp_index, utils.toggle)
    })
  // construct new partial
  PSP1(
    target,
    new_current_state,
    new_buttons_pressed,
    filtered_buttons_available,
  )
}

fn compare_buttons(a: Button, b: Button) {
  case a, b {
    [], [] -> order.Eq
    [], _ -> order.Lt
    _, [] -> order.Gt
    [x, ..xs], [y, ..ys] -> {
      let xy = int.compare(x, y)
      case xy {
        order.Gt -> order.Gt
        order.Lt -> order.Lt
        order.Eq -> compare_buttons(xs, ys)
      }
    }
  }
}

// BFS should find the shortest first, no need to find all solutions anymore
fn solve_problem1(psps: iv.Array(PartiallySolvedProblem1)) -> Int {
  case iv.is_empty(psps) {
    True -> panic as "no solutions found"
    // still more possibilities to investigate
    False -> {
      let assert Ok(psp) = iv.first(psps)
      let assert Ok(rest) = iv.rest(psps)
      let PSP1(target, current_state, buttons_pressed, buttons_available) = psp
      case target == current_state {
        // we've reached the target, so we can stop this partial as adding buttons would never result in a shorter solution
        True -> buttons_pressed
        // not at target yet
        False -> {
          let buttons_available_list =
            buttons_available |> dict.filter(fn(_k, v) { v > 0 }) |> dict.keys
          case buttons_available_list {
            // out of buttons to press but not at the target, so this is not a solution
            [] -> solve_problem1(rest)
            // try to press all the buttons
            available_buttons -> {
              let new_partials =
                list.map(available_buttons, fn(button) {
                  apply_button1(psp, button)
                })
              solve_problem1(iv.append_list(rest, new_partials))
            }
          }
        }
      }
    }
  }
}

fn make_partial1(problem: Problem) -> PartiallySolvedProblem1 {
  let Problem(tgt_dict, toggles, _joltages) = problem
  let sorted_toggles = list.sort(toggles, compare_buttons)
  let available_buttons =
    list.fold(sorted_toggles, dict.new(), fn(acc, new) {
      dict.insert(acc, new, 1)
    })
  // set all values to false for initial state
  let start_state = dict.map_values(tgt_dict, fn(_, _) { False })
  PSP1(tgt_dict, start_state, 0, available_buttons)
}

// finding all solutions dfs was 3 seconds, with bfs it was 36 seconds to find all solutions
// with BFS just finding the shortest was 7 ms
// but now on the real problem some of them time out (because the search space is too large?)
// oh! some subproblems overlap because the search space is mirrored: [b1,b2] == [b2,b1]
// so we must dedupe this somehow. Idea: generate only solutions with sorted buttons, so once
// you press a button you are never again allowed to press any "smaller" buttons
pub fn pt_1(input: List(Problem)) {
  input
  |> list.map(make_partial1)
  |> parallel_map.list_pmap(
    fn(partial) { solve_problem1(iv.wrap(partial)) },
    parallel_map.WorkerAmount(24),
    1000,
  )
  |> list.map(result.unwrap(_, 0))
  |> int.sum
}

// ... it's a matrix/ILP solving problem? That took me WAY too long to see
// solution is based around getting parsing the input into a structure that the z3 solver can understand
// and then shelling out to that

fn make_z3_input(problem: Problem) -> StringTree {
  let Problem(_tgt_dict, toggles, joltages) = problem
  // declare button vars and that they're positive ints:
  // (declare-const b1 Int)
  // (assert (>= b1 0))
  let tree =
    list.index_fold(toggles, string_tree.new(), fn(acc, _new, index) {
      let button_name = int.to_string(index)
      let button_decl = "(declare-const b" <> button_name <> " Int)\n"
      let button_positive = "(assert (>= b" <> button_name <> " 0))\n"
      let acc = string_tree.append(acc, button_decl)
      string_tree.append(acc, button_positive)
    })
  // declare target vars and their value:
  // (declare-const t1 Int)
  // (assert (= t1 3))
  let tree =
    list.index_fold(joltages, tree, fn(acc, new, index) {
      let target_name = int.to_string(index)
      let button_decl = "(declare-const t" <> target_name <> " Int)\n"
      let button_positive =
        "(assert (= t" <> target_name <> " " <> int.to_string(new) <> "))\n"
      let acc = string_tree.append(acc, button_decl)
      string_tree.append(acc, button_positive)
    })
  // now the sums. 
  let tree_to_buttons =
    list.index_fold(toggles, dict.new(), fn(acc, button, button_idx) {
      list.fold(button, acc, fn(inner_acc, target) {
        dict.upsert(inner_acc, target, utils.list_add(_, button_idx))
      })
    })
  // convert dict to list of strings and add to tree
  let tree =
    dict.fold(tree_to_buttons, tree, fn(acc, k, v) {
      // (assert (= t1 (+ b5 b6)))
      let toggles = list.map(v, fn(bat) { "b" <> int.to_string(bat) <> " " })
      let sum_string =
        "(assert (= t"
        <> int.to_string(k)
        <> " (+ "
        <> string.concat(toggles)
        <> ")))\n"
      string_tree.append(acc, sum_string)
    })

  let tree = string_tree.append(tree, "(declare-const total Int)\n")
  // declare that total is the sum of all toggles
  // (assert (= total (+ b1 b2 b3 b4 b5 b6)))
  let targets =
    string.concat(
      list.index_map(toggles, fn(_tgt, idx) { "b" <> int.to_string(idx) <> " " }),
    )
  let total_sum = "(assert (= total (+ " <> targets <> ")))\n"
  let tree = string_tree.append(tree, total_sum)
  // computation part
  let tree = string_tree.append(tree, "(minimize total)\n")
  let tree = string_tree.append(tree, "(check-sat)\n")
  let tree = string_tree.append(tree, "(get-objectives)\n")
  tree
}

fn extract_output(str, acc) {
  case str {
    "" -> acc
    "1" <> rest -> extract_output(rest, acc * 10 + 1)
    "2" <> rest -> extract_output(rest, acc * 10 + 2)
    "3" <> rest -> extract_output(rest, acc * 10 + 3)
    "4" <> rest -> extract_output(rest, acc * 10 + 4)
    "5" <> rest -> extract_output(rest, acc * 10 + 5)
    "6" <> rest -> extract_output(rest, acc * 10 + 6)
    "7" <> rest -> extract_output(rest, acc * 10 + 7)
    "8" <> rest -> extract_output(rest, acc * 10 + 8)
    "9" <> rest -> extract_output(rest, acc * 10 + 9)
    "0" <> rest -> extract_output(rest, acc * 10 + 0)
    _ -> acc
  }
}

fn ask_z3(st: string_tree.StringTree) {
  let complete_input = string_tree.to_string(st)
  let random_name = int.random(10_000_000) |> int.to_string
  let temp_file_name = "/tmp/" <> random_name <> ".smt"
  let _ = simplifile.write(temp_file_name, complete_input)
  let assert Ok(output) =
    child_process.new("/home/linuxbrew/.linuxbrew/bin/z3")
    |> child_process.arg(temp_file_name)
    |> child_process.run()
  let child_process.Output(_status_code, output) = output
  case output {
    "sat\n(objectives\n (total " <> rest -> extract_output(rest, 0)
    _ -> panic as "unsat"
  }
}

pub fn pt_2(input: List(Problem)) {
  input
  |> list.map(make_z3_input)
  |> parallel_map.list_pmap(
    fn(partial) { ask_z3(partial) },
    parallel_map.WorkerAmount(24),
    1000,
  )
  |> list.map(result.unwrap(_, -999_999))
  |> int.sum
}
