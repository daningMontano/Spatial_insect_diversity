
library(shiny)
library(leaflet)
library(ggplot2)
library(dplyr)
library(DT)
library(sf)
library(plotly)

select <- dplyr::select

source("metrics.R", local = TRUE)
source("prepare_data.R", local = TRUE)
source("load_data.R", local = TRUE)
sync_notebook_assets()
app_data_dir <- "data"
bundle <- load_notebook_data(app_data_dir)
records_sf <- bundle$records_sf
records_df <- st_drop_geometry(records_sf)
region_links <- bundle$region_links
snap_links <- bundle$snap_links
source("map_layers.R", local = TRUE)
load_grid <- make_grid_loader(app_data_dir)
load_raster <- make_raster_loader(app_data_dir)
delayedAssign("grid_shp", load_grid())
delayedAssign("grid_filtered", eligible_grid(grid_shp))
delayedAssign("filter_index", build_filter_index(records_df, region_links, snap_links))
# Shared bounded cache: identical applied selections can reuse their grouped summaries.
summary_cache <- cachem::cache_mem(max_size = 32 * 1024^2, max_age = 3600)
filter_inputs <- c(order = "order_filter", family = "family_filter", genus = "genus_filter",
  scientificName = "species_filter", snap = "snap_filter", region = "region_filter")

# Define UI
ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "flatly"),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "branding.css")),
  tags$header(class = "institutional-header", `aria-label` = "Institutional partners",
    div(class = "institutional-logos",
      div(class = "institutional-logo",
        tags$img(src = "logos/biogeo-e2.jpg", alt = "BioGeoE2 logo", width = 664, height = 571)),
      div(class = "institutional-logo",
        tags$img(src = "logos/integrative-biology.jpg", alt = "Integrative Biology Laboratory logo", width = 1240, height = 1080)),
      div(class = "institutional-logo institutional-logo-wide",
        tags$img(src = "logos/pachamama.png", alt = "Fundación Pachamama logo", width = 1358, height = 347))
    )
  ),
  titlePanel("Spatial Patterns of Insect Diversity in Ecuador"),
  sidebarLayout(
    sidebarPanel(
      h4("Filters"),
      selectizeInput("order_filter", "Order:", choices = "All", selected = "All"),
      selectizeInput("family_filter", "Family:", choices = "All", selected = "All"),
      selectizeInput("genus_filter", "Genus:", choices = "All", selected = "All"),
      selectizeInput("species_filter", "Species:", choices = "All", selected = "All"),
      selectizeInput("snap_filter", "SNAP / Protected Area:", choices = "All", selected = "All"),
      selectizeInput("region_filter", "Natural Region:", choices = "All", selected = "All"),
      actionButton("run_filters", "Run", class = "btn-primary"),
      actionButton("reset_filters", "Reset selection"),
      textOutput("filter_status"),
      hr(),
      h4("Map Settings"),
      checkboxInput("show_grid", "Show sampling grid", TRUE),
      checkboxInput("show_occurrences", "Show occurrences (grouped by coordinate)", FALSE),
      selectInput("grid_scope", "Sampling grid:", choices = c("Complete sampling grid" = "all", "Analysis cells: records >=100; coverage >=0.7" = "eligible")),
      selectInput("grid_var", "Grid metric:",
        choices = c(
          "Total Records" = "Ttl_rcr",
          "Total Species" = "Totl_sp",
          "Sampling Coverage" = "Smplg_c"
        ),
        selected = "Ttl_rcr"
      ),
      selectizeInput("map_rasters", "Raster layers:", choices = setNames(raster_catalog$id, raster_catalog$label), multiple = TRUE),
      sliderInput("raster_opacity", "Raster opacity:", min = 0.1, max = 1, value = 0.75, step = 0.05),
      selectInput("raster_legend", "Raster legend:", choices = character()),
      textOutput("raster_status"),
      hr(),
      p("Select filters, then press Run to update statistics and occurrences. Map visibility and raster choices update immediately. Raster and grid values retain the original analysis scope."),
      p("Known families/orders exclude missing names. Regional memberships can overlap; regional counts are not an additive national total.")
    ),
    mainPanel(
      tabsetPanel(id = "main_tabs",
        tabPanel(
          "Overview & Statistics", value = "overview",
          p("National totals count unique occurrence identifiers within Ecuador. Regional plots preserve the regional assignments used in the report."),
          textOutput("missing_taxa"),
          selectInput("summary_group", "Distribution summary", choices = c("Order" = "order", "Database" = "database_name", "Institution" = "institutionCode", "Natural region" = "veget", "SNAP" = "snap_in_out", "Family" = "family", "Genus" = "genus", "Species" = "scientificName")),
          DTOutput("distribution_summary"),
          fluidRow(
            style = "margin-top: 20px;",
            column(2, wellPanel(h3(textOutput("total_records")), p("Total Records"))),
            column(2, wellPanel(h3(textOutput("total_species")), p("Unique Species"))),
            column(2, wellPanel(h3(textOutput("total_genera")), p("Known Genera"))),
            column(2, wellPanel(h3(textOutput("total_families")), p("Known Families"))),
            column(2, wellPanel(h3(textOutput("total_orders")), p("Known Orders")))
          ),
          fluidRow(
            column(6, plotlyOutput("snap_records_plot", height = "350px")),
            column(6, plotlyOutput("snap_species_plot", height = "350px"))
          ),
          fluidRow(
            column(6, plotlyOutput("region_records_plot", height = "350px")),
            column(6, plotlyOutput("region_species_plot", height = "350px"))
          ),
          fluidRow(
            column(6, plotlyOutput("family_records_plot", height = "350px")),
            column(6, plotlyOutput("family_species_plot", height = "350px"))
          )
        ),
        tabPanel(
          "Interactive Map", value = "map",
          p("Choose raster layers in the sidebar. Sampling grids and model surfaces retain the complete analysis scope. Occurrence filters apply only after Run; points at identical coordinates are grouped without discarding records."),
          leafletOutput("map", height = "750px")
        ),
        tabPanel(
          "Records Database", value = "database",
          p("You can search and filter the database below. Use the download button to export the entire filtered dataset with all metadata."),
          div(
            style = "margin-bottom: 15px;",
            downloadButton("download_filtered", "Download Filtered Dataset (CSV)", class = "btn-success")
          ),
          DTOutput("table")
        )
      )
    )
  )
)

