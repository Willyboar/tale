/// Content module
/// Responsible for the content of the markdown files
/// Handles the frontmatter and page metadata
import frontmatter
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import mork
import simplifile
import tale/util
import tom

/// Type of what can be added in the frontmatter section in the top
/// of the markdown file. Frontmatter starts with `---` and ends with `---`
/// all frontmatter must be inside those.
pub type PageFrontmatter {
  PageFrontmatter(
    title: String,
    description: String,
    layout: String,
    date: Option(String),
    draft: Bool,
    tags: List(String),
    author: Option(String),
  )
}

pub type PageMetadata {
  PageMetadata(
    title: String,
    description: String,
    date: Option(String),
    draft: Bool,
    tags: List(String),
    author: String,
    slug: String,
  )
}

pub type PageData {
  PageData(
    relative_path: String,
    output_rel_path: String,
    output_abs_path: String,
    permalink: String,
    layout: String,
    metadata: PageMetadata,
    body_html: String,
  )
}

/// Load pages
pub fn load_pages(
  root: String,
  content_dir: String,
  default_author: String,
) -> Result(List(PageData), String) {
  use files <- result.try(
    simplifile.get_files(content_dir)
    |> result.map_error(fn(err) {
      "Unable to list content: " <> simplifile.describe_error(err)
    }),
  )

  let md_files =
    files
    |> list.filter(fn(path) { string.ends_with(path, ".md") })

  load_page_list(root, content_dir, default_author, md_files, [])
}

/// Loads page list
fn load_page_list(
  root: String,
  content_dir: String,
  default_author: String,
  files: List(String),
  acc: List(PageData),
) -> Result(List(PageData), String) {
  case files {
    [] -> Ok(list.reverse(acc))
    [file, ..rest] -> {
      use page <- result.try(load_page(root, content_dir, default_author, file))
      load_page_list(root, content_dir, default_author, rest, [page, ..acc])
    }
  }
}

/// Load page
fn load_page(
  root: String,
  content_dir: String,
  default_author: String,
  path: String,
) -> Result(PageData, String) {
  use contents <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(err) {
      "Unable to read " <> path <> ": " <> simplifile.describe_error(err)
    }),
  )

  let frontmatter.Extracted(frontmatter: fm_text, content: body) =
    frontmatter.extract(contents)

  let relative = relative_content_path(path, content_dir)
  use meta <- result.try(parse_page_metadata(relative, fm_text))

  let body_html = render_markdown(body)
  let slug = slug_from_title(relative, meta.title)
  let output_rel = output_path_for(relative, slug)
  let output_abs = root <> "/" <> output_rel
  let author = option.unwrap(meta.author, default_author)
  let permalink = permalink_for_path(relative, slug)

  Ok(PageData(
    relative_path: relative,
    output_rel_path: output_rel,
    output_abs_path: output_abs,
    permalink: permalink,
    layout: meta.layout,
    metadata: PageMetadata(
      title: meta.title,
      description: meta.description,
      date: meta.date,
      draft: meta.draft,
      tags: meta.tags,
      author: author,
      slug: slug,
    ),
    body_html: body_html,
  ))
}

/// Parsing Page metadata
fn parse_page_metadata(
  relative: String,
  raw: Option(String),
) -> Result(PageFrontmatter, String) {
  let defaults =
    PageFrontmatter(
      title: fallback_title(relative),
      description: "Page description",
      layout: infer_layout(relative),
      date: None,
      draft: False,
      tags: [],
      author: None,
    )

  case raw {
    None -> Ok(defaults)
    Some(text) -> {
      use doc <- result.try(
        tom.parse(text)
        |> result.map_error(fn(err) {
          "Unable to parse frontmatter in "
          <> relative
          <> ": "
          <> util.describe_toml_error(err)
        }),
      )

      Ok(PageFrontmatter(
        title: util.get_string_or(doc, ["title"], defaults.title),
        description: util.get_string_or(
          doc,
          ["description"],
          defaults.description,
        ),
        layout: util.get_string_or(doc, ["layout"], defaults.layout),
        date: util.optional_string(tom.get_string(doc, ["date"])),
        draft: util.get_bool_or(doc, ["draft"], defaults.draft),
        tags: util.get_string_list_or(doc, ["tags"], defaults.tags),
        author: util.optional_string(tom.get_string(doc, ["author"])),
      ))
    }
  }
}

fn relative_content_path(path: String, content_dir: String) -> String {
  let prefix = content_dir <> "/"
  case string.starts_with(path, prefix) {
    True -> string.drop_start(path, string.length(prefix))
    False -> path
  }
}

