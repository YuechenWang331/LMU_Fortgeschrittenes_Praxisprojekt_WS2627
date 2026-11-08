library(shiny)
library(leaflet)
library(sf)
library(dplyr)

# 1. Locate the project
project_dir <- if (dir.exists("data_processed")) {
  normalizePath(".")
} else if (dir.exists("../data_processed")) {
  normalizePath("..")
} else {
  stop("Open the RStudio project before running this app.")
}

# 2. Read annual classifications
regional_files <- list.files(
  file.path(project_dir, "data_processed"),
  pattern = "^population_Kreistyp_Raumtyp_.*\\.rds$",
  full.names = TRUE
)

if (length(regional_files) != 1L) {
  stop("Expected exactly one population_Kreistyp_Raumtyp_*.rds file.")
}

normalize_code <- function(x) {
  x <- trimws(as.character(x))
  
  if (anyNA(x) || any(!grepl("^[0-9]{1,5}$", x))) {
    stop("Invalid district codes.")
  }
  
  sprintf("%05d", as.integer(x))
}

regional <- readRDS(regional_files) %>%
  ungroup()

stopifnot(
  all(c(
    "geo_code", "geo_name", "year", "kreistyp_code"
  ) %in% names(regional))
)

regional <- regional %>%
  transmute(
    geo_code = normalize_code(geo_code),
    geo_name = as.character(geo_name),
    year = as.integer(as.character(year)),
    kreistyp_code = as.integer(as.character(kreistyp_code))
  ) %>%
  filter(year %in% 2020:2024)

stopifnot(
  nrow(regional) == 2000L,
  !anyDuplicated(regional[c("geo_code", "year")]),
  setequal(regional$year, 2020:2024),
  !anyNA(regional),
  all(regional$kreistyp_code %in% 1:4),
  all(count(regional, year)$n == 400L)
)

type_names <- c(
  "Kreisfreie Großstädte",
  "Städtische Kreise",
  "Ländliche Kreise mit Verdichtungsansätzen",
  "Dünn besiedelte ländliche Kreise"
)

type_colours <- c(
  "#084594",
  "#2171B5",
  "#6BAED6",
  "#C6DBEF"
)

regional <- regional %>%
  mutate(kreistyp_name = type_names[kreistyp_code])

district_choices <- regional %>%
  filter(year == 2020) %>%
  arrange(geo_name) %>%
  mutate(
    label = paste0(geo_name, " (", geo_code, ")")
  )

# 3. Prepare district boundaries
district_map <- st_read(
  file.path(
    project_dir,
    "data_geo",
    "landkreise_simplify200.geojson"
  ),
  quiet = TRUE
)

stopifnot("AGS" %in% names(district_map))

if (is.na(st_crs(district_map))) {
  stop("The boundary file has no coordinate reference system.")
}

if ("GF" %in% names(district_map)) {
  district_map <- district_map %>%
    filter(as.character(GF) == "4")
}

district_map <- district_map %>%
  mutate(
    geo_code = normalize_code(AGS),
    geo_code = if_else(
      geo_code == "16056",
      "16063",
      geo_code
    )
  ) %>%
  select(geo_code) %>%
  st_transform(3035) %>%
  st_make_valid() %>%
  group_by(geo_code) %>%
  summarise(.groups = "drop") %>%
  st_transform(4326)

expected_codes <- unique(regional$geo_code)

if (!setequal(district_map$geo_code, expected_codes)) {
  stop(
    "Boundary codes do not match the regional dataset.\n",
    "Missing: ",
    paste(setdiff(expected_codes, district_map$geo_code), collapse = ", "),
    "\nExtra: ",
    paste(setdiff(district_map$geo_code, expected_codes), collapse = ", ")
  )
}

stopifnot(
  nrow(district_map) == 400L,
  !any(st_is_empty(district_map))
)

map_bounds <- st_bbox(district_map)

escape_html <- function(x) {
  as.character(htmltools::htmlEscape(as.character(x)))
}

