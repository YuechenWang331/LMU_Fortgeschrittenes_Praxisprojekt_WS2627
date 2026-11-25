suppressPackageStartupMessages(library(data.table))

# Run from the project root to publish both weekly panels.
# Source this script to use prepare_model_data(readRDS(path), spec).
# Supply one value per option, with aggregation and phase_missing for phase data.
# Unbalanced keeps all keys. Complete phases need every exposure; available phases
# use matching cases and exposure only from usable weeks. Zero cases stay valid.
# Supply imputed_population keyed by geo_code, iso_year and age_group with a
# population column holding the full group denominator for each missing key.
source("Scripts/Modellierung/config.R", local = TRUE)

assert_key <- function(x, key, label) {
  if (anyNA(x[, ..key]) || anyDuplicated(x, by = key)) {
    stop(label, " has missing or duplicate keys.", call. = FALSE)
  }
}

study_calendar_weeks <- function() {
  seq(study_config$time_origin, tail(period_definitions$end, 1L), by = "week")
}

elapsed_weeks <- function(date) {
  as.numeric(date - study_config$time_origin) / 7
}

phase_calendar_time <- function(split_postw5) {
  calendar <- rbindlist(lapply(seq_len(nrow(period_definitions)), function(i) {
    data.table(period = period_definitions$period[i],
               week_start = seq(period_definitions$start[i], period_definitions$end[i], by = "week"))
  }))
  stopifnot(identical(calendar$week_start, study_calendar_weeks()))
  if (split_postw5) calendar[period == "PostW5", period := paste0(period, "_", format(week_start, "%G"))]
  calendar[, .(phase_start_week = elapsed_weeks(min(week_start)),
               phase_end_week = elapsed_weeks(max(week_start))), by = period][
    , phase_mid_week := (phase_start_week + phase_end_week) / 2][]
}

build_weekly_model_data <- function(age_scheme) {
  stopifnot(length(age_scheme) == 1L, age_scheme %in% data_options$age_scheme)
  x <- as.data.table(readRDS(paths$weekly[[age_scheme]]))
  mapping <- readRDS(paths$age_mapping)
  ages <- unique(mapping[[paste0("age_group_", age_scheme)]])
  key <- c("geo_code", "age_group", "week_start")
  assert_key(x, key, "Weekly age panel")
  weeks <- unique(x[, .(week_start, iso_year, iso_week)])[order(week_start)]
  assert_key(weeks, "week_start", "ISO calendar")
  expected_weeks <- study_calendar_weeks()
  districts <- unique(x$geo_code)
  stopifnot(
    length(districts) == study_config$expected_n_kreise,
    nrow(weeks) == study_config$expected_n_weeks,
    identical(weeks$week_start, expected_weeks),
    identical(weeks$iso_year, as.integer(format(expected_weeks, "%G"))),
    identical(weeks$iso_week, as.integer(format(expected_weeks, "%V"))),
    identical(unique(weeks$iso_year), study_config$years),
    setequal(x$age_group, ages), length(ages) == as.integer(age_scheme),
    nrow(x) == length(districts) * nrow(weeks) * length(ages),
    all(is.finite(x$cases_total) & x$cases_total >= 0 & x$cases_total == trunc(x$cases_total)),
    identical(x$denominator_complete, x$n_missing_age_denominators == 0L),
    !anyNA(x$denominator_complete),
    identical(is.na(x$incidence), !x$denominator_complete)
  )
  annual_age <- unique(x[, .(geo_code, iso_year, age_group, population_available,
                             denominator_complete, n_missing_age_denominators)])
  assert_key(annual_age, c("geo_code", "iso_year", "age_group"), "Annual age denominators")
  complete <- x[denominator_complete == TRUE]
  stopifnot(all(is.finite(complete$population_available) & complete$population_available > 0),
            isTRUE(all.equal(complete$incidence,
                             study_config$incidence_scale * complete$cases_total /
                               complete$population_available, tolerance = 1e-10)))

  regional <- as.data.table(readRDS(paths$regional))[year %in% study_config$years]
  setnames(regional, "year", "iso_year")
  snapshot <- as.data.table(readRDS(paths$snapshot))
  area <- as.data.table(readRDS(paths$area))
  assert_key(regional, c("geo_code", "iso_year"), "Annual regional data")
  assert_key(snapshot, "geo_code", "2023 regional data")
  assert_key(area, "geo_code", "2023 area data")
  stopifnot(setequal(regional$geo_code, districts),
            nrow(regional) == length(districts) * length(study_config$years),
            setequal(snapshot$geo_code, districts), setequal(area$geo_code, districts),
            !anyNA(regional), !anyNA(snapshot),
            all(regional$kreistyp_code %in% 1:4), all(regional$raumtyp_lage_code %in% 1:4),
            all(is.finite(regional$population_total) & regional$population_total > 0),
            all(is.finite(area$area_km2) & area$area_km2 > 0))
  regional[snapshot, on = "geo_code", `:=`(
    kreistyp_code_2023 = as.integer(i.kreistyp_code),
    location_type_code_2023 = as.integer(i.location_type_code),
    location_type_2023 = i.location_type_label
  )]
  stopifnot(regional[iso_year == 2023L, all(kreistyp_code == kreistyp_code_2023 &
                                           raumtyp_lage_code == location_type_code_2023)])
  type_names <- unique(regional[, .(kreistyp_code, kreistyp_name)])
  assert_key(type_names, "kreistyp_code", "Kreistyp labels")
  regional[type_names, on = .(kreistyp_code_2023 = kreistyp_code),
           kreistyp_name_2023 := i.kreistyp_name]
  regional[area, on = "geo_code", area_km2 := i.area_km2]
  regional[, pop_density := population_total / area_km2]
  original_rows <- nrow(x)
  x <- merge(x, regional, by = c("geo_code", "iso_year"), all.x = TRUE)
  stopifnot(nrow(x) == original_rows, !anyNA(x[, names(regional), with = FALSE]))
  assert_key(x, key, "Enriched weekly panel")

  membership <- vapply(seq_len(nrow(period_definitions)), function(i) {
    weeks$week_start >= period_definitions$start[i] & weeks$week_start <= period_definitions$end[i]
  }, logical(nrow(weeks)))
  stopifnot(all(rowSums(membership) == 1L), all(colSums(membership) > 0L))
  weeks[, period_original := period_definitions$period[max.col(membership)]]
  weeks[, period_split := period_original]
  weeks[period_original == "PostW5", period_split := paste0("PostW5_", iso_year)]
  stopifnot(setequal(weeks[period_original == "PostW5", iso_year], 2022:2023))
  x[weeks, on = "week_start", `:=`(period_original = i.period_original, period_split = i.period_split)]
  balanced_codes <- readRDS(paths$balanced_codes)
  stopifnot(!anyDuplicated(balanced_codes),
            setequal(balanced_codes, setdiff(districts, x[denominator_complete == FALSE, unique(geo_code)])))
  x[, `:=`(age_scheme = age_scheme, balanced_panel = geo_code %chin% balanced_codes)]
  x[, balanced_kreis_age := all(denominator_complete), by = .(geo_code, age_group)]
  x[, elapsed_week := elapsed_weeks(week_start)]
  setkeyv(x, key)
  x
}

