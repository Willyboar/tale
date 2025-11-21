/// Generators of Tale static blog generator
/// Generate:
/// - a new site that contains a default theme.
/// - a new theme for user customization
/// - a new post based on the archetypes with a timestamp
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import simplifile
import tale/paths
import tale/util

const templates_root = "templates"

const site_template_root = templates_root <> "/site"

const default_theme_name = "default"

const theme_template_root = templates_root <> "/theme/" <> default_theme_name

/// Creates a new site rooted at the provided path. The generated site copies
/// Tale's default content and theme, and updates the config title.
/// New site contains:
/// - archetypes: Contains the default markdown file
/// - assets: Empty but user can add files here if they dont want to use or create a theme
/// - content: Contains index.md, pages markdown files and posts directory who contains posts. Can be modified in config.toml
/// - layouts: Empty but again user can add templates here.
/// - static: Empty, user can add static files here.
/// - `config.toml` file
pub fn new_site_gen(raw_name: String) -> Result(String, String) {
  let name = string.trim(raw_name)

  case name {
    "" -> Error("Please provide a site name, e.g. `tale new site my-blog`.")
    _ -> create_site(name)
  }
}

fn create_site(name: String) -> Result(String, String) {
  use exists <- result.try(path_exists(name))
  case exists {
    True -> Error("Cannot create site, path already exists: " <> name)
    False -> scaffold_site(name)
  }
}

/// Creates a new theme `<name>` based on Tale's default theme.
/// Theme directory contains:
/// - assets: Contains css, js and images
/// - layouts: Contains layout templates
/// - static: Contains all static files that will be copied in the site/blog like robots.txt, favicon etc.
pub fn new_theme_gen(raw_name: String) -> Result(String, String) {
  let name = string.trim(raw_name)

  case name {
    "" -> Error("Please provide a theme name, e.g. `tale new theme docs`.")
    _ -> create_theme(name)
  }
}

fn create_theme(name: String) -> Result(String, String) {
  use exists <- result.try(path_exists(name))
  case exists {
    True -> Error("Path already exists: " <> name)
    False -> scaffold_theme(name, name)
  }
}

fn scaffold_site(name: String) -> Result(String, String) {
  use _ <- result.try(copy_directory(site_template_root, name))
  use _ <- result.try(copy_directory(
    theme_template_root,
    name <> "/themes/" <> default_theme_name,
  ))
  use _ <- result.try(update_config_title(name <> "/config.toml", name))

  Ok("Site " <> name <> " created with the Tale default theme.")
}

fn scaffold_theme(path: String, name: String) -> Result(String, String) {
  use _ <- result.try(copy_directory(theme_template_root, path))
  use _ <- result.try(update_theme_name(path <> "/theme.toml", name))

  Ok("Theme " <> name <> " created at " <> path <> ".")
}

/// Creates a new post under `content/posts/` using the archetype template and current timestamp.
pub fn new_post_gen(raw_input: String) -> Result(String, String) {
  let input = string.trim(raw_input)
  case input {
    "" -> Error("Please provide a post name, e.g. `tale new post my-article`.")
    _ -> create_post(input)
  }
}

/// Create post
fn create_post(name: String) -> Result(String, String) {
  let #(dest, title_source) = post_destination_info(name)

  use exists <- result.try(path_exists(dest))
  case exists {
    True -> Error("Post already exists: " <> dest)
    False -> scaffold_post(title_source, dest)
  }
}

/// Scaffold post function.
fn scaffold_post(title_source: String, dest: String) -> Result(String, String) {
  use template <- result.try(load_post_template())

  let title = prettify_title(title_source)
  let timestamp = current_timestamp()
  let updated =
    template
    |> replace_property("title", "title = " <> quoted(title))
    |> replace_property("date", "date = " <> quoted(timestamp))

  use _ <- result.try(paths.ensure_parent_dirs(dest))

  simplifile.write(dest, updated)
  |> result.map_error(fn(err) {
    "Unable to write post at " <> dest <> ": " <> simplifile.describe_error(err)
  })
  |> result.map(fn(_) { "Post created at " <> dest <> "." })
}

fn copy_directory(src: String, dest: String) -> Result(Nil, String) {
  simplifile.copy_directory(src, dest)
  |> result.map_error(fn(err) {
    "Unable to copy directory "
    <> src
    <> " -> "
    <> dest
    <> ": "
    <> simplifile.describe_error(err)
  })
}

fn path_exists(path: String) -> Result(Bool, String) {
  case simplifile.file_info(path) {
    Ok(_) -> Ok(True)
    Error(simplifile.Enoent) -> Ok(False)
    Error(err) ->
      Error(
        "Unable to inspect " <> path <> ": " <> simplifile.describe_error(err),
      )
  }
}

