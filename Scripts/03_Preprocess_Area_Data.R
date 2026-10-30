# Prepare GENESIS district area data;
library(readr)
library(dplyr)

area_kreis <- read_delim(
  "data_raw/11111-0002 Gebietsfläche nach Kreise.csv",
  delim = ";",
  col_types = cols(.default = col_character()),
  na = c("", "-"),
  show_col_types = FALSE
) %>%
  transmute(
    geo_code = `1_variable_attribute_code`,
    geo_name = `1_variable_attribute_label`,
    year = as.integer(substr(time, 1, 4)),
    area_km2 = parse_number(value, locale = locale(decimal_mark = ",", grouping_mark = "."))
  ) %>%
  filter(!is.na(area_km2)) %>%
  arrange(year, geo_code)

# Check the district-year key and the area values before saving.
stopifnot(
  !anyDuplicated(area_kreis[c("year", "geo_code")]),
  is.numeric(area_kreis$area_km2),
  !anyNA(area_kreis$area_km2)
)

print(count(area_kreis, year))
cat("Total:", nrow(area_kreis), "rows;", ncol(area_kreis), "columns\n")
saveRDS(area_kreis, "data_processed/area_kreis.rds")
