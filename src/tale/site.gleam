import gleam/io
import gleam/list
import tale/build

/// Main function.
pub fn main() -> Nil {
  case build.build_site() {
    Ok(messages) -> list.each(messages, io.println)
    Error(problem) -> io.println("Build failed: " <> problem)
  }
}

/// Build site function.
pub fn build_site() -> Result(List(String), String) {
  build.build_site()
}

/// Resolved public root function.
pub fn resolved_public_root() -> Result(String, String) {
  build.resolved_public_root()
}
