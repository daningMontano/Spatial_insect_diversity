input_file_hashes <- function(paths, data_dir, verify = FALSE) {
  info <- file.info(paths)
  state <- data.frame(path = paths, size = info$size, mtime = as.numeric(info$mtime), row.names = NULL)
  cache <- file.path(data_dir, "input_hash_state.rds")
  previous <- if (file.exists(cache)) tryCatch(readRDS(cache), error = function(e) NULL) else NULL
  if (!verify && !is.null(previous) && identical(previous$state, state)) return(previous$hashes)
  hashes <- tools::md5sum(paths)
  saveRDS(list(state = state, hashes = hashes), cache)
  hashes
}

load_notebook_data <- function(data_dir = "data", verify = FALSE) {
  paths <- c("insects_records_clean.csv", unlist(lapply(
    c("ecuador_limits", "ron_2011_no_UTM", "snap"),
    function(x) paste0(x, c(".shp", ".shx", ".dbf", ".prj")))))
  paths <- c(paths, list.files(data_dir, pattern = "\\.cpg$"))
  full_paths <- file.path(data_dir, paths)
  if (any(!file.exists(full_paths))) stop("Missing occurrence inputs: ", paste(paths[!file.exists(full_paths)], collapse = ", "))
  signature <- list(version = 4L, input_encoding = "latin1", hashes = input_file_hashes(full_paths, data_dir, verify),
    sf = as.character(packageVersion("sf")), spatial_engine = sf::sf_extSoftVersion(),
    s2 = sf::sf_use_s2())
  cache <- file.path(data_dir, "notebook_records_v4.rds")
  if (file.exists(cache)) {
    saved <- tryCatch(readRDS(cache), error = function(e) NULL)
    if (!is.null(saved) && identical(saved$signature, signature)) return(saved)
  }
  # The canonical CSV contains Latin-1 bytes; explicit marking avoids locale-dependent names.
  raw <- read.csv(file.path(data_dir, "insects_records_clean.csv"), stringsAsFactors = FALSE, encoding = "latin1")
  message("Rebuilding national occurrences from notebook inputs...")
  required <- c("id_record", "scientificName", "taxonRank", "decimalLongitude", "decimalLatitude", "order", "family", "genus")
  if (!all(required %in% names(raw))) stop("Invalid occurrence schema.")
  if (anyNA(raw$id_record) || anyDuplicated(raw$id_record)) stop("Clean CSV must have unique, non-missing id_record.")
  if (any(raw$taxonRank != "species" | is.na(raw$taxonRank))) stop("Clean CSV contains non-species records.")
  if (!is.numeric(raw$decimalLongitude) || !is.numeric(raw$decimalLatitude) ||
      any(!is.finite(raw$decimalLongitude) | abs(raw$decimalLongitude) > 180 |
          !is.finite(raw$decimalLatitude) | abs(raw$decimalLatitude) > 90)) stop("Invalid coordinates in clean CSV.")
  read_layer <- function(name) {
    x <- sf::st_read(file.path(data_dir, paste0(name, ".shp")), quiet = TRUE)
    if (is.na(sf::st_crs(x))) stop("Undefined CRS: ", name)
    sf::st_transform(sf::st_make_valid(x), 4326)
  }
  ecu <- read_layer("ecuador_limits")
  ecu_u <- sf::st_union(ecu)
  pts <- sf::st_as_sf(raw, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326, remove = FALSE)
  pts <- sf::st_make_valid(pts)
  pts <- pts[lengths(sf::st_within(pts, ecu_u)) > 0, ]
  message("Assigning natural regions with the Report notebook procedure...")

  # Match Report cell 18: region membership may legitimately have multiple rows.
  regions <- sf::st_make_valid(sf::st_intersection(read_layer("ron_2011_no_UTM"), ecu_u))
  joined <- sf::st_join(pts[, "id_record", drop = FALSE], regions, join = sf::st_within, left = TRUE)
  region_cols <- setdiff(names(regions), attr(regions, "sf_column"))
  absent <- is.na(sf::st_drop_geometry(joined)[[region_cols[1]]])
  joined$natural_region_assignment <- "within"
  joined$natural_region_dist_to_nearest_m <- NA_real_
  if (any(absent)) {
    nearest <- sf::st_nearest_feature(joined[absent, ], regions)
    joined[absent, region_cols] <- sf::st_drop_geometry(regions[nearest, region_cols, drop = FALSE])
    joined$natural_region_assignment[absent] <- "nearest"
    joined$natural_region_dist_to_nearest_m[absent] <- as.numeric(sf::st_distance(joined[absent, ], regions[nearest, ], by_element = TRUE))
  }
  region_links <- sf::st_drop_geometry(joined)
  message("Assigning SNAP membership without multiplying occurrence rows...")

  # Match Report cell 21: membership is a boolean, never a row-multiplying join.
  snap <- sf::st_make_valid(sf::st_intersection(read_layer("snap"), ecu_u))
  if (!all(c("map", "nam") %in% names(snap))) stop("SNAP must contain map and nam.")
  snap$snap_name <- trimws(paste(ifelse(is.na(snap$map), "", snap$map), ifelse(is.na(snap$nam), "", snap$nam)))
  snap$snap_name[snap$snap_name == ""] <- "Unnamed Protected Area"
  membership <- sf::st_within(pts, snap)
  pts$snap_in_out <- ifelse(lengths(membership) > 0, "SNAP", "Outside SNAP")
  snap_links <- data.frame(id_record = rep(pts$id_record, lengths(membership)),
    snap_name = snap$snap_name[unlist(membership)], stringsAsFactors = FALSE)
  pts$snap_name <- vapply(membership, function(ids) {
    if (!length(ids)) "Outside SNAP" else paste(sort(unique(snap$snap_name[ids])), collapse = "; ")
  }, character(1))
  region_names <- split(region_links$veget, region_links$id_record)
  pts$veget <- vapply(as.character(pts$id_record), function(id) paste(sort(unique(region_names[[id]])), collapse = "; "), character(1))
  result <- list(signature = signature, records_sf = pts, region_links = region_links,
    snap_links = unique(snap_links), n_source = nrow(raw))
  # Replace only the derived cache after the complete build succeeds.
  temporary <- tempfile(tmpdir = data_dir, fileext = ".rds")
  saveRDS(result, temporary)
  if (!file.copy(temporary, cache, overwrite = TRUE)) stop("Could not save derived cache.")
  unlink(temporary)
  result
}
