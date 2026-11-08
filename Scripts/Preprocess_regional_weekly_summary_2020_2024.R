library(dplyr)

# 1. Read all-age weekly cases
cases <- readRDS(
  "data_processed/rki_weekly_cases_all_ages.rds"
) %>%
  as.data.frame() %>%
  ungroup()

# 2. Locate the annual population and regional-type table
regional_files <- list.files(
  "data_processed",
  pattern = "^population_Kreistyp_Raumtyp_.*\\.rds$",
  full.names = TRUE
)

if (length(regional_files) != 1L) {
  stop(
    "Expected exactly one population_Kreistyp_Raumtyp_*.rds file."
  )
}

regional <- readRDS(regional_files[[1]]) %>%
  as.data.frame() %>%
  ungroup()

# 3. Check required columns
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

# 4. Standardize identifiers
normalize_code <- function(x) {
  x <- trimws(as.character(x))
  
  stopifnot(
    !anyNA(x),
    all(grepl("^[0-9]{1,5}$", x))
  )
  
  sprintf("%05d", as.integer(x))
}

cases <- cases %>%
  transmute(
    geo_code = normalize_code(geo_code),
    week_start = as.Date(week_start),
    iso_year = as.integer(iso_year),
    iso_week = as.integer(iso_week),
    cases_total = cases_total
  )

regional <- regional %>%
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

# 5. Validate input coverage and uniqueness
stopifnot(
  nrow(cases) == 104400L,
  setequal(cases$iso_year, 2020:2024),
  !anyNA(cases),
  nrow(distinct(cases, geo_code, iso_year, iso_week)) ==
    nrow(cases),
  nrow(distinct(cases, geo_code, week_start)) ==
    nrow(cases),
  all(is.finite(cases$cases_total)),
  all(cases$cases_total >= 0),
  
  nrow(regional) == 2000L,
  setequal(regional$year, 2020:2024),
  nrow(distinct(regional, geo_code, year)) == 2000L,
  all(table(regional$year) == 400L),
  !anyNA(regional),
  all(is.finite(regional$population_total)),
  all(regional$population_total > 0),
  all(regional$kreistyp_code %in% 1:4),
  all(regional$raumtyp_lage_code %in% 1:4)
)

# 6. Verify population and type matches for every region-year
unmatched <- cases %>%
  distinct(geo_code, iso_year) %>%
  anti_join(
    regional,
    by = c("geo_code", "iso_year" = "year")
  )

if (nrow(unmatched) > 0L) {
  stop("Some case region-years have no matching regional data.")
}

# 7. Join annual characteristics and calculate weekly incidence
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

# 8. Verify output coverage and case preservation
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
  nrow(weekly_coverage) == 261L,
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

# 9. Save the combined table
saveRDS(
  regional_weekly_summary,
  "data_processed/regional_weekly_summary_2020_2024.rds"
)