fn update_config_title(path: String, title: String) -> Result(Nil, String) {
  use contents <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(err) {
      "Unable to read " <> path <> ": " <> simplifile.describe_error(err)
    }),
  )

  let updated = replace_property(contents, "title", "title = " <> quoted(title))

  simplifile.write(path, updated)
  |> result.map_error(fn(err) {
    "Unable to write " <> path <> ": " <> simplifile.describe_error(err)
  })
}

fn update_theme_name(path: String, name: String) -> Result(Nil, String) {
  use contents <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(err) {
      "Unable to read " <> path <> ": " <> simplifile.describe_error(err)
    }),
  )

  let updated = replace_property(contents, "name", "name = " <> quoted(name))

  simplifile.write(path, updated)
  |> result.map_error(fn(err) {
    "Unable to write " <> path <> ": " <> simplifile.describe_error(err)
  })
}

fn replace_property(contents: String, key: String, line: String) -> String {
  let #(replaced, reversed) =
    string.split(contents, "\n")
    |> list.fold(#(False, []), fn(state, current) {
      let #(done, acc) = state
      case done {
        True -> #(True, [current, ..acc])
        False -> {
          let trimmed = string.trim(current)
          case matches_key(trimmed, key) {
            True -> #(True, [line, ..acc])
            False -> #(False, [current, ..acc])
          }
        }
      }
    })

  let rebuilt =
    reversed
    |> list.reverse
    |> string.join("\n")

  case replaced {
    True -> rebuilt
    False -> line <> "\n" <> rebuilt
  }
}

fn matches_key(line: String, key: String) -> Bool {
  string.starts_with(line, key <> " ") || string.starts_with(line, key <> "=")
}

fn quoted(value: String) -> String {
  let escaped = string.replace(value, "\"", "\\\"")
  "\"" <> escaped <> "\""
}

/// Load post template function.
fn load_post_template() -> Result(String, String) {
  case simplifile.read("archetypes/default.md") {
    Ok(contents) -> Ok(contents)
    Error(simplifile.Enoent) -> {
      let fallback = site_template_root <> "/archetypes/default.md"
      simplifile.read(fallback)
      |> result.map_error(fn(err) {
        "Unable to read archetype at "
        <> fallback
        <> ": "
        <> simplifile.describe_error(err)
      })
    }
    Error(err) ->
      Error(
        "Unable to read archetype at archetypes/default.md: "
        <> simplifile.describe_error(err),
      )
  }
}

fn prettify_title(input: String) -> String {
  let cleaned =
    input
    |> string.replace("-", " ")
    |> string.replace("_", " ")
    |> string.trim

  case string.length(cleaned) {
    0 -> "New Post"
    _ ->
      cleaned
      |> string.split(" ")
      |> list.filter(fn(word) { word != "" })
      |> list.map(capitalize_word)
      |> string.join(" ")
  }
}

fn capitalize_word(word: String) -> String {
  case string.length(word) {
    0 -> ""
    _ ->
      string.uppercase(string.slice(from: word, at_index: 0, length: 1))
      <> string.lowercase(string.drop_start(word, 1))
  }
}

fn post_slug(input: String) -> String {
  case util.slugify(input) {
    "" -> "post"
    slug -> slug
  }
}

/// Current timestamp function.
fn current_timestamp() -> String {
  timestamp.system_time()
  |> format_timestamp
}

/// Post destination info function.
fn post_destination_info(input: String) -> #(String, String) {
  let normalised =
    input
    |> string.trim
    |> string.replace("\\", "/")

  let segments =
    normalised
    |> string.split("/")
    |> list.filter(fn(segment) { segment != "" })

  let filename_input =
    segments
    |> list.reverse
    |> list.first
    |> result.unwrap("post")

  let directories = drop_last_path_segments(segments)

  let filename = case string.ends_with(filename_input, ".md") {
    True -> filename_input
    False -> post_slug(filename_input) <> ".md"
  }

  let title_source = case string.ends_with(filename_input, ".md") {
    True -> string.drop_end(filename_input, 3)
    False -> filename_input
  }

  let dest = case directories {
    [] -> filename
    _ -> string.join(directories, "/") <> "/" <> filename
  }

  #(dest, title_source)
}

/// Drop last path segments helper.
fn drop_last_path_segments(list_: List(String)) -> List(String) {
  case list_ {
    [] -> []
    [_] -> []
    [first, ..rest] -> [first, ..drop_last_path_segments(rest)]
  }
}

/// Format timestamp function.
fn format_timestamp(ts: timestamp.Timestamp) -> String {
  let #(date, _) = timestamp.to_calendar(ts, calendar.utc_offset)
  int.to_string(date.year)
  <> "-"
  <> pad(calendar.month_to_int(date.month))
  <> "-"
  <> pad(date.day)
}

/// Pad helper function.
fn pad(value: Int) -> String {
  let s = int.to_string(value)
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}