modal_type <- function(code, tie) {
  # The caller supplies calendar weeks in chronological order.
  counts <- table(code)
  tied <- code[code %in% names(counts)[counts == max(counts)]]
  if (uniqueN(tied) > 1L && tie == "error") {
    stop("Phase type is tied across calendar weeks. Specify an explicit tie rule.", call. = FALSE)
  }
  if (tie == "latest") tail(tied, 1L) else tied[1L]
}

prepare_model_data <- function(weekly, spec, imputed_population = NULL) {
  required <- setdiff(names(data_options), c("aggregation", "phase_missing", "phase_type_tie"))
  if (!is.list(spec) || anyDuplicated(names(spec)) || !all(required %in% names(spec)) ||
      !all(names(spec) %in% names(data_options))) {
    stop("Specify each data option explicitly. Phase-only options are conditional.", call. = FALSE)
  }
  for (name in names(spec)) {
    value <- spec[[name]]
    if (length(value) != 1L || !value %in% data_options[[name]]) {
      stop("Invalid data option: ", name, call. = FALSE)
    }
  }
  phase <- spec$time_resolution == "phase"
  if (phase && !all(c("aggregation", "phase_missing") %in% names(spec))) {
    stop("Phase data require explicit aggregation and phase_missing options.", call. = FALSE)
  }
  stopifnot(setequal(weekly$age_scheme, spec$age_scheme))
  x <- copy(weekly)
  if (!spec$include_p0) x <- x[period_original != "P0"]
  x[, period := if (spec$split_postw5) period_split else period_original]
  x[, population := fifelse(denominator_complete, population_available, NA_real_)]
  if (spec$missing_strategy == "balanced") x <- x[balanced_panel == TRUE]
  if (spec$missing_strategy == "imputed") {
    if (is.null(imputed_population)) {
      stop("Supply externally imputed full age-group populations.", call. = FALSE)
    }
    imputed <- as.data.table(imputed_population)
    key <- c("geo_code", "iso_year", "age_group")
    assert_key(imputed, key, "Imputed populations")
    needed <- unique(x[denominator_complete == FALSE, ..key])
    source_missing <- unique(weekly[denominator_complete == FALSE, ..key])
    stopifnot(nrow(imputed[!source_missing, on = key]) == 0L,
              nrow(needed[!imputed, on = key]) == 0L,
              is.numeric(imputed$population),
              all(is.finite(imputed$population) & imputed$population > 0))
    x[imputed, on = key, population := i.population]
  }
  x[, denominator_imputed := !denominator_complete & !is.na(population)]
  x[, incidence_observed := incidence]
  x[, incidence := study_config$incidence_scale * cases_total / population]
  x[, kreistyp := if (spec$kreistyp_version == "dynamic") kreistyp_name else kreistyp_name_2023]
  x[, location_type := raumtyp_lage_name]

  if (phase) {
    setorder(x, week_start)
    tie <- spec$phase_type_tie
    if (is.null(tie)) tie <- "error"
    # Use all calendar weeks for structural covariates, independent of age coverage.
    regional <- unique(x[, .(geo_code, week_start, period, kreistyp, location_type, pop_density)])
    regional <- regional[, .(
      kreistyp = modal_type(kreistyp, tie),
      location_type = modal_type(location_type, tie),
      pop_density = mean(pop_density)
    ), by = .(geo_code, period)]
    calendar <- unique(x[, .(period, week_start)])[, .(n_weeks_expected = .N), by = period]
    x <- x[, {
      valid <- !is.na(population)
      list(
        cases_total = sum(cases_total),
        cases = if (any(valid)) sum(cases_total[valid]) else NA_real_,
        exposure = if (any(valid)) sum(population[valid]) else NA_real_,
        n_weeks = sum(valid),
        n_weeks_observed = sum(denominator_complete),
        n_weeks_imputed = sum(denominator_imputed),
        incidence_arithmetic = if (any(valid)) mean(incidence[valid]) else NA_real_,
        period_original = unique(period_original),
        balanced_panel = all(balanced_panel),
        balanced_kreis_age = all(balanced_kreis_age)
      )
    }, by = .(geo_code, age_scheme, age_group, period)]
    x <- merge(x, calendar, by = "period", all.x = TRUE)
    # Phase anchors use the full study calendar even when some outcomes are unavailable.
    x <- merge(x, phase_calendar_time(spec$split_postw5), by = "period", all.x = TRUE)
    x <- merge(x, regional, by = c("geo_code", "period"), all.x = TRUE)
    x[, `:=`(denominator_complete = n_weeks_observed == n_weeks_expected,
             denominator_imputed = n_weeks_imputed > 0L)]
    if (spec$phase_missing == "complete") {
      x[n_weeks < n_weeks_expected, `:=`(cases = NA_real_, exposure = NA_real_,
                                       incidence_arithmetic = NA_real_)]
    }
    x[, incidence_exposure := study_config$incidence_scale * cases / exposure]
    x[, incidence := if (spec$aggregation == "arithmetic") incidence_arithmetic else incidence_exposure]
    assert_key(x, c("geo_code", "age_group", "period"), "Phase panel")
    stopifnot(nrow(x) == nrow(regional) * as.integer(spec$age_scheme),
              !anyNA(x[, .(kreistyp, location_type, pop_density, n_weeks_expected,
                           phase_start_week, phase_mid_week, phase_end_week)]),
              sum(x$cases_total) == sum(weekly[geo_code %chin% x$geo_code &
                (spec$include_p0 | period_original != "P0"), cases_total]),
              all(x$n_weeks <= x$n_weeks_expected))
  } else {
    x[, `:=`(cases = cases_total, exposure = population, n_weeks = as.integer(!is.na(population)),
             n_weeks_expected = 1L, elapsed_week = elapsed_weeks(week_start))]
  }

  x[, `:=`(log1p_incidence = log1p(incidence), log_exposure = log(exposure),
           weight_population = exposure / fifelse(n_weeks > 0L, n_weeks, NA_integer_),
           weight_duration = n_weeks, weight_exposure = exposure)]
  x[, kreistyp_phase := kreistyp]
  stopifnot(all(is.na(x$incidence) | (is.finite(x$incidence) & x$incidence >= 0)),
            identical(is.na(x$incidence), is.na(x$exposure)),
            all(is.na(x$exposure) | (is.finite(x$exposure) & x$exposure > 0)))
  attr(x, "data_spec") <- spec
  attr(x, "structure_terms") <- structure_terms[[spec$structure]]
  x
}

save_weekly_model_data <- function() {
  panels <- lapply(data_options$age_scheme, build_weekly_model_data)
  dir.create(paths$model_data, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_along(panels)) {
    output <- file.path(paths$model_data, paste0("kreis_weekly_", data_options$age_scheme[i], ".rds"))
    staged <- tempfile(tmpdir = paths$model_data)
    tryCatch({
      saveRDS(panels[[i]], staged)
      if (!file.rename(staged, output)) stop("Could not publish ", output, call. = FALSE)
    }, finally = unlink(staged))
    message(output, " (", nrow(panels[[i]]), " rows)")
  }
  invisible(NULL)
}

if (sys.nframe() == 0L) save_weekly_model_data()
