library(dplyr)
library(readxl)

# 1. Locate exactly one source file
find_source <- function(pattern) {
  paths <- list.files(
    "data_raw",
    pattern = pattern,
    full.names = TRUE,
    recursive = TRUE
  )
  
  paths <- paths[!startsWith(basename(paths), "~$")]
  
  if (length(paths) != 1L) {
    stop(
      "Expected exactly one file matching: ",
      pattern,
      "; found ",
      length(paths),
      "."
    )
  }
  
  paths[[1]]
}

# 2. Normalize district codes from BBSR reference tables
normalize_bbsr_code <- function(x) {
  x <- trimws(as.character(x))
  
  stopifnot(
    !anyNA(x),
    all(grepl("^[0-9]{1,8}$", x))
  )
  
  substr(
    sprintf("%08d", as.integer(x)),
    1, 5
  )
}

# 3. Read the cleaned annual population
population <- readRDS(
  "data_processed/population_kreis_2020_2024.rds"
) %>%
  as.data.frame() %>%
  ungroup()

stopifnot(
  all(
    c(
      "geo_code", "geo_name", "year", "population_total"
    ) %in% names(population)
  )
)

population <- population %>%
  mutate(
    geo_code = trimws(as.character(geo_code)),
    year = as.integer(year)
  )

stopifnot(
  !anyNA(population$geo_code),
  all(grepl("^[0-9]{1,5}$", population$geo_code))
)

population <- population %>%
  mutate(
    geo_code = sprintf("%05d", as.integer(geo_code))
  )

stopifnot(
  nrow(population) == 2000L,
  setequal(population$year, 2020:2024),
  all(table(population$year) == 400L),
  nrow(distinct(population, geo_code, year)) == 2000L,
  !anyNA(population$geo_name),
  all(is.finite(population$population_total)),
  all(population$population_total > 0)
)

# 4. Read one 2020 classification CSV
read_type_2020 <- function(pattern, value_column) {
  raw <- read.csv(
    find_source(pattern),
    sep = ";",
    header = TRUE,
    colClasses = "character",
    fileEncoding = "Windows-1252",
    check.names = FALSE
  )
  
  stopifnot(ncol(raw) >= 4L)
  
  result <- tibble(
    source_code = trimws(raw[[1]]),
    category_code = trimws(raw[[3]])
  ) %>%
    filter(
      !is.na(source_code),
      grepl("^[0-9]{1,8}$", source_code)
    ) %>%
    transmute(
      geo_code = normalize_bbsr_code(source_code),
      category_code = as.integer(category_code)
    )
  
  stopifnot(
    nrow(result) == 401L,
    n_distinct(result$geo_code) == 401L,
    all(result$category_code %in% 1:4)
  )
  
  # Harmonize Eisenach and Wartburgkreis.
  # Stop if their classifications conflict.
  result <- result %>%
    mutate(
      geo_code = if_else(
        geo_code == "16056", "16063", geo_code
      )
    )
  
  conflicts <- result %>%
    group_by(geo_code) %>%
    summarise(
      categories = n_distinct(category_code),
      .groups = "drop"
    ) %>%
    filter(categories != 1L)
  
  if (nrow(conflicts) > 0L) {
    stop(
      "Conflicting 2020 categories after geographic harmonization: ",
      value_column
    )
  }
  
  result <- result %>%
    distinct(geo_code, category_code)
  
  names(result)[names(result) == "category_code"] <- value_column
  
  stopifnot(nrow(result) == 400L)
  
  result
}

# 5. Combine the two 2020 classification tables
kreistyp_2020 <- read_type_2020(
  "^siedlungsstrukt-kreistypen-2020.*\\.csv$",
  "kreistyp_code"
)

raumtyp_2020 <- read_type_2020(
  "^raumtypen-lage-2020.*\\.csv$",
  "raumtyp_lage_code"
)

stopifnot(
  setequal(kreistyp_2020$geo_code, raumtyp_2020$geo_code)
)

types_2020 <- kreistyp_2020 %>%
  left_join(raumtyp_2020, by = "geo_code") %>%
  mutate(year = 2020L)

# 6. Read KTU and RLK from each annual Excel file
read_annual_types <- function(y) {
  raw <- read_excel(
    find_source(
      paste0(
        "^raumgliederungen-referenzen-",
        y,
        ".*\\.xlsx$"
      )
    ),
    sheet = "Kreisreferenz",
    col_types = "text"
  )
  
  district_column <- paste0("KRS", y)
  kreistyp_column <- paste0("KTU", y)
  raumtyp_column <- paste0("RLK", y)
  
  stopifnot(
    all(
      c(
        district_column,
        kreistyp_column,
        raumtyp_column
      ) %in% names(raw)
    )
  )
  
  result <- raw %>%
    transmute(
      source_code = trimws(.data[[district_column]]),
      kreistyp_raw = trimws(.data[[kreistyp_column]]),
      raumtyp_raw = trimws(.data[[raumtyp_column]])
    ) %>%
    filter(
      !is.na(source_code),
      grepl("^[0-9]{1,8}$", source_code)
    ) %>%
    transmute(
      geo_code = normalize_bbsr_code(source_code),
      kreistyp_code = as.integer(kreistyp_raw),
      raumtyp_lage_code = as.integer(raumtyp_raw),
      year = as.integer(y)
    )
  
  stopifnot(
    nrow(result) == 400L,
    n_distinct(result$geo_code) == 400L,
    all(result$kreistyp_code %in% 1:4),
    all(result$raumtyp_lage_code %in% 1:4)
  )
  
  result
}

types_annual <- bind_rows(
  types_2020,
  bind_rows(lapply(2021:2024, read_annual_types))
)

stopifnot(
  nrow(types_annual) == 2000L,
  nrow(distinct(types_annual, geo_code, year)) == 2000L
)

# 7. Add consistent category labels
kreistyp_labels <- c(
  "Kreisfreie Großstädte",
  "Städtische Kreise",
  "Ländliche Kreise mit Verdichtungsansätzen",
  "Dünn besiedelte ländliche Kreise"
)

raumtyp_labels <- c(
  "sehr zentral",
  "zentral",
  "peripher",
  "sehr peripher"
)

types_annual <- types_annual %>%
  mutate(
    kreistyp_name = kreistyp_labels[kreistyp_code],
    raumtyp_lage_name = raumtyp_labels[raumtyp_lage_code]
  )

# 8. Check region-year matches in both directions
population_without_types <- population %>%
  anti_join(
    types_annual,
    by = c("geo_code", "year")
  )

types_without_population <- types_annual %>%
  anti_join(
    population,
    by = c("geo_code", "year")
  )

stopifnot(
  nrow(population_without_types) == 0L,
  nrow(types_without_population) == 0L
)

# 9. Build the annual regional table
regional_characteristics_2020_2024 <- population %>%
  select(geo_code, geo_name, year, population_total) %>%
  left_join(
    types_annual,
    by = c("geo_code", "year")
  ) %>%
  select(
    geo_code,
    geo_name,
    year,
    population_total,
    kreistyp_code,
    kreistyp_name,
    raumtyp_lage_code,
    raumtyp_lage_name
  ) %>%
  arrange(geo_code, year)

stopifnot(
  nrow(regional_characteristics_2020_2024) == 2000L,
  !anyNA(regional_characteristics_2020_2024),
  all(
    table(regional_characteristics_2020_2024$year) == 400L
  )
)

# 10. Save new outputs
dir.create("data_processed", showWarnings = FALSE)

saveRDS(
  regional_characteristics_2020_2024,
  "data_processed/population_Kreistyp_Raumtyp_2020_2024.rds"
)

