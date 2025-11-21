//// Welcome to the Tale static site/blog generator
//// You can use tale CLI with:
//// - clone repository and inside tale run `gleam run -- help`
////   You will see all available commands:
////   ```
////   build                 Build the static files into the public directory.
////   new (site | theme | post)   Create sites, themes, or posts.
////   serve                 Serve a site and rebuild when changes are detected.
////   version               Print the Tale CLI version.
////   ```
//// - build an escript with `gleam run -m gleescript` take the executable and move it into your path.
////   You will be able to run `tale help` globally.

import tale/cli

/// Version
const version = "0.1.0"

// TODO: Change version on every release!

pub fn main() -> Nil {
  cli.cli(version)
}
