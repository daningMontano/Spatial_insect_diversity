# Run from Apps after installing the dependencies listed in README.md.
source("metrics.R")
source("prepare_data.R")
source("load_data.R")
source("map_layers.R")
sync_notebook_assets(verify = TRUE)
bundle <- load_notebook_data()
df <- sf::st_drop_geometry(bundle$records_sf)
stopifnot(nrow(df) == length(unique(df$id_record)), nrow(df) == 106651L,
  known_taxa(df$scientificName) == 8626L, known_taxa(df$family) == 316L,
  known_taxa(df$order) == 21L)

workbook <- "../Results/Reports/excels/distribution_data_report.xlsx"
compare_export <- function(actual, sheet) {
  reference <- openxlsx::read.xlsx(workbook, sheet = sheet, check.names = FALSE)
  idx <- match(as.character(reference[[1]]), actual$Group)
  stopifnot(!anyNA(idx), nrow(reference) == nrow(actual),
    all(actual$Total_records[idx] == reference[[2]]),
    all(actual$Total_species[idx] == reference[[4]]),
    max(abs(actual$Percentage_records[idx] - reference[[3]])) < 1e-8,
    max(abs(actual$Percentage_species_of_total[idx] - reference[[5]])) < 1e-8)
  cat("MATCH", sheet, nrow(reference), "groups\n")
}
compare_export(distribution_summary(df, "snap_in_out"), "snap_summary")
compare_export(distribution_summary(df, "database_name"), "db_summary")
region_df <- merge(bundle$region_links, df[, setdiff(names(df), "veget")], by = "id_record", sort = FALSE)
compare_export(distribution_summary(region_df, "veget"), "veg_summary")
institutions <- distribution_summary(df, "institutionCode")
ref_inst <- openxlsx::read.xlsx(workbook, sheet = "inst_summary", check.names = FALSE)
# Six institution labels in the historical workbook have replacement characters.
# Check named matches directly and compare the full multiset of numerical signatures.
common <- match(ref_inst[[1]], institutions$Group)
matched <- !is.na(common)
stopifnot(all(institutions$Total_records[common[matched]] == ref_inst[[2]][matched]),
  all(institutions$Total_species[common[matched]] == ref_inst[[4]][matched]),
  identical(sort(paste(institutions$Total_records, institutions$Total_species)),
    sort(paste(ref_inst[[2]], ref_inst[[4]]))))
cat("MATCH institution numerical signatures; historical label encoding differences:", sum(!matched), "\n")
# The historical order export includes a missing-value category, displayed as No data here.
ref_order <- openxlsx::read.xlsx(workbook, sheet = "order_summary", check.names = FALSE)
ref_order[[1]][is.na(ref_order[[1]]) | ref_order[[1]] == ""] <- "No data"
order_actual <- distribution_summary(df, "order")
idx <- match(ref_order[[1]], order_actual$Group)
stopifnot(!anyNA(idx), all(order_actual$Total_records[idx] == ref_order[[2]]),
  all(order_actual$Total_species[idx] == ref_order[[4]]))
cat("MATCH order_summary\n")

grid <- sf::st_read("data/grid_10km_sampling.shp", quiet = TRUE)
stopifnot(sum(grid$Ttl_rcr, na.rm = TRUE) == 117233L, nrow(eligible_grid(grid)) == 162L)
selected_path <- "../Results/shp/grid_10km_sampling_filter.shp"
if (file.exists(selected_path)) {
  selected_export <- sf::st_read(selected_path, quiet = TRUE)
  stopifnot(setequal(eligible_grid(grid)$id, selected_export$id))
  cat("MATCH sampling grid and original selected cells\n")
} else {
  cat("PASS sampling threshold and 162 cells; optional original filtered export is not versioned\n")
}

selections <- list(order = "All", family = "All", genus = "All", scientificName = "All", snap = "All", region = "All")
filt <- function(s) filter_occurrences(df, s, bundle$region_links, bundle$snap_links)
stopifnot(nrow(filt(selections)) == 106651L)
s <- selections; s$snap <- "SNAP"; stopifnot(nrow(filt(s)) == 18917L)
s$snap <- "Outside SNAP"; stopifnot(nrow(filt(s)) == 87734L)
s <- selections; s$order <- "nonexistent"; stopifnot(nrow(filt(s)) == 0L, nrow(distribution_summary(filt(s), "order")) == 0L)
s <- selections; s$scientificName <- df$scientificName[1]
stopifnot(known_taxa(filt(s)$scientificName) == 1L, !anyDuplicated(filt(s)$id_record))
for (region in unique(bundle$region_links$veget)) {
  s <- selections; s$region <- region
  stopifnot(setequal(filt(s)$id_record, bundle$region_links$id_record[bundle$region_links$veget == region]))
}
cat("PASS filters: all, SNAP, outside, empty, species, all regions\n")

manifest <- read.csv("data/notebook_assets_manifest.csv")
stopifnot(all(unname(tools::md5sum(file.path("data", manifest$destination))) == manifest$md5))
# Validate every native raster, lazy Web Mercator projection, classes and cached reuse.
raster_loader <- make_raster_loader("data")
for (id in raster_catalog$id) {
  layer <- raster_loader(id)
  stopifnot(terra::same.crs(layer$raster, "EPSG:3857"), identical(layer$key, raster_loader(id)$key))
  if (layer$categorical) {
    values <- as.numeric(terra::values(layer$raster))
    stopifnot(all(values[!is.na(values)] %in% layer$classes))
  }
  widget <- leaflet::addRasterImage(leaflet::leaflet(), layer$raster, colors = layer$pal, project = FALSE)
  stopifnot(any(vapply(widget$x$calls, function(call) call$method == "addRasterImage", logical(1))))
}
cat("PASS 9 raster layers: Web Mercator, class preservation, image encoding and cache reuse\n")

