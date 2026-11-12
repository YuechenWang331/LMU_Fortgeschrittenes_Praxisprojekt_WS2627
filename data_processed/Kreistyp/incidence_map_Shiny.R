# Setup ----
library(shiny)
library(leaflet)
library(sf)
library(dplyr)

analysis_years <- 2020:2023

# 1. Locate the project ----
project_candidates <- c(".", "..", "../..")
project_matches <- dir.exists(file.path(project_candidates, "data_processed")) &
  dir.exists(file.path(project_candidates, "data_geo"))

if (!any(project_matches)) {
  stop("Run the app from the project root or data_processed/Kreistyp.")
}

project_dir <- normalizePath(project_candidates[project_matches][1L])

normalize_code <- function(x) {
  x <- trimws(as.character(x))
  
  if (anyNA(x) || any(!grepl("^[0-9]{1,5}$", x))) {
    stop("Invalid district codes.")
  }
  
  sprintf("%05d", as.integer(x))
}

escape_html <- function(x) {
  as.character(htmltools::htmlEscape(as.character(x)))
}

format_number <- function(x, digits = 0) {
  formatC(
    x,
    format = "f",
    digits = digits,
    big.mark = ".",
    decimal.mark = ","
  )
}

# 2. Read weekly data ----
source_file <- file.path(
  project_dir,
  "data_processed",
  "Kreistyp",
  "regional_weekly_summary_2020_2023.rds"
)

if (!file.exists(source_file)) {
  stop("Weekly summary not found: ", source_file)
}

weekly <- readRDS(source_file) %>%
  ungroup()

required_columns <- c(
  "geo_code", "geo_name", "week_start",
  "iso_year", "iso_week",
  "cases_total", "population_total"
)

stopifnot(all(required_columns %in% names(weekly)))

weekly <- weekly %>%
  transmute(
    geo_code = normalize_code(geo_code),
    geo_name = as.character(geo_name),
    week_start = as.Date(week_start),
    iso_year = as.integer(iso_year),
    iso_week = as.integer(iso_week),
    cases_total,
    population_total
  ) %>%
  filter(iso_year %in% analysis_years)

stopifnot(
  nrow(weekly) == 83600L,
  !anyNA(weekly),
  !anyDuplicated(weekly[c("geo_code", "iso_year", "iso_week")]),
  all(is.finite(weekly$cases_total)),
  all(weekly$cases_total >= 0),
  all(is.finite(weekly$population_total)),
  all(weekly$population_total > 0),
  setequal(weekly$iso_year, analysis_years),
  all(as.integer(format(weekly$week_start, "%G")) == weekly$iso_year),
  all(as.integer(format(weekly$week_start, "%V")) == weekly$iso_week)
)

week_checks <- weekly %>%
  count(iso_year, iso_week)

year_checks <- weekly %>%
  group_by(iso_year) %>%
  summarise(
    regions = n_distinct(geo_code),
    weeks = n_distinct(iso_week),
    .groups = "drop"
  )

population_checks <- weekly %>%
  group_by(geo_code, iso_year) %>%
  summarise(
    values = n_distinct(population_total),
    .groups = "drop"
  )

week_dates <- weekly %>%
  distinct(iso_year, iso_week, week_start) %>%
  arrange(iso_year, iso_week)

stopifnot(
  all(week_checks$n == 400L),
  all(year_checks$regions == 400L),
  all(
    year_checks$weeks ==
      ifelse(year_checks$iso_year == 2020, 53L, 52L)
  ),
  all(population_checks$values == 1L),
  !anyDuplicated(week_dates[c("iso_year", "iso_week")])
)

# 3. Aggregate weekly data ----
# Monthly allocation follows the week's Monday.
# ISO boundary weeks are assigned to January or December
# of their ISO year to preserve annual totals.
weekly <- weekly %>%
  mutate(
    monday_year = as.integer(format(week_start, "%Y")),
    month = case_when(
      monday_year < iso_year ~ 1L,
      monday_year > iso_year ~ 12L,
      TRUE ~ as.integer(format(week_start, "%m"))
    )
  )

