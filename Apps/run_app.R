# Portable launcher; project-local validation libraries are optional and never deployed.
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (length(script_arg)) {
  app_dir <- dirname(normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/"))
} else if (file.exists("app.R")) {
  app_dir <- normalizePath(".", winslash = "/")
} else if (file.exists("CODIGOS/Apps/app.R")) {
  app_dir <- normalizePath("CODIGOS/Apps", winslash = "/")
} else stop("Run this launcher from the project root or Apps directory.")
local_library <- file.path(app_dir, ".test-library")
user_libraries <- Sys.glob(file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/*"))
.libPaths(c(if (dir.exists(local_library)) local_library, user_libraries, .libPaths()))
required <- c("shiny", "leaflet", "ggplot2", "dplyr", "DT", "sf", "plotly", "bslib", "terra", "data.table", "cachem", "digest")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages: ", paste(missing, collapse = ", "))
shiny::runApp(app_dir, host = "127.0.0.1", launch.browser = interactive())