fn output_path_for(relative: String, slug: String) -> String {
  let segments = segments_without_extension(relative)

  case segments {
    [] -> "index.html"
    segs -> {
      let last = list.last(segs) |> result.unwrap("index")
      let parents = drop_last(segs)
      case last {
        "_index" -> parent_index_path(parents)
        other -> {
          let final = slug_or_fallback(slug, other)
          build_path(parents, final <> "/index.html")
        }
      }
    }
  }
}

fn strip_extension(path: String) -> String {
  case string.ends_with(path, ".md") {
    True -> string.drop_end(path, 3)
    False -> path
  }
}

fn infer_layout(relative: String) -> String {
  case is_section_index(relative) {
    True -> "home"
    False -> {
      case string.starts_with(relative, "posts/") {
        True -> "section"
        False -> "page"
      }
    }
  }
}

fn is_section_index(relative: String) -> Bool {
  let stem = strip_extension(relative)
  case stem {
    "_index" -> True
    _ -> string.ends_with(stem, "/_index")
  }
}

fn permalink_for_path(relative: String, slug: String) -> String {
  let segments = segments_without_extension(relative)
  case segments {
    [] -> "/"
    segs -> {
      let last = list.last(segs) |> result.unwrap("")
      let parents = drop_last(segs)
      case last {
        "_index" -> path_from_segments(parents)
        other -> {
          let final = slug_or_fallback(slug, other)
          path_from_segments(list.append(parents, [final]))
        }
      }
    }
  }
}

pub fn permalink_from_output(output_rel: String) -> String {
  let trimmed = case string.ends_with(output_rel, ".html") {
    True -> string.drop_end(output_rel, 5)
    False -> output_rel
  }

  let segments =
    trimmed
    |> string.split("/")
    |> list.filter(fn(s) { s != "" })

  case segments {
    [] -> "/"
    segs -> {
      let last = list.last(segs) |> result.unwrap("")
      let parents = drop_last(segs)
      case last {
        "index" -> {
          case parents {
            [] -> "/"
            _ -> path_from_segments(parents)
          }
        }
        other -> path_from_segments(list.append(parents, [other]))
      }
    }
  }
}

fn fallback_title(relative: String) -> String {
  let stem =
    relative
    |> strip_extension
    |> string.split("/")
    |> list.reverse
    |> list.first
    |> result.unwrap("Page")

  capitalize_slug(stem)
}

fn capitalize_slug(slug: String) -> String {
  let words =
    slug
    |> string.replace("-", " ")
    |> string.replace("_", " ")

  case string.length(words) {
    0 -> "Page"
    _ ->
      string.uppercase(string.slice(from: words, at_index: 0, length: 1))
      <> string.drop_start(words, 1)
  }
}

fn slug_from_title(relative: String, title: String) -> String {
  case util.slugify(title) {
    "" -> fallback_slug(relative)
    slug -> slug
  }
}

fn fallback_slug(relative: String) -> String {
  relative
  |> strip_extension
  |> string.split("/")
  |> list.filter(fn(segment) { segment != "" && segment != "_index" })
  |> list.last
  |> result.unwrap("page")
  |> util.slugify
}

fn segments_without_extension(relative: String) -> List(String) {
  relative
  |> strip_extension
  |> string.split("/")
  |> list.filter(fn(segment) { segment != "" })
}

fn drop_last(list_: List(String)) -> List(String) {
  case list_ {
    [] -> []
    [_] -> []
    [first, ..rest] -> [first, ..drop_last(rest)]
  }
}

fn parent_index_path(parents: List(String)) -> String {
  case parents {
    [] -> "index.html"
    _ -> string.join(parents, "/") <> "/index.html"
  }
}

fn build_path(parents: List(String), final: String) -> String {
  case parents {
    [] -> final
    _ -> string.join(parents, "/") <> "/" <> final
  }
}

fn slug_or_fallback(slug: String, fallback: String) -> String {
  case slug {
    "" -> util.slugify(fallback)
    other -> other
  }
}

fn path_from_segments(segments: List(String)) -> String {
  case segments {
    [] -> "/"
    _ -> "/" <> string.join(segments, "/")
  }
}

pub fn is_post_page(page: PageData) -> Bool {
  string.starts_with(page.relative_path, "posts/")
}

pub fn is_list_layout(page: PageData) -> Bool {
  page.layout == "home" || page.layout == "term"
}

pub fn with_output_path(
  page: PageData,
  root: String,
  output_rel: String,
) -> PageData {
  PageData(
    relative_path: page.relative_path,
    output_rel_path: output_rel,
    output_abs_path: root <> "/" <> output_rel,
    permalink: permalink_from_output(output_rel),
    layout: page.layout,
    metadata: page.metadata,
    body_html: page.body_html,
  )
}

fn render_markdown(markdown: String) -> String {
  let options =
    mork.configure()
    |> mork.extended(True)

  mork.parse_with_options(options, markdown)
  |> mork.to_html
}
