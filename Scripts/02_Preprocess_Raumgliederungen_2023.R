# BBSR Laufende Raumbeobachtung, territorial status 31 December 2023.
# Run from the project root. The workbook's second row describes the variables.
library(readxl)
library(dplyr)
library(stringr)

source_file <- "data_raw/raumgliederungen-referenzen-2023.xlsx"
output_file <- "data_processed/raumgliederungen_kreis_2023.rds"

# Kreis codes are stored as eight-digit keys ending in 000; Excel drops leading
# zeros. Restore the eight-digit key before taking its five-digit Kreis code.
# Kreisregion codes identify the representative Kreis of a BBSR Kreisregion;
# some independent cities inherit the structural type of the combined region.
result <- read_excel(source_file, sheet = "Kreisreferenz", col_types = "text") %>%
  slice(-1) %>%
  mutate(across(everything(), ~ na_if(str_trim(.x), ""))) %>%
  filter(if_any(everything(), ~ !is.na(.x))) %>%
  transmute(
    geo_code = str_sub(str_pad(KRS2023, 8, pad = "0"), 1, 5),
    geo_name = KRS_NAME,
    bundesland_code = str_pad(BLD2023, 2, pad = "0"),
    bundesland_name = BLD_NAME,
    administrative_type_code = SLK2023,
    administrative_type_label = SLK_NAME,
    kreisregion_code = str_sub(str_pad(KKR2023, 8, pad = "0"), 1, 5),
    kreisregion_name = KKR_NAME,
    kreistyp_code = KTU2023,
    kreistyp_label = KTU_NAME,
    location_type_code = RLK2023,
    location_type_label = RLK_NAME
  ) %>%
  arrange(geo_code)

# The 2023 reference contains 400 Kreise, each with one key and Kreistyp.
stopifnot(
  nrow(result) == 400,
  !anyDuplicated(result$geo_code),
  !anyNA(result$geo_code),
  !anyNA(result$kreistyp_code)
)

saveRDS(result, output_file)
cat("Saved", nrow(result), "districts to", output_file, "\n")
