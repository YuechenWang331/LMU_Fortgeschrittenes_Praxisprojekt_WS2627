# Prepare GENESIS district area data;

library(readr)
library(dplyr)

# Read raw area data
area_kreis <- read_delim(
  "data_raw/11111-0002 Gebietsfläche nach Kreise.csv",
  delim = ";",
  col_types = cols(.default = col_character()),
  na = c("", "-"),
  show_col_types = FALSE
) %>%
  transmute(
    geo_code = `1_variable_attribute_code`,
    year = as.integer(substr(time, 1, 4)),
    area_km2 = parse_number(
      value,
      locale = locale(
        decimal_mark = ",",
        grouping_mark = "."
      )
    )
  ) %>%
  # Keep only 2023
  filter(year == 2023, !is.na(area_km2)) %>%
  select(geo_code, area_km2) %>%
  arrange(geo_code)

# Data quality checks
stopifnot(
  nrow(area_kreis) == 400,
  !anyDuplicated(area_kreis$geo_code),
  !anyNA(area_kreis),
  all(is.finite(area_kreis$area_km2)),
  all(area_kreis$area_km2 > 0)
)

# Save cleaned data
saveRDS(
  area_kreis,
  "data_processed/area_kreis_2023.rds"
)