weekly_data <- weekly %>%
  transmute(
    geo_code,
    year = iso_year,
    period = iso_week,
    cases_total,
    population_total,
    incidence = cases_total / population_total * 100000
  )

monthly_data <- weekly %>%
  group_by(
    geo_code,
    year = iso_year,
    period = month
  ) %>%
  summarise(
    cases_total = sum(cases_total),
    population_total = first(population_total),
    .groups = "drop"
  ) %>%
  mutate(
    incidence = cases_total / population_total * 100000
  )

annual_data <- weekly %>%
  group_by(geo_code, year = iso_year) %>%
  summarise(
    period = 1L,
    cases_total = sum(cases_total),
    population_total = first(population_total),
    .groups = "drop"
  ) %>%
  mutate(
    incidence = cases_total / population_total * 100000
  )

monthly_check <- monthly_data %>%
  group_by(geo_code, year) %>%
  summarise(
    monthly_cases = sum(cases_total),
    .groups = "drop"
  ) %>%
  inner_join(
    annual_data %>%
      select(
        geo_code,
        year,
        annual_cases = cases_total
      ),
    by = c("geo_code", "year")
  )

stopifnot(
  nrow(monthly_data) == 19200L,
  nrow(annual_data) == 1600L,
  nrow(monthly_check) == 1600L,
  all(
    monthly_check$monthly_cases ==
      monthly_check$annual_cases
  )
)

datasets <- list(
  week = weekly_data,
  month = monthly_data,
  year = annual_data
)

district_choices <- weekly %>%
  arrange(iso_year, week_start) %>%
  distinct(geo_code, .keep_all = TRUE) %>%
  arrange(geo_name) %>%
  transmute(
    geo_code,
    geo_name,
    label = paste0(geo_name, " (", geo_code, ")")
  )

# 4. Prepare district boundaries ----
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

stopifnot(
  nrow(district_map) == 400L,
  !any(st_is_empty(district_map)),
  setequal(district_map$geo_code, weekly$geo_code)
)

district_map <- district_map %>%
  left_join(
    district_choices %>%
      select(geo_code, geo_name),
    by = "geo_code",
    relationship = "one-to-one"
  )

map_bounds <- st_bbox(district_map)

# 5. Fixed colour classes ----
# Visualization intervals, not official risk thresholds.
colour_values <- c(
  "#FFF7BC",
  "#FEE391",
  "#FEC44F",
  "#FE9929",
  "#EC7014",
  "#CC4C02",
  "#993404",
  "#662506"
)

bin_edges <- list(
  week = c(
    0, 10, 50, 100, 250,
    500, 1000, 2000, Inf
  ),
  month = c(
    0, 50, 250, 500, 1000,
    2500, 5000, 10000, Inf
  ),
  year = c(
    0, 500, 1000, 2500, 5000,
    10000, 25000, 50000, Inf
  )
)

palettes <- lapply(bin_edges, function(edges) {
  colorBin(
    palette = colour_values,
    bins = edges,
    domain = c(0, 100000),
    na.color = "#BDBDBD",
    right = FALSE
  )
})

month_names <- c(
  "Januar", "Februar", "März", "April",
  "Mai", "Juni", "Juli", "August",
  "September", "Oktober", "November", "Dezember"
)

metric_names <- c(
  week = "Wocheninzidenz",
  month = "Monatliche kumulative Inzidenz",
  year = "Jährliche kumulative Inzidenz"
)

