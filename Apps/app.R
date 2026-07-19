library(shiny)
library(leaflet)
library(ggplot2)
library(dplyr)
library(DT)
library(sf)
library(plotly)

select <- dplyr::select

# -------------------------------------------------------------
# Self-Containment / Caching (data/)
# -------------------------------------------------------------
app_data_dir <- "data"
preprocessed_path <- file.path(app_data_dir, "insects_ecuador_preprocessed.rds")
grid_dest_shp <- file.path(app_data_dir, "grid_10km_sampling.shp")
flag_file <- file.path(app_data_dir, "preprocessed_v3.flag")

# Force regeneration of RDS once to apply the new snap_name formatting & bounds filter
if (!file.exists(flag_file)) {
  if (file.exists(preprocessed_path)) {
    file.remove(preprocessed_path)
  }
  writeLines("v3", flag_file)
}

# If the preprocessed RDS doesn't exist locally, build it from the local data/ files
if (!file.exists(preprocessed_path)) {
  message("Building preprocessed dataset from local data/ files...")
  
  # 1. Load raw clean records
  records_csv <- read.csv(file.path(app_data_dir, "insects_records_clean.csv"), stringsAsFactors = FALSE)
  records_csv <- records_csv %>% 
    filter(!is.na(decimalLatitude) & !is.na(decimalLongitude)) %>%
    filter(decimalLatitude != 0 & decimalLongitude != 0)
  
  insects_pts <- st_as_sf(
    records_csv,
    coords = c("decimalLongitude", "decimalLatitude"),
    crs = 4326,
    remove = FALSE
  ) %>%
    st_make_valid()
  
  # Ecuador limits
  ecu <- st_read(file.path(app_data_dir, "ecuador_limits.shp"), quiet = TRUE)
  ecu <- st_make_valid(ecu)
  if (is.na(st_crs(ecu))) st_crs(ecu) <- 4326
  ecu <- st_transform(ecu, 4326)
  ecu_u <- st_union(ecu)
  
  in_ecu <- lengths(st_within(insects_pts, ecu_u)) > 0
  records_sf <- insects_pts[in_ecu, ]
  
  # Natural Regions
  nat_reg <- st_read(file.path(app_data_dir, "ron_2011_no_UTM.shp"), quiet = TRUE)
  nat_reg <- st_make_valid(nat_reg)
  if (is.na(st_crs(nat_reg))) st_crs(nat_reg) <- 4326
  nat_reg <- st_transform(nat_reg, 4326)
  
  records_sf <- st_join(records_sf, nat_reg, join = st_within, left = TRUE)
  na_reg <- is.na(records_sf$veget)
  if (any(na_reg)) {
    nearest_id <- st_nearest_feature(records_sf[na_reg, ], nat_reg)
    records_sf$veget[na_reg] <- nat_reg$veget[nearest_id]
  }
  
  # SNAP Protected Areas - Unite 'map' and 'nam' columns to build the SNAP name
  snap <- st_read(file.path(app_data_dir, "snap.shp"), quiet = TRUE)
  snap <- st_make_valid(snap)
  if (is.na(st_crs(snap))) st_crs(snap) <- 4326
  snap <- st_transform(snap, 4326)
  
  if (all(c("map", "nam") %in% names(snap))) {
    snap$snap_name <- paste(ifelse(is.na(snap$map), "", snap$map),
      ifelse(is.na(snap$nam), "", snap$nam),
      sep = " "
    )
    snap$snap_name <- trimws(snap$snap_name)
    snap$snap_name[snap$snap_name == ""] <- "Unnamed Protected Area"
  } else {
    snap_name_col <- names(snap)[grep("nom|name|des|cat", names(snap), ignore.case = TRUE)][1]
    if (is.na(snap_name_col)) snap_name_col <- names(snap)[1]
    snap$snap_name <- snap[[snap_name_col]]
  }
  
  snap_subset <- snap %>% select(snap_name)
  
  records_sf <- st_join(records_sf, snap_subset, join = st_within, left = TRUE)
  records_sf$snap_in_out <- ifelse(is.na(records_sf$snap_name), "Outside SNAP", "SNAP")
  records_sf$snap_name[is.na(records_sf$snap_name)] <- "Outside SNAP"
  
  saveRDS(records_sf, preprocessed_path)
  message("Preprocessed RDS saved locally.")
}

