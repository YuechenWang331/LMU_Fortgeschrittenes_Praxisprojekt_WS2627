library(data.table)

# Run from the RStudio project root.
processed_dir <- "data_processed"
kreistyp_dir <- file.path(processed_dir, "Kreistyp")
study_years <- 2020:2023

weekly <- as.data.table(readRDS(file.path(processed_dir, "rki_weekly_long.rds")))
annual <- as.data.table(readRDS(file.path(processed_dir, "rki_population_annual.rds")))
kreistyp <- as.data.table(readRDS(file.path(
  kreistyp_dir, "Kreistyp_prepare", "population_Kreistyp_Raumtyp_2020_2024.rds"
)))

# Both RKI inputs use the same 400 Kreis codes, including merged Berlin.
# The ISO week year determines which population and Kreistyp to use.
age_labels <- c("0-5", "6-17", "18-39", "40-59", "60-69", "70-79", "80+")
age_breaks <- c(0L, 6L, 18L, 40L, 60L, 70L, 80L, 81L)
age_lookup <- setNames(
  rep(age_labels, diff(age_breaks)),
  c(as.character(0:79), "80+")
)
expected_ages <- setNames(diff(age_breaks), age_labels)
week_key <- c("geo_code", "week_start", "iso_year", "iso_week")
population_key <- c("geo_code", "iso_year", "age_group")
type_key <- c("geo_code", "iso_year")

# 1. Sum weekly cases within each requested age band.
weekly <- weekly[iso_year %in% study_years,
                 .(geo_code, week_start, iso_year, iso_week, age_group, count)]
stopifnot(
  !anyDuplicated(weekly, by = c(week_key, "age_group")),
  all(is.finite(weekly$count) & weekly$count >= 0),
  all(is.na(weekly$age_group) | weekly$age_group %chin% c(names(age_lookup), "NA"))
)
weekly[, age_band := unname(age_lookup[age_group])]
unknown_cases <- weekly[is.na(age_band), sum(count)]
weekly_totals <- weekly[, .(cases_total = sum(count)), by = week_key]
unknown_weekly <- weekly[is.na(age_band), .(unknown_cases = sum(count)), by = week_key]
cases <- weekly[!is.na(age_band), .(cases = sum(count), n_ages = .N),
                by = c(week_key, "age_band")]
stopifnot(all(cases$n_ages == expected_ages[cases$age_band]))
cases[, n_ages := NULL]
setnames(cases, "age_band", "age_group")
rm(weekly)

# 2. Sum annual population only when all constituent ages are available.
annual <- annual[year %in% study_years,
                 .(geo_code, iso_year = year, age_group, population)]
stopifnot(
  !anyDuplicated(annual, by = population_key),
  all(annual$age_group %chin% names(age_lookup))
)
annual[, age_band := unname(age_lookup[age_group])]
annual[, valid := is.finite(population) & population >= 0]
population <- annual[, .(
  population = sum(population[valid]),
  n_valid_ages = sum(valid)
), by = c(type_key, "age_band")]
setnames(population, "age_band", "age_group")

result <- merge(cases, population, by = population_key, all.x = TRUE)
result[is.na(n_valid_ages), n_valid_ages := 0L]
result[, n_expected_ages := unname(expected_ages[age_group])]
result[, population_status := "complete"]
result[n_valid_ages != n_expected_ages, `:=`(
  population = NA_real_, population_status = "incomplete"
)]
result[population == 0, population_status := "zero"]
result[, incidence := NA_real_]
result[population_status == "complete", incidence := cases / population * 100000]

# 3. Attach the annual Kreistyp and validate the output.
kreistyp <- kreistyp[year %in% study_years,
                     .(geo_code, iso_year = year, geo_name, kreistyp_code, kreistyp_name)]
stopifnot(!anyDuplicated(kreistyp, by = type_key))
result <- merge(result, kreistyp, by = type_key, all.x = TRUE)
stopifnot(
  !anyNA(result$kreistyp_code),
  !anyNA(result$kreistyp_name),
  !anyDuplicated(result, by = c(week_key, "age_group")),
  nrow(result) == 400L * 209L * length(age_labels),
  all(result[, .N, by = week_key]$N == length(age_labels))
)

audit <- merge(result[, .(known_cases = sum(cases)), by = week_key],
               weekly_totals, by = week_key, all = TRUE)
audit <- merge(audit, unknown_weekly, by = week_key, all.x = TRUE)
audit[is.na(unknown_cases), unknown_cases := 0]
stopifnot(
  !anyNA(audit$known_cases),
  !anyNA(audit$cases_total),
  all(audit$known_cases + audit$unknown_cases == audit$cases_total)
)

result[, age_group := factor(age_group, levels = age_labels, ordered = TRUE)]
result[, week_start := as.Date(week_start)]
setcolorder(result, c(
  "geo_code", "geo_name", "week_start", "iso_year", "iso_week", "age_group",
  "kreistyp_code", "kreistyp_name", "cases", "population", "incidence",
  "population_status", "n_valid_ages", "n_expected_ages"
))
setorder(result, geo_code, week_start, age_group)

output_dir <- file.path(processed_dir, "Kreistyp x Altersgruppe")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_file <- file.path(output_dir, "kreis_weekly_age_kreistyp_2020_2023.rds")
saveRDS(result, output_file)
message("Saved ", nrow(result), " rows to ", output_file)
message("Cases with unknown age: ", unknown_cases)
print(result[, .N, by = .(iso_year, population_status)][order(iso_year, population_status)])
