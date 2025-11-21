/// Simple Developement Static Files Server
/// You can fire up server with: `tale serve` command
/// You can also pick the port running: `tale serve 4567` (default:8000)
import ewe.{type Request, type Response}
import filepath
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import logging
import simplifile
import tale/config
import tale/site
import tale/watch

pub const default_port: Int = 8000

pub fn main() -> Nil {
  serve(default_port)
}

pub fn serve(port: Int) -> Nil {
  logging.configure()
  logging.set_level(logging.Info)

  rebuild_site()

  let root = detect_public_root()
  logging.log(
    logging.Info,
    "Serving " <> root <> " on http://localhost:" <> int.to_string(port),
  )

  let _watcher =
    watch.start(watch.WatchConfig(
      paths: paths_to_watch(),
      on_change: rebuild_site,
    ))

  let handler = fn(req: Request) -> Response { static_handler(req, root) }

  case
    ewe.new(handler)
    |> ewe.bind_all()
    |> ewe.listening(port: port)
    |> ewe.start()
  {
    Ok(_) -> process.sleep_forever()
    Error(error) ->
      logging.log(
        logging.Error,
        "Failed to start server: " <> string.inspect(error),
      )
  }
}

/// Detects the public root
fn detect_public_root() -> String {
  case site.resolved_public_root() {
    Ok(path) -> path
    Error(error) -> panic as error
  }
}

fn static_handler(req: Request, root: String) -> Response {
  let candidates = candidate_paths(request.path_segments(req))
  serve_candidates(root, candidates)
}

fn candidate_paths(segments: List(String)) -> List(String) {
  let clean =
    segments
    |> list.filter(fn(segment) { segment != "." && segment != "" })
    |> list.filter(fn(segment) { segment != ".." })

  case clean {
    [] -> ["index.html"]
    ["", ..rest] -> candidate_paths(rest)
    segments -> {
      let joined = string.join(segments, "/")
      case has_extension(joined) {
        True -> [joined]
        False -> [joined <> ".html", joined <> "/index.html"]
      }
    }
  }
}

fn serve_candidates(root: String, paths: List(String)) -> Response {
  case paths {
    [] -> not_found()
    [path, ..rest] -> {
      let absolute = root <> "/" <> path
      case ewe.file(absolute, offset: option.None, limit: option.None) {
        Ok(body) -> success_response(path, body)
        Error(_) -> serve_candidates(root, rest)
      }
    }
  }
}

/// Succesfull Response
fn success_response(path: String, body: ewe.ResponseBody) -> Response {
  response.new(200)
  |> response.set_header("content-type", content_type(path))
  |> response.set_body(body)
}

/// Page not found response
fn not_found() -> Response {
  response.new(404)
  |> response.set_header("content-type", "text/plain; charset=utf-8")
  |> response.set_body(ewe.TextData("Not found"))
}

/// Content type development server supports
fn content_type(path: String) -> String {
  case
    string.split(path, ".")
    |> list.reverse
    |> list.first
  {
    Ok("html") -> "text/html; charset=utf-8"
    Ok("css") -> "text/css; charset=utf-8"
    Ok("js") -> "application/javascript; charset=utf-8"
    Ok("json") -> "application/json; charset=utf-8"
    Ok("svg") -> "image/svg+xml"
    Ok("png") -> "image/png"
    Ok("jpg") | Ok("jpeg") -> "image/jpeg"
    Ok("ico") -> "image/vnd.microsoft.icon"
    _ -> "application/octet-stream"
  }
}

fn has_extension(path: String) -> Bool {
  string.contains(path, ".")
}

fn rebuild_site() {
  case site.build_site() {
    Ok(messages) ->
      list.each(messages, fn(message) { logging.log(logging.Info, message) })
    Error(problem) -> logging.log(logging.Error, "Build failed: " <> problem)
  }
}

/// Paths in the directory that watcher monitor for changes
fn paths_to_watch() -> List(String) {
  let cwd =
    simplifile.current_directory()
    |> result.unwrap(".")

  case config.load() {
    Ok(site_config) -> {
      let site_paths = config.site_paths(site_config)
      dedup([
        config.config_path,
        site_config.content_dir,
        site_paths.layouts,
        site_paths.partials,
        site_paths.assets,
        site_paths.static,
      ])
      |> list.map(fn(path) { absolute_path(cwd, path) })
    }
    Error(problem) -> {
      logging.log(logging.Warning, "Watcher fallback paths: " <> problem)
      [
        absolute_path(cwd, "config.toml"),
        absolute_path(cwd, "content"),
        absolute_path(cwd, "layouts"),
        absolute_path(cwd, "assets"),
        absolute_path(cwd, "static"),
      ]
    }
  }
}

fn dedup(paths: List(String)) -> List(String) {
  list.fold(paths, [], fn(acc, path) {
    case list.contains(acc, path) {
      True -> acc
      False -> [path, ..acc]
    }
  })
}

fn absolute_path(base: String, path: String) -> String {
  let joined = case filepath.is_absolute(path) {
    True -> path
    False -> filepath.join(base, path)
  }

  case filepath.expand(joined) {
    Ok(expanded) -> expanded
    Error(_) -> joined
  }
}
