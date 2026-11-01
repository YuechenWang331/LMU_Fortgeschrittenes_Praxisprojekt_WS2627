library(dplyr)
library(stringr)
library(sf)

# ------------------------------------------------------------
# Monatliche Fallzahlen einlesen
# ------------------------------------------------------------

monthly_cases <- readRDS(
  "data_processed/monthly_map_data.rds"
) %>%
  mutate(
    geo_code = as.character(geo_code),
    age_group = as.character(age_group),
    month = as.Date(month),
    year = as.integer(format(month, "%Y"))
  )

stopifnot(
  all(c(
    "geo_code",
    "age_group",
    "month",
    "year",
    "cases"
  ) %in% names(monthly_cases)),
  
  !anyNA(
    monthly_cases[c(
      "geo_code",
      "age_group",
      "month",
      "year",
      "cases"
    )]
  ),
  
  all(is.finite(monthly_cases$cases)),
  all(monthly_cases$cases >= 0),
  
  !anyDuplicated(
    monthly_cases[c(
      "geo_code",
      "age_group",
      "month"
    )]
  )
)

dir.create(
  "data_processed",
  showWarnings = FALSE
)

# ------------------------------------------------------------
# Bekannte Alterskategorien auswaehlen
# ------------------------------------------------------------

known_age_cases <- monthly_cases %>%
  filter(age_group != "NA")

expected_ages <- c(
  as.character(0:79),
  "80+"
)

stopifnot(
  setequal(
    unique(known_age_cases$age_group),
    expected_ages
  )
)

# ------------------------------------------------------------
# RKI-Bevoelkerungsdaten einlesen
# ------------------------------------------------------------

population_raw <- readRDS(
  "data_raw/Count_Bev_LK_RKI_2020_2024.RData"
)

population_clean <- population_raw %>%
  ungroup() %>%
  transmute(
    geo_code = str_extract(
      as.character(geo_code),
      "[0-9]{5}(?=\\]$)"
    ),
    
    age_group = as.character(age_name),
    
    year = as.integer(year),
    
    population = as.numeric(population)
  )

stopifnot(
  !anyNA(population_clean),
  
  all(is.finite(population_clean$population)),
  
  all(population_clean$population > 0),
  
  !anyDuplicated(
    population_clean[c(
      "geo_code",
      "age_group",
      "year"
    )]
  ),
  
  setequal(
    unique(population_clean$age_group),
    expected_ages
  )
)

# ------------------------------------------------------------
# Berliner Bezirke zusammenfassen
# ------------------------------------------------------------

population_berlin <- population_clean %>%
  filter(startsWith(geo_code, "11")) %>%
  group_by(age_group, year) %>%
  summarise(
    districts = n_distinct(geo_code),
    .groups = "drop"
  )

stopifnot(
  nrow(population_berlin) ==
    length(expected_ages) *
    n_distinct(population_clean$year),
  
  all(population_berlin$districts == 12)
)

population_map_original <- population_clean %>%
  mutate(
    geo_code = if_else(
      startsWith(geo_code, "11"),
      "11000",
      geo_code
    )
  ) %>%
  group_by(geo_code, age_group, year) %>%
  summarise(
    population = sum(population),
    .groups = "drop"
  )

stopifnot(
  isTRUE(all.equal(
    sum(population_clean$population),
    sum(population_map_original$population)
  ))
)

# ------------------------------------------------------------
# Benoetigte Bevoelkerungskombinationen bestimmen
# ------------------------------------------------------------

population_keys <- known_age_cases %>%
  distinct(
    geo_code,
    age_group,
    year
  )

population_complete <- population_keys %>%
  left_join(
    population_map_original,
    by = c(
      "geo_code",
      "age_group",
      "year"
    )
  )

# ------------------------------------------------------------
# Fehlende Bevoelkerung und Fallzahlen dokumentieren
# ------------------------------------------------------------

missing_details <- known_age_cases %>%
  left_join(
    population_map_original,
    by = c(
      "geo_code",
      "age_group",
      "year"
    )
  ) %>%
  filter(is.na(population)) %>%
  group_by(geo_code, age_group, year) %>%
  summarise(
    months = n(),
    cases_total = sum(cases),
    .groups = "drop"
  )

print(missing_details, n = Inf)

print(
  missing_details %>%
    summarise(
      combinations = n(),
      regions = n_distinct(geo_code),
      combinations_with_cases = sum(cases_total > 0),
      cases_total = sum(cases_total)
    )
)

saveRDS(
  missing_details,
  "data_processed/missing_population_details.rds"
)

# ------------------------------------------------------------
# Fehlende Werte innerhalb einer Zeitreihe schaetzen
# ------------------------------------------------------------

estimate_population <- function(year, population) {
  
  available <- is.finite(population) &
    population > 0
  
  if (all(available)) {
    return(population)
  }
  
  if (sum(available) < 2) {
    return(population)
  }
  
  estimates <- approx(
    x = year[available],
    y = population[available],
    xout = year,
    method = "linear",
    rule = 2
  )$y
  
  result <- population
  
  result[!available] <- estimates[!available]
  
  result
}

