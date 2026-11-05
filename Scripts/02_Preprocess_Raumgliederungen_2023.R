
# BBSR Raumgliederungen, Gebietsstand 31.12.2023

library(readxl)
library(dplyr)
library(stringr)

source_file <- "data_raw/raumgliederungen-referenzen-2023.xlsx"
output_file <- "data_processed/raumgliederungen_kreis_2023.rds"

# Read and clean the original data
raumgliederungen <- read_excel(
  source_file,
  sheet = "Kreisreferenz",
  col_types = "text"
) %>%
  slice(-1) %>%
  mutate(
    across(everything(), ~ na_if(str_trim(.x), ""))
  ) %>%
  filter(
    if_any(everything(), ~ !is.na(.x))
  ) %>%
  transmute(
    geo_code = str_sub(
      str_pad(KRS2023, 8, pad = "0"), 1, 5
    ),
    kreistyp_code = KTU2023,
    kreistyp_label = KTU_NAME,
    location_type_code = RLK2023,
    location_type_label = RLK_NAME,
    administrative_type_code = SLK2023,
    administrative_type_label = SLK_NAME
  ) %>%
  arrange(geo_code)

# Data quality checks
stopifnot(
  nrow(raumgliederungen) == 400,
  ncol(raumgliederungen) == 7,
  !anyDuplicated(raumgliederungen$geo_code),
  all(grepl("^[0-9]{5}$", raumgliederungen$geo_code)),
  !anyNA(raumgliederungen)
)

# Save cleaned dataset
saveRDS(
  raumgliederungen,
  output_file
)

cat(
  "Saved", nrow(raumgliederungen),
  "districts with", ncol(raumgliederungen),
  "variables to", output_file, "\n"
)

