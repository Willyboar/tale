//// Embedded templates for Tale's generators

import gleam/list
import gleam/result
import simplifile.{type FileError}
import tale/paths

pub type TemplateFile {
  Text(path: String, contents: String)
}

pub fn write_site(to: String) -> Result(Nil, String) {
  write_files(to, site_files)
}

pub fn write_default_theme(to: String) -> Result(Nil, String) {
  write_files(to, default_theme_files)
}

pub fn default_post_archetype() -> String {
  case
    list.find_map(site_files, fn(file) {
      case file {
        Text("archetypes/default.md", contents) -> Ok(contents)
        _ -> Error(Nil)
      }
    })
  {
    Ok(contents) -> contents
    Error(_) -> ""
  }
}

fn write_files(root: String, files: List(TemplateFile)) -> Result(Nil, String) {
  list.try_each(files, fn(file) { write_template(root, file) })
}

fn write_template(root: String, template: TemplateFile) -> Result(Nil, String) {
  let path = case template {
    Text(p, _) -> p
  }
  let full_path = join_path(root, path)

  use _ <- result.try(paths.ensure_parent_dirs(full_path))

  case template {
    Text(_, contents) ->
      simplifile.write(full_path, contents)
      |> result.map_error(fn(err) { describe_write_error(full_path, err) })
  }
}

fn describe_write_error(path: String, err: FileError) -> String {
  "Unable to write " <> path <> ": " <> simplifile.describe_error(err)
}

fn join_path(root: String, path: String) -> String {
  case path {
    "" -> root
    _ -> root <> "/" <> path
  }
}

const site_files = [
  Text(
    "archetypes/default.md",
    "---\ntitle = \"New Article\"\ndescription = \"Short summary of the page\"\ndate = \"2025-01-01\"\ndraft = true\n---\n\n# Title Goes Here\n\nWrite your Markdown content here. Use code fences, blockquotes, headings, and\nlists to structure your article. All frontmatter values accept standard TOML.\n",
  ),
  Text("assets/.gitkeep", ""),
  Text(
    "config.toml",
    "# Site/Blog Configuration\n\n# Title of the Site/Blog\ntitle = \"Tale\"\n\n# Description of the Site/Blog\ndescription = \"A Gleam static site generator\"\n\n# Author of the Site/Blog\n# Will be set as post author if not define in the post metadata\nauthor = \"Tale Team\"\n\n# Base URL of the Site/Blog\nbaseUrl = \"https://example.com\"\n\n# The Directory where static files will be generated for deployment\n# Default: \"public\" if not defined\npublishDir = \"public\"\n\n# The Directory where content files are located\n# Default: \"content\" if not defined\ncontentDir = \"content\"\n\n# The Theme to use for the Site/Blog\n# Default: \"default\" if not defined\ntheme = \"default\"\n\n# The Number of posts to display per page\n# pagination = 5\n\n# Navigation menu (order matters)\n[menus]\n  [[menus.main]]\n    name = \"Home\"\n    pageRef = \"/\"\n    weight = 10\n\n  [[menus.main]]\n    name = \"About\"\n    pageRef = \"/about\"\n    weight = 20\n\n  [[menus.main]]\n    name = \"Tags\"\n    pageRef = \"/tags/\"\n    weight = 30\n",
  ),
  Text(
    "content/_index.md",
    "---\ntitle = \"Home\"\ndescription = \"Welcome to the Tale static site/blog generator\"\n---\n\n# Welcome to Tale\n\nCreate Markdown files inside `content/` to publish pages and posts. The default\nsite ships with a documentation-friendly theme, paginated home page, and tag\nlistings. Edit `content/posts/markdown-tour.md` to see how different Markdown\nconstructs render in the UI.\n",
  ),
  Text(
    "content/about.md",
    "---\ntitle = \"About\"\ndescription = \"Learn more about this prototype\"\n---\n\n## About This Site\n\nThis site demonstrates:\n\n- TOML frontmatter parsing via `tom`\n- Markdown to HTML rendering through `mork`\n- Handles templates with partials and pagination helpers\n",
  ),
  Text(
    "content/posts/markdown-tour.md",
    "---\ntitle = \"Markdown Syntax Tour\"\ndescription = \"A mega-post demonstrating Markdown and GFM output\"\ndate = \"2025-11-21\"\ntags = [\"docs\", \"markdown\", \"syntax\"]\n---\n\n# Markdown syntax tour\n\nThis document mirrors the Markdown reference at <https://www.markdownguide.org> so we can see how\ncommon constructs are rendered inside the theme.\n\n## Inline formatting\n\n*Italic*, **strong**, ***strong italic***, `inline code`, ~~strikethrough~~, and\n<ins>inserted text</ins> using raw HTML. Escape sequence: `\\*` literally shows\nan asterisk.\n\n## Links & images\n\nLink styles: [inline link](https://commonmark.org) or reference-style [docs][docs].\n\n![Markdown logo](https://commonmark.org/help/images/favicon.png)\n\n[docs]: https://commonmark.org/help/\n\n## Lists\n\n- Bullet one\n- Bullet two\n  - Nested bullet\n    1. Ordered inside\n    2. Still works\n- [ ] Task unchecked\n- [x] Task checked\n\n1. Ordered list entry\n2. Another entry\n3. And a third\n\n## Blockquotes\n\n> Block quotes can contain paragraphs, **inline styles**, and nested lists.\n>\n> > A nested quote feels nice too.\n\n## Footnotes\n\nMarkdown handles footnotes[^note] inline, great for references.[^ref]\n\n[^note]: Rendered at the bottom with backlinks.\n[^ref]: This one proves multiple notes work.\n\n## Code blocks\n\n```gleam\npub fn main() {\n  io.println(\"Hello from Markdown fenced code!\")\n}\n```\n\nIndented code works too:\n\n    touch src/app.gleam\n    gleam test\n\n## Tables\n\n| Feature      | Status | Notes                        |\n|--------------|--------|------------------------------|\n| Inline code  | ✅     | Backticks everywhere.        |\n| Task lists   | ✅     | Syntax uses `[ ]` and `[x]`.  |\n| Footnotes    | ✅     | Great for citations.         |\n\n## Thematic breaks\n\n---\n\n## Final paragraph\n\nIf something renders oddly, tweak the theme knowing every major Markdown feature is\nrepresented here.\n",
  ),
  Text(
    "content/tags/_index.md",
    "---\ntitle = \"Tags overview\"\ndescription = \"Browse all tags\"\n---\n\n# Tags\n\nAll tags are listed below. Use these links to explore topics.\n",
  ),
  Text("layouts/.gitkeep", ""),
  Text("static/.gitkeep", ""),
]

