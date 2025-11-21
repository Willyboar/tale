import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import logging
import simplifile

const poll_interval_ms: Int = 1000

pub type WatchConfig {
  WatchConfig(paths: List(String), on_change: fn() -> Nil)
}

pub fn start(config: WatchConfig) -> process.Pid {
  process.spawn(fn() { run(config.paths, config.on_change) })
}

fn run(paths: List(String), notify: fn() -> Nil) {
  let snapshot = capture(paths)
  loop(paths, snapshot, notify)
}

fn loop(paths: List(String), state: List(String), notify: fn() -> Nil) {
  process.sleep(poll_interval_ms)
  let next = capture(paths)
  case state == next {
    True -> Nil
    False -> {
      logging.log(logging.Info, "Detected changes, rebuilding site…")
      notify()
    }
  }
  loop(paths, next, notify)
}

fn capture(paths: List(String)) -> List(String) {
  gather(paths, [])
  |> list.map(signature)
  |> list.sort(fn(a, b) { string.compare(a, b) })
}

fn gather(paths: List(String), acc: List(String)) -> List(String) {
  case paths {
    [] -> acc
    [path, ..rest] -> {
      let acc = [path, ..acc]
      let contents = case simplifile.is_directory(path) {
        Ok(True) ->
          simplifile.get_files(path)
          |> result.map(fn(files) { files })
          |> result.unwrap([])
        _ -> []
      }
      gather(rest, list.append(contents, acc))
    }
  }
}

fn signature(path: String) -> String {
  case simplifile.file_info(path) {
    Ok(info) -> path <> ":" <> int.to_string(info.mtime_seconds)
    Error(_) -> path <> ":missing"
  }
}
