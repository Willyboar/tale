import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import handles/error
import tom

/// get string or
pub fn get_string_or(
  doc: Dict(String, tom.Toml),
  key: List(String),
  fallback: String,
) -> String {
  case tom.get_string(doc, key) {
    Ok(value) -> value
    Error(_) -> fallback
  }
}

/// get bool or
pub fn get_bool_or(
  doc: Dict(String, tom.Toml),
  key: List(String),
  fallback: Bool,
) -> Bool {
  case tom.get_bool(doc, key) {
    Ok(value) -> value
    Error(_) -> fallback
  }
}

/// Get string list
pub fn get_string_list_or(
  doc: Dict(String, tom.Toml),
  key: List(String),
  fallback: List(String),
) -> List(String) {
  case tom.get_array(doc, key) {
    Ok(values) ->
      case toml_array_to_strings(values, []) {
        option.Some(strings) -> strings
        option.None -> fallback
      }
    Error(_) -> fallback
  }
}

/// Optional string
pub fn optional_string(
  result: Result(String, tom.GetError),
) -> option.Option(String) {
  case result {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

pub fn optional_int(result: Result(Int, tom.GetError)) -> option.Option(Int) {
  case result {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

/// Toml array to strings
fn toml_array_to_strings(
  values: List(tom.Toml),
  acc: List(String),
) -> option.Option(List(String)) {
  case values {
    [] -> option.Some(list.reverse(acc))
    [tom.String(value), ..rest] -> toml_array_to_strings(rest, [value, ..acc])
    [_other, ..] -> option.None
  }
}

/// TOML Errors description
pub fn describe_toml_error(err: tom.ParseError) -> String {
  case err {
    tom.Unexpected(got, expected) ->
      "Unexpected \"" <> got <> "\", expected " <> expected
    tom.KeyAlreadyInUse(key) ->
      "Duplicate key \"" <> string.join(key, ".") <> "\""
  }
}

pub fn describe_tokenizer_error(err: error.TokenizerError) -> String {
  case err {
    error.UnbalancedTag(index) ->
      "Unbalanced tag near character " <> int.to_string(index)
    error.UnbalancedBlock(index) ->
      "Unbalanced block near character " <> int.to_string(index)
    error.MissingArgument(index) ->
      "Missing argument near character " <> int.to_string(index)
    error.MissingBlockKind(index) ->
      "Missing block kind near character " <> int.to_string(index)
    error.MissingPartialId(index) ->
      "Missing partial id near character " <> int.to_string(index)
    error.UnexpectedMultipleArguments(index) ->
      "Too many arguments near character " <> int.to_string(index)
    error.UnexpectedArgument(index) ->
      "Unexpected argument near character " <> int.to_string(index)
    error.UnexpectedBlockKind(index) ->
      "Unexpected block kind near character " <> int.to_string(index)
    error.UnexpectedBlockEnd(index) ->
      "Unexpected block end near character " <> int.to_string(index)
  }
}

pub fn describe_runtime_error(err: error.RuntimeError) -> String {
  case err {
    error.UnexpectedType(index, path, got, expected) ->
      "Unexpected value at "
      <> describe_path(path)
      <> " (near character "
      <> int.to_string(index)
      <> "): got "
      <> got
      <> ", expected one of "
      <> string.join(expected, ", ")
    error.UnknownProperty(index, path) ->
      "Unknown property "
      <> describe_path(path)
      <> " near character "
      <> int.to_string(index)
    error.UnknownPartial(_index, id) -> "Unknown partial \"" <> id <> "\""
  }
}

fn describe_path(path: List(String)) -> String {
  case path {
    [] -> "(root)"
    props -> string.join(props, ".")
  }
}

pub fn slugify(value: String) -> String {
  value
  |> string.lowercase
  |> replace_for_slug
  |> string.replace("--", "-")
}

fn replace_for_slug(value: String) -> String {
  value
  |> string.to_graphemes
  |> list.fold([], fn(acc, char) {
    case is_allowed_slug_char(char) {
      True -> [char, ..acc]
      False -> ["-", ..acc]
    }
  })
  |> list.reverse
  |> string.concat
}

fn is_allowed_slug_char(char: String) -> Bool {
  case char {
    "-" -> True
    other -> is_alphanumeric(other)
  }
}

fn is_alphanumeric(char: String) -> Bool {
  case string.to_utf_codepoints(char) {
    [codepoint, ..] -> {
      let value = string.utf_codepoint_to_int(codepoint)
      let is_digit = value >= 48 && value <= 57
      let is_lower = value >= 97 && value <= 122
      let is_upper = value >= 65 && value <= 90
      is_digit || is_lower || is_upper
    }
    _ -> False
  }
}
