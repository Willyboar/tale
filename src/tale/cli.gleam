//// # Tale CLI
//// ## Available Commands:
//// - `serve`: Serve a site and rebuild when changes are detected.
//// - `build`: Build a site into static HTML files.
//// - `new`: Create sites or themes via subcommands.
//// - `new site`: Create a new blog or site. (eg: `tale new site my-blog`)
//// - `new theme`: Create a new theme. (eg: `tale new theme my-theme`)
//// - `new post`: Create a new post. (eg: `tale new post post_name_needs_underscores`)
//// - `version`: Display the version of Tale.

import argv
import gleam/int
import gleam/io
import gleam/list
import glint
import tale/generators
import tale/server
import tale/site

const global_help_text = "\u{001b}[1;3mTale - A static story telling generator\u{001b}[0m"

/// Initialize the CLI application.
pub fn cli(version: String) -> Nil {
  let args = case argv.load().arguments {
    ["help", ..rest] -> list.append(rest, ["--help"])
    [] -> ["--help"]
    other -> other
  }

  let app =
    glint.new()
    |> glint.pretty_help(glint.default_pretty_help())
    |> glint.with_name("tale")
    |> glint.global_help(of: global_help_text)
    |> glint.add(at: ["version"], do: version_command(version))
    |> glint.add(at: ["new"], do: new_command())
    |> glint.add(at: ["new", "site"], do: new_site_command())
    |> glint.add(at: ["new", "theme"], do: new_theme_command())
    |> glint.add(at: ["new", "post"], do: new_post_command())
    |> glint.add(at: ["serve"], do: serve_command())
    |> glint.add(at: ["build"], do: build_command())

  glint.run_and_handle(from: app, for: args, with: fn(_) { Nil })
}

/// Initialize the new command.
fn new_command() -> glint.Command(Nil) {
  use <- glint.command_help("Create sites, themes or posts via subcommands.")
  use _, _, _ <- glint.command()
  {
    io.println("Use `tale new site|theme|post <name>`.")
    Nil
  }
}

/// Command that generates a new site/blog
/// See generators.gleam for details
fn new_site_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Create a new blog or site. Usage: tale new site <name>",
  )
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _, args, _ <- glint.command()
  {
    case args {
      [name] -> print_result(generators.new_site_gen(name))
      _ -> io.println("Missing site name. Run `tale new site <name>`.")
    }
    Nil
  }
}

/// Command that generates a new theme.
/// See generators.gleam for details
fn new_theme_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Create a new theme inside themes/. Usage: tale new theme <name>",
  )
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _, args, _ <- glint.command()
  {
    case args {
      [name] -> print_result(generators.new_theme_gen(name))
      _ -> io.println("Missing theme name. Run `tale new theme <name>`.")
    }
    Nil
  }
}

/// Command that generates a new Markdown post from the archetype.
fn new_post_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Create a new post from archetypes/default.md. Usage: tale new post <name>",
  )
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _, args, _ <- glint.command()
  {
    case args {
      [name] -> print_result(generators.new_post_gen(name))
      _ -> io.println("Missing post name. Run `tale new post <name>`.")
    }
    Nil
  }
}

/// Triggers a simple static server for development purposes
fn serve_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Serve a site with a basic server. Usage: tale serve [port]",
  )
  use _, args, _ <- glint.command()
  {
    case args {
      [] -> start_server(server.default_port)
      [port_str] -> {
        case int.parse(port_str) {
          Ok(port) -> start_server(port)
          Error(_) ->
            io.println(
              "Invalid port value \"" <> port_str <> "\". Please pass a number.",
            )
        }
      }
      _ -> io.println("Provide at most one port value, e.g. `tale serve 4500`.")
    }
    Nil
  }
}

/// Builds the static files into a directory(default:public)
fn build_command() -> glint.Command(Nil) {
  use <- glint.command_help("Build the static files into the public directory.")
  use _, _, _ <- glint.command()
  {
    case site.build_site() {
      Ok(messages) -> list.each(messages, io.println)
      Error(problem) -> io.println("Build failed: " <> problem)
    }
    Nil
  }
}

/// Prints the version
fn version_command(version: String) -> glint.Command(Nil) {
  use <- glint.command_help("Print the Tale CLI version.")
  use _, _, _ <- glint.command()
  {
    io.println("Tale v" <> version)
    Nil
  }
}

/// Prints messages of generators
fn print_result(outcome: Result(String, String)) {
  case outcome {
    Ok(message) -> io.println(message)
    Error(problem) -> io.println("Error: " <> problem)
  }
}

/// Starts the development server
fn start_server(port: Int) {
  io.println(
    "Starting Tale dev server on http://localhost:"
    <> int.to_string(port)
    <> " (Ctrl+C to stop)...",
  )
  server.serve(port)
}
