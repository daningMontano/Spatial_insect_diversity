# Synchronize only runtime inputs and final map rasters; retired article outputs are not parsed.
sync_notebook_assets <- function(project_dir = "..", destination = "data", verify = FALSE) {
  if (!file.exists(file.path(project_dir, "1_Sampling_coverage.ipynb"))) return(invisible(FALSE))
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  layers <- c("ecuador_limits", "ron_2011_no_UTM", "snap")
  sources <- c("Data/Records/insects_records_clean.csv",
    unlist(lapply(layers, function(name) paste0("Data/shp/", name, c(".shp", ".shx", ".dbf", ".prj")))),
    paste0("Results/shp/grid_10km_sampling", c(".shp", ".shx", ".dbf", ".prj")),
    "Results/GIE/Endemism_consensus.tiff", "Results/raster/GAM_prediction_alpha.tif",
    "Results/raster/nmds_result.tiff", "Results/raster/cluster_raster_result.tiff",
    "Results/raster/records_kernel_density.tiff",
    "Results/raster/alpha_diversity/alpha_conservation_all_clusters_likert5.tif",
    "Results/raster/endemism/endemism_conservation_all_clusters_likert5.tif",
    "Results/raster/alpha_endemism_records/alpha_endemism_records_all_clusters_likert5.tif")
  cpg <- paste0("Data/shp/", layers, ".cpg")
  sources <- c(sources, cpg[file.exists(file.path(project_dir, cpg))])
  src <- file.path(project_dir, sources)
  dst <- file.path(destination, basename(sources))
  if (any(!file.exists(src))) stop("Missing source assets: ", paste(sources[!file.exists(src)], collapse = ", "))
  metadata <- function(paths) {
    info <- file.info(paths)
    data.frame(path = paths, size = info$size, mtime = as.numeric(info$mtime), row.names = NULL)
  }
  cache <- file.path(destination, "asset_sync_state.rds")
  manifest_path <- file.path(destination, "notebook_assets_manifest.csv")
  state <- list(version = 2L, source = metadata(src), destination = metadata(dst))
  previous <- if (file.exists(cache)) tryCatch(readRDS(cache), error = function(e) NULL) else NULL
  # Normal startup checks size and mtime; verify=TRUE explicitly performs a full integrity audit.
  if (!verify && identical(previous, state) && file.exists(manifest_path)) return(invisible(FALSE))
  hashes <- unname(tools::md5sum(src))
  destination_hashes <- unname(tools::md5sum(dst))
  changed <- is.na(destination_hashes) | destination_hashes != hashes
  for (i in which(changed)) {
    if (!file.copy(src[i], dst[i], overwrite = TRUE)) stop("Could not synchronize: ", sources[i])
  }
  if (any(unname(tools::md5sum(dst)) != hashes)) stop("Asset copy verification failed.")
  write.csv(data.frame(source = sources, destination = basename(sources), md5 = hashes), manifest_path, row.names = FALSE)
  state$destination <- metadata(dst)
  saveRDS(state, cache)
  invisible(TRUE)
}
