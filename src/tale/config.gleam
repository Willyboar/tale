/// Configuration module
/// Responsible to take values from config.toml file
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tale/util
import tom

/// Site configuration file
pub const config_path: String = "config.toml"

const default_layouts_dir: String = "layouts"

const default_partials_dir: String = "layouts/_partials"

const default_assets_dir: String = "assets"

const default_static_dir: String = "static"

/// Config types
/// REpresents all the options in the config.toml
pub type SiteConfig {
  SiteConfig(
    title: String,
    theme: String,
    description: String,
    author: String,
    base_url: String,
    public_root: String,
    content_dir: String,
    pagination: Option(Int),
    menu_main: List(MenuItem),
  )
}

/// Paths of all directories in the newly created site
pub type SitePaths {
  SitePaths(
    content: String,
    layouts: String,
    partials: String,
    assets: String,
    static: String,
  )
}

/// Menu item with weight
/// items are ordered per weight starting for the smaller one
pub type MenuItem {
  MenuItem(label: String, url: String, weight: Int)
}

/// Loads the configuration file
pub fn load() -> Result(SiteConfig, String) {
  use contents <- result.try(
    simplifile.read(config_path)
    |> result.map_error(fn(err) {
      "Unable to read config at "
      <> config_path
      <> ": "
      <> simplifile.describe_error(err)
    }),
  )

  use doc <- result.try(
    tom.parse(contents)
    |> result.map_error(fn(err) {
      "Unable to parse config at "
      <> config_path
      <> ": "
      <> util.describe_toml_error(err)
    }),
  )

  let legacy_base_url = util.get_string_or(doc, ["base_url"], "/")
  let configured_base_url =
    util.get_string_or(doc, ["baseUrl"], legacy_base_url)
    |> util.normalize_base_url
  let menu_main = parse_menu(doc, ["menus", "main"])

  Ok(SiteConfig(
    title: util.get_string_or(doc, ["title"], "Untitled site"),
    description: util.get_string_or(doc, ["description"], ""),
    author: util.get_string_or(doc, ["author"], "Anonymous"),
    base_url: configured_base_url,
    public_root: util.get_string_or(doc, ["publishDir"], "public"),
    theme: util.get_string_or(doc, ["theme"], "default"),
    content_dir: util.get_string_or(doc, ["contentDir"], "contents"),
    pagination: util.optional_int(tom.get_int(doc, ["pagination"])),
    menu_main: menu_main,
  ))
}

/// Configure public root.
/// By default this is `public` but user can change it in the config.toml file.
pub fn public_root(config: SiteConfig) -> String {
  config.public_root
}

/// Site path for the themes
pub fn site_paths(config: SiteConfig) -> SitePaths {
  let theme_root = "themes/" <> config.theme
  SitePaths(
    content: config.content_dir,
    layouts: themed_directory(theme_root <> "/layouts", default_layouts_dir),
    partials: themed_directory(
      theme_root <> "/layouts/_partials",
      default_partials_dir,
    ),
    assets: themed_directory(theme_root <> "/assets", default_assets_dir),
    static: themed_directory(theme_root <> "/static", default_static_dir),
  )
}

fn themed_directory(candidate: String, fallback: String) -> String {
  case simplifile.is_directory(candidate) {
    Ok(True) -> candidate
    _ -> fallback
  }
}

/// Parse functions for the menu items
fn parse_menu(
  doc: dict.Dict(String, tom.Toml),
  key: List(String),
) -> List(MenuItem) {
  case tom.get_array(doc, key) {
    Ok(entries) ->
      parse_menu_entries(entries, [])
      |> sort_menu_items
    Error(_) -> []
  }
}

fn parse_menu_entries(
  entries: List(tom.Toml),
  acc: List(MenuItem),
) -> List(MenuItem) {
  case entries {
    [] -> list.reverse(acc)
    [entry, ..rest] -> {
      let acc = case menu_item_from(entry) {
        Some(item) -> [item, ..acc]
        None -> acc
      }
      parse_menu_entries(rest, acc)
    }
  }
}

fn menu_item_from(entry: tom.Toml) -> Option(MenuItem) {
  case entry {
    tom.Table(table) -> menu_item_from_table(table)
    tom.InlineTable(table) -> menu_item_from_table(table)
    _ -> None
  }
}

fn menu_item_from_table(table: dict.Dict(String, tom.Toml)) -> Option(MenuItem) {
  let label = util.optional_string(tom.get_string(table, ["name"]))
  let page_ref = util.optional_string(tom.get_string(table, ["pageRef"]))
  let weight = util.optional_int(tom.get_int(table, ["weight"]))
  case label, page_ref {
    Some(label), Some(ref) ->
      Some(MenuItem(
        label: label,
        url: page_ref_to_url(ref),
        weight: option.unwrap(weight, 0),
      ))
    _, _ -> None
  }
}

fn page_ref_to_url(ref: String) -> String {
  case ref {
    "" -> "/"
    "/" -> "/"
    other -> {
      let cleaned = string.trim(other)
      let with_leading = case string.starts_with(cleaned, "/") {
        True -> cleaned
        False -> "/" <> cleaned
      }
      case with_leading {
        "" -> "/"
        "/" -> "/"
        _ -> with_leading
      }
    }
  }
}

/// Sorting menu items per weight
fn sort_menu_items(items: List(MenuItem)) -> List(MenuItem) {
  list.sort(items, fn(a, b) {
    case a.weight == b.weight {
      True -> string.compare(a.label, b.label)
      False -> int.compare(a.weight, b.weight)
    }
  })
}
