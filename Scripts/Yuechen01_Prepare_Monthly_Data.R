library(dplyr)

# ------------------------------------------------------------
# Woechentliche Fallzahlen einlesen
# ------------------------------------------------------------

covid_raw <- readRDS(
  "data_raw/Count_COVID_LK_Week_RKI_2020_2024.RData"
)

dim(covid_raw)


# ------------------------------------------------------------
# Wochen anhand ihres Startdatums einem Monat zuordnen
# ------------------------------------------------------------

week_labels <- dimnames(covid_raw)[[3]]

week_lookup <- data.frame(
  week_index = seq_along(week_labels),
  week_label = week_labels,
  week_start = as.Date(substr(week_labels, 1, 10)),
  stringsAsFactors = FALSE
)

week_lookup <- week_lookup %>%
  mutate(
    month = as.Date(format(week_start, "%Y-%m-01"))
  )

View(week_lookup)

# ------------------------------------------------------------
# Fallzahlen je Alterskategorie, Gebiet und Monat summieren
# ------------------------------------------------------------

month_values <- sort(unique(week_lookup$month))

monthly_cases <- array(
  NA_real_,
  dim = c(
    dim(covid_raw)[1],
    dim(covid_raw)[2],
    length(month_values)
  ),
  dimnames = list(
    age_group = dimnames(covid_raw)[[1]],
    district = dimnames(covid_raw)[[2]],
    month = as.character(month_values)
  )
)

for (m in seq_along(month_values)) {
  
  week_indices <- which(
    week_lookup$month == month_values[m]
  )
  
  monthly_cases[, , m] <- apply(
    covid_raw[, , week_indices, drop = FALSE],
    MARGIN = c(1, 2),
    FUN = sum
  )
}

dim(monthly_cases)


# ------------------------------------------------------------
# Gesamtsumme vor und nach der Aggregation vergleichen
# ------------------------------------------------------------

stopifnot(
  isTRUE(all.equal(
    sum(covid_raw),
    sum(monthly_cases)
  ))
)

# ------------------------------------------------------------
# Erstes Gebiet fuer die Alterskategorie 0 anzeigen
# ------------------------------------------------------------

monthly_example <- data.frame(
  month = month_values,
  district = dimnames(monthly_cases)[[2]][1],
  age_group = "0",
  cases = as.numeric(monthly_cases["0", 1, ])
)

View(monthly_example)




# ------------------------------------------------------------
# Alle Alterskategorien, Gebiete und Monate als Tabelle ausgeben
# ------------------------------------------------------------

monthly_data <- expand.grid(
  age_group = dimnames(monthly_cases)[[1]],
  district_index = seq_len(dim(monthly_cases)[2]),
  month = dimnames(monthly_cases)[[3]],
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)

monthly_data$district <- dimnames(monthly_cases)[[2]][
  monthly_data$district_index
]

monthly_data$cases <- as.vector(monthly_cases)

monthly_data <- monthly_data %>%
  mutate(month = as.Date(month)) %>%
  select(
    district_index,
    district,
    age_group,
    month,
    cases
  ) %>%
  arrange(district_index, age_group, month)

View(monthly_data)


# ------------------------------------------------------------
# Vollstaendigkeit der Tabelle pruefen
# ------------------------------------------------------------

monthly_data %>%
  summarise(
    regions = n_distinct(district_index),
    age_categories = n_distinct(age_group),
    months = n_distinct(month),
    rows = n()
  )

stopifnot(
  isTRUE(all.equal(
    sum(monthly_data$cases),
    sum(monthly_cases)
  ))
)


# ------------------------------------------------------------
# Gebietsschluessel als Text einlesen
# ------------------------------------------------------------

county_lookup_raw <- readr::read_delim(
  "data_raw/CountyKey71Map.csv",
  delim = NULL,
  col_types = readr::cols(
    .default = readr::col_character()
  ),
  show_col_types = FALSE
)

names(county_lookup_raw)

View(head(county_lookup_raw, 10))



