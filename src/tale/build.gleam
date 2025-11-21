/// Build module
/// Responisible to build the static files into the public directory(user can configure that in config.toml)
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tale/config
import tale/content
import tale/paths
import tale/renderer
import tale/util

/// Build site function
pub fn build_site() -> Result(List(String), String) {
  use site_config <- result.try(config.load())
  let root = config.public_root(site_config)
  let paths = config.site_paths(site_config)

  use pages <- result.try(content.load_pages(
    root,
    paths.content,
    site_config.author,
  ))
  use partials <- result.try(renderer.load_partials(paths.partials))

  use _ <- result.try(reset_public_dir(root))
  use assets_msg <- result.try(copy_assets(root, paths.assets))
  use static_msg <- result.try(copy_static(root, paths.static))

  let posts =
    pages
    |> list.filter(content.is_post_page)
    |> list.filter(fn(page) { page.metadata.draft == False })
    |> sort_posts_by_date()

  let site_tags = build_site_tags(posts)

  let jobs = plan_render_jobs(pages, posts, site_tags, site_config, root)

  use rendered <- result.try(renderer.render_jobs(
    jobs,
    site_config,
    partials,
    paths.layouts,
  ))

  Ok([assets_msg, static_msg, ..rendered])
}

/// Resolves public root function
pub fn resolved_public_root() -> Result(String, String) {
  use site_config <- result.try(config.load())
  Ok(config.public_root(site_config))
}

/// Plan render jobs function
fn plan_render_jobs(
  pages: List(content.PageData),
  posts: List(content.PageData),
  site_tags: List(renderer.TagContext),
  site_config: config.SiteConfig,
  root: String,
) -> List(renderer.RenderJob) {
  let per_page = pagination_size(site_config.pagination, list.length(posts))
  let chunks = paginate_posts(posts, per_page)
  let total_pages = list.length(chunks)

  let page_jobs =
    pages
    |> list.flat_map(fn(page) {
      case content.is_list_layout(page) {
        True ->
          paginate_page_jobs(
            page,
            chunks,
            per_page,
            total_pages,
            site_tags,
            root,
          )
        False -> [
          renderer.RenderJob(
            page: page,
            posts: [],
            pagination: None,
            current_tag: None,
            site_tags: site_tags,
          ),
        ]
      }
    })

  let tag_jobs =
    build_tag_jobs(site_tags, per_page, site_tags, root, site_config.author)

  let jobs = list.append(page_jobs, tag_jobs)
  list.append(jobs, tag_overview_job(site_tags, site_config, root))
}

/// Build tags jobs function
fn build_tag_jobs(
  tags: List(renderer.TagContext),
  per_page: Int,
  site_tags: List(renderer.TagContext),
  root: String,
  default_author: String,
) -> List(renderer.RenderJob) {
  tags
  |> list.flat_map(fn(tag) {
    let tag_page = tag_page_data(tag, root, default_author)
    let tag_chunks = paginate_posts(tag.posts, per_page)
    let total_pages = list.length(tag_chunks)
    paginate_loop(
      tag_chunks,
      1,
      per_page,
      total_pages,
      tag_page,
      site_tags,
      root,
      Some(tag),
      [],
    )
  })
}

/// Function responsible for the pagination
fn paginate_page_jobs(
  page: content.PageData,
  chunks: List(List(content.PageData)),
  per_page: Int,
  total_pages: Int,
  site_tags: List(renderer.TagContext),
  root: String,
) -> List(renderer.RenderJob) {
  paginate_loop(
    chunks,
    1,
    per_page,
    total_pages,
    page,
    site_tags,
    root,
    None,
    [],
  )
}

