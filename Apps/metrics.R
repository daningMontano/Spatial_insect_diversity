# Pure functions shared by the application and its regression checks.
known_taxa <- function(x) length(unique(x[!is.na(x) & nzchar(trimws(x))]))

unique_records <- function(x) {
  if (!"id_record" %in% names(x) || anyNA(x$id_record)) stop("Missing occurrence identifiers.")
  x[!duplicated(x$id_record), , drop = FALSE]
}

eligible_grid <- function(x) {
  x[!is.na(x$Ttl_rcr) & !is.na(x$Smplg_c) &
      x$Ttl_rcr >= 100 & x$Smplg_c >= 0.7, , drop = FALSE]
}

distribution_summary <- function(df, field) {
  group <- as.character(df[[field]])
  group[is.na(group) | trimws(group) == ""] <- "No data"
  if (field == "institutionCode") group[group == "Uniwersytet Jagiello?ski"] <- "Uniwersytet Jagielloński"
  grouped <- data.table::data.table(Group = group, scientificName = df$scientificName)
  totals <- grouped[, list(Total_records = .N, Total_species = known_taxa(scientificName)), by = Group]
  levels <- totals$Group
  n <- totals$Total_records
  richness <- totals$Total_species
  total_species <- known_taxa(df$scientificName)
  result <- data.frame(Group = levels, Total_records = n,
    Percentage_records = if (nrow(df)) 100 * n / nrow(df) else numeric(),
    Total_species = richness,
    Percentage_species_of_total = if (total_species) 100 * richness / total_species else rep(0, length(levels)))
  result[order(-result$Total_records, result$Group), , drop = FALSE]
}

default_filters <- function() setNames(as.list(rep("All", 6)),
  c("order", "family", "genus", "scientificName", "snap", "region"))

build_filter_index <- function(df, region_links, snap_links) {
  fields <- c("order", "family", "genus", "scientificName")
  lookup <- lapply(df[fields], function(values) {
    keep <- !is.na(values) & nzchar(trimws(values))
    split(which(keep), values[keep])
  })
  lookup$region <- lapply(split(region_links$id_record, region_links$veget),
    function(ids) unique(match(ids, df$id_record)))
  lookup$snap <- lapply(split(snap_links$id_record, snap_links$snap_name),
    function(ids) unique(match(ids, df$id_record)))
  lookup$snap[["SNAP"]] <- which(df$snap_in_out == "SNAP")
  lookup$snap[["Outside SNAP"]] <- which(df$snap_in_out == "Outside SNAP")
  lookup <- lapply(lookup, function(field) lapply(field, function(rows) sort(unique(rows[!is.na(rows)]))))
  list(lookup = lookup, all_rows = seq_len(nrow(df)), taxonomy = df[fields])
}

index_rows <- function(index, selections, exclude = character()) {
  fields <- setdiff(names(index$lookup), exclude)
  active <- fields[vapply(fields, function(field) {
    value <- selections[[field]]
    !is.null(value) && !identical(value, "All")
  }, logical(1))]
  if (!length(active)) return(index$all_rows)
  sets <- lapply(active, function(field) {
    value <- index$lookup[[field]][[selections[[field]]]]
    if (is.null(value)) integer() else value
  })
  sets <- sets[order(lengths(sets))]
  if (!length(sets[[1]])) return(integer())
  sort(Reduce(intersect, sets))
}

facet_options <- function(index, selections) {
  result <- lapply(names(index$lookup), function(field) {
    rows <- index_rows(index, selections, exclude = field)
    if (length(rows) == length(index$all_rows)) {
      values <- sort(names(index$lookup[[field]]))
    } else if (field %in% names(index$taxonomy)) {
      values <- index$taxonomy[[field]][rows]
      values <- sort(unique(values[!is.na(values) & nzchar(trimws(values))]))
    } else {
      candidates <- index$lookup[[field]]
      included <- rep(FALSE, length(index$all_rows))
      included[rows] <- TRUE
      values <- sort(names(candidates)[vapply(candidates, function(ids) any(included[ids]), logical(1))])
    }
    c("All", values)
  })
  setNames(result, names(index$lookup))
}

display_distribution <- function(df) {
  for (field in intersect(c("Percentage_records", "Percentage_species_of_total"), names(df))) {
    df[[field]] <- round(df[[field]], 2)
  }
  df
}

filter_occurrences <- function(df, selections, region_links, snap_links) {
  for (field in c("order", "family", "genus", "scientificName")) {
    value <- selections[[field]]
    if (!is.null(value) && value != "All") df <- df[!is.na(df[[field]]) & df[[field]] == value, , drop = FALSE]
  }
  value <- selections$snap
  if (!is.null(value) && value != "All") {
    if (value %in% c("SNAP", "Outside SNAP")) {
      df <- df[df$snap_in_out == value, , drop = FALSE]
    } else {
      df <- df[df$id_record %in% snap_links$id_record[snap_links$snap_name == value], , drop = FALSE]
    }
  }
  value <- selections$region
  if (!is.null(value) && value != "All") {
    df <- df[df$id_record %in% region_links$id_record[region_links$veget == value], , drop = FALSE]
  }
  unique_records(df)
}
