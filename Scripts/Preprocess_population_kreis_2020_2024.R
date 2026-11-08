library(dplyr)
library(readxl)


# Read and aggregate one annual BBSR reference file
read_annual_population <- function(year) {
  
  file_pattern <- paste0(
    "^raumgliederungen-referenzen-",
    year,
    ".*\\.xlsx$"
  )
  
  input_files <- list.files(
    "data_raw",
    pattern = file_pattern,
    full.names = TRUE,
    recursive = TRUE
  )
  
  input_files <- input_files[
    !startsWith(basename(input_files), "~$")
  ]
  
  if (length(input_files) != 1L) {
    stop(
      "Expected exactly one reference file for ",
      year,
      "; found ",
      length(input_files),
      "."
    )
  }
  
  # Skip the descriptive second header row
  raw <- read_excel(
    input_files[[1]],
    sheet = "Administrativ",
    col_types = "text",
    .name_repair = "minimal"
  )
  
  district_column <- paste0("KRS", year)
  population_column <- paste0("bev", substr(year, 3, 4))
  municipality_column <- paste0("GEM", year)
  
  required_columns <- c(
    district_column,
    population_column,
    municipality_column
  )
  
  if (!all(required_columns %in% names(raw))) {
    stop("Required columns are missing for ", year, ".")
  }
  
  source <- raw %>%
    transmute(
      municipality_code = trimws(.data[[municipality_column]]),
      district_code_raw = trimws(.data[[district_column]]),
      population_text = trimws(.data[[population_column]])
    ) %>%
    filter(
      !is.na(municipality_code),
      grepl("^[0-9]{1,8}$", municipality_code)
    )
  
  stopifnot(
    nrow(source) > 0L,
    !anyNA(source$district_code_raw),
    all(grepl("^[0-9]{1,8}$", source$district_code_raw))
  )
  
  source <- source %>%
    mutate(
      municipality_code = sprintf(
        "%08d", as.integer(municipality_code)
      ),
      geo_code = substr(
        sprintf("%08d", as.integer(district_code_raw)),
        1, 5
      ),
      population = as.numeric(population_text)
    )
  
  stopifnot(
    n_distinct(source$municipality_code) == nrow(source),
    all(is.finite(source$population)),
    all(source$population >= 0)
  )
  
  # Sum municipality populations within each district
  result <- source %>%
    group_by(geo_code) %>%
    summarise(
      population_total = sum(population),
      .groups = "drop"
    ) %>%
    mutate(year = as.integer(year)) %>%
    select(geo_code, year, population_total) %>%
    arrange(geo_code)
  
  stopifnot(
    nrow(result) == 400L,
    n_distinct(result$geo_code) == 400L,
    all(result$population_total > 0),
    sum(result$population_total) == sum(source$population),
    !("16056" %in% result$geo_code)
  )
  
  result
}

# Process 2021-2024
population_2021_2024 <- bind_rows(
  lapply(2021:2024, read_annual_population)
)

# Read the cleaned 2020 population
population_2020 <- readRDS(
  "data_processed/population_kreis_2020_official.rds"
)

stopifnot(
  nrow(population_2020) == 400L,
  n_distinct(population_2020$geo_code) == 400L,
  all(population_2020$year == 2020L)
)

# Check that district codes match the harmonized 2020 geography
reference_codes <- population_2020$geo_code

for (current_year in 2021:2024) {
  current_codes <- population_2021_2024 %>%
    filter(year == current_year) %>%
    pull(geo_code)
  
  stopifnot(setequal(current_codes, reference_codes))
}

# Use consistent district names from the cleaned 2020 table
district_names <- population_2020 %>%
  select(geo_code, geo_name)

population_2021_2024 <- population_2021_2024 %>%
  left_join(district_names, by = "geo_code") %>%
  select(geo_code, geo_name, year, population_total)

# Combine all five years
population_kreis_annual_official <- bind_rows(
  population_2020 %>%
    select(geo_code, geo_name, year, population_total),
  population_2021_2024
) %>%
  arrange(geo_code, year)

stopifnot(
  nrow(population_kreis_annual_official) == 2000L,
  nrow(
    distinct(
      population_kreis_annual_official,
      geo_code,
      year
    )
  ) == 2000L,
  all(is.finite(
    population_kreis_annual_official$population_total
  )),
  all(
    population_kreis_annual_official$population_total > 0
  ),
  !anyNA(population_kreis_annual_official$geo_name)
)

# Save each annual dataset
for (current_year in 2021:2024) {
  saveRDS(
    population_2021_2024 %>%
      filter(year == current_year),
    paste0(
      "data_processed/population_kreis_",
      current_year,
      "_official.rds"
    )
  )
}

# Save the combined annual dataset
saveRDS(
  population_kreis_annual_official,
  "data_processed/population_kreis_2020_2024.rds"
)