# 4. User interface
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        margin: 0;
        background: #f6f8fb;
        color: #19304b;
        font-family: -apple-system, BlinkMacSystemFont,
                     'Segoe UI', sans-serif;
      }

      .container-fluid {
        padding: 24px;
        max-width: 1900px;
        margin: auto;
      }

      .page-title {
        font-size: 28px;
        font-weight: 750;
        margin-bottom: 6px;
      }

      .page-subtitle {
        font-size: 14px;
        color: #77859a;
        margin-bottom: 22px;
      }

      .app-layout {
        display: grid;
        grid-template-columns: 260px minmax(0, 1fr);
        gap: 20px;
        align-items: start;
      }

      .panel-card {
        background: white;
        border: 1px solid #edf1f5;
        border-radius: 14px;
        padding: 20px;
        margin-bottom: 16px;
      }

      .panel-heading-text {
        font-size: 11px;
        font-weight: 750;
        letter-spacing: 1px;
        color: #7b8ba0;
        text-transform: uppercase;
        margin-bottom: 18px;
      }

      .control-label {
        font-size: 13px;
        font-weight: 600;
      }

      .selectize-input {
        border-radius: 7px;
        border-color: #dce4ec;
        box-shadow: none;
        font-size: 12px;
      }

      .type-row {
        display: grid;
        grid-template-columns: 13px minmax(0, 1fr) auto;
        gap: 9px;
        align-items: start;
        padding: 12px 0;
        border-bottom: 1px solid #f0f3f6;
      }

      .type-row:last-child {
        border-bottom: 0;
      }

      .swatch {
        width: 13px;
        height: 13px;
        border-radius: 3px;
        margin-top: 3px;
      }

      .type-name {
        font-size: 12px;
        line-height: 1.55;
      }

      .type-count {
        font-size: 15px;
        font-weight: 750;
        font-variant-numeric: tabular-nums;
      }

      .total {
        color: #7b8ba0;
        font-size: 12px;
        margin-top: 15px;
      }

      .map-card {
        background: white;
        border: 1px solid #edf1f5;
        border-radius: 15px;
        padding: 7px;
        overflow: hidden;
      }

      .leaflet-container {
        background: #ffffff;
        border-radius: 10px;
      }

      /* Light, muted background; district colours stay unchanged. */
      #map .leaflet-tile-pane {
        filter: grayscale(85%);
      }

      .leaflet-tooltip {
        border: none;
        border-radius: 7px;
        box-shadow: 0 2px 12px rgba(23,43,70,0.12);
        font-size: 12px;
        padding: 8px 11px;
      }

      .leaflet-control-attribution {
        font-size: 9px;
      }

      .footnote {
        font-size: 11px;
        color: #7b8ba0;
        line-height: 1.7;
        margin-top: 12px;
      }

      .btn-default {
        background: #fff;
        color: #29415f;
        border: 1px solid #dce4ec;
        border-radius: 7px;
        font-size: 12px;
      }

      @media (max-width: 800px) {
        .app-layout {
          grid-template-columns: 1fr;
        }

        .container-fluid {
          padding: 12px;
        }

        .page-title {
          font-size: 23px;
        }
      }
    "))
  ),
  
  div(
    class = "page-title",
    "Siedlungsstrukturelle Kreistypen in Deutschland"
  ),
  
  div(
    class = "page-subtitle",
    "Jährliche BBSR-Klassifikation · 2020–2024"
  ),
  
  div(
    class = "app-layout",
    
    div(
      div(
        class = "panel-card",
        
        div(
          class = "panel-heading-text",
          "Kartenauswahl"
        ),
        
        sliderInput(
          "year",
          "Jahr",
          min = 2020,
          max = 2024,
          value = 2020,
          step = 1,
          sep = "",
          animate = animationOptions(
            interval = 1600,
            loop = TRUE
          )
        ),
        
        selectizeInput(
          "district",
          "Kreis suchen",
          choices = c(
            "Bitte auswählen" = "",
            setNames(
              district_choices$geo_code,
              district_choices$label
            )
          ),
          selected = "",
          options = list(
            placeholder = "Name oder Kreisschlüssel",
            allowEmptyOption = TRUE
          )
        ),
        
        actionButton(
          "reset",
          "Auswahl und Ansicht zurücksetzen"
        )
      ),
      
      div(
        class = "panel-card",
        div(
          class = "panel-heading-text",
          "Anzahl der Kreise nach Typ"
        ),
        uiOutput("type_legend")
      )
    ),
    
    div(
      div(
        class = "map-card",
        leafletOutput("map", height = "80vh")
      ),
      
      div(
        class = "footnote",
        "Kreis auswählen oder anklicken, um ihn hervorzuheben. ",
        "Die Kartenansicht bleibt bei der Auswahl erhalten. ",
        "Einheitliche Gebietsabgrenzung mit 400 Kreisen; ",
        "Eisenach ist dem Wartburgkreis zugeordnet. ",
        "Klassifikation: BBSR · Hintergrund: © OpenStreetMap-Mitwirkende."
      )
    )
  )
)

