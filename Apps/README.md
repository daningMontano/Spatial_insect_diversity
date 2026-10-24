# Shiny: insect spatial patterns

From the project root on the current computer:

```powershell
& 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' 'CODIGOS/Apps/run_app.R'
```

In a configured R environment, from Apps:

```r
shiny::runApp(".")
```

Required runtime packages: shiny, leaflet, ggplot2, dplyr, DT, sf, plotly, bslib,
terra, data.table, cachem, digest and their dependencies. The launcher discovers
`.test-library/` and the local user libraries; the test library is excluded from
deployment. No deployment is performed by these scripts.

The validation script also requires openxlsx to read the versioned reference
workbook in `Results/Reports/excels/`. The original filtered-grid export is checked
when present; otherwise the threshold and 162 selected cells are verified using
the versioned complete grid.

## Filter workflow

The six selectors are pending choices. Each menu is updated according to the
other five choices, including region and protected area. All menus use server-side
selectize, and updates are debounced by 120 ms. An incompatible selected value is
kept visible with a no-matches label rather than silently changing the query.
`Reset selection` clears pending choices; it does not apply them.

`Run` copies the pending choices to the applied state. Counts, graphs, tables,
CSV downloads and occurrence markers depend only on that applied state. Initial
results show all national occurrences. Re-running an identical selection does not
invalidate its results. The pending/applied status is shown beside the button.

Map visibility, grid metric, raster selection, opacity and legend are display
settings and update immediately; they do not refit models or change analyses.

## Map

The background uses the public HTTPS OpenStreetMap Standard tiles without an API
key, with visible attribution and browser caching. Internet access is needed for
background tiles. No bulk downloading or tile prefetching is implemented.
Usage policy: https://operations.osmfoundation.org/policies/tiles/

The sidebar supports simultaneous selection of nine layers:

- Alpha GAM predicted richness.
- NMDS1 and NMDS2.
- Beta-diversity clusters.
- Endemism consensus index.
- Occurrence kernel density.
- Three knowledge-importance surfaces (alpha, endemism and integrated).

The last selected raster is drawn on top. The legend selector identifies which
selected surface is being described. Opacity applies to selected raster layers.
The categorical legends preserve class codes; knowledge importance uses classes
1-5. Source rasters remain unchanged. Display copies are projected to Web Mercator
using nearest neighbour for categories and bilinear interpolation for continuous
values. CRS, valid values and class preservation are checked before display.

Total records uses seven quantile classes (fewer where repeated breaks require
it), with a yellow-to-dark-red palette. Legend ranges remain in original record
counts; only the display classification changes. NoData is transparent.

The map and its overlays load when the map tab is opened. Occurrences are off by
default to avoid transmitting all points unnecessarily. Activating them groups
identical coordinates into markers whose popups retain record and species counts;
no occurrence is removed from statistics, tables or exports.

## Scientific definitions retained

National occurrences follow Report cells 4 and 10, with one row per id_record.
SNAP follows the boolean within test in cell 21. Regional memberships retain the
multiple assignments and nearest-region fallback from cell 18; regional counts
are not additive national totals. Known taxa omit missing/blank names.

The complete sampling extent contains 117,233 records. National totals contain
106,651 occurrences and 8,626 species. SNAP: 18,917 inside and 87,734 outside.
There are 316 known families and 21 known orders. Analysis grid selection remains
at least 100 records and coverage at least 0.7 (162 cells in the current snapshot).

The article-results section has been removed. Its former module and exports are
not loaded or synchronized by the active app; unused assets are excluded from
future deployment. The original notebooks and results are preserved. Rasters and
grid values retain the original analysis scope when occurrence filters change.
Percentage display is rounded to two decimals without rounding analytical values.

## Startup and processing optimizations

- Synchronization checks source/destination size and modification time. Full hashes
  are recalculated when metadata changes or when verify=TRUE is requested.
- Dataset fingerprint hashes are reused when input metadata is unchanged. The
  existing spatial cache still invalidates on input hashes, processing version,
  sf/spatial-engine version and s2 settings.
- The app does not parse notebooks, figures or workbooks at startup.
- Shared row indexes support pending menu queries and applied occurrence filters.
- Grouped summaries use data.table and a shared cache bounded to 32 MiB/one hour.
- The transformed sampling grid and raster projections have disk and process
  caches. Raster reads/projection and PNG encoding are deferred until selection.
- Map changes use leafletProxy; changing the legend does not resend raster images.
- Empty grid cells are not transmitted as transparent polygons. Occurrence markers
  group identical coordinates; marker clustering uses chunked loading.
- The database table is paginated and processed on the server.

Windows may inherit an incompatible PROJ database from PostgreSQL or QGIS. The
raster loader sets the current R process to terra's bundled PROJ database. It does
not edit system variables or other applications.

## Verification and timing

From Apps, with the launcher libraries configured:

```r
.libPaths(c(normalizePath(".test-library", winslash = "/"),
  "C:/Users/Daning/AppData/Local/R/win-library/4.6", .libPaths()))
source("validate_app.R")
source("benchmark_app.R")
```

`validation_results.txt` records the current regression run. Checks cover source
hashes, original national/SNAP/regional counts, indexed filtering, pending versus
applied state, dependent menus, decimal display, palette contrast, lazy maps,
nine raster selections, CRS, class preservation and raster cache reuse.
Institution numerical signatures are checked against the original workbook;
several historical institution labels already contain replacement characters.

`performance_results.csv` records local elapsed times, including first lazy loads
and warm cache access. Timings are not a browser/network benchmark or a guarantee
for shinyapps.io. To force a full source integrity audit, run:

```r
source("prepare_data.R")
source("load_data.R")
sync_notebook_assets(verify = TRUE)
load_notebook_data(verify = TRUE)
```

Caches use size/mtime as the fast change detector. The explicit verify mode is
required to detect a content change that deliberately preserves both metadata
fields. Regression constants must be reviewed when a new scientific snapshot is
accepted. Tests establish consistency with stored results, not scientific model
validity or a complete audit of the notebooks.

## Institutional header and interface language

All app controls and sections use English, including Run and Reset selection.
The institutional header contains the three supplied, unmodified logo files in
`www/logos/`, served locally with no external image dependency. `www/branding.css`
keeps them in one horizontal row, preserves aspect ratios and scales the row for
narrow screens. Text embedded in the original institutional logos is preserved.