index <- build_filter_index(df, bundle$region_links, bundle$snap_links)
scenarios <- list(default_filters())
for (region in unique(bundle$region_links$veget)) {
  state <- default_filters(); state$region <- region; scenarios[[length(scenarios) + 1L]] <- state
}
for (snap in c("SNAP", "Outside SNAP", head(names(index$lookup$snap), 3))) {
  state <- default_filters(); state$snap <- snap; scenarios[[length(scenarios) + 1L]] <- state
}
state <- default_filters(); state$scientificName <- df$scientificName[1]; scenarios[[length(scenarios) + 1L]] <- state
for (state in scenarios) {
  expected <- filter_occurrences(df, state, bundle$region_links, bundle$snap_links)
  stopifnot(setequal(df$id_record[index_rows(index, state)], expected$id_record))
}
state <- default_filters(); state$snap <- "SNAP"
choices <- facet_options(index, state)
stopifnot(setequal(setdiff(choices$order, "All"), unique(df$order[df$snap_in_out == "SNAP" & !is.na(df$order)])))
state$scientificName <- df$scientificName[1]
choices <- facet_options(index, state)
rows_without_order <- index_rows(index, state, exclude = "order")
stopifnot(setequal(setdiff(choices$order, "All"), unique(df$order[rows_without_order][!is.na(df$order[rows_without_order])])))
rounded <- display_distribution(distribution_summary(df, "order"))
stopifnot(identical(rounded$Percentage_records, round(rounded$Percentage_records, 2)),
  identical(rounded$Percentage_species_of_total, round(rounded$Percentage_species_of_total, 2)))
style <- grid_style(grid, "Ttl_rcr")
stopifnot(length(unique(style$pal(grid$Ttl_rcr[!is.na(grid$Ttl_rcr)]))) >= 5L)
cat("PASS indexed filters, dependent menus, two-decimal display and record color contrast\n")

app_env <- new.env(parent = globalenv())
sys.source("app.R", envir = app_env)
stopifnot(!grepl("Article analyses", paste(as.character(app_env$ui), collapse = ""), fixed = TRUE))
shiny::testServer(app_env$server, {
  session$setInputs(order_filter = "All", family_filter = "All", genus_filter = "All",
    species_filter = "All", snap_filter = "All", region_filter = "All", grid_var = "Ttl_rcr",
    grid_scope = "all", summary_group = "snap_in_out", run_filters = 0,
    main_tabs = "overview", show_grid = TRUE, show_occurrences = FALSE)
  stopifnot(as.integer(output$total_records) == 106651L, as.integer(output$total_species) == 8626L,
    as.integer(output$total_families) == 316L, as.integer(output$total_orders) == 21L)
  session$setInputs(snap_filter = "SNAP")
  stopifnot(as.integer(output$total_records) == 106651L, pending_filters()$snap == "SNAP", applied_filters()$snap == "All")
  session$setInputs(run_filters = 1)
  stopifnot(as.integer(output$total_records) == 18917L)
  session$setInputs(region_filter = "Amazon")
  stopifnot(as.integer(output$total_records) == 18917L,
    sum(region_summary()$Total_records) >= 18917L)
  session$setInputs(run_filters = 2)
  oracle <- filter_occurrences(df, list(snap = "SNAP", region = "Amazon"), bundle$region_links, bundle$snap_links)
  stopifnot(as.integer(output$total_records) == nrow(oracle),
    all(region_summary()$Group == "Amazon"))
  for (field in c("genus", "scientificName")) {
    session$setInputs(summary_group = field)
    summary <- get_summary(field)
    stopifnot(sum(summary$Total_records) == nrow(oracle),
      nrow(summary) == known_taxa(oracle[[field]]))
  }
  # Hidden maps must not load or transmit any raster, even after a sidebar selection.
  session$setInputs(map_rasters = c("alpha", "clusters"), raster_opacity = 0.75, raster_legend = "clusters")
  stopifnot(length(ls(environment(app_env$load_raster)$loaded)) == 0L)
  map_widget <- jsonlite::fromJSON(output$map)
  stopifnot(grepl("tile.openstreetmap.org", output$map, fixed = TRUE), !grepl("CartoDB", output$map, fixed = TRUE))
  session$setInputs(main_tabs = "map", grid_scope = "eligible", grid_var = "Smplg_c")
  stopifnot(nrow(selected_grid()) == 162L,
    length(ls(environment(app_env$load_raster)$loaded)) == 2L,
    as.integer(output$total_records) == nrow(oracle))
  session$setInputs(show_occurrences = TRUE)
  stopifnot(nrow(grouped_points()) <= nrow(oracle))
  for (id in raster_catalog$id) {
    session$setInputs(map_rasters = id, raster_legend = id)
    stopifnot(identical(selected_rasters(), id))
  }
  session$setInputs(map_rasters = character(), show_occurrences = FALSE, show_grid = FALSE)
  stopifnot(length(selected_rasters()) == 0L)
  session$setInputs(order_filter = "nonexistent")
  stopifnot(as.integer(output$total_records) == nrow(oracle))
  session$setInputs(run_filters = 3)
  stopifnot(as.integer(output$total_records) == 0L)
})
cat("PASS Shiny: pending/applied filters, regional scope, OSM tiles, lazy map, 9 raster selections and empty results\n")
cat("VALIDATION COMPLETE\n")
