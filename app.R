library(shiny)
library(leaflet)
library(sf)
library(dplyr)

# ------------------------------------------------------------
# Daten einlesen
# ------------------------------------------------------------

map_kreise <- st_read(
  "data_geo/landkreise_simplify200.geojson",
  quiet = TRUE
) %>%
  filter(GF == 4) %>%
  mutate(
    geo_code = as.character(AGS),
    region_label = paste0(GEN, " (", BEZ, ")")
  ) %>%
  select(geo_code, region_label) %>%
  st_transform(4326)

monthly_data <- readRDS(
  "data_processed/monthly_map_data.rds"
)

months <- sort(unique(monthly_data$month))

age_choices <- c(
  setNames(as.character(0:79), paste0(0:79, " Jahre")),
  "80 Jahre und aelter" = "80+",
  "Alter unbekannt" = "NA"
)

# ------------------------------------------------------------
# Benutzeroberflaeche
# ------------------------------------------------------------

ui <- fluidPage(
  titlePanel("COVID-19: Monatliche Fallzahlen"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput(
        "age",
        "Alter:",
        choices = age_choices,
        selected = "80+"
      ),
      
      sliderInput(
        "month_index",
        "Monat:",
        min = 1,
        max = length(months),
        value = match(as.Date("2022-03-01"), months),
        step = 1,
        animate = animationOptions(
          interval = 1500,
          loop = FALSE
        ),
        sep = ""
      ),
      
      strong(textOutput("month_label")),
      
      hr(),
      
      helpText(
        "Die Farben zeigen gemeldete Fallzahlen,",
        "keine bevoelkerungsbezogene Inzidenz."
      ),
      
      helpText(
        "Wochen werden nach ihrem Startdatum",
        "einem Monat zugeordnet.",
        "Berlin: Summe der 12 Bezirke."
      ),
      
      helpText(
        "Feste Farbklassen fuer alle Monate und Alterskategorien.",
        "Grau bedeutet: keine Daten."
      )
    ),
    
    mainPanel(
      leafletOutput("map", height = "600px"),
      h4(textOutput("selected_region")),
      plotOutput("trend", height = "260px")
    )
  ),
  
  tags$small(
    "Geometrie: GeoBasis-DE / BKG 2023, vereinfacht; ",
    tags$a(
      "GeoJSON Utilities",
      href = "https://geodata.bw-im.de/src/",
      target = "_blank"
    ),
    ". ",
    tags$a(
      "dl-de/by-2-0",
      href = "https://www.govdata.de/dl-de/by-2-0",
      target = "_blank"
    )
  )
)

# ------------------------------------------------------------
# Server
# ------------------------------------------------------------

server <- function(input, output, session) {
  
  selected_code <- reactiveVal("09162")
  
  selected_month <- reactive({
    months[as.integer(input$month_index)]
  })
  
  map_values <- reactive({
    monthly_data %>%
      filter(
        age_group == input$age,
        month == selected_month()
      )
  })
  
  palette <- colorBin(
    palette = "YlOrRd",
    domain = monthly_data$cases,
    bins = c(0, 1, 10, 50, 100, 500, 1000, 5000, Inf),
    right = FALSE,
    na.color = "#bdbdbd"
  )
  
  output$month_label <- renderText({
    format(selected_month(), "%m/%Y")
  })
  
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      fitBounds(5.8, 47.2, 15.1, 55.1)
  })
  
  observe({
    current_map <- map_kreise %>%
      left_join(map_values(), by = "geo_code") %>%
      mutate(
        cases_label = if_else(
          is.na(cases),
          "Keine Daten",
          format(
            cases,
            big.mark = ".",
            decimal.mark = ",",
            scientific = FALSE,
            trim = TRUE
          )
        ),
        hover_label = paste0(
          region_label,
          ": ",
          cases_label,
          " Faelle"
        )
      )
    
    leafletProxy("map", data = current_map) %>%
      clearShapes() %>%
      clearControls() %>%
      addPolygons(
        layerId = ~geo_code,
        fillColor = ~palette(cases),
        fillOpacity = 0.8,
        color = "white",
        weight = 0.7,
        label = ~hover_label,
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#238b45",
          bringToFront = TRUE
        )
      ) %>%
      addLegend(
        position = "bottomright",
        pal = palette,
        values = monthly_data$cases,
        title = "Gemeldete Faelle",
        opacity = 0.8
      )
  })
  
  observeEvent(input$map_shape_click, {
    selected_code(input$map_shape_click$id)
  })
  
  output$selected_region <- renderText({
    region_name <- map_kreise$region_label[
      match(selected_code(), map_kreise$geo_code)
    ]
    
    paste0(
      region_name,
      " | ",
      names(age_choices)[match(input$age, age_choices)]
    )
  })
  
  output$trend <- renderPlot({
    trend_data <- monthly_data %>%
      filter(
        geo_code == selected_code(),
        age_group == input$age
      ) %>%
      arrange(month)
    
    req(nrow(trend_data) > 0)
    
    plot(
      trend_data$month,
      trend_data$cases,
      type = "l",
      lwd = 2,
      col = "#2171b5",
      xlab = "Monat",
      ylab = "Gemeldete Faelle",
      ylim = c(0, max(1, trend_data$cases, na.rm = TRUE))
    )
    
    abline(
      v = as.numeric(selected_month()),
      col = "#e6550d",
      lty = 2,
      lwd = 2
    )
  })
}

shinyApp(ui, server)