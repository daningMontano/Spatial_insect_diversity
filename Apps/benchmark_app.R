# Run from Apps in the same environment used by validate_app.R.
results <- list()
measure <- function(label, expression, repeats = 1L) {
  code <- substitute(expression)
  times <- replicate(repeats, system.time(eval(code, parent.frame()))[["elapsed"]])
  results[[length(results) + 1L]] <<- data.frame(operation = label, repeats = repeats,
    median_seconds = median(times), min_seconds = min(times), max_seconds = max(times))
}
app <- new.env(parent = globalenv())
measure("App source: first in this R process", sys.source("app.R", envir = app))
measure("Build shared occurrence indexes", app$filter_index)
state <- app$default_filters()
measure("Menu choices: all occurrences", app$facet_options(app$filter_index, state), repeats = 5L)
state$snap <- "SNAP"; state$region <- "Amazon"
measure("Menu choices: SNAP and Amazon", app$facet_options(app$filter_index, state), repeats = 5L)
measure("Filter rows: indexed", app$index_rows(app$filter_index, state), repeats = 5L)
measure("Filter rows: previous dataframe scan", app$filter_occurrences(app$records_df, state, app$region_links, app$snap_links), repeats = 5L)
measure("Family summary: all national records", app$distribution_summary(app$records_df, "family"), repeats = 5L)
measure("Sampling grid: first lazy load", app$load_grid())
measure("Sampling grid: shared in-memory cache", app$load_grid(), repeats = 5L)
measure("Raster: first lazy load including terra initialization", app$load_raster("alpha"))
measure("Raster: shared in-memory cache", app$load_raster("alpha"), repeats = 5L)
output <- do.call(rbind, results)
write.csv(output, "performance_results.csv", row.names = FALSE)
print(output, row.names = FALSE)
