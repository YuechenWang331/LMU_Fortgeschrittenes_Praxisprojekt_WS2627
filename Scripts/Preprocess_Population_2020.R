library(dplyr)
library(readxl)


# Read the official 2020 population table
raw_2020 <- read_excel(
  "data_raw/12411-0016_de 2020.xlsx",
  sheet = "12411-0016",
  skip = 6,
  col_names = FALSE,
  col_types = "text",
  .name_repair = "minimal"
)

names(raw_2020) <- paste0("col", seq_len(ncol(raw_2020)))

# Extract district codes, names and total population
population_source <- raw_2020 %>%
  transmute(
    geo_code = trimws(col1),
    geo_name = col2,
    population_text = col7
  ) %>%
  filter(grepl("^[0-9]{5}$", geo_code)) %>%
  mutate(
    population_total = as.numeric(population_text)
  ) %>%
  select(-population_text)

stopifnot(
  nrow(population_source) == 401L,
  n_distinct(population_source$geo_code) == 401L,
  all(is.finite(population_source$population_total)),
  all(population_source$population_total > 0)
)

# Merge Eisenach into Wartburgkreis
population_2020 <- population_source %>%
  mutate(
    geo_code = if_else(
      geo_code == "16056", "16063", geo_code
    ),
    geo_name = if_else(
      geo_code == "16063", "Wartburgkreis", geo_name
    )
  ) %>%
  group_by(geo_code) %>%
  summarise(
    geo_name = first(geo_name),
    population_total = sum(population_total),
    .groups = "drop"
  ) %>%
  mutate(year = 2020L) %>%
  select(geo_code, geo_name, year, population_total) %>%
  arrange(geo_code)

# Validate the cleaned data
stopifnot(
  nrow(population_2020) == 400L,
  n_distinct(population_2020$geo_code) == 400L,
  sum(population_2020$population_total) ==
    sum(population_source$population_total),
  population_2020$population_total[
    population_2020$geo_code == "16063"
  ] == 159937
)

# Save the cleaned dataset
dir.create("data_processed", showWarnings = FALSE)

saveRDS(
  population_2020,
  "data_processed/population_kreis_2020_official.rds"
)
