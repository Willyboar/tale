/// Paths module
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

/// Ensure parent dirs function.
pub fn ensure_parent_dirs(path: String) -> Result(Nil, String) {
  case parent_directory(path) {
    None -> Ok(Nil)
    Some(dir) ->
      simplifile.create_directory_all(dir)
      |> result.map_error(fn(err) {
        "Unable to create directory "
        <> dir
        <> ": "
        <> simplifile.describe_error(err)
      })
  }
}

/// Parent directory function.
pub fn parent_directory(path: String) -> Option(String) {
  let segments = string.split(path, "/")
  case list.length(segments) {
    len if len <= 1 -> None
    len -> {
      let keep = len - 1
      let dir =
        segments
        |> list.take(keep)
        |> string.join("/")
      case dir {
        "" -> None
        other -> Some(other)
      }
    }
  }
}