/// Paginate page jobs function.
fn paginate_loop(
  chunks: List(List(content.PageData)),
  index: Int,
  per_page: Int,
  total_pages: Int,
  base_page: content.PageData,
  site_tags: List(renderer.TagContext),
  root: String,
  current_tag: Option(renderer.TagContext),
  acc: List(renderer.RenderJob),
) -> List(renderer.RenderJob) {
  case chunks {
    [] -> list.reverse(acc)
    [chunk, ..rest] -> {
      let paged_page = case index {
        1 -> base_page
        _ -> {
          let rel = paginated_output_rel(base_page.output_rel_path, index)
          content.with_output_path(base_page, root, rel)
        }
      }

      let pagination_info =
        Some(renderer.PaginationInfo(
          current_page: index,
          total_pages: total_pages,
          per_page: per_page,
          previous: previous_link(base_page, index),
          next: next_link(base_page, index, total_pages),
        ))

      let job =
        renderer.RenderJob(
          page: paged_page,
          posts: chunk,
          pagination: pagination_info,
          current_tag: current_tag,
          site_tags: site_tags,
        )

      paginate_loop(
        rest,
        index + 1,
        per_page,
        total_pages,
        base_page,
        site_tags,
        root,
        current_tag,
        [job, ..acc],
      )
    }
  }
}

/// Sorting posts per date (From newer to older)
fn sort_posts_by_date(posts: List(content.PageData)) -> List(content.PageData) {
  posts
  |> list.sort(fn(a, b) {
    let a_date = option.unwrap(a.metadata.date, "0000-00-00")
    let b_date = option.unwrap(b.metadata.date, "0000-00-00")
    // Descending order: newer (greater string) should come first.
    string.compare(b_date, a_date)
  })
}

/// Previous link(page) to pagination
fn previous_link(base_page: content.PageData, index: Int) -> Option(String) {
  case index {
    1 -> None
    2 -> Some(base_page.permalink)
    _ -> {
      let rel = paginated_output_rel(base_page.output_rel_path, index - 1)
      Some(content.permalink_from_output(rel))
    }
  }
}

/// Next link(page) to pagination
fn next_link(
  base_page: content.PageData,
  index: Int,
  total_pages: Int,
) -> Option(String) {
  case index >= total_pages {
    True -> None
    False -> {
      let target = index + 1
      case target {
        1 -> Some(base_page.permalink)
        _ -> {
          let rel = paginated_output_rel(base_page.output_rel_path, target)
          Some(content.permalink_from_output(rel))
        }
      }
    }
  }
}

/// Paginated output
fn paginated_output_rel(base: String, index: Int) -> String {
  let suffix = "page/" <> int.to_string(index) <> "/index.html"
  case paths.parent_directory(base) {
    None -> suffix
    Some(dir) -> dir <> "/" <> suffix
  }
}

/// Pagination size
fn pagination_size(setting: Option(Int), total_posts: Int) -> Int {
  let fallback = case total_posts {
    0 -> 1
    other -> other
  }

  case setting {
    Some(value) if value > 0 -> value
    _ -> fallback
  }
}

/// Paginate posts
fn paginate_posts(
  posts: List(content.PageData),
  per_page: Int,
) -> List(List(content.PageData)) {
  case posts {
    [] -> [posts]
    _ -> paginate_posts_loop(posts, per_page, [])
  }
}

fn paginate_posts_loop(
  posts: List(content.PageData),
  per_page: Int,
  acc: List(List(content.PageData)),
) -> List(List(content.PageData)) {
  case posts {
    [] -> list.reverse(acc)
    _ -> {
      let chunk = list.take(posts, per_page)
      let remaining = list.drop(posts, per_page)
      paginate_posts_loop(remaining, per_page, [chunk, ..acc])
    }
  }
}

/// Build tags page
fn build_site_tags(posts: List(content.PageData)) -> List(renderer.TagContext) {
  posts
  |> list.fold(dict.new(), fn(acc, page) {
    list.fold(page.metadata.tags, acc, fn(tags_acc, tag) {
      dict.upsert(tags_acc, tag, fn(existing) {
        let posts_list = case existing {
          None -> []
          Some(current) -> current
        }
        [page, ..posts_list]
      })
    })
  })
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(tag, tagged_posts) = entry
    let slug = util.slugify(tag)
    renderer.TagContext(
      name: tag,
      slug: slug,
      permalink: tag_permalink(slug),
      posts: list.reverse(tagged_posts),
    )
  })
}