# ------------------------------------------------------------
# Bevoelkerung ergaenzen und Methode kennzeichnen
# ------------------------------------------------------------

population_map <- population_complete %>%
  mutate(
    population_original = population,
    population_estimated = is.na(population)
  ) %>%
  group_by(geo_code, age_group) %>%
  arrange(year, .by_group = TRUE) %>%
  mutate(
    first_available_year = if (
      any(!is.na(population_original))
    ) {
      min(year[!is.na(population_original)])
    } else {
      NA_integer_
    },
    
    last_available_year = if (
      any(!is.na(population_original))
    ) {
      max(year[!is.na(population_original)])
    } else {
      NA_integer_
    },
    
    population = estimate_population(
      year,
      population_original
    ),
    
    population_method = case_when(
      !population_estimated ~ "original",
      
      is.na(population) ~ "unresolved",
      
      year < first_available_year |
        year > last_available_year ~ "nearest_year",
      
      TRUE ~ "linear_interpolation"
    )
  ) %>%
  ungroup() %>%
  select(
    -first_available_year,
    -last_available_year
  )

unresolved_population <- population_map %>%
  filter(
    is.na(population) |
      !is.finite(population) |
      population <= 0
  )

if (nrow(unresolved_population) > 0) {
  
  print(
    unresolved_population,
    n = Inf
  )
  
  stop(
    "Einige Bevoelkerungswerte konnten nicht ergaenzt werden."
  )
}

# ------------------------------------------------------------
# Unveraenderte Originalwerte pruefen
# ------------------------------------------------------------

original_rows <- !population_map$population_estimated

stopifnot(
  isTRUE(all.equal(
    population_map$population[original_rows],
    population_map$population_original[original_rows]
  )),
  
  !anyDuplicated(
    population_map[c(
      "geo_code",
      "age_group",
      "year"
    )]
  )
)

population_estimates <- population_map %>%
  filter(population_estimated) %>%
  select(
    geo_code,
    age_group,
    year,
    population_original,
    population,
    population_method
  )

print(
  population_estimates,
  n = Inf
)

print(
  population_estimates %>%
    count(
      population_method,
      name = "combinations"
    )
)

saveRDS(
  population_estimates,
  "data_processed/population_estimates.rds"
)

# ------------------------------------------------------------
# Karte einlesen und Geometrien vorbereiten
# ------------------------------------------------------------

map_regions <- st_read(
  "data_geo/landkreise_simplify200.geojson",
  quiet = TRUE
) %>%
  filter(GF == 4) %>%
  mutate(
    geo_code = str_pad(
      as.character(AGS),
      width = 5,
      side = "left",
      pad = "0"
    ),
    
    region_name = as.character(GEN)
  ) %>%
  select(
    geo_code,
    region_name
  ) %>%
  st_make_valid()

stopifnot(
  nrow(map_regions) == 400,
  !anyNA(map_regions$geo_code),
  !anyDuplicated(map_regions$geo_code),
  !any(st_is_empty(map_regions))
)

# ------------------------------------------------------------
# Gebietsschluessel zwischen Karte und Daten vergleichen
# ------------------------------------------------------------

missing_on_map <- setdiff(
  unique(known_age_cases$geo_code),
  map_regions$geo_code
)

missing_in_data <- setdiff(
  map_regions$geo_code,
  unique(known_age_cases$geo_code)
)

print(missing_on_map)
print(missing_in_data)

stopifnot(
  length(missing_on_map) == 0,
  length(missing_in_data) == 0
)

# ------------------------------------------------------------
# Flaechen aus den Grenzen von 2023 berechnen
# ------------------------------------------------------------

map_projected <- st_transform(
  map_regions,
  3035
)

area_table <- map_projected %>%
  st_drop_geometry() %>%
  select(geo_code)

area_table$area_km2 <- as.numeric(
  st_area(map_projected)
) / 1e6

stopifnot(
  all(is.finite(area_table$area_km2)),
  all(area_table$area_km2 > 0)
)

map_regions <- st_transform(
  map_regions,
  4326
)

# ------------------------------------------------------------
# Altersbezogene Fallraten berechnen
# ------------------------------------------------------------

age_indicators <- known_age_cases %>%
  left_join(
    population_map,
    by = c(
      "geo_code",
      "age_group",
      "year"
    )
  )

stopifnot(
  nrow(age_indicators) == nrow(known_age_cases),
  !anyNA(age_indicators$population),
  !anyNA(age_indicators$population_estimated)
)

age_indicators <- age_indicators %>%
  mutate(
    rate = cases / population * 100000
  )

stopifnot(
  isTRUE(all.equal(
    sum(age_indicators$cases),
    sum(known_age_cases$cases)
  ))
)