# ------------------------------------------------------------
# Reihenfolge der Gebiete im Fallzahlen-Array anzeigen
# ------------------------------------------------------------

array_regions <- data.frame(
  district_index = seq_len(dim(covid_raw)[2]),
  district = dimnames(covid_raw)[[2]],
  stringsAsFactors = FALSE
)

View(head(array_regions, 10))


# ------------------------------------------------------------
# Monatliche Fallzahlen fuer die Shiny-Anwendung speichern
# ------------------------------------------------------------

dir.create(
  "data_processed",
  showWarnings = FALSE
)

saveRDS(
  monthly_data,
  "data_processed/monthly_cases.rds"
)

# ------------------------------------------------------------
# Gebietsschluessel vorbereiten und Array-Reihenfolge pruefen
# ------------------------------------------------------------

library(dplyr)
library(stringr)
library(sf)

county_lookup <- county_lookup_raw %>%
  transmute(
    district_index = as.integer(region_position),
    lookup_name = Name,
    geo_code = str_extract(ComponentId, "[0-9]{5}")
  ) %>%
  arrange(district_index)

stopifnot(
  nrow(county_lookup) == dim(covid_raw)[2],
  !anyNA(county_lookup),
  !anyDuplicated(county_lookup$district_index),
  !anyDuplicated(county_lookup$geo_code),
  identical(
    county_lookup$district_index,
    seq_len(dim(covid_raw)[2])
  ),
  identical(
    as.character(county_lookup$lookup_name),
    as.character(dimnames(covid_raw)[[2]])
  )
)

# ------------------------------------------------------------
# Monatliche Fallzahlen mit Gebietsschluesseln verknuepfen
# ------------------------------------------------------------

monthly_with_codes <- monthly_data %>%
  left_join(
    county_lookup %>% select(district_index, geo_code),
    by = "district_index"
  )

stopifnot(
  nrow(monthly_with_codes) == nrow(monthly_data),
  !anyNA(monthly_with_codes$geo_code),
  sum(startsWith(county_lookup$geo_code, "11")) == 12
)

# ------------------------------------------------------------
# Berliner Bezirke je Alter und Monat zusammenfassen
# ------------------------------------------------------------

monthly_map_data <- monthly_with_codes %>%
  mutate(
    geo_code = if_else(
      startsWith(geo_code, "11"),
      "11000",
      geo_code
    )
  ) %>%
  group_by(geo_code, age_group, month) %>%
  summarise(
    cases = sum(cases),
    .groups = "drop"
  )

stopifnot(
  isTRUE(all.equal(
    sum(monthly_map_data$cases),
    sum(monthly_data$cases)
  ))
)

# ------------------------------------------------------------
# Gebietsschluessel mit der Karte vergleichen
# ------------------------------------------------------------

map_check <- st_read(
  "data_geo/landkreise_simplify200.geojson",
  quiet = TRUE
) %>%
  filter(GF == 4) %>%
  mutate(geo_code = as.character(AGS))

missing_on_map <- setdiff(
  unique(monthly_map_data$geo_code),
  map_check$geo_code
)

missing_in_data <- setdiff(
  map_check$geo_code,
  unique(monthly_map_data$geo_code)
)

print(missing_on_map)
print(missing_in_data)

stopifnot(
  !anyDuplicated(map_check$geo_code),
  length(missing_on_map) == 0,
  length(missing_in_data) == 0
)

# ------------------------------------------------------------
# Randmonat ausschliessen und Ergebnis speichern
# ------------------------------------------------------------

monthly_map_data <- monthly_map_data %>%
  filter(month >= as.Date("2020-01-01"))

monthly_map_data %>%
  summarise(
    regions = n_distinct(geo_code),
    age_categories = n_distinct(age_group),
    months = n_distinct(month),
    rows = n()
  )

dir.create("data_processed", showWarnings = FALSE)

saveRDS(
  monthly_map_data,
  "data_processed/monthly_map_data.rds"
)