# 6. User interface ----
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background: #f6f8fb;
        color: #19304b;
        font-family: -apple-system, BlinkMacSystemFont,
                     'Segoe UI', sans-serif;
      }

      .container-fluid {
        max-width: 1900px;
        padding: 24px;
        margin: auto;
      }

      .page-title {
        font-size: 28px;
        font-weight: 750;
        margin-bottom: 6px;
      }

      .subtitle {
        color: #7b8ba0;
        margin-bottom: 22px;
      }

      .app-layout {
        display: grid;
        grid-template-columns: 260px minmax(0, 1fr);
        gap: 20px;
        align-items: start;
      }

      .card {
        background: white;
        border: 1px solid #edf1f5;
        border-radius: 14px;
        padding: 19px;
        margin-bottom: 16px;
      }

      .card-heading {
        color: #7b8ba0;
        font-size: 11px;
        font-weight: 750;
        letter-spacing: 1px;
        text-transform: uppercase;
        margin-bottom: 16px;
      }

      .control-label {
        font-size: 13px;
      }

      .selectize-input {
        font-size: 12px;
        border-radius: 7px;
        box-shadow: none;
      }

      .time-selector {
        position: relative;
      }

      .time-selector .control-label {
        display: block;
        padding-right: 32px;
      }

      .time-selector .slider-animate-container {
        position: absolute;
        top: 0;
        right: 0;
        margin: 0;
        padding: 0;
      }

      .time-selector .slider-animate-button {
        font-size: 17px;
        color: #526f91;
      }

      .map-card {
        background: white;
        padding: 7px;
        border-radius: 15px;
        border: 1px solid #edf1f5;
      }

      .leaflet-container {
        background: white;
        border-radius: 10px;
      }

      #map .leaflet-tile-pane {
        filter: grayscale(85%);
      }

      .leaflet-tooltip {
        border: none;
        border-radius: 7px;
        padding: 9px 12px;
        box-shadow: 0 2px 12px rgba(23,43,70,0.12);
      }

      #map .info.legend {
        background: rgba(255,255,255,0.96);
        border-radius: 10px;
        padding: 12px 14px;
        box-shadow: 0 2px 12px rgba(23,43,70,0.12);
        font-size: 11px;
        line-height: 19px;
        color: #29415f;
        max-width: 240px;
      }

      #map .info.legend i {
        border-radius: 3px;
      }

      .period-title {
        font-size: 18px;
        font-weight: 700;
        margin-bottom: 5px;
      }

      .metric-subtitle {
        font-size: 12px;
        color: #7b8ba0;
        margin-bottom: 12px;
      }

      .note {
        color: #7b8ba0;
        font-size: 11px;
        line-height: 1.65;
      }

      .stat-value {
        font-size: 27px;
        font-weight: 750;
        margin-bottom: 3px;
      }

      .stat-label {
        font-size: 12px;
        color: #7b8ba0;
        margin-bottom: 17px;
      }

      .btn-default {
        font-size: 12px;
        border-radius: 7px;
        border-color: #dce4ec;
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
    "COVID-19 in Deutschland"
  ),
  
  div(
    class = "subtitle",
    paste0(
      "Gemeldete Fälle je 100.000 Einwohner · Alle Altersgruppen · ",
      min(analysis_years), "–", max(analysis_years)
    )
  ),
  
  div(
    class = "app-layout",
    
    div(
      div(
        class = "card",
        
        div(
          class = "card-heading",
          "Zeitraum und Auswahl"
        ),
        
        selectInput(
          "scale",
          "Zeitebene",
          choices = c(
            "Woche" = "week",
            "Monat" = "month",
            "Jahr" = "year"
          ),
          selected = "week"
        ),
        
        selectInput(
          "year",
          "Jahr",
          choices = analysis_years,
          selected = min(analysis_years)
        ),
        
        conditionalPanel(
          condition = "input.scale != 'year'",
          
          div(
            class = "time-selector",
            
            sliderInput(
              "period",
              "Kalenderwoche",
              min = 1,
              max = 53,
              value = 1,
              step = 1,
              sep = "",
              animate = animationOptions(
                interval = 1000,
                loop = TRUE
              )
            )
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
          "Karte zurücksetzen"
        )
      ),
      
      div(
        class = "card",
        
        div(
          class = "card-heading",
          "Deutschland"
        ),
        
        uiOutput("national_summary")
      )
    ),
    
    div(
      uiOutput("map_heading"),
      
      div(
        class = "map-card",
        leafletOutput("map", height = "78vh")
      ),
      
      div(
        class = "note",
        style = "margin-top: 12px;",
        
        textOutput("method_note"),
        
        tags$br(),
        
        "Feste Farbklassen innerhalb jeder Zeitebene; ",
        "keine offiziellen Risikostufen. ",
        "400 harmonisierte Kreise; Eisenach ist dem Wartburgkreis zugeordnet. ",
        "Gemeldete Fälle sind keine Zählung eindeutig verschiedener Personen. ",
        "Änderungen der Test- und Meldepraxis beeinflussen die Vergleichbarkeit. ",
        "Hintergrund: © OpenStreetMap-Mitwirkende."
      )
    )
  )
)

