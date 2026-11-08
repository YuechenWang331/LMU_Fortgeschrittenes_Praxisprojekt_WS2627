library(data.table)
library(dplyr)

# Run this script from the project root.
output_dir <- "Scripts/age_group/data"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

source("Scripts/age_group/functions/age_group_functions.R")

# Load and restrict the study data.
weekly_cases <- as.data.table(readRDS("data_processed/rki_weekly_long.rds"))[
  iso_year %in% 2020:2023,
  .(geo_code, iso_year, week_start, age_group, count)
]
annual_population <- as.data.table(readRDS("data_processed/rki_population_annual.rds"))[
  year %in% 2020:2023,
  .(geo_code, iso_year = year, age_group, population)
]

weekly_cases[, `:=`(
  geo_code = as.character(geo_code),
  iso_year = as.integer(iso_year),
  age_group = as.character(age_group),
  count = as.numeric(count)
)]
annual_population[, `:=`(
  geo_code = as.character(geo_code),
  iso_year = as.integer(iso_year),
  age_group = as.character(age_group),
  population = as.numeric(population)
)]

# Check unique identifiers before the population join.
stopifnot(
  !anyDuplicated(weekly_cases, by = c("geo_code", "iso_year", "week_start", "age_group")),
  !anyDuplicated(annual_population, by = c("geo_code", "iso_year", "age_group"))
)

# Attach annual population to each weekly observation.
weekly_cases[
  annual_population,
  population := i.population,
  on = .(geo_code, iso_year, age_group)
]

# Report missing and invalid observations before exclusion.
valid_ages <- c(as.character(0:79), "80+")
quality_summary <- weekly_cases[, .(
  rows = .N,
  unknown_age = sum(is.na(age_group) | !age_group %in% valid_ages),
  missing_count = sum(is.na(count)),
  negative_count = sum(count < 0, na.rm = TRUE),
  missing_population = sum(is.na(population)),
  invalid_population = sum(population <= 0, na.rm = TRUE)
), by = iso_year]
print(quality_summary)


# Keep valid known-age observations for incidence calculations.
valid_weekly_cases <- weekly_cases[
  age_group %in% valid_ages &
    !is.na(geo_code) & !is.na(week_start) &
    !is.na(count) & count >= 0 &
    !is.na(population) & population > 0
]

# Aggregate cases and population before computing incidence.
age_weekly_incidence <- valid_weekly_cases[, .(
  cases = sum(count),
  population = sum(population)
), by = .(iso_year, week_start, age_group)]
age_weekly_incidence[, `:=`(
  age = suppressWarnings(as.integer(age_group)),
  incidence = cases / population * 100000
)]
setorder(age_weekly_incidence, iso_year, week_start, age)

# Apply the existing age-group function only to 81 age labels.
age_scheme_lookup <- data.table(age_group = valid_ages)
age_scheme_lookup <- as.data.table(
  prepare_age_schemes(age_scheme_lookup)
)[, .(scheme, age_group, age_group_new)]
stopifnot(
  nrow(age_scheme_lookup) == 81L * 3L,
  !anyNA(age_scheme_lookup$age_group_new),
  all(age_scheme_lookup[age_group == "80+", age_group_new] == "80+")
)

# Aggregate all candidate schemes from the same weekly source.
scheme_weekly_incidence <- merge(
  age_weekly_incidence[, .(iso_year, week_start, age_group, cases, population)],
  age_scheme_lookup,
  by = "age_group",
  allow.cartesian = TRUE
)[, .(
  cases = sum(cases),
  population = sum(population)
), by = .(scheme, iso_year, week_start, age_group_new)]
scheme_weekly_incidence[, incidence := cases / population * 100000]
setorder(scheme_weekly_incidence, scheme, iso_year, week_start, age_group_new)

# Save data shared by the exploration and comparison scripts.
saveRDS(age_weekly_incidence, file.path(output_dir, "age_weekly_incidence.rds"))
saveRDS(age_scheme_lookup, file.path(output_dir, "age_scheme_lookup.rds"))
saveRDS(scheme_weekly_incidence, file.path(output_dir, "scheme_weekly_incidence.rds"))
