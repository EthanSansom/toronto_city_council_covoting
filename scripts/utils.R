library(here)
library(fs)
library(cli)

assert_file_exits <- function(path) {
  if (!file_exists(path)) {
    cli_abort(c(
      "Missing expected file: {.path {path_rel(path, start = here())}}.",
      i = "See {.path README.md} for instructions to create this file."
    ))
  }
}