# Define Server
server <- function(input, output, session) {
  # Helper to configure plotly download button high resolution
  plotly_high_res <- function(p, filename = "plot") {
    ggplotly(p) %>%
      config(
        toImageButtonOptions = list(
          format = "png",
          filename = filename,
          width = 1600,
          height = 1000,
          scale = 3 # Increases resolution/DPI significantly
        )
      )
  }

  pending_filters <- reactive({
    setNames(lapply(filter_inputs, function(id) {
      value <- input[[id]]
      if (is.null(value) || !length(value) || !nzchar(value)) "All" else value
    }), names(filter_inputs))
  })
  applied_filters <- reactiveVal(default_filters())
  observeEvent(input$run_filters, { applied_filters(pending_filters()) }, ignoreInit = TRUE)
  observeEvent(input$reset_filters, {
    for (id in filter_inputs) updateSelectizeInput(session, id, selected = "All")
  }, ignoreInit = TRUE)
  available_choices <- reactive(facet_options(filter_index, pending_filters()))
  menu_choices <- debounce(available_choices, 120)
  last_menus <- new.env(parent = emptyenv())
  observeEvent(menu_choices(), {
    choices <- menu_choices()
    pending <- isolate(pending_filters())
    for (field in names(filter_inputs)) {
      values <- choices[[field]]
      current <- pending[[field]]
      # Keep an incompatible selection visible until the user clears it, instead of silently
      # changing the requested query. Other menus still expose only compatible values.
      if (!current %in% values) values <- c(values, setNames(current, paste0(current, " (no matches)")))
      # The user's own selector already has its new value. Reinitializing it on
      # every choice emits transient empty values from Selectize and resets queries.
      if (!identical(last_menus[[field]], values)) {
        freezeReactiveValue(input, filter_inputs[[field]])
        updateSelectizeInput(session, filter_inputs[[field]], choices = values, selected = current, server = TRUE)
        last_menus[[field]] <- values
      }
    }
  })
  output$filter_status <- renderText({
    if (!identical(pending_filters(), applied_filters())) "Pending changes: press Run to apply."
    else paste("Applied selection:", format(length(applied_rows()), big.mark = ","), "records.")
  })
  applied_rows <- reactive(index_rows(filter_index, applied_filters()))
  filtered_data <- reactive(records_df[applied_rows(), , drop = FALSE])
  filtered_regions <- reactive({
    links <- region_links
    selected <- applied_filters()$region
    if (selected != "All") links <- links[links$veget == selected, , drop = FALSE]
    links %>% inner_join(filtered_data() %>% select(-veget), by = "id_record")
  })
  get_summary <- function(field) {
    key <- digest::digest(list(applied_filters(), field))
    result <- summary_cache$get(key)
    if (inherits(result, "key_missing")) {
      result <- distribution_summary(if (field == "veget") filtered_regions() else filtered_data(), field)
      summary_cache$set(key, result)
    }
    result
  }
  snap_summary <- reactive(get_summary("snap_in_out"))
  region_summary <- reactive(get_summary("veget"))
  family_summary <- reactive(get_summary("family"))

  output$missing_taxa <- renderText({
    df <- filtered_data()
    paste("Records without family:", sum(is.na(df$family) | trimws(df$family) == ""),
      "| without order:", sum(is.na(df$order) | trimws(df$order) == ""))
  })
  output$distribution_summary <- renderDT({
    req(input$summary_group)
    result <- switch(input$summary_group,
      snap_in_out = snap_summary(), veget = region_summary(), family = family_summary(),
      get_summary(input$summary_group))
    datatable(display_distribution(result), rownames = FALSE,
      options = list(scrollX = TRUE, pageLength = 10)) %>%
      formatRound(c("Percentage_records", "Percentage_species_of_total"), digits = 2)
  }, server = TRUE)
  # Summary Metrics
  output$total_records <- renderText({
    nrow(filtered_data())
  })
  output$total_species <- renderText({
    known_taxa(filtered_data()$scientificName)
  })
  output$total_genera <- renderText({ known_taxa(filtered_data()$genus) })
  output$total_families <- renderText({
    known_taxa(filtered_data()$family)
  })
  output$total_orders <- renderText({
    known_taxa(filtered_data()$order)
  })

  # Interactive Plots (Using Plotly with High-Res Download)

  # SNAP - Records count plot
  output$snap_records_plot <- renderPlotly({
    df <- snap_summary()
    if (nrow(df) == 0) return(NULL)
    df <- df %>% transmute(snap_in_out = Group, n = Total_records)
    p <- df %>%
      ggplot(aes(x = snap_in_out, y = n, fill = snap_in_out)) +
      geom_bar(stat = "identity", width = 0.6) +
      theme_minimal() +
      scale_fill_manual(values = c("SNAP" = "#1B4D3E", "Outside SNAP" = "#e74c3c")) +
      labs(title = "Records inside/outside SNAP", x = "", y = "Records Count", fill = "SNAP Status")
    plotly_high_res(p, "snap_records")
  })

  # SNAP - Species richness plot
  output$snap_species_plot <- renderPlotly({
    df <- snap_summary()
    if (nrow(df) == 0) return(NULL)
    df <- df %>% transmute(snap_in_out = Group, n = Total_species)
    p <- df %>%
      ggplot(aes(x = snap_in_out, y = n, fill = snap_in_out)) +
      geom_bar(stat = "identity", width = 0.6) +
      theme_minimal() +
      scale_fill_manual(values = c("SNAP" = "#1B4D3E", "Outside SNAP" = "#e74c3c")) +
      labs(title = "Unique Species inside/outside SNAP", x = "", y = "Species Count", fill = "SNAP Status")
    plotly_high_res(p, "snap_species_richness")
  })

  # Region - Records count plot
  output$region_records_plot <- renderPlotly({
    df <- region_summary()
    if (nrow(df) == 0) return(NULL)
    df <- df %>% transmute(veget = Group, n = Total_records)
    p <- df %>%
      ggplot(aes(x = reorder(veget, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Records by Natural Region", x = "", y = "Records Count")
    plotly_high_res(p, "region_records")
  })

  # Region - Species count plot
  output$region_species_plot <- renderPlotly({
    df <- region_summary()
    if (nrow(df) == 0) return(NULL)
    df <- df %>% transmute(veget = Group, n = Total_species)
    p <- df %>%
      ggplot(aes(x = reorder(veget, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Species Richness by Natural Region", x = "", y = "Species Count")
    plotly_high_res(p, "region_species_richness")
  })

  # Family - Records count plot (Top 15)
  output$family_records_plot <- renderPlotly({
    df <- family_summary()
    if (nrow(df) == 0) return(NULL)
    df <- df %>% transmute(family = Group, n = Total_records)
    p <- df %>%
      slice_max(n, n = 15, with_ties = FALSE) %>%
      ggplot(aes(x = reorder(family, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Top 15 Families by Record Count", x = "Family", y = "Count")
    plotly_high_res(p, "family_records")
  })

  # Family - Species count plot (Top 15)
  output$family_species_plot <- renderPlotly({
    df <- family_summary()
    if (nrow(df) == 0) return(NULL)
    df <- df %>% transmute(family = Group, n = Total_species)
    p <- df %>%
      slice_max(n, n = 15, with_ties = FALSE) %>%
      ggplot(aes(x = reorder(family, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Top 15 Families by Species Richness", x = "Family", y = "Unique Species Count")
    plotly_high_res(p, "family_species_richness")
  })

  output$map <- renderLeaflet({
    leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
      addTiles(urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        options = tileOptions(maxZoom = 19), group = "OpenStreetMap") %>%
      setView(lng = -78.5, lat = -1.5, zoom = 7)
  })
  map_active <- reactive(identical(input$main_tabs, "map"))
  selected_grid <- reactive({
    if (identical(input$grid_scope, "eligible")) grid_filtered else grid_shp
  })
  selected_rasters <- reactive({
    selected <- input$map_rasters
    if (is.null(selected)) character() else intersect(selected, raster_catalog$id)
  })
  observeEvent(selected_rasters(), {
    selected <- selected_rasters()
    current <- isolate(input$raster_legend)
    if (!length(current) || !current %in% selected) current <- if (length(selected)) tail(selected, 1) else character()
    labels <- raster_catalog$label[match(selected, raster_catalog$id)]
    updateSelectInput(session, "raster_legend", choices = setNames(selected, labels), selected = current)
  }, ignoreNULL = FALSE)
  output$raster_status <- renderText({
    if (!length(selected_rasters())) "No raster selected."
    else if (!map_active()) "Selected rasters will load when you open the map."
    else "Raster values retain the original model scope. The last selected layer is drawn on top."
  })
  observe({
    req(map_active(), input$grid_var)
    proxy <- leafletProxy("map") %>% clearGroup("Sampling Grid (10km)") %>% removeControl("grid_legend")
    if (!isTRUE(input$show_grid)) return(invisible(NULL))
    grid <- selected_grid()
    grid <- grid[!is.na(grid[[input$grid_var]]), ]
    if (!nrow(grid)) return(invisible(NULL))
    style <- grid_style(grid, input$grid_var)
    proxy %>% addPolygons(data = grid, weight = 0.3, color = "#555555",
      fillColor = style$pal(grid[[input$grid_var]]), fillOpacity = 0.65,
      group = "Sampling Grid (10km)",
      popup = paste0("<b>Cell:</b> ", grid$id, "<br><b>", style$label, ":</b> ", grid[[input$grid_var]])) %>%
      addLegend(pal = style$pal, values = grid[[input$grid_var]], title = style$label,
        position = "bottomleft", layerId = "grid_legend")
  })
  grouped_points <- reactive(map_point_groups(filtered_data()))
  observe({
    req(map_active())
    proxy <- leafletProxy("map") %>% clearGroup("Occurrences")
    if (!isTRUE(input$show_occurrences)) return(invisible(NULL))
    df <- grouped_points()
    if (!nrow(df)) return(invisible(NULL))
    proxy %>% addCircleMarkers(data = df, lng = ~decimalLongitude, lat = ~decimalLatitude,
      popup = ~popup, radius = 4, color = "#c0392b", fillOpacity = 0.75, stroke = FALSE,
      group = "Occurrences", clusterOptions = markerClusterOptions(chunkedLoading = TRUE))
  })
  observe({
    req(map_active())
    proxy <- leafletProxy("map") %>% clearGroup("Model rasters")
    selected <- selected_rasters()
    for (id in selected) {
      layer <- tryCatch(load_raster(id), error = function(e) {
        showNotification(conditionMessage(e), type = "error", duration = NULL)
        NULL
      })
      if (is.null(layer)) next
      proxy <- proxy %>% addRasterImage(layer$raster, colors = layer$pal,
        opacity = if (is.null(input$raster_opacity)) 0.75 else input$raster_opacity,
        project = FALSE, group = "Model rasters", layerId = paste0("raster_", id))
    }
  })
  # Changing the legend must not resend already-rendered raster images.
  observe({
    req(map_active())
    proxy <- leafletProxy("map") %>% removeControl("raster_legend")
    selected <- selected_rasters()
    legend <- input$raster_legend
    if (length(legend) && legend %in% selected) {
      layer <- tryCatch(load_raster(legend), error = function(e) NULL)
      if (is.null(layer)) return(invisible(NULL))
      if (layer$categorical) {
        codes <- if (grepl("^priority_", legend)) 1:5 else layer$classes
        labels <- if (grepl("^priority_", legend)) paste(codes, c("Very low", "Low", "Moderate", "High", "Very high")) else paste("Cluster", codes)
        proxy %>% addLegend(colors = layer$pal(codes), labels = labels, title = layer$label,
          position = "bottomright", layerId = "raster_legend")
      } else proxy %>% addLegend(pal = layer$pal, values = layer$range, title = layer$label,
        position = "bottomright", layerId = "raster_legend")
    }
  })

  # Data Table (Preview and Interactive Search)
  output$table <- renderDT({
    datatable(
      filtered_data(),
      options = list(
        pageLength = 10,
        scrollX = TRUE
      ),
      rownames = FALSE
    )
  }, server = TRUE)

  # CSV Download Handler (Exports full filtered dataset with all metadata)
  output$download_filtered <- downloadHandler(
    filename = function() {
      paste("filtered_insect_records-", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )
}

# Run app
shinyApp(ui = ui, server = server)
