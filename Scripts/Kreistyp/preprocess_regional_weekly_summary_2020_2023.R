# Setup ----
library(dplyr)

analysis_years <- 2020:2023

output_dir <- file.path("data_processed", "Kreistyp")
prepare_dir <- file.path(output_dir, "Kreistyp_prepare")

# 1. Read all-age weekly cases ----
cases <- readRDS(
  file.path(prepare_dir, "rki_weekly_cases_all_ages.rds")
) %>%
  as.data.frame() %>%
  ungroup()

# 2. Read annual population and regional types ----
regional <- readRDS(
  file.path(prepare_dir, "population_Kreistyp_Raumtyp_2020_2024.rds")
) %>%
  as.data.frame() %>%
  ungroup()

# 3. Check required columns ----
stopifnot(
  all(
    c(
      "geo_code", "week_start", "iso_year",
      "iso_week", "cases_total"
    ) %in% names(cases)
  ),
  all(
    c(
      "geo_code", "geo_name", "year",
      "population_total",
      "kreistyp_code", "kreistyp_name",
      "raumtyp_lage_code", "raumtyp_lage_name"
    ) %in% names(regional)
  )
)

# 4. Filter years and standardize identifiers ----
# Cases use ISO week years. Population and regional types use annual records.
normalize_code <- function(x) {
  x <- trimws(as.character(x))
  
  stopifnot(
    !anyNA(x),
    all(grepl("^[0-9]{1,5}$", x))
  )
  
  sprintf("%05d", as.integer(x))
}

cases <- cases %>%
  filter(as.integer(iso_year) %in% analysis_years) %>%
  transmute(
    geo_code = normalize_code(geo_code),
    week_start = as.Date(week_start),
    iso_year = as.integer(iso_year),
    iso_week = as.integer(iso_week),
    cases_total = cases_total
  )

regional <- regional %>%
  filter(as.integer(year) %in% analysis_years) %>%
  transmute(
    geo_code = normalize_code(geo_code),
    geo_name,
    year = as.integer(year),
    population_total,
    kreistyp_code,
    kreistyp_name,
    raumtyp_lage_code,
    raumtyp_lage_name
  )

# 5. Validate input coverage and uniqueness ----
stopifnot(
  nrow(cases) == 83600L,
  setequal(cases$iso_year, analysis_years),
  !anyNA(cases),
  nrow(distinct(cases, geo_code, iso_year, iso_week)) ==
    nrow(cases),
  nrow(distinct(cases, geo_code, week_start)) ==
    nrow(cases),
  all(is.finite(cases$cases_total)),
  all(cases$cases_total >= 0),
  
  nrow(regional) == 1600L,
  setequal(regional$year, analysis_years),
  nrow(distinct(regional, geo_code, year)) == 1600L,
  all(table(regional$year) == 400L),
  !anyNA(regional),
  all(is.finite(regional$population_total)),
  all(regional$population_total > 0),
  all(regional$kreistyp_code %in% 1:4),
  all(regional$raumtyp_lage_code %in% 1:4)
)

# 6. Verify population and type matches for every region-year ----
unmatched <- cases %>%
  distinct(geo_code, iso_year) %>%
  anti_join(
    regional,
    by = c("geo_code", "iso_year" = "year")
  )

if (nrow(unmatched) > 0L) {
  stop("Some case region-years have no matching regional data.")
}

# 7. Join annual characteristics and calculate weekly incidence ----
regional_weekly_summary <- cases %>%
  left_join(
    regional,
    by = c("geo_code", "iso_year" = "year")
  ) %>%
  mutate(
    incidence = cases_total / population_total * 100000
  ) %>%
  select(
    geo_code,
    geo_name,
    kreistyp_code,
    kreistyp_name,
    raumtyp_lage_code,
    raumtyp_lage_name,
    week_start,
    iso_year,
    iso_week,
    cases_total,
    population_total,
    incidence
  ) %>%
  arrange(geo_code, week_start)

# 8. Verify output coverage and case preservation ----
weekly_coverage <- regional_weekly_summary %>%
  count(iso_year, iso_week)

annual_case_check <- cases %>%
  group_by(iso_year) %>%
  summarise(
    cases_before = sum(cases_total),
    .groups = "drop"
  ) %>%
  left_join(
    regional_weekly_summary %>%
      group_by(iso_year) %>%
      summarise(
        cases_after = sum(cases_total),
        .groups = "drop"
      ),
    by = "iso_year"
  )

stopifnot(
  nrow(regional_weekly_summary) == nrow(cases),
  nrow(weekly_coverage) == 209L,
  all(weekly_coverage$n == 400L),
  !anyNA(regional_weekly_summary),
  all(is.finite(regional_weekly_summary$incidence)),
  all(regional_weekly_summary$incidence >= 0),
  all(
    abs(
      annual_case_check$cases_before -
        annual_case_check$cases_after
    ) < 1e-8
  )
)

# 9. Save the combined table ----
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(
  regional_weekly_summary,
  file.path(output_dir, "regional_weekly_summary_2020_2023.rds")
)
