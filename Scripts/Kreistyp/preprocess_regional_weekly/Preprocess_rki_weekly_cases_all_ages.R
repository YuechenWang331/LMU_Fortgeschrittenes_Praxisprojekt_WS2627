library(dplyr)

# Read age-specific weekly cases
weekly <- readRDS(
  "data_processed/rki_weekly_long.rds"
)

stopifnot(
  all(
    c(
      "geo_code", "week_start", "iso_year",
      "iso_week", "age_group", "count"
    ) %in% names(weekly)
  ),
  is.numeric(weekly$count)
)

# Standardize identifiers
weekly <- weekly %>%
  ungroup() %>%
  mutate(
    geo_code = trimws(as.character(geo_code)),
    age_group = as.character(age_group)
  )

stopifnot(
  !anyNA(weekly$geo_code),
  all(grepl("^[0-9]{1,5}$", weekly$geo_code)),
  !anyNA(weekly$week_start),
  !anyNA(weekly$iso_year),
  !anyNA(weekly$iso_week),
  all(is.finite(weekly$count)),
  all(weekly$count >= 0)
)

weekly <- weekly %>%
  mutate(
    geo_code = sprintf("%05d", as.integer(geo_code))
  )

# Check that age-specific records are unique
duplicates <- weekly %>%
  count(geo_code, iso_year, iso_week, age_group) %>%
  filter(n > 1L)

stopifnot(nrow(duplicates) == 0L)

# Check age coverage and date consistency
known_ages <- c(as.character(0:79), "80+")

coverage <- weekly %>%
  group_by(geo_code, iso_year, iso_week) %>%
  summarise(
    known_age_groups = n_distinct(
      age_group[age_group %in% known_ages]
    ),
    unknown_age_rows = sum(
      is.na(age_group) |
        age_group %in% c("NA", "Unknown", "unknown", "")
    ),
    age_rows = n(),
    dates = n_distinct(week_start),
    .groups = "drop"
  )

stopifnot(
  all(coverage$known_age_groups == 81L),
  all(coverage$unknown_age_rows <= 1L),
  all(
    coverage$age_rows ==
      coverage$known_age_groups + coverage$unknown_age_rows
  ),
  all(coverage$dates == 1L)
)

# Sum cases across all ages, including unknown age
rki_weekly_cases_all_ages <- weekly %>%
  group_by(geo_code, iso_year, iso_week) %>%
  summarise(
    week_start = first(week_start),
    cases_total = sum(count),
    .groups = "drop"
  ) %>%
  select(
    geo_code,
    week_start,
    iso_year,
    iso_week,
    cases_total
  ) %>%
  arrange(geo_code, iso_year, iso_week)

# Verify that aggregation preserves annual case totals
annual_check <- weekly %>%
  group_by(iso_year) %>%
  summarise(
    cases_before = sum(count),
    .groups = "drop"
  ) %>%
  left_join(
    rki_weekly_cases_all_ages %>%
      group_by(iso_year) %>%
      summarise(
        cases_after = sum(cases_total),
        .groups = "drop"
      ),
    by = "iso_year"
  )

stopifnot(
  all(
    abs(
      annual_check$cases_before - annual_check$cases_after
    ) < 1e-8
  )
)

# Save the aggregated cases
saveRDS(
  rki_weekly_cases_all_ages,
  "data_processed/rki_weekly_cases_all_ages.rds"
)