/// Tags permalink
fn tag_permalink(slug: String) -> String {
  "/tags/" <> slug <> "/"
}

fn tag_output_rel(slug: String) -> String {
  "tags/" <> slug <> "/index.html"
}

/// Tag page data
fn tag_page_data(
  tag: renderer.TagContext,
  root: String,
  default_author: String,
) -> content.PageData {
  let output_rel = tag_output_rel(tag.slug)
  content.PageData(
    relative_path: "tags/" <> tag.slug <> ".generated",
    output_rel_path: output_rel,
    output_abs_path: root <> "/" <> output_rel,
    permalink: tag.permalink,
    layout: "term",
    metadata: content.PageMetadata(
      title: "Tag: " <> tag.name,
      description: "Posts tagged " <> tag.name,
      date: None,
      draft: False,
      tags: [],
      author: default_author,
      slug: tag.slug,
    ),
    body_html: "",
  )
}

/// Tag overview job function.
fn tag_overview_job(
  site_tags: List(renderer.TagContext),
  site_config: config.SiteConfig,
  root: String,
) -> List(renderer.RenderJob) {
  [
    renderer.RenderJob(
      page: tag_overview_page(root, site_config.author),
      posts: [],
      pagination: None,
      current_tag: None,
      site_tags: site_tags,
    ),
  ]
}

/// Tag overview page function.
fn tag_overview_page(root: String, default_author: String) -> content.PageData {
  let output_rel = "tags/index.html"
  content.PageData(
    relative_path: "tags/index.generated",
    output_rel_path: output_rel,
    output_abs_path: root <> "/" <> output_rel,
    permalink: "/tags/",
    layout: "taxonomy",
    metadata: content.PageMetadata(
      title: "All tags",
      description: "Browse every tag used on the site",
      date: None,
      draft: False,
      tags: [],
      author: default_author,
      slug: "tags",
    ),
    body_html: "",
  )
}

/// Reset public dir function.
fn reset_public_dir(root: String) -> Result(Nil, String) {
  use _ <- result.try(clean_public_dir(root))

  simplifile.create_directory_all(root)
  |> result.map_error(fn(err) {
    "Unable to create public directory: " <> simplifile.describe_error(err)
  })
}

/// Clean public dir function.
fn clean_public_dir(root: String) -> Result(Nil, String) {
  case simplifile.delete(root) {
    Ok(Nil) -> Ok(Nil)
    Error(simplifile.Enoent) -> Ok(Nil)
    Error(err) ->
      Error(
        "Unable to clean public directory: " <> simplifile.describe_error(err),
      )
  }
}

/// Copy assets function.
fn copy_assets(root: String, assets_dir: String) -> Result(String, String) {
  case simplifile.is_directory(assets_dir) {
    Ok(True) -> {
      let dest = root <> "/assets"
      simplifile.copy_directory(assets_dir, dest)
      |> result.map(fn(_) { "Copied assets to " <> dest })
      |> result.map_error(fn(err) {
        "Unable to copy assets: " <> simplifile.describe_error(err)
      })
    }
    _ -> Ok("No assets directory to copy")
  }
}

/// Copy static function.
fn copy_static(root: String, static_dir: String) -> Result(String, String) {
  case simplifile.is_directory(static_dir) {
    Ok(True) ->
      simplifile.copy_directory(static_dir, root)
      |> result.map(fn(_) { "Copied static files from " <> static_dir })
      |> result.map_error(fn(err) {
        "Unable to copy static files: " <> simplifile.describe_error(err)
      })
    _ -> Ok("No static directory to copy")
  }
}