# 7. Server ----
server <- function(input, output, session) {
  
  # Adapt the time selector
  observeEvent(
    list(input$scale, input$year),
    {
      req(input$scale, input$year)
      
      if (input$scale == "year") {
        return()
      }
      
      upper <- if (input$scale == "month") {
        12L
      } else {
        max(
          weekly_data$period[
            weekly_data$year == as.integer(input$year)
          ]
        )
      }
      
      current <- isolate(input$period)
      
      if (is.null(current)) {
        current <- 1L
      }
      
      updateSliderInput(
        session,
        "period",
        label = if (input$scale == "month") {
          "Monat"
        } else {
          "Kalenderwoche"
        },
        min = 1,
        max = upper,
        value = min(current, upper)
      )
    },
    ignoreInit = FALSE
  )
  
  selected_period <- reactive({
    if (input$scale == "year") {
      return(1L)
    }
    
    upper <- if (input$scale == "month") {
      12L
    } else {
      max(
        weekly_data$period[
          weekly_data$year == as.integer(input$year)
        ]
      )
    }
    
    req(input$period)
    
    as.integer(
      max(1, min(input$period, upper))
    )
  })
  
  current_data <- reactive({
    req(input$scale, input$year)
    
    result <- datasets[[input$scale]] %>%
      filter(
        year == as.integer(input$year),
        period == selected_period()
      )
    
    validate(
      need(
        nrow(result) == 400L,
        "Für diesen Zeitraum fehlen Daten."
      )
    )
    
    result
  })
  
  current_map <- reactive({
    district_map %>%
      left_join(
        current_data(),
        by = "geo_code",
        relationship = "one-to-one"
      )
  })
  
  period_title <- reactive({
    year <- as.integer(input$year)
    period <- selected_period()
    
    if (input$scale == "year") {
      return(
        paste("Jahr", year, "· ISO-Kalenderjahr")
      )
    }
    
    if (input$scale == "month") {
      return(
        paste(month_names[period], year)
      )
    }
    
    date <- week_dates %>%
      filter(
        iso_year == year,
        iso_week == period
      ) %>%
      pull(week_start)
    
    req(length(date) == 1L)
    
    paste0(
      year,
      " · KW ",
      sprintf("%02d", period),
      " · ",
      format(date, "%d.%m.%Y"),
      "–",
      format(date + 6, "%d.%m.%Y")
    )
  })
  
  output$map_heading <- renderUI({
    tagList(
      div(
        class = "period-title",
        period_title()
      ),
      
      div(
        class = "metric-subtitle",
        metric_names[[input$scale]],
        " · Gemeldete Fälle je 100.000 Einwohner"
      )
    )
  })
  
  # Render the background map
  output$map <- renderLeaflet({
    leaflet(
      options = leafletOptions(
        minZoom = 4,
        maxZoom = 12,
        zoomSnap = 0.25
      )
    ) %>%
      addMapPane(
        "selectionPane",
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
        unname(map_bounds["xmin"]),
        unname(map_bounds["ymin"]),
        unname(map_bounds["xmax"]),
        unname(map_bounds["ymax"])
      ) %>%
      addScaleBar(
        position = "bottomleft",
        options = scaleBarOptions(
          imperial = FALSE
        )
      )
  })
  
  # Update district colours and the map legend together
  observe({
    data <- current_map()
    palette <- palettes[[input$scale]]
    edges <- bin_edges[[input$scale]]
    
    tooltip_labels <- lapply(
      paste0(
        "<strong>",
        escape_html(data$geo_name),
        "</strong>",
        "<br>",
        escape_html(period_title()),
        "<br>Gemeldete Fälle: ",
        format_number(data$cases_total),
        "<br>Fälle je 100.000 Einwohner: <strong>",
        format_number(data$incidence, 1),
        "</strong>"
      ),
      htmltools::HTML
    )
    
    legend_labels <- vapply(
      seq_len(length(edges) - 1L),
      function(i) {
        lower <- format_number(edges[i])
        upper <- edges[i + 1L]
        
        if (is.infinite(upper)) {
          paste0("≥ ", lower)
        } else {
          paste0(
            lower,
            " bis < ",
            format_number(upper)
          )
        }
      },
      character(1)
    )
    
    leafletProxy("map", data = data) %>%
      clearGroup("districts") %>%
      removeControl("incidence_legend") %>%
      addPolygons(
        group = "districts",
        layerId = ~geo_code,
        fillColor = palette(data$incidence),
        fillOpacity = 0.8,
        color = "#FFFFFF",
        weight = 0.65,
        opacity = 0.95,
        label = tooltip_labels,
        highlightOptions = highlightOptions(
          weight = 1.8,
          color = "#34465A",
          fillOpacity = 0.8,
          bringToFront = TRUE
        )
      ) %>%
      addLegend(
        position = "bottomright",
        colors = colour_values,
        labels = legend_labels,
        opacity = 0.8,
        title = paste0(
          metric_names[[input$scale]],
          "<br>Fälle je 100.000 Einwohner"
        ),
        layerId = "incidence_legend"
      )
  })
  
  # Highlight the selected district without zooming
  observe({
    code <- input$district
    
    proxy <- leafletProxy("map") %>%
      clearGroup("selection")
    
    if (!is.null(code) && code != "") {
      proxy %>%
        addPolygons(
          data = district_map %>%
            filter(geo_code == code),
          group = "selection",
          fill = FALSE,
          color = "#152A43",
          weight = 3,
          options = pathOptions(
            pane = "selectionPane",
            interactive = FALSE
          )
        )
    }
  })
  
  observeEvent(input$map_shape_click, {
    code <- input$map_shape_click$id
    
    if (!is.null(code) && code %in% district_map$geo_code) {
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
        unname(map_bounds["xmin"]),
        unname(map_bounds["ymin"]),
        unname(map_bounds["xmax"]),
        unname(map_bounds["ymax"])
      )
  })
  
  # National totals use the total population, not mean district incidence
  output$national_summary <- renderUI({
    data <- current_data()
    
    national_cases <- sum(data$cases_total)
    national_population <- sum(data$population_total)
    
    national_incidence <-
      national_cases / national_population * 100000
    
    tagList(
      div(
        class = "stat-value",
        format_number(national_cases)
      ),
      
      div(
        class = "stat-label",
        "Gemeldete Fälle im Zeitraum"
      ),
      
      div(
        class = "stat-value",
        format_number(national_incidence, 1)
      ),
      
      div(
        class = "stat-label",
        "Fälle je 100.000 Einwohner"
      ),
      
      div(
        class = "note",
        "Berechnung: Summe der Fälle / ",
        "Summe der Bevölkerung × 100.000"
      )
    )
  })
  
  output$method_note <- renderText({
    switch(
      input$scale,
      
      week = paste(
        "Wocheninzidenz: Fälle der ISO-Kalenderwoche /",
        "Bevölkerung des zugehörigen ISO-Jahres × 100.000."
      ),
      
      month = paste(
        "Monatliche kumulative Inzidenz:",
        "Summe der zugeordneten Wochenfälle / Jahresbevölkerung × 100.000.",
        "Zuordnung nach Wochenbeginn (Montag);",
        "jahresübergreifende ISO-Wochen werden dem Januar bzw.",
        "Dezember ihres ISO-Jahres zugeordnet.",
        "Näherung aus Wochendaten, keine exakten Kalendermonatswerte."
      ),
      
      year = paste(
        "Jährliche kumulative Inzidenz:",
        "Summe der Fälle aller ISO-Kalenderwochen des Jahres /",
        "Jahresbevölkerung × 100.000.",
        "2020 umfasst 53, die übrigen Jahre jeweils 52 Wochen."
      )
    )
  })
}

# 8. Launch the app ----
shinyApp(ui = ui, server = server)
