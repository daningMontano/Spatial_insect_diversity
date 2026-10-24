# Browser verification

Local app tested at http://127.0.0.1:3877/ on 2026-10-23.

- Only Overview & Statistics, Interactive Map and Records Database tabs are present.
- Initial national total: 106651; the initial table shows percentages such as 34.46 and 42.48.
- Selecting Coleoptera leaves the national total at 106651 with a pending-changes notice.
- The selection remains Coleoptera after dependent menus update.
- Pressing Correr changes the applied total to 21540.
- OpenStreetMap background tiles load with visible attribution and without a key prompt.
- The integrated knowledge-importance raster renders over Ecuador; its sidebar selection
  is priority_integrated, with legend codes 1-5 and low-to-high class labels.
- Preview saved as map_preview.jpg. No production deployment was performed.

A client-side selector-reset problem found during this check was corrected by
freezing dependent inputs while updating choices and avoiding reinitialization of
selectors whose option lists have not changed.

## Institutional header update

The current interface uses Run and Reset selection, with all surrounding instructions
in English. Three original logo files are bundled under www/logos. Their SHA-256
hashes match the supplied files. Browser verification confirmed all images loaded
in a single horizontal row with object-fit: contain at a narrow viewport. Screenshot:
branding_preview.jpg. Original text embedded in institutional marks is preserved.