const default_theme_files = [
  Text(
    "assets/css/style.css",
    ":root {\n    color: #111;\n    font-family:\n        system-ui,\n        -apple-system,\n        BlinkMacSystemFont,\n        sans-serif;\n}\n\n* {\n    box-sizing: border-box;\n}\n\nbody {\n    margin: 0 auto;\n    max-width: 68ch;\n    padding: 2rem 1.25rem 4rem;\n    line-height: 1.4;\n    color: inherit;\n    background: #fff;\n}\n\na {\n    color: inherit;\n    text-decoration: none;\n}\n\nh1,\nh2,\nh3 {\n    margin: 0 0 0.4rem;\n    font-weight: 600;\n}\n\np {\n    margin: 0 0 0.8rem;\n}\n\nhgroup {\n    margin: 0 0 1rem;\n}\n\n.site-header {\n    margin-bottom: 1.5rem;\n}\n\n.site-header h1 {\n    font-size: 1.9rem;\n}\n\n.site-header hgroup p {\n    color: #666;\n}\n\n.site-menu {\n    display: flex;\n    flex-wrap: wrap;\n    gap: 0.75rem;\n    margin-top: 0.75rem;\n    font-size: 0.95rem;\n}\n\n.site-menu a:hover {\n    color: #666;\n}\n\n.layout main,\n.layout {\n    display: block;\n}\n\n.post-list {\n    margin-top: 1.5rem;\n}\n\n.post-card {\n    margin-bottom: 1.6rem;\n}\n\n.post-card h2 {\n    font-size: 1.35rem;\n    margin-bottom: 0.25rem;\n}\n\n.post-meta {\n    font-size: 0.85rem;\n    color: #555;\n    margin-bottom: 0.25rem;\n}\n\n.tag-list {\n    display: flex;\n    flex-wrap: wrap;\n    gap: 0.4rem;\n    margin: 0.4rem 0;\n}\n\n.tag-list a {\n    display: inline-block;\n    padding: 0.1rem 0.6rem;\n    border: 1px solid #222;\n    border-radius: 999px;\n    font-size: 0.8rem;\n}\n\n.pagination {\n    display: flex;\n    justify-content: center;\n    align-items: center;\n    gap: 1.5rem;\n    margin-top: 2rem;\n    font-size: 0.9rem;\n    text-align: center;\n}\n\nfooter {\n    margin-top: 3rem;\n    font-size: 0.85rem;\n    color: #555;\n}\n\n/* Minimal Markdown styles */\npre,\ncode {\n    font-family:\n        ui-monospace,\n        SFMono-Regular,\n        SF Mono,\n        Menlo,\n        Consolas,\n        \"Liberation Mono\",\n        monospace;\n}\n\npre {\n    background: #f5f5f5;\n    padding: 0.75rem;\n    border-radius: 6px;\n    overflow: auto;\n    border: 1px solid #e0e0e0;\n    margin: 0 0 1rem;\n}\n\ncode {\n    background: #f5f5f5;\n    padding: 0.1rem 0.35rem;\n    border-radius: 4px;\n    border: 1px solid #e0e0e0;\n}\n\ntable {\n    width: 100%;\n    border-collapse: collapse;\n    margin: 1rem 0;\n    font-size: 0.95rem;\n}\n\nth,\ntd {\n    padding: 0.5rem 0.75rem;\n    border: 1px solid #ddd;\n    text-align: left;\n}\n\nthead th {\n    background: #fafafa;\n    font-weight: 600;\n}\n",
  ),
  Text(
    "assets/js/app.js",
    "(() => {\n  const el = document.querySelector('[data-build-info]')\n  if (!el) return\n  const time = new Date().toLocaleString()\n  el.textContent = `Built at ${time}`\n})()\n",
  ),
  Text(
    "layouts/_partials/footer.html",
    "<footer>\n    <p>\n        &copy; {{current_year}} {{metadata.site_title}} ·\n        {{metadata.site_author}}\n    </p>\n</footer>\n",
  ),
  Text(
    "layouts/_partials/head/css.html",
    "<link rel=\"stylesheet\" href=\"/assets/css/style.css\" />\n",
  ),
  Text(
    "layouts/_partials/head/js.html",
    "<!-- Reserved for future enhancements inspired by Hugo's cached head partials -->\n",
  ),
  Text(
    "layouts/_partials/head.html",
    "<head>\n  <meta charset=\"utf-8\" />\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n  <title>\n    {{#if is_home}}\n      {{metadata.site_title}}\n    {{/if}}\n    {{#if is_subpage}}\n      {{metadata.title}} | {{metadata.site_title}}\n    {{/if}}\n  </title>\n  <meta name=\"description\" content=\"{{metadata.description}}\" />\n  <meta name=\"author\" content=\"{{metadata.author}}\" />\n  {{>_partials/head_css metadata}}\n  {{>_partials/head_js metadata}}\n</head>\n",
  ),
  Text(
    "layouts/_partials/header.html",
    "<header class=\"site-header\">\n    <hgroup>\n        <h1><a href=\"/\">{{metadata.site_title}}</a></h1>\n        <p>{{metadata.site_description}}</p>\n    </hgroup>\n    {{>_partials/menu metadata}}\n</header>\n",
  ),
  Text(
    "layouts/_partials/menu.html",
    "{{#if has_site_menu}}\n<nav class=\"site-menu\">\n    {{#each site_menu}}\n    <a href=\"{{url}}\">{{label}}</a>\n    {{/each}}\n</nav>\n{{/if}}\n",
  ),
  Text(
    "layouts/_partials/post_card.html",
    "<article class=\"post-card\">\n    <p class=\"post-meta\">{{date}} · {{author}}</p>\n    <h2><a href=\"{{permalink}}\">{{title}}</a></h2>\n    <p>{{description}}</p>\n    {{#if has_tags}}\n    <div class=\"tag-list\">\n        {{#each tags}}\n        <a href=\"{{permalink}}\">{{name}}</a>\n        {{/each}}\n    </div>\n    {{/if}}\n</article>\n",
  ),
  Text(
    "layouts/baseof.html",
    "<!doctype html>\n<html lang=\"en\">\n    {{>_partials/head .}}\n    <body>\n        {{>_partials/header .}} {{main}} {{>_partials/footer .}}\n    </body>\n</html>\n",
  ),
  Text(
    "layouts/home.html",
    "<main class=\"layout layout--list\">\n    <section class=\"page-hero\">\n        <hgroup>\n            <h1>{{metadata.title}}</h1>\n            <p>{{metadata.description}}</p>\n        </hgroup>\n    </section>\n\n    {{#if has_body}}\n    <section class=\"page-content\">{{body}}</section>\n    {{/if}}\n\n    <section class=\"post-list\">\n        {{#each pages}} {{>_partials/post_card .}} {{/each}}\n    </section>\n\n    {{#if pagination.has_pages}}\n    <nav class=\"pagination\">\n        {{#if pagination.has_previous}}\n        <a href=\"{{pagination.previous}}\">&larr;</a>\n        {{/if}}\n        <span\n            >Page {{pagination.current_page}} of\n            {{pagination.total_pages}}</span\n        >\n        {{#if pagination.has_next}}\n        <a href=\"{{pagination.next}}\">&rarr;</a>\n        {{/if}}\n    </nav>\n    {{/if}}\n</main>\n",
  ),
  Text(
    "layouts/page.html",
    "<main class=\"layout layout--page\">\n    <article>\n        <header class=\"page-header\">\n            <hgroup>\n                <h1>{{metadata.title}}</h1>\n                <p>{{metadata.description}}</p>\n            </hgroup>\n        </header>\n        {{body}}\n    </article>\n</main>\n",
  ),
  Text(
    "layouts/section.html",
    "<main class=\"layout layout--single\">\n    <article>\n        <header class=\"post-header\">\n            <p class=\"post-meta\">{{metadata.date}} · {{metadata.author}}</p>\n            <h1>{{metadata.title}}</h1>\n            <p>{{metadata.description}}</p>\n        </header>\n        {{body}} {{#if metadata.has_tags}}\n        <section class=\"post-tags\">\n            <div class=\"tag-list\">\n                {{#each metadata.tags}}\n                <a href=\"{{permalink}}\">{{name}}</a>\n                {{/each}}\n            </div>\n        </section>\n        {{/if}}\n    </article>\n</main>\n",
  ),
  Text(
    "layouts/taxonomy.html",
    "<main class=\"layout layout--tags\">\n    <section class=\"page-hero\">\n        <hgroup>\n            <h1>{{metadata.title}}</h1>\n            <p>{{metadata.description}}</p>\n        </hgroup>\n    </section>\n    <section class=\"tag-directory\">\n        <div class=\"tag-list\">\n            {{#each site_tags}}\n            <a href=\"{{permalink}}\">{{name}} ({{count}})</a>\n            {{/each}}\n        </div>\n    </section>\n</main>\n",
  ),
  Text(
    "layouts/term.html",
    "<main class=\"layout layout--list\">\n    <section class=\"page-hero\">\n        <hgroup>\n            <h1>{{current_tag.name}}</h1>\n            <p>{{current_tag.count}} posts</p>\n        </hgroup>\n    </section>\n\n    <section class=\"post-list\">\n        {{#each pages}} {{>_partials/post_card .}} {{/each}}\n    </section>\n\n    {{#if pagination.has_pages}}\n    <nav class=\"pagination\">\n        {{#if pagination.has_previous}}\n        <a href=\"{{pagination.previous}}\">&larr;</a>\n        {{/if}}\n        <span\n            >Page {{pagination.current_page}} of\n            {{pagination.total_pages}}</span\n        >\n        {{#if pagination.has_next}}\n        <a href=\"{{pagination.next}}\">&rarr;</a>\n        {{/if}}\n    </nav>\n    {{/if}}\n</main>\n",
  ),
  Text("static/robots.txt", "User-agent: *\nAllow: /\n"),
  Text(
    "theme.toml",
    "# Theme name\nname = \"default\"\n# License\nlicense = \"MIT\"\n\n# Description\ndescription = \"Starter theme for the Tale SSG with docs-friendly layouts\"\n\n# Version\nversion = \"0.1.0\"\n\n# Theme Link\nsrc = \"https://example.com/themes/default\"\n\n# Theme tags\ntags = [\"blog\", \"docs\", \"tags\", \"responsive\"]\n\n# Theme features\nfeatures = [\"pagination\", \"tags\", \"documentation\", \"partials\"]\n\n# Theme author\n[author]\n  name = \"Tale SSG Team\"\n  homepage = \"https://example.com\"\n  email = \"hello@example.com\"\n",
  ),
]
