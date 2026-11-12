library(shiny)
library(leaflet)
library(dplyr)
library(sf)
library(htmltools)
library(shinyWidgets)

# ------------------------------------------------------------
# Vorbereitete Daten einlesen
# ------------------------------------------------------------

data_path <- "data_processed/map_dashboard_data.rds"

if (!file.exists(data_path)) {
  stop(
    "Bitte zuerst Yuechen02_Prepare_Map_Indicators.R ausfuehren."
  )
}

dashboard_data <- readRDS(data_path)

map_regions <- dashboard_data$map
indicators <- dashboard_data$indicators
national <- dashboard_data$national

months <- sort(unique(indicators$month))

estimate_count <- nrow(
  dashboard_data$population_estimates
)

region_order <- order(
  map_regions$region_name,
  map_regions$geo_code
)

region_choices <- setNames(
  map_regions$geo_code[region_order],
  paste0(
    map_regions$region_name[region_order],
    " [",
    map_regions$geo_code[region_order],
    "]"
  )
)

age_choices <- c(
  "Alle bekannten Alterskategorien" = "All",
  
  setNames(
    as.character(0:79),
    paste0(0:79, " Jahre")
  ),
  
  "80 Jahre und aelter" = "80+"
)

default_region <- if (
  "09162" %in% map_regions$geo_code
) {
  "09162"
} else {
  map_regions$geo_code[1]
}

default_month <- match(
  as.Date("2022-03-01"),
  months
)

if (is.na(default_month)) {
  default_month <- 1L
}

# ------------------------------------------------------------
# Formatierung
# ------------------------------------------------------------

format_number <- function(x, digits = 0) {
  
  result <- rep(
    "Keine Daten",
    length(x)
  )
  
  available <- is.finite(x)
  
  result[available] <- formatC(
    x[available],
    format = "f",
    digits = digits,
    big.mark = ".",
    decimal.mark = ","
  )
  
  result
}

yes_no <- function(x) {
  ifelse(
    is.na(x),
    "Unbekannt",
    ifelse(x, "Ja", "Nein")
  )
}

# ------------------------------------------------------------
# Feste Farbklassen
# ------------------------------------------------------------

rate_bins <- c(
  0, 1, 10, 50, 100,
  250, 500, 1000, 2500, 5000, Inf
)

rate_colors <- c(
  "#FFFFCC",
  "#FFEDA0",
  "#FED976",
  "#FEB24C",
  "#FD8D3C",
  "#FC4E2A",
  "#E31A1C",
  "#BD0026",
  "#990026",
  "#66001F"
)

rate_labels <- c(
  "0 bis < 1",
  "1 bis < 10",
  "10 bis < 50",
  "50 bis < 100",
  "100 bis < 250",
  "250 bis < 500",
  "500 bis < 1.000",
  "1.000 bis < 2.500",
  "2.500 bis < 5.000",
  "Ab 5.000"
)

density_bins <- c(
  0, 50, 100, 200,
  500, 1000, 2000, 5000, Inf
)

density_colors <- c(
  "#F7FBFF",
  "#DEEBF7",
  "#C6DBEF",
  "#9ECAE1",
  "#6BAED6",
  "#4292C6",
  "#2171B5",
  "#084594"
)

density_labels <- c(
  "Unter 50",
  "50 bis < 100",
  "100 bis < 200",
  "200 bis < 500",
  "500 bis < 1.000",
  "1.000 bis < 2.000",
  "2.000 bis < 5.000",
  "Ab 5.000"
)

rate_palette <- colorBin(
  palette = rate_colors,
  domain = indicators$rate,
  bins = rate_bins,
  right = FALSE,
  na.color = "#BDBDBD"
)

density_palette <- colorBin(
  palette = density_colors,
  domain = indicators$density,
  bins = density_bins,
  right = FALSE,
  na.color = "#BDBDBD"
)

# ------------------------------------------------------------
# Benutzeroberflaeche
# ------------------------------------------------------------