# Load the preprocessed data from local app data folder
records_sf <- readRDS(preprocessed_path)
records_df <- as.data.frame(records_sf) %>% select(-geometry)

# Load Map Layers from the local app data folder
grid_shp <- st_read(file.path(app_data_dir, "grid_10km_sampling.shp"), quiet = TRUE)
grid_shp <- st_transform(grid_shp, 4326)

# Set up dropdown filters
orders <- c("All", sort(unique(records_df$order)))
families <- c("All", sort(unique(records_df$family)))
genera <- c("All", sort(unique(records_df$genus)))
species_list <- c("All", sort(unique(records_df$scientificName)))
snaps <- c("All", "SNAP", "Outside SNAP", sort(unique(records_df$snap_name[records_df$snap_name != "Outside SNAP"])))
regions <- c("All", sort(unique(records_df$veget)))

# Define UI
ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "flatly"),
  titlePanel("Spatial Patterns of Insect Diversity in Ecuador"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Filters"),
      selectInput("order_filter", "Order:", choices = orders, selected = "All"),
      selectInput("family_filter", "Family:", choices = families, selected = "All"),
      selectInput("genus_filter", "Genus:", choices = genera, selected = "All"),
      selectInput("species_filter", "Species:", choices = species_list, selected = "All"),
      selectInput("snap_filter", "SNAP / Protected Area:", choices = snaps, selected = "All"),
      selectInput("region_filter", "Natural Region:", choices = regions, selected = "All"),
      hr(),
      h4("Map Settings"),
      selectInput("grid_var", "Grid Shapefile Variable:",
        choices = c(
          "Total Records" = "Ttl_rcr",
          "Total Species" = "Totl_sp",
          "Sampling Coverage" = "Smplg_c"
        ),
        selected = "Ttl_rcr"
      ),
      hr(),
      p("This application displays spatial insect patterns in Ecuador, integrating conservation rasters, SNAP registries, and natural regions.")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Overview & Statistics",
          fluidRow(
            style = "margin-top: 20px;",
            column(3, wellPanel(h3(textOutput("total_records")), p("Total Records"))),
            column(3, wellPanel(h3(textOutput("total_species")), p("Unique Species"))),
            column(3, wellPanel(h3(textOutput("total_families")), p("Unique Families"))),
            column(3, wellPanel(h3(textOutput("total_orders")), p("Unique Orders")))
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
          "Interactive Map",
          leafletOutput("map", height = "750px")
        ),
        tabPanel(
          "Records Database",
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
          scale = 3  # Increases resolution/DPI significantly
        )
      )
  }

  # Dynamically update filter dropdowns based on selections to improve usability
  observe({
    df <- records_df
    
    if (input$order_filter != "All") df <- df %>% filter(order == input$order_filter)
    if (input$family_filter != "All") df <- df %>% filter(family == input$family_filter)
    if (input$genus_filter != "All") df <- df %>% filter(genus == input$genus_filter)
    
    updateSelectInput(session, "family_filter", choices = c("All", sort(unique(df$family))), selected = input$family_filter)
    updateSelectInput(session, "genus_filter", choices = c("All", sort(unique(df$genus))), selected = input$genus_filter)
    updateSelectInput(session, "species_filter", choices = c("All", sort(unique(df$scientificName))), selected = input$species_filter)
  })
  
  # Reactive dataset based on filters
  filtered_data <- reactive({
    df <- records_df
    
    if (input$order_filter != "All") {
      df <- df %>% filter(order == input$order_filter)
    }
    if (input$family_filter != "All") {
      df <- df %>% filter(family == input$family_filter)
    }
    if (input$genus_filter != "All") {
      df <- df %>% filter(genus == input$genus_filter)
    }
    if (input$species_filter != "All") {
      df <- df %>% filter(scientificName == input$species_filter)
    }
    if (input$snap_filter != "All") {
      if (input$snap_filter == "SNAP") {
        df <- df %>% filter(snap_in_out == "SNAP")
      } else if (input$snap_filter == "Outside SNAP") {
        df <- df %>% filter(snap_in_out == "Outside SNAP")
      } else {
        df <- df %>% filter(snap_name == input$snap_filter)
      }
    }
    if (input$region_filter != "All") {
      df <- df %>% filter(veget == input$region_filter)
    }
    
    df
  })
  
  # Summary Metrics
  output$total_records <- renderText({ nrow(filtered_data()) })
  output$total_species <- renderText({ n_distinct(filtered_data()$scientificName) })
  output$total_families <- renderText({ n_distinct(filtered_data()$family) })
  output$total_orders <- renderText({ n_distinct(filtered_data()$order) })
  
  # Interactive Plots (Using Plotly with High-Res Download)
  
  # SNAP - Records count plot
  output$snap_records_plot <- renderPlotly({
    df <- filtered_data()
    if (nrow(df) == 0) return(NULL)
    
    p <- df %>% 
      count(snap_in_out) %>%
      ggplot(aes(x = snap_in_out, y = n, fill = snap_in_out)) +
      geom_bar(stat = "identity", width = 0.6) +
      theme_minimal() +
      scale_fill_manual(values = c("SNAP" = "#1B4D3E", "Outside SNAP" = "#e74c3c")) +
      labs(title = "Records inside/outside SNAP", x = "", y = "Records Count", fill = "SNAP Status")
    plotly_high_res(p, "snap_records")
  })
  
  # SNAP - Species richness plot
  output$snap_species_plot <- renderPlotly({
    df <- filtered_data()
    if (nrow(df) == 0) return(NULL)
    
    p <- df %>% 
      distinct(snap_in_out, scientificName) %>%
      count(snap_in_out) %>%
      ggplot(aes(x = snap_in_out, y = n, fill = snap_in_out)) +
      geom_bar(stat = "identity", width = 0.6) +
      theme_minimal() +
      scale_fill_manual(values = c("SNAP" = "#1B4D3E", "Outside SNAP" = "#e74c3c")) +
      labs(title = "Unique Species inside/outside SNAP", x = "", y = "Species Count", fill = "SNAP Status")
    plotly_high_res(p, "snap_species_richness")
  })
  
  # Region - Records count plot
  output$region_records_plot <- renderPlotly({
    df <- filtered_data()
    if (nrow(df) == 0) return(NULL)
    
    p <- df %>% 
      count(veget) %>%
      ggplot(aes(x = reorder(veget, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Records by Natural Region", x = "", y = "Records Count")
    plotly_high_res(p, "region_records")
  })
  
  # Region - Species count plot
  output$region_species_plot <- renderPlotly({
    df <- filtered_data()
    if (nrow(df) == 0) return(NULL)
    
    p <- df %>% 
      distinct(veget, scientificName) %>%
      count(veget) %>%
      ggplot(aes(x = reorder(veget, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Species Richness by Natural Region", x = "", y = "Species Count")
    plotly_high_res(p, "region_species_richness")
  })
  
  # Family - Records count plot (Top 15)
  output$family_records_plot <- renderPlotly({
    df <- filtered_data()
    if (nrow(df) == 0) return(NULL)
    
    p <- df %>%
      count(family) %>%
      top_n(15, wt = n) %>%
      ggplot(aes(x = reorder(family, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Top 15 Families by Record Count", x = "Family", y = "Count")
    plotly_high_res(p, "family_records")
  })
  
  # Family - Species count plot (Top 15)
  output$family_species_plot <- renderPlotly({
    df <- filtered_data()
    if (nrow(df) == 0) return(NULL)
    
    p <- df %>%
      distinct(family, scientificName) %>%
      count(family) %>%
      top_n(15, wt = n) %>%
      ggplot(aes(x = reorder(family, n), y = n)) +
      geom_bar(stat = "identity", fill = "#1B4D3E") +
      coord_flip() +
      theme_minimal() +
      labs(title = "Top 15 Families by Species Richness", x = "Family", y = "Unique Species Count")
    plotly_high_res(p, "family_species_richness")
  })
  
  # Base Map Initialization
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron, group = "CartoDB Positron") %>%
      addProviderTiles(providers$Esri.WorldImagery, group = "Satellite Imagery") %>%
      setView(lng = -78.5, lat = -1.5, zoom = 7) %>%
      hideGroup("Sampling Grid (10km)")
  })
  
  # Reactive palettes for grid (Uses Natural Jenks classification)
  grid_pal <- reactive({
    var_data <- grid_shp[[input$grid_var]]
    clean_data <- var_data[!is.na(var_data)]
    
    if (length(clean_data) == 0) {
      return(colorNumeric("Blues", domain = c(0, 1), na.color = "transparent"))
    }
    
    if (length(unique(clean_data)) > 1) {
      # Calculate Natural Jenks breaks
      breaks <- tryCatch(
        {
          classInt::classIntervals(clean_data, n = 5, style = "jenks")$brks
        },
        error = function(e) {
          pretty(clean_data, n = 5)
        }
      )
      breaks <- unique(breaks)
      if (length(breaks) < 2) {
        breaks <- c(min(clean_data), max(clean_data))
      }
      colorBin("Blues", domain = var_data, bins = breaks, na.color = "transparent")
    } else {
      colorNumeric("Blues", domain = var_data, na.color = "transparent")
    }
  })
  
  # Observe grid variable and active layers to update map overlays
  observe({
    pal <- grid_pal()
    var_name <- input$grid_var
    var_label <- switch(var_name,
      "Ttl_rcr" = "Total Records",
      "Totl_sp" = "Total Species",
      "Smplg_c" = "Sampling Coverage"
    )
    
    leafletProxy("map") %>%
      # Reactively colored grid overlay (Colored with Natural Jenks)
      clearGroup("Sampling Grid (10km)") %>%
      addPolygons(
        data = grid_shp, weight = 1, color = "#2c3e50", fillColor = ~ pal(grid_shp[[var_name]]), fillOpacity = 0.6,
        group = "Sampling Grid (10km)",
        popup = ~ paste0(
          "<strong>Grid Cell ID:</strong> ", id, "<br>",
          "<strong>", var_label, ":</strong> ", grid_shp[[var_name]]
        )
      ) %>%
      
      # Layer Controls
      addLayersControl(
        baseGroups = c("CartoDB Positron", "Satellite Imagery"),
        overlayGroups = c("Occurrences", "Sampling Grid (10km)"),
        options = layersControlOptions(collapsed = FALSE)
      )
  })
  
  # Reactive Map Markers Update
  observe({
    df <- filtered_data()
    
    if (nrow(df) > 0) {
      leafletProxy("map", data = df) %>%
        clearGroup("Occurrences") %>%
        addCircleMarkers(
          lng = ~decimalLongitude,
          lat = ~decimalLatitude,
          radius = 4,
          color = "#e74c3c",
          fillOpacity = 0.7,
          stroke = FALSE,
          group = "Occurrences",
          popup = ~ paste0(
            "<strong>Species:</strong> <em>", scientificName, "</em><br>",
            "<strong>Family:</strong> ", family, "<br>",
            "<strong>SNAP:</strong> ", snap_name
          ),
          clusterOptions = markerClusterOptions()
        )
    } else {
      leafletProxy("map") %>% clearGroup("Occurrences")
    }
  })
  
  # Dynamic Legend Observer: Displays legends for active layers only
  observe({
    proxy <- leafletProxy("map")
    proxy %>% clearControls()
    
    active_groups <- input$map_groups
    
    if ("Sampling Grid (10km)" %in% active_groups) {
      pal <- grid_pal()
      var_name <- input$grid_var
      var_label <- switch(var_name,
        "Ttl_rcr" = "Total Records",
        "Totl_sp" = "Total Species",
        "Smplg_c" = "Sampling Coverage"
      )
      proxy %>% addLegend(
        pal = pal,
        values = grid_shp[[var_name]],
        title = paste("Grid:", var_label),
        position = "bottomleft",
        layerId = "grid_legend"
      )
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
  })
  
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
