raster_catalog <- data.frame(
  id = c("alpha", "nmds1", "nmds2", "clusters", "endemism", "density", "priority_alpha", "priority_endemism", "priority_integrated"),
  label = c("Alpha: predicted richness", "Beta: NMDS1", "Beta: NMDS2", "Beta: clusters",
    "Endemism: consensus index", "Occurrence kernel density", "Knowledge importance: alpha",
    "Knowledge importance: endemism", "Knowledge importance: integrated"),
  file = c("GAM_prediction_alpha.tif", "nmds_result.tiff", "nmds_result.tiff", "cluster_raster_result.tiff",
    "Endemism_consensus.tiff", "records_kernel_density.tiff", "alpha_conservation_all_clusters_likert5.tif",
    "endemism_conservation_all_clusters_likert5.tif", "alpha_endemism_records_all_clusters_likert5.tif"),
  band = c(1L, 1L, 2L, rep(1L, 6)),
  categorical = c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE),
  stringsAsFactors = FALSE
)

grid_style <- function(grid, variable) {
  values <- grid[[variable]]
  if (variable == "Ttl_rcr") {
    valid <- values[is.finite(values)]
    breaks <- if (length(valid)) unique(as.numeric(stats::quantile(valid, seq(0, 1, length.out = 8), type = 1))) else c(0, 1)
    if (length(breaks) == 1L) breaks <- breaks + c(-0.5, 0.5)
    return(list(pal = leaflet::colorBin(c("#ffffcc", "#ffeda0", "#fed976", "#feb24c", "#fd8d3c", "#e31a1c", "#800026"),
      domain = values, bins = breaks, na.color = "transparent"), label = "Total records (quantile classes)"))
  }
  list(pal = leaflet::colorNumeric("viridis", domain = if (variable == "Smplg_c") c(0, 1) else values,
      na.color = "transparent", reverse = variable == "Smplg_c"),
    label = if (variable == "Smplg_c") "Sampling coverage" else "Observed species")
}

make_grid_loader <- function(data_dir = "data") {
  loaded <- NULL
  function() {
    if (!is.null(loaded)) return(loaded)
    paths <- file.path(data_dir, paste0("grid_10km_sampling", c(".shp", ".shx", ".dbf", ".prj")))
    if (any(!file.exists(paths))) stop("Sampling grid files are missing.")
    signature <- list(hashes = tools::md5sum(paths), sf = as.character(packageVersion("sf")), version = 1L)
    cache <- file.path(data_dir, "map_grid_wgs84.rds")
    saved <- if (file.exists(cache)) tryCatch(readRDS(cache), error = function(e) NULL) else NULL
    if (!is.null(saved) && identical(saved$signature, signature)) {
      loaded <<- saved$grid
      return(loaded)
    }
    grid <- sf::st_read(paths[1], quiet = TRUE)
    if (is.na(sf::st_crs(grid))) stop("Sampling grid CRS is undefined.")
    fields <- c("id", "Ttl_rcr", "Totl_sp", "Smplg_c")
    if (!all(fields %in% names(grid))) stop("Invalid sampling grid schema.")
    if (any(grid$Smplg_c < 0 | grid$Smplg_c > 1, na.rm = TRUE)) stop("Sampling coverage is outside [0,1].")
    loaded <<- sf::st_transform(grid[, fields], 4326)
    saveRDS(list(signature = signature, grid = loaded), cache, compress = FALSE)
    loaded
  }
}

make_raster_loader <- function(data_dir = "data") {
  # No terra raster is read or reprojected until a user actually selects it.
  loaded <- new.env(parent = emptyenv())
  function(id) {
    # Windows may inherit PostgreSQL/QGIS PROJ_LIB. GDAL must use the database bundled
    # with this terra installation; these variables affect only the current R process.
    proj_dir <- system.file("proj", package = "terra")
    if (nzchar(proj_dir) && file.exists(file.path(proj_dir, "proj.db"))) {
      Sys.setenv(PROJ_DATA = proj_dir, PROJ_LIB = proj_dir)
      terra::projPaths(proj_dir)
    }
    spec <- raster_catalog[match(id, raster_catalog$id), ]
    if (is.na(spec$id)) stop("Unknown raster layer.")
    path <- file.path(data_dir, spec$file)
    if (!file.exists(path)) stop("Missing raster: ", spec$file)
    info <- file.info(path)
    signature <- list(size = info$size, mtime = as.numeric(info$mtime), band = spec$band,
      categorical = spec$categorical, terra = as.character(packageVersion("terra")), version = 2L)
    key <- digest::digest(signature)
    if (exists(id, loaded, inherits = FALSE) && identical(loaded[[id]]$key, key)) return(loaded[[id]])
    native <- terra::rast(path)[[spec$band]]
    if (!nzchar(terra::crs(native))) stop("Undefined raster CRS: ", spec$file)
    values <- as.numeric(terra::values(native))
    valid <- values[is.finite(values)]
    if (!length(valid)) stop("Raster has no valid cells: ", spec$file)
    classes <- sort(unique(valid))
    if (spec$categorical && any(classes != round(classes))) stop("Non-integer raster class codes.")
    if (spec$categorical) {
      colors <- if (id == "clusters") c("#0072B2", "#E69F00", "#009E73") else c("#1a9850", "#91cf60", "#fee08b", "#fc8d59", "#d73027")
      pal <- leaflet::colorFactor(colors, domain = if (id == "clusters") classes else 1:5,
        na.color = "transparent")
    } else pal <- leaflet::colorNumeric("viridis", domain = range(valid), na.color = "transparent")
    dir.create(file.path(data_dir, "map_cache"), showWarnings = FALSE)
    cache <- file.path(data_dir, "map_cache", paste0(id, "-", key, ".tif"))
    if (!file.exists(cache)) {
      projected <- leaflet::projectRasterForLeaflet(native, method = if (spec$categorical) "ngb" else "bilinear")
      if (spec$categorical) {
        result_classes <- unique(as.numeric(terra::values(projected)))
        if (any(!is.na(result_classes) & !result_classes %in% classes)) stop("Projection introduced invalid classes.")
      }
      terra::writeRaster(projected, cache, overwrite = TRUE, gdal = "COMPRESS=LZW")
    }
    loaded[[id]] <- list(key = key, raster = terra::rast(cache), pal = pal, classes = classes,
      categorical = spec$categorical, range = range(valid), label = spec$label, id = id)
    loaded[[id]]
  }
}

map_point_groups <- function(df) {
  if (!nrow(df)) return(data.frame(decimalLongitude = numeric(), decimalLatitude = numeric(), popup = character()))
  points <- data.table::as.data.table(df[, c("decimalLongitude", "decimalLatitude", "scientificName")])
  result <- points[, list(records = .N, species = data.table::uniqueN(scientificName), example = scientificName[1]),
    by = c("decimalLongitude", "decimalLatitude")]
  result$popup <- paste0("<b>Records at this coordinate:</b> ", result$records,
    "<br><b>Species:</b> ", result$species, "<br><b>Example:</b> <i>", htmltools::htmlEscape(result$example), "</i>")
  as.data.frame(result[, c("decimalLongitude", "decimalLatitude", "popup")])
}