ui <- fluidPage(
  
  tags$head(
    tags$style(
      HTML("
        body {
          background-color: #F5F7FA;
        }

        .well {
          background-color: #FFFFFF;
          border-radius: 10px;
        }

        .main-panel-box {
          background-color: #FFFFFF;
          padding: 16px;
          border-radius: 10px;
          margin-bottom: 18px;
        }

        .leaflet-container {
          border-radius: 8px;
        }
      ")
    )
  ),
  
  titlePanel(
    "COVID-19 und regionale Struktur in Deutschland"
  ),
  
  sidebarLayout(
    
    sidebarPanel(
      width = 3,
      
      selectInput(
        "age",
        "Alterskategorie:",
        choices = age_choices,
        selected = "80+"
      ),
      
      sliderTextInput(
        inputId = "month_index",
        label = "Monat auswaehlen:",
        choices = format(months, "%m/%Y"),
        selected = format(months[default_month], "%m/%Y"),
        grid = FALSE,
        animate = animationOptions(
          interval = 1500,
          loop = FALSE
        )
      ),
      
      h4(
        textOutput("month_label")
      ),
      
      selectInput(
        "region",
        "Region:",
        choices = region_choices,
        selected = default_region
      ),
      
      hr(),
      
      p(
        "Eine Region auf einer der beiden Karten anklicken, ",
        "um die Detailansicht zu aktualisieren."
      ),
      
      p(
        "Fallrate: gemeldete Faelle je 100.000 Personen ",
        "der ausgewaehlten Alterskategorie."
      ),
      
      p(
        "Dichte: Gesamtbevoelkerung je km² im ausgewaehlten Jahr. ",
        "Sie ist unabhaengig von der Altersauswahl."
      ),
      
      hr(),
      
      tags$small(
        "Wochen werden vollstaendig dem Monat ihres ",
        "Startdatums zugeordnet. Die Monatswerte sind ",
        "daher keine exakten Kalendermonatswerte."
      ),
      
      br(),
      br(),
      
      tags$small(
        "Die Kategorie 'Alle bekannten Alterskategorien' ",
        "schliesst Faelle mit unbekanntem Alter aus."
      ),
      
      br(),
      br(),
      
      tags$small(
        paste0(
          estimate_count,
          " fehlende Bevoelkerungswerte wurden ",
          "durch lineare Interpolation oder den ",
          "naechsten verfuegbaren Jahreswert ergaenzt."
        )
      ),
      
      br(),
      br(),
      
      tags$small(
        "Die Flaechen wurden aus vereinfachten Grenzen ",
        "vom 31.12.2023 berechnet. ",
        "Berliner Bezirke sind zusammengefasst."
      )
    ),
    
    mainPanel(
      width = 9,
      
      div(
        class = "main-panel-box",
        
        fluidRow(
          
          column(
            6,
            
            h4(
              "Monatliche gemeldete Fallrate"
            ),
            
            leafletOutput(
              "rate_map",
              height = "480px"
            )
          ),
          
          column(
            6,
            
            h4(
              "Bevoelkerungsdichte"
            ),
            
            leafletOutput(
              "density_map",
              height = "480px"
            )
          )
        )
      ),
      
      div(
        class = "main-panel-box",
        
        h4(
          textOutput("selected_label")
        ),
        
        tableOutput(
          "region_summary"
        )
      ),
      
      div(
        class = "main-panel-box",
        
        fluidRow(
          
          column(
            6,
            
            h4(
              "Zeitlicher Verlauf"
            ),
            
            plotOutput(
              "trend",
              height = "310px"
            )
          ),
          
          column(
            6,
            
            h4(
              "Dichte und gemeldete Fallrate"
            ),
            
            plotOutput(
              "scatter",
              height = "310px"
            )
          )
        )
      ),
      
      p(
        tags$small(
          "Die Darstellung ist deskriptiv. ",
          "Unterschiede in Testung und Meldung ",
          "koennen die beobachteten Fallraten beeinflussen. ",
          "Geodaten: BKG / GeoJSON Utilities, dl-de/by-2-0."
        )
      )
    )
  )
)

# ------------------------------------------------------------
# Server
# ------------------------------------------------------------

server <- function(input, output, session) {
  
  # ----------------------------------------------------------
  # Aktuelle Auswahl
  # ----------------------------------------------------------
  
  selected_month <- reactive({
    req(input$month_index)
    
    month_position <- match(
      input$month_index,
      format(months, "%m/%Y")
    )
    
    req(!is.na(month_position))
    
    months[month_position]
  })
  
  selected_name <- reactive({
    
    req(input$region)
    
    map_regions$region_name[
      match(
        input$region,
        map_regions$geo_code
      )
    ]
  })
  
  current_data <- reactive({
    
    req(input$age)
    
    indicators %>%
      filter(
        age_group == input$age,
        month == selected_month()
      )
  })
  
  current_map <- reactive({
    
    map_regions %>%
      left_join(
        current_data(),
        by = "geo_code"
      )
  })
  
  output$month_label <- renderText({
    
    format(
      selected_month(),
      "%m/%Y"
    )
  })
  
  output$selected_label <- renderText({
    
    paste0(
      selected_name(),
      " [",
      input$region,
      "]"
    )
  })
  
  # ----------------------------------------------------------
  # Grundkarten erstellen
  # ----------------------------------------------------------
  
  create_base_map <- function() {
    
    leaflet(
      options = leafletOptions(
        minZoom = 4
      )
    ) %>%
      addTiles() %>%
      fitBounds(
        lng1 = 5.8,
        lat1 = 47.2,
        lng2 = 15.1,
        lat2 = 55.1
      )
  }
  
  output$rate_map <- renderLeaflet({
    create_base_map()
  })
  
  output$density_map <- renderLeaflet({
    create_base_map()
  })
  
  # ----------------------------------------------------------
  # Karten aktualisieren
  # ----------------------------------------------------------
  
  observe({
    
    dat <- current_map()
    
    rate_tooltips <- lapply(
      seq_len(nrow(dat)),
      function(i) {
        
        HTML(
          paste0(
            "<strong>",
            htmlEscape(dat$region_name[i]),
            "</strong>",
            "<br>AGS: ",
            dat$geo_code[i],
            "<br>Faelle: ",
            format_number(dat$cases[i]),
            "<br>Je 100.000: ",
            format_number(dat$rate[i], 1),
            "<br>Bevoelkerung ergaenzt: ",
            yes_no(dat$population_estimated[i])
          )
        )
      }
    )
    
    density_tooltips <- lapply(
      seq_len(nrow(dat)),
      function(i) {
        
        HTML(
          paste0(
            "<strong>",
            htmlEscape(dat$region_name[i]),
            "</strong>",
            "<br>AGS: ",
            dat$geo_code[i],
            "<br>Personen je km²: ",
            format_number(dat$density[i], 1),
            "<br>Bevoelkerung teilweise ergaenzt: ",
            yes_no(
              dat$density_population_estimated[i]
            )
          )
        )
      }
    )
    
    border_colors <- ifelse(
      dat$geo_code == input$region,
      "#00A676",
      "#FFFFFF"
    )
    
    border_weights <- ifelse(
      dat$geo_code == input$region,
      3,
      0.7
    )
    
    leafletProxy(
      "rate_map",
      data = dat
    ) %>%
      clearShapes() %>%
      clearControls() %>%
      addPolygons(
        layerId = ~geo_code,
        fillColor = ~rate_palette(rate),
        fillOpacity = 0.85,
        color = border_colors,
        weight = border_weights,
        label = rate_tooltips,
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#333333",
          bringToFront = TRUE
        )
      ) %>%
      addLegend(
        colors = c(
          rate_colors,
          "#BDBDBD"
        ),
        labels = c(
          rate_labels,
          "Keine Daten"
        ),
        title = "Faelle je 100.000",
        position = "bottomright",
        opacity = 0.9
      )
    
    leafletProxy(
      "density_map",
      data = dat
    ) %>%
      clearShapes() %>%
      clearControls() %>%
      addPolygons(
        layerId = ~geo_code,
        fillColor = ~density_palette(density),
        fillOpacity = 0.85,
        color = border_colors,
        weight = border_weights,
        label = density_tooltips,
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#333333",
          bringToFront = TRUE
        )
      ) %>%
      addLegend(
        colors = c(
          density_colors,
          "#BDBDBD"
        ),
        labels = c(
          density_labels,
          "Keine Daten"
        ),
        title = "Personen je km²",
        position = "bottomright",
        opacity = 0.9
      )
  })
  
  # ----------------------------------------------------------
  # Regionsauswahl durch Kartenklick aktualisieren
  # ----------------------------------------------------------
  
  observeEvent(
    input$rate_map_shape_click,
    {
      
      clicked_id <- input$rate_map_shape_click$id
      
      if (
        !is.null(clicked_id) &&
        clicked_id %in% map_regions$geo_code
      ) {
        
        updateSelectInput(
          session,
          "region",
          selected = clicked_id
        )
      }
    }
  )
  
  observeEvent(
    input$density_map_shape_click,
    {
      
      clicked_id <- input$density_map_shape_click$id
      
      if (
        !is.null(clicked_id) &&
        clicked_id %in% map_regions$geo_code
      ) {
        
        updateSelectInput(
          session,
          "region",
          selected = clicked_id
        )
      }
    }
  )
  
  # ----------------------------------------------------------
  # Kennzahlen der ausgewaehlten Region
  # ----------------------------------------------------------
  
  output$region_summary <- renderTable({
    
    dat <- current_data() %>%
      filter(
        geo_code == input$region
      )
    
    req(nrow(dat) == 1)
    
    data.frame(
      Kennzahl = c(
        "Monat",
        "Alterskategorie",
        "Gemeldete Faelle",
        "Bevoelkerung der Altersauswahl",
        "Fallrate je 100.000",
        "Gesamtbevoelkerung",
        "Personen je km²",
        "Bevoelkerung der Altersauswahl ergaenzt",
        "Gesamtbevoelkerung teilweise ergaenzt"
      ),
      
      Wert = c(
        format(
          selected_month(),
          "%m/%Y"
        ),
        
        names(age_choices)[
          match(
            input$age,
            unname(age_choices)
          )
        ],
        
        format_number(dat$cases),
        
        format_number(dat$population),
        
        format_number(dat$rate, 1),
        
        format_number(dat$total_population),
        
        format_number(dat$density, 1),
        
        yes_no(dat$population_estimated),
        
        yes_no(
          dat$density_population_estimated
        )
      ),
      
      check.names = FALSE
    )
    
  },
  striped = TRUE,
  bordered = FALSE,
  spacing = "s"
  )
  
  # ----------------------------------------------------------
  # Regionalen Verlauf mit Deutschland vergleichen
  # ----------------------------------------------------------
  
  output$trend <- renderPlot({
    
    regional <- indicators %>%
      filter(
        geo_code == input$region,
        age_group == input$age
      ) %>%
      arrange(month)
    
    germany <- national %>%
      filter(
        age_group == input$age
      ) %>%
      arrange(month)
    
    req(
      nrow(regional) > 0,
      nrow(germany) > 0
    )
    
    upper <- max(
      c(
        regional$rate,
        germany$rate,
        1
      ),
      na.rm = TRUE
    )
    
    par(
      mar = c(4.2, 4.6, 1, 1)
    )
    
    plot(
      regional$month,
      regional$rate,
      type = "n",
      ylim = c(
        0,
        upper * 1.12
      ),
      xlab = "Monat",
      ylab = "Gemeldete Faelle je 100.000"
    )
    
    grid(
      nx = NA,
      ny = NULL,
      col = "#EEEEEE"
    )
    
    lines(
      regional$month,
      regional$rate,
      col = "#D95F02",
      lwd = 2
    )
    
    lines(
      germany$month,
      germany$rate,
      col = "#276FBF",
      lwd = 2
    )
    
    estimated <- regional$population_estimated
    
    points(
      regional$month[estimated],
      regional$rate[estimated],
      pch = 1,
      col = "#D95F02",
      cex = 0.8
    )
    
    abline(
      v = as.numeric(
        selected_month()
      ),
      lty = 2,
      col = "#555555"
    )
    
    selected <- regional %>%
      filter(
        month == selected_month()
      )
    
    points(
      selected$month,
      selected$rate,
      pch = 19,
      col = "#D95F02",
      cex = 1.2
    )
    
    legend(
      "topright",
      legend = c(
        selected_name(),
        "Deutschland",
        "Regionaler Nenner ergaenzt"
      ),
      col = c(
        "#D95F02",
        "#276FBF",
        "#D95F02"
      ),
      lty = c(
        1,
        1,
        NA
      ),
      pch = c(
        NA,
        NA,
        1
      ),
      lwd = c(
        2,
        2,
        NA
      ),
      bty = "n",
      cex = 0.75
    )
  })
  
  # ----------------------------------------------------------
  # Dichte und Fallrate aller Regionen darstellen
  # ----------------------------------------------------------
  
  output$scatter <- renderPlot({
    
    dat <- current_data() %>%
      filter(
        is.finite(density),
        density > 0,
        is.finite(rate)
      )
    
    selected <- dat %>%
      filter(
        geo_code == input$region
      )
    
    validate(
      need(
        nrow(dat) > 0,
        "Keine gueltigen Daten vorhanden."
      )
    )
    
    upper <- max(
      c(dat$rate, 1)
    )
    
    estimated <- dat$population_estimated |
      dat$density_population_estimated
    
    par(
      mar = c(4.2, 4.6, 1, 1)
    )
    
    plot(
      dat$density,
      dat$rate,
      log = "x",
      type = "n",
      ylim = c(
        0,
        upper * 1.12
      ),
      xlab = "Personen je km² (logarithmisch)",
      ylab = "Gemeldete Faelle je 100.000"
    )
    
    grid(
      nx = NA,
      ny = NULL,
      col = "#EEEEEE"
    )
    
    points(
      dat$density[!estimated],
      dat$rate[!estimated],
      pch = 16,
      col = adjustcolor(
        "#426A8C",
        alpha.f = 0.5
      )
    )
    
    points(
      dat$density[estimated],
      dat$rate[estimated],
      pch = 1,
      col = "#426A8C"
    )
    
    if (nrow(selected) == 1) {
      
      points(
        selected$density,
        selected$rate,
        pch = 21,
        bg = "#D95F02",
        col = "#222222",
        cex = 1.8
      )
    }
    
    legend(
      "topright",
      legend = c(
        "Ohne zusaetzliche Ergaenzung",
        "Bevoelkerung teilweise ergaenzt",
        selected_name()
      ),
      pch = c(
        16,
        1,
        21
      ),
      col = c(
        "#426A8C",
        "#426A8C",
        "#222222"
      ),
      pt.bg = c(
        "#426A8C",
        NA,
        "#D95F02"
      ),
      bty = "n",
      cex = 0.7
    )
  })
}

# ------------------------------------------------------------
# Anwendung starten
# ------------------------------------------------------------

shinyApp(
  ui = ui,
  server = server
)