# 5. Server
server <- function(input, output, session) {
  
  annual_data <- reactive({
    regional %>%
      filter(year == input$year)
  })
  
  annual_map <- reactive({
    district_map %>%
      left_join(
        annual_data(),
        by = "geo_code",
        relationship = "one-to-one"
      )
  })
  
  selected_code <- reactive({
    if (is.null(input$district) || input$district == "") {
      return(NULL)
    }
    
    input$district
  })
  
  output$map <- renderLeaflet({
    leaflet(
      options = leafletOptions(
        minZoom = 4,
        maxZoom = 12,
        zoomSnap = 0.25,
        attributionControl = TRUE
      )
    ) %>%
      addMapPane(
        name = "selectionPane",
        zIndex = 450
      ) %>%
      addTiles(
        urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        attribution = paste0(
          '&copy; <a href="https://www.openstreetmap.org/copyright">',
          'OpenStreetMap</a>-Mitwirkende'
        ),
        options = tileOptions(
          opacity = 0.30,
          maxZoom = 19
        )
      ) %>%
      fitBounds(
        lng1 = unname(map_bounds["xmin"]),
        lat1 = unname(map_bounds["ymin"]),
        lng2 = unname(map_bounds["xmax"]),
        lat2 = unname(map_bounds["ymax"])
      ) %>%
      addScaleBar(
        position = "bottomleft",
        options = scaleBarOptions(imperial = FALSE)
      )
  })
  
  # Update annual classifications without changing the view
  observe({
    current_map <- annual_map()
    
    labels <- lapply(
      paste0(
        "<strong>",
        escape_html(current_map$geo_name),
        "</strong><br>",
        escape_html(current_map$kreistyp_name)
      ),
      htmltools::HTML
    )
    
    leafletProxy("map", data = current_map) %>%
      clearGroup("districts") %>%
      addPolygons(
        group = "districts",
        layerId = ~geo_code,
        fillColor = type_colours[current_map$kreistyp_code],
        fillOpacity = 0.8,
        color = "#FFFFFF",
        weight = 0.65,
        opacity = 0.95,
        label = labels,
        highlightOptions = highlightOptions(
          weight = 1.8,
          color = "#34465A",
          fillOpacity = 0.8,
          bringToFront = TRUE
        ),
        labelOptions = labelOptions(
          direction = "auto"
        )
      )
  })
  
  # Update only the selection outline
  observe({
    code <- selected_code()
    
    proxy <- leafletProxy("map") %>%
      clearGroup("selection")
    
    if (!is.null(code)) {
      proxy %>%
        addPolygons(
          data = district_map %>%
            filter(geo_code == code),
          group = "selection",
          fill = FALSE,
          color = "#152A43",
          weight = 3,
          opacity = 1,
          options = pathOptions(
            pane = "selectionPane",
            interactive = FALSE
          )
        )
    }
  })
  
  # Clicking selects a district without zooming
  observeEvent(input$map_shape_click, {
    code <- input$map_shape_click$id
    
    if (!is.null(code) && code %in% expected_codes) {
      updateSelectizeInput(
        session,
        "district",
        selected = code
      )
    }
  })
  
  observeEvent(input$reset, {
    updateSelectizeInput(
      session,
      "district",
      selected = ""
    )
    
    leafletProxy("map") %>%
      clearGroup("selection") %>%
      fitBounds(
        lng1 = unname(map_bounds["xmin"]),
        lat1 = unname(map_bounds["ymin"]),
        lng2 = unname(map_bounds["xmax"]),
        lat2 = unname(map_bounds["ymax"])
      )
  })
  
  # Display counts for the selected year
  output$type_legend <- renderUI({
    totals <- tabulate(
      annual_data()$kreistyp_code,
      nbins = 4
    )
    
    tagList(
      lapply(seq_len(4), function(i) {
        div(
          class = "type-row",
          
          div(
            class = "swatch",
            style = paste0(
              "background: ",
              type_colours[i],
              ";"
            )
          ),
          
          div(
            class = "type-name",
            type_names[i]
          ),
          
          div(
            class = "type-count",
            totals[i]
          )
        )
      }),
      
      div(
        class = "total",
        paste("Insgesamt 400 Kreise ·", input$year)
      )
    )
  })
}

shinyApp(ui = ui, server = server)