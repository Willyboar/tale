/// Renderer module
/// Responsible to  render the handles tempplates(.html)
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string_tree
import gleam/time/calendar
import gleam/time/timestamp
import handles
import handles/ctx
import simplifile
import tale/config.{type MenuItem, type SiteConfig}
import tale/content
import tale/paths
import tale/util

/// Pagination type
pub type PaginationInfo {
  PaginationInfo(
    current_page: Int,
    total_pages: Int,
    per_page: Int,
    previous: Option(String),
    next: Option(String),
  )
}

/// Tag Context type
pub type TagContext {
  TagContext(
    name: String,
    slug: String,
    permalink: String,
    posts: List(content.PageData),
  )
}

pub type RenderJob {
  RenderJob(
    page: content.PageData,
    posts: List(content.PageData),
    pagination: Option(PaginationInfo),
    current_tag: Option(TagContext),
    site_tags: List(TagContext),
  )
}

/// Loading template partials
pub fn load_partials(
  partials_dir: String,
) -> Result(List(#(String, handles.Template)), String) {
  load_partial_list(handles_partial_specs(), partials_dir, [])
}

/// Partials List. This is a strict list for now.
/// TODO: Make partials and generally layouts more flexible.
fn handles_partial_specs() -> List(#(String, String)) {
  [
    #("_partials/head", "head.html"),
    #("_partials/head_css", "head/css.html"),
    #("_partials/head_js", "head/js.html"),
    #("_partials/menu", "menu.html"),
    #("_partials/header", "header.html"),
    #("_partials/post_card", "post_card.html"),
    #("_partials/footer", "footer.html"),
  ]
}

/// Load templates partials list
fn load_partial_list(
  specs: List(#(String, String)),
  partials_dir: String,
  acc: List(#(String, handles.Template)),
) -> Result(List(#(String, handles.Template)), String) {
  case specs {
    [] -> Ok(list.reverse(acc))
    [#(name, file), ..rest] -> {
      use template <- result.try(load_handles_template(
        partials_dir <> "/" <> file,
      ))
      load_partial_list(rest, partials_dir, [#(name, template), ..acc])
    }
  }
}

/// Load handle templates
fn load_handles_template(path: String) -> Result(handles.Template, String) {
  use template_source <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(err) {
      "Unable to read template "
      <> path
      <> ": "
      <> simplifile.describe_error(err)
    }),
  )

  handles.prepare(template_source)
  |> result.map_error(fn(err) {
    "Template syntax error in "
    <> path
    <> ": "
    <> util.describe_tokenizer_error(err)
  })
}

pub fn render_jobs(
  jobs: List(RenderJob),
  config: SiteConfig,
  partials: List(#(String, handles.Template)),
  layouts_dir: String,
) -> Result(List(String), String) {
  render_loop(jobs, config, partials, layouts_dir, [])
}

fn render_loop(
  jobs: List(RenderJob),
  config: SiteConfig,
  partials: List(#(String, handles.Template)),
  layouts_dir: String,
  acc: List(String),
) -> Result(List(String), String) {
  case jobs {
    [] -> Ok(list.reverse(acc))
    [job, ..rest] -> {
      use message <- result.try(render_job(job, config, partials, layouts_dir))
      render_loop(rest, config, partials, layouts_dir, [message, ..acc])
    }
  }
}

fn render_job(
  job: RenderJob,
  config: SiteConfig,
  partials: List(#(String, handles.Template)),
  layouts_dir: String,
) -> Result(String, String) {
  use template <- result.try(load_handles_template(
    layouts_dir <> "/" <> job.page.layout <> ".html",
  ))

  let context = build_page_context(job, config)

  use rendered <- result.try(
    handles.run(template, context, partials)
    |> result.map_error(fn(err) {
      "Template runtime error in "
      <> job.page.layout
      <> " for "
      <> job.page.output_rel_path
      <> ": "
      <> util.describe_runtime_error(err)
    }),
  )

  use wrapped <- result.try(wrap_with_base(
    rendered,
    context,
    partials,
    layouts_dir,
  ))

  use _ <- result.try(paths.ensure_parent_dirs(job.page.output_abs_path))

  simplifile.write(job.page.output_abs_path, string_tree.to_string(wrapped))
  |> result.map_error(fn(err) {
    "Unable to write "
    <> job.page.output_abs_path
    <> ": "
    <> simplifile.describe_error(err)
  })
  |> result.map(fn(_) { "Wrote " <> job.page.output_abs_path })
}

fn build_page_context(job: RenderJob, config: SiteConfig) -> ctx.Value {
  let metadata =
    ctx.Dict([
      ctx.Prop("title", ctx.Str(job.page.metadata.title)),
      ctx.Prop("description", ctx.Str(job.page.metadata.description)),
      ctx.Prop("date", ctx.Str(option.unwrap(job.page.metadata.date, ""))),
      ctx.Prop("slug", ctx.Str(job.page.metadata.slug)),
      ctx.Prop("site_title", ctx.Str(config.title)),
      ctx.Prop("site_description", ctx.Str(config.description)),
      ctx.Prop("site_author", ctx.Str(config.author)),
      ctx.Prop("site_base_url", ctx.Str(config.base_url)),
      ctx.Prop("site_theme", ctx.Str(config.theme)),
      ctx.Prop("site_pagination", ctx.Int(option.unwrap(config.pagination, 0))),
      ctx.Prop("draft", ctx.Bool(job.page.metadata.draft)),
      ctx.Prop("author", ctx.Str(job.page.metadata.author)),
      ctx.Prop("tags", tag_list_context(job.page.metadata.tags)),
      ctx.Prop("permalink", ctx.Str(job.page.permalink)),
      ctx.Prop("is_home", ctx.Bool(job.page.permalink == "/")),
      ctx.Prop("has_tags", ctx.Bool(job.page.metadata.tags != [])),
      ctx.Prop("site_menu", menu_context(config.menu_main)),
      ctx.Prop("has_site_menu", ctx.Bool(config.menu_main != [])),
    ])

  let pagination_prop =
    ctx.Prop("pagination", pagination_context(job.pagination))

  let tag_prop = ctx.Prop("current_tag", current_tag_context(job.current_tag))

  let body_prop = ctx.Prop("body", ctx.Str(job.page.body_html))

  let base = [
    ctx.Prop("metadata", metadata),
    body_prop,
    pagination_prop,
    tag_prop,
    ctx.Prop("site_tags", tags_context(job.site_tags)),
    ctx.Prop("is_home", ctx.Bool(job.page.permalink == "/")),
    ctx.Prop("is_tag_page", ctx.Bool(option.is_some(job.current_tag))),
    ctx.Prop("is_index_page", ctx.Bool(option.is_none(job.current_tag))),
    ctx.Prop("is_subpage", ctx.Bool(job.page.permalink != "/")),
    ctx.Prop("has_body", ctx.Bool(job.page.body_html != "")),
    ctx.Prop("current_year", ctx.Str(current_year_string())),
  ]

  case content.is_list_layout(job.page) {
    True -> ctx.Dict([ctx.Prop("pages", posts_context(job.posts)), ..base])
    False -> ctx.Dict(base)
  }
}

fn posts_context(posts: List(content.PageData)) -> ctx.Value {
  posts
  |> list.map(post_summary_to_ctx)
  |> ctx.List
}

/// Finds the current year. Used in default theme footer.
fn current_year_string() -> String {
  let #(date, _) =
    timestamp.system_time()
    |> timestamp.to_calendar(calendar.utc_offset)
  int.to_string(date.year)
}

fn post_summary_to_ctx(page: content.PageData) -> ctx.Value {
  ctx.Dict([
    ctx.Prop("title", ctx.Str(page.metadata.title)),
    ctx.Prop("description", ctx.Str(page.metadata.description)),
    ctx.Prop("date", ctx.Str(option.unwrap(page.metadata.date, ""))),
    ctx.Prop("slug", ctx.Str(page.metadata.slug)),
    ctx.Prop("permalink", ctx.Str(page.permalink)),
    ctx.Prop("author", ctx.Str(page.metadata.author)),
    ctx.Prop("draft", ctx.Bool(page.metadata.draft)),
    ctx.Prop("has_tags", ctx.Bool(page.metadata.tags != [])),
    ctx.Prop("tags", tag_list_context(page.metadata.tags)),
  ])
}

fn pagination_context(info: Option(PaginationInfo)) -> ctx.Value {
  case info {
    None -> ctx.Dict([])
    Some(PaginationInfo(
      current_page: current,
      total_pages: total,
      per_page: per,
      previous: previous,
      next: next,
    )) ->
      ctx.Dict([
        ctx.Prop("current_page", ctx.Int(current)),
        ctx.Prop("total_pages", ctx.Int(total)),
        ctx.Prop("per_page", ctx.Int(per)),
        ctx.Prop("previous", ctx.Str(option.unwrap(previous, ""))),
        ctx.Prop("next", ctx.Str(option.unwrap(next, ""))),
        ctx.Prop("has_previous", ctx.Bool(option.is_some(previous))),
        ctx.Prop("has_next", ctx.Bool(option.is_some(next))),
        ctx.Prop("has_pages", ctx.Bool(total > 1)),
      ])
  }
}

fn current_tag_context(tag: Option(TagContext)) -> ctx.Value {
  case tag {
    None -> ctx.Dict([])
    Some(TagContext(name: name, slug: slug, permalink: link, posts: posts)) ->
      ctx.Dict([
        ctx.Prop("name", ctx.Str(name)),
        ctx.Prop("slug", ctx.Str(slug)),
        ctx.Prop("permalink", ctx.Str(link)),
        ctx.Prop("count", ctx.Int(list.length(posts))),
        ctx.Prop("posts", posts_context(posts)),
      ])
  }
}

fn tags_context(tags: List(TagContext)) -> ctx.Value {
  tags
  |> list.map(fn(tag) {
    let TagContext(name: name, slug: slug, permalink: link, posts: posts) = tag
    ctx.Dict([
      ctx.Prop("name", ctx.Str(name)),
      ctx.Prop("slug", ctx.Str(slug)),
      ctx.Prop("permalink", ctx.Str(link)),
      ctx.Prop("count", ctx.Int(list.length(posts))),
      ctx.Prop("posts", posts_context(posts)),
    ])
  })
  |> ctx.List
}

fn tag_list_context(tags: List(String)) -> ctx.Value {
  tags
  |> list.map(tag_value)
  |> ctx.List
}

fn tag_value(name: String) -> ctx.Value {
  let slug = util.slugify(name)
  ctx.Dict([
    ctx.Prop("name", ctx.Str(name)),
    ctx.Prop("slug", ctx.Str(slug)),
    ctx.Prop("permalink", ctx.Str(tag_permalink_from_slug(slug))),
  ])
}

fn tag_permalink_from_slug(slug: String) -> String {
  "/tags/" <> slug <> "/"
}

fn menu_context(items: List(MenuItem)) -> ctx.Value {
  items
  |> list.map(fn(item) {
    let config.MenuItem(label: label, url: url, weight: _) = item
    ctx.Dict([
      ctx.Prop("label", ctx.Str(label)),
      ctx.Prop("url", ctx.Str(url)),
    ])
  })
  |> ctx.List
}

fn wrap_with_base(
  inner: string_tree.StringTree,
  context: ctx.Value,
  partials: List(#(String, handles.Template)),
  layouts_dir: String,
) -> Result(string_tree.StringTree, String) {
  let base_path = layouts_dir <> "/baseof.html"
  case simplifile.is_file(base_path) {
    Ok(True) -> {
      use base_template <- result.try(load_handles_template(base_path))
      let slot = string_tree.to_string(inner)
      use extended_context <- result.try(add_slot(context, slot))
      handles.run(base_template, extended_context, partials)
      |> result.map_error(fn(err) {
        "Template runtime error in baseof for slot "
        <> base_path
        <> ": "
        <> util.describe_runtime_error(err)
      })
    }
    _ -> Ok(inner)
  }
}

fn add_slot(context: ctx.Value, slot: String) -> Result(ctx.Value, String) {
  case context {
    ctx.Dict(props) -> Ok(ctx.Dict([ctx.Prop("main", ctx.Str(slot)), ..props]))
    _ -> Error("Unable to extend template context for base layout")
  }
}