# ------------------------------------------------------------
# Vollstaendigkeit der Alterskategorien pruefen
# ------------------------------------------------------------

age_coverage <- age_indicators %>%
  group_by(geo_code, month) %>%
  summarise(
    age_categories = n_distinct(age_group),
    .groups = "drop"
  )

stopifnot(
  all(
    age_coverage$age_categories ==
      length(expected_ages)
  )
)

# ------------------------------------------------------------
# Gesamtwerte fuer bekannte Alterskategorien berechnen
# ------------------------------------------------------------

total_indicators <- age_indicators %>%
  group_by(geo_code, year, month) %>%
  summarise(
    cases = sum(cases),
    
    population = sum(population),
    
    population_estimated = any(
      population_estimated
    ),
    
    .groups = "drop"
  ) %>%
  mutate(
    age_group = "All",
    
    rate = cases / population * 100000,
    
    population_method = if_else(
      population_estimated,
      "aggregate_with_estimates",
      "original"
    )
  )

# ------------------------------------------------------------
# Gesamtbevoelkerung und Dichte berechnen
# ------------------------------------------------------------

density_table <- population_map %>%
  group_by(geo_code, year) %>%
  summarise(
    age_categories = n_distinct(age_group),
    
    total_population = sum(population),
    
    density_population_estimated = any(
      population_estimated
    ),
    
    .groups = "drop"
  ) %>%
  left_join(
    area_table,
    by = "geo_code"
  ) %>%
  mutate(
    density = total_population / area_km2
  )

stopifnot(
  all(
    density_table$age_categories ==
      length(expected_ages)
  ),
  
  !anyNA(density_table$density),
  
  all(is.finite(density_table$density)),
  
  all(density_table$density > 0)
)

density_table <- density_table %>%
  select(-age_categories)

# ------------------------------------------------------------
# Indikatoren fuer die Anwendung zusammenstellen
# ------------------------------------------------------------

map_indicators <- bind_rows(
  age_indicators,
  total_indicators
) %>%
  left_join(
    density_table,
    by = c(
      "geo_code",
      "year"
    )
  ) %>%
  arrange(
    geo_code,
    age_group,
    month
  )

stopifnot(
  !anyNA(map_indicators$population),
  
  !anyNA(map_indicators$density),
  
  !anyNA(map_indicators$population_estimated),
  
  all(is.finite(map_indicators$rate)),
  
  !anyDuplicated(
    map_indicators[c(
      "geo_code",
      "age_group",
      "month"
    )]
  ),
  
  setequal(
    unique(map_indicators$geo_code),
    map_regions$geo_code
  )
)

# ------------------------------------------------------------
# Nationale Vergleichswerte berechnen
# ------------------------------------------------------------

national_indicators <- map_indicators %>%
  group_by(age_group, month) %>%
  summarise(
    cases = sum(cases),
    
    population = sum(population),
    
    population_estimated = any(
      population_estimated
    ),
    
    .groups = "drop"
  ) %>%
  mutate(
    rate = cases / population * 100000
  )

# ------------------------------------------------------------
# Gesamtsummen ohne doppelte Altersaggregation pruefen
# ------------------------------------------------------------

stopifnot(
  isTRUE(all.equal(
    sum(
      map_indicators$cases[
        map_indicators$age_group != "All"
      ]
    ),
    sum(known_age_cases$cases)
  )),
  
  isTRUE(all.equal(
    sum(
      map_indicators$cases[
        map_indicators$age_group == "All"
      ]
    ),
    sum(known_age_cases$cases)
  ))
)

# ------------------------------------------------------------
# Zusammenfassung anzeigen
# ------------------------------------------------------------

print(
  map_indicators %>%
    summarise(
      regions = n_distinct(geo_code),
      age_categories = n_distinct(age_group),
      months = n_distinct(month),
      rows = n()
    )
)

print(
  map_indicators %>%
    select(
      geo_code,
      age_group,
      month,
      cases,
      population,
      population_estimated,
      rate,
      density
    ) %>%
    head()
)

# ------------------------------------------------------------
# Daten und Dokumentation speichern
# ------------------------------------------------------------

metadata <- list(
  month_assignment = "Entire weeks assigned by week start date",
  
  age_total = "All excludes cases with unknown age",
  
  population_source = "RKI population inferred via infer_population",
  
  population_missing_combinations = nrow(
    population_estimates
  ),
  
  population_estimation = paste(
    "Linear interpolation within available years;",
    "nearest available year outside the observed range"
  ),
  
  density_area = paste(
    "Area calculated in EPSG:3035",
    "from simplified boundaries dated 2023-12-31"
  )
)

saveRDS(
  list(
    map = map_regions,
    indicators = map_indicators,
    national = national_indicators,
    population_estimates = population_estimates,
    metadata = metadata
  ),
  "data_processed/map_dashboard_data.rds"
)

message(
  "Fertig: data_processed/map_dashboard_data.rds"
)

