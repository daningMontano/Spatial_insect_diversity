# Changelog

## 2026-10-23

### Consistency with the notebooks

- Count national occurrences once per `id_record` and calculate SNAP membership
  without row-multiplying spatial joins.
- Retain the report's regional memberships and nearest-region assignments in a
  separate table, keeping overlapping memberships out of national totals.
- Display known taxonomic counts separately from missing identifications.
- Add distribution summaries by genus and species, alongside order, family,
  database, institution, region and SNAP. Show percentages to two decimals while
  retaining full analytical precision.

### Interface and maps

- Apply occurrence filters only with **Run**. Update dependent selector options
  immediately, preserving pending choices until applied.
- Use English labels and instructions throughout the active interface.
- Add the three supplied institutional logos in a responsive horizontal header,
  preserving their original files and aspect ratios.
- Remove the article-results section and move the nine final raster layers into
  the interactive map, with multiple selection, opacity and explicit legends.
- Use OpenStreetMap background tiles without an API key and retain attribution.
- Improve record-count contrast with yellow-to-dark-red quantile classes.
- Keep complete/selected sampling grids and model rasters at their original
  scientific scope when occurrence filters change.

### Performance and reproducibility

- Defer grid/raster loading and map transfers until those layers are requested.
- Reuse row indexes, grouped summaries and cached raster projections. Process
  database pagination on the server and group coincident map coordinates without
  discarding occurrence records.
- Synchronize canonical inputs with a fast metadata check and explicit full-hash
  verification mode; invalidate derived data when input/engine signatures change.
- Reproject categorical map copies with nearest neighbour and continuous copies
  with bilinear interpolation. Use terra's bundled PROJ database within R.
- Include validation, local timing and launch scripts plus execution guidance.
- Exclude local package libraries, runtime data copies, caches and screenshots
  from Git. Scientific notebooks and canonical source results are unchanged.

### Validation scope

Regression checks cover the stored national, SNAP and regional summaries; applied
versus pending filters; menu choices; decimal display; selected analysis cells;
and all nine raster layers, including CRS and preservation of categorical codes.
Browser checks confirmed stable selections, button-driven updates, map overlays,
the institutional header, and genus/species summaries. These checks establish
consistency with stored results; they do not independently validate the scientific
models or replace a new notebook execution.
