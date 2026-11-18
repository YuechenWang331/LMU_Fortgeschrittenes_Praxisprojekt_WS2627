library(data.table)

assign_andre_age_group <- function(age, scheme = c("A", "B")) {
  scheme <- match.arg(scheme)
  age_index <- match(as.character(age), c(as.character(0:79), "80+")) - 1L
  breaks <- list(A = c(0L, 6L, 18L, 40L, 60L, 70L, 80L),
                 B = c(0L, 3L, 6L, 10L, 15L, 18L, 25L, 30L, 40L, 50L, 60L, 70L, 80L))[[scheme]]
  labels <- c(paste(head(breaks, -1L), tail(breaks, -1L) - 1L, sep = "–"), "80+")
  labels[findInterval(age_index, breaks)]
}

check <- function(id, description, assertions) {
  tryCatch(
    {
      force(assertions)
      cat(sprintf("%02d PASS %s\n", id, description))
    },
    error = function(err) {
      stop(sprintf("%02d FAIL %s — %s", id, description, conditionMessage(err)),
           call. = FALSE)
    }
  )
}

sum_available <- function(population) {
  if (all(is.na(population))) NA_real_ else sum(population, na.rm = TRUE)
}

add_incidence <- function(panel) {
  panel[, ':='(denominator_complete = n_missing_age_denominators == 0L,
               incidence = NA_real_)]
  panel[denominator_complete == TRUE, incidence := 100000 * cases_total / population_available]
  panel
}

aggregate_kreis <- function(weekly, annual, group_column) {
  panel <- weekly[, .(cases_total = sum(count)),
                  by = c("geo_code", "week_start", "iso_year", "iso_week", group_column)]
  denominator <- annual[, .(population_available = sum_available(population),
                             n_missing_age_denominators = sum(is.na(population))),
                         by = c("geo_code", "iso_year", group_column)]
  setnames(panel, group_column, "age_group")
  setnames(denominator, group_column, "age_group")
  panel[denominator, on = .(geo_code, iso_year, age_group),
        ':='(population_available = i.population_available,
             n_missing_age_denominators = i.n_missing_age_denominators)]
  add_incidence(panel)
}

aggregate_national <- function(kreis_panel, codes, scope) {
  panel <- kreis_panel[geo_code %chin% codes, .(
    cases_total = sum(cases_total),
    population_available = sum_available(population_available),
    n_missing_age_denominators = sum(n_missing_age_denominators),
    n_kreise = .N,
    n_incomplete_kreise = sum(!denominator_complete)
  ), by = .(week_start, iso_year, iso_week, age_group)]
  panel[, scope := scope]
  setcolorder(add_incidence(panel), c("scope", "week_start", "iso_year", "iso_week", "age_group",
                                    "cases_total", "population_available",
                                    "n_missing_age_denominators", "denominator_complete",
                                    "incidence", "n_kreise", "n_incomplete_kreise"))
  panel
}

same_numbers <- function(x, y) {
  missing <- is.na(x)
  if (!identical(missing, is.na(y))) return(FALSE)
  x <- x[!missing]
  y <- y[!missing]
  all(abs(x - y) <= 1e-12 * pmax(1, abs(x), abs(y)))
}

run_andre_age_aggregation <- function(output_dir = "data_processed/Altsgruppen_ZeitlicheEntwicklung") {
  # Run from the repository root. A different, unused output path can be supplied
  # when sourcing this file for a reproducibility check.
  if (file.exists(output_dir)) {
    stop("Output already exists. Supply an unused output_dir to rerun.", call. = FALSE)
  }
  years <- 2020:2023
  weeks <- seq(as.Date("2019-12-30"), as.Date("2023-12-25"), by = "week")
  known_ages <- c(as.character(0:79), "80+")
  geo_week <- c("geo_code", "week_start", "iso_year", "iso_week")
  kreis_key <- c("geo_code", "week_start", "age_group")
  national_key <- c("week_start", "age_group")

  mapping <- data.table(
    age_original = known_ages,
    age_group_13 = assign_andre_age_group(known_ages, "B"),
    age_group_7 = assign_andre_age_group(known_ages, "A")
  )
  groups_13 <- c("0–2", "3–5", "6–9", "10–14", "15–17", "18–24", "25–29",
                 "30–39", "40–49", "50–59", "60–69", "70–79", "80+")
  groups_7 <- c("0–5", "6–17", "18–39", "40–59", "60–69", "70–79", "80+")
  check(1, "81 known categories map exactly once in both schemes", {
    stopifnot(
      identical(mapping$age_original, known_ages), !anyDuplicated(mapping$age_original),
      identical(mapping$age_group_13, rep(groups_13, c(3L, 3L, 4L, 5L, 3L, 7L, 5L, 10L, 10L, 10L, 10L, 10L, 1L))),
      identical(mapping$age_group_7, rep(groups_7, c(6L, 12L, 22L, 20L, 10L, 10L, 1L))),
      all(is.na(assign_andre_age_group(c("NA", NA_character_, "80"), "A"))),
      all(is.na(assign_andre_age_group(c("NA", NA_character_, "80"), "B")))
    )
  })
  parent_groups <- unique(mapping[, .(age_group_13, age_group_7)])
  check(2, "all 13 groups have the expected unique parent", {
    stopifnot(
      identical(parent_groups$age_group_13, groups_13),
      identical(parent_groups$age_group_7, rep(groups_7, c(2L, 3L, 3L, 2L, 1L, 1L, 1L)))
    )
  })

  weekly <- readRDS("data_processed/rki_weekly_long.rds")[
    iso_year %in% years, .(geo_code, week_start, iso_year, iso_week, age_group, count)
  ]
  annual_source <- readRDS("data_processed/rki_population_annual.rds")[
    year %in% years, .(geo_code, iso_year = year, age_group, population)
  ]
  reference <- readRDS("data_processed/Kreistyp/Kreistyp_prepare/raumgliederungen_kreis_2023.rds")
  kreise <- sort(reference$geo_code)

  # These checks guard the uniqueness and coverage assertions before any join.
  tryCatch(
    stopifnot(!anyDuplicated(weekly, by = kreis_key),
              !anyDuplicated(annual_source, by = c("geo_code", "iso_year", "age_group"))),
    error = function(err) stop("06 FAIL Input keys are duplicated. ", conditionMessage(err), call. = FALSE)
  )
  check(7, "input covers the expected 400 Kreise, 209 ISO weeks and 82 age codes", {
    week_index <- unique(weekly[, .(week_start, iso_year, iso_week)])[order(week_start)]
    stopifnot(
      length(kreise) == 400L, !anyNA(kreise), !anyDuplicated(kreise),
      all(grepl("^[0-9]{5}$", kreise)), "11000" %chin% kreise,
      !any(sprintf("110%02d", 1:12) %chin% kreise),
      setequal(weekly$geo_code, kreise), all(annual_source$geo_code %chin% kreise),
      identical(week_index$week_start, weeks),
      identical(week_index$iso_year, as.integer(format(weeks, "%G"))),
      identical(week_index$iso_week, as.integer(format(weeks, "%V"))),
      setequal(weekly$age_group, c(known_ages, "NA")),
      all(annual_source$age_group %chin% known_ages),
      nrow(weekly) == length(kreise) * length(weeks) * (length(known_ages) + 1L),
      all(is.finite(weekly$count) & weekly$count >= 0 & weekly$count == trunc(weekly$count))
    )
  })

  annual <- CJ(geo_code = kreise, iso_year = years, age_group = known_ages)
  annual[annual_source, on = .(geo_code, iso_year, age_group), population := i.population]
  annual[!is.finite(population) | population <= 0, population := NA_real_]
  balanced_codes <- setdiff(kreise, annual[is.na(population), unique(geo_code)])

  unknown_qc <- weekly[age_group == "NA", .(
    cases_unknown_age = sum(count),
    n_kreise = .N,
    n_kreise_with_unknown_cases = sum(count > 0)
  ), by = .(week_start, iso_year, iso_week)]
  all_age_totals <- weekly[, .(all_cases = sum(count)), by = .(week_start)]
  known <- weekly[age_group %chin% known_ages]
  rm(weekly)
  for (column in c("age_group_13", "age_group_7")) {
    known[, (column) := mapping[[column]][match(age_group, mapping$age_original)]]
    annual[, (column) := mapping[[column]][match(age_group, mapping$age_original)]]
  }

  kreis_13 <- aggregate_kreis(known, annual, "age_group_13")
  parent <- parent_groups$age_group_7[match(kreis_13$age_group, parent_groups$age_group_13)]
  kreis_7 <- kreis_13[, .(
    cases_total = sum(cases_total),
    population_available = sum_available(population_available),
    n_missing_age_denominators = sum(n_missing_age_denominators)
  ), by = .(geo_code, week_start, iso_year, iso_week, age_group = parent)]
  kreis_7 <- add_incidence(kreis_7)
  kreis_7_direct <- aggregate_kreis(known, annual, "age_group_7")
  setorderv(kreis_13, kreis_key)
  setorderv(kreis_7, kreis_key)
  setorderv(kreis_7_direct, kreis_key)

  all_13 <- aggregate_national(kreis_13, kreise, "all400")
  all_7 <- aggregate_national(kreis_7, kreise, "all400")
  balanced_13 <- aggregate_national(kreis_13, balanced_codes, "balanced")
  balanced_7 <- aggregate_national(kreis_7, balanced_codes, "balanced")

  panels_kreis <- list(kreis_13, kreis_7, kreis_7_direct)
  panels_national <- list(all_13, all_7, balanced_13, balanced_7)
  for (panel in panels_national) setorderv(panel, national_key)
  panel_groups <- list(groups_13, groups_7, groups_7)
  national_groups <- list(groups_13, groups_7, groups_13, groups_7)
  includes_expected_groups <- function(panel, groups) setequal(panel$age_group, groups)

  check(6, "all output panel, mapping, sample and unknown-age keys are unique", {
    stopifnot(
      all(vapply(panels_kreis, function(x) !anyDuplicated(x, by = kreis_key), logical(1))),
      all(vapply(panels_national, function(x) !anyDuplicated(x, by = national_key), logical(1))),
      !anyDuplicated(mapping$age_original), !anyDuplicated(balanced_codes),
      !anyDuplicated(unknown_qc$week_start)
    )
  })
  check(8, "every Kreis-group and every national group has all 209 aligned weeks", {
    for (i in seq_along(panels_kreis)) {
      panel <- panels_kreis[[i]]
      stopifnot(setequal(panel$geo_code, kreise), includes_expected_groups(panel, panel_groups[[i]]),
                nrow(panel) == length(kreise) * length(weeks) * length(panel_groups[[i]]))
    }
    for (i in seq_along(panels_national)) {
      panel <- panels_national[[i]]
      stopifnot(includes_expected_groups(panel, national_groups[[i]]),
                nrow(panel) == length(weeks) * length(national_groups[[i]]))
    }
    for (panel in c(panels_kreis, panels_national)) {
      stopifnot(identical(sort(unique(panel$week_start)), weeks),
                identical(unique(panel[, .(week_start, iso_year, iso_week)])[order(week_start)],
                          week_index))
    }
  })

  check(3, "known-age case counts are conserved by Kreis-week and in all400", {
    input_totals <- known[, .(cases_total = sum(count)), by = geo_week]
    setorderv(input_totals, geo_week)
    for (panel in panels_kreis) {
      totals <- panel[, .(cases_total = sum(cases_total)), by = geo_week]
      setorderv(totals, geo_week)
      stopifnot(identical(totals, input_totals))
    }
    national_totals <- input_totals[, .(cases_total = sum(cases_total)), by = week_start]
    setorder(national_totals, week_start)
    for (panel in list(all_13, all_7)) {
      totals <- panel[, .(cases_total = sum(cases_total)), by = week_start]
      setorder(totals, week_start)
      stopifnot(identical(totals, national_totals))
    }
  })
  check(4, "13-to-7 and direct aggregation have identical keys and cases in every cell", {
    stopifnot(identical(kreis_7[, ..kreis_key], kreis_7_direct[, ..kreis_key]),
              identical(kreis_7$cases_total, kreis_7_direct$cases_total))
  })
  check(5, "13-to-7 and direct aggregation agree on denominator support, population and incidence", {
    stopifnot(
      identical(kreis_7$n_missing_age_denominators, kreis_7_direct$n_missing_age_denominators),
      identical(kreis_7$denominator_complete, kreis_7_direct$denominator_complete),
      same_numbers(kreis_7$population_available, kreis_7_direct$population_available),
      same_numbers(kreis_7$incidence, kreis_7_direct$incidence)
    )
  })
  check(9, "complete incidences are finite, nonnegative and recompute from counts and population", {
    for (panel in c(panels_kreis, panels_national)) {
      complete <- panel[denominator_complete == TRUE]
      stopifnot(nrow(complete) > 0L,
                all(is.finite(complete$incidence) & complete$incidence >= 0),
                all(is.finite(complete$population_available) & complete$population_available > 0),
                identical(complete$incidence, 100000 * complete$cases_total / complete$population_available))
    }
  })
  check(10, "incomplete age denominators propagate to all400 and incidence is missing", {
    for (i in seq_along(panels_kreis)) {
      column <- if (i == 1L) "age_group_13" else "age_group_7"
      missing_counts <- annual[is.na(population), .N, by = c("geo_code", "iso_year", column)]
      setnames(missing_counts, column, "age_group")
      panel <- panels_kreis[[i]]
      expected <- missing_counts[panel, on = .(geo_code, iso_year, age_group), N]
      expected[is.na(expected)] <- 0L
      stopifnot(identical(panel$n_missing_age_denominators, expected))
      national <- list(all_13, all_7, all_7)[[i]]
      national_missing <- missing_counts[, .(ages = sum(N), kreise = .N), by = .(iso_year, age_group)]
      expected <- national_missing[national, on = .(iso_year, age_group), .(ages, kreise)]
      stopifnot(
        identical(national$n_missing_age_denominators, fcoalesce(expected$ages, 0L)),
        identical(national$n_incomplete_kreise, fcoalesce(expected$kreise, 0L)),
        all(national$n_kreise == 400L)
      )
    }
    for (panel in c(panels_kreis, panels_national)) {
      stopifnot(identical(panel$denominator_complete, panel$n_missing_age_denominators == 0L),
                identical(is.na(panel$incidence), !panel$denominator_complete),
                !any(is.nan(panel$incidence)))
    }
  })
  check(11, "balanced sample is fixed and all four years have complete age denominators", {
    retained <- annual[geo_code %chin% balanced_codes]
    stopifnot(length(balanced_codes) > 0L,
              nrow(retained) == length(balanced_codes) * length(years) * length(known_ages),
              all(is.finite(retained$population) & retained$population > 0),
              all(setdiff(kreise, balanced_codes) %chin% annual[is.na(population), geo_code]))
    for (i in 1:2) {
      fixed <- panels_kreis[[i]][geo_code %chin% balanced_codes]
      series <- list(balanced_13, balanced_7)[[i]]
      stopifnot(
        setequal(fixed$geo_code, balanced_codes),
        nrow(fixed) == length(balanced_codes) * length(weeks) * length(panel_groups[[i]]),
        all(fixed$denominator_complete), all(series$denominator_complete),
        all(series$n_kreise == length(balanced_codes)), all(series$n_incomplete_kreise == 0L)
      )
    }
  })
  check(12, "unknown-age cases are separate and reconcile with all-age cases every week", {
    known_totals <- known[, .(known_cases = sum(count)), by = week_start]
    setorder(known_totals, week_start)
    setorder(unknown_qc, week_start)
    setorder(all_age_totals, week_start)
    stopifnot(
      identical(unknown_qc$week_start, weeks), all(unknown_qc$n_kreise == length(kreise)),
      identical(all_age_totals$week_start, known_totals$week_start),
      identical(all_age_totals$all_cases, known_totals$known_cases + unknown_qc$cases_unknown_age),
      all(vapply(c(panels_kreis, panels_national), function(x) !anyNA(x$age_group) &&
                   !("NA" %chin% x$age_group), logical(1)))
    )
  })

  check(13, "legacy single-age baseline agrees on the same valid age-by-Kreis support", {
    legacy <- readRDS("Scripts/age_group/data/age_weekly_incidence.rds")
    reference_keys <- c("week_start", "iso_year", "age_group")
    stopifnot(!anyDuplicated(legacy, by = c("week_start", "age_group")))
    known[annual, on = .(geo_code, iso_year, age_group), population := i.population]
    comparable <- known[!is.na(population),
      .(cases = sum(count), population = sum(population)), by = reference_keys]
    comparable[, incidence := 100000 * cases / population]
    setorderv(legacy, reference_keys)
    setorderv(comparable, reference_keys)
    stopifnot(
      identical(comparable[, ..reference_keys], legacy[, ..reference_keys]),
      identical(comparable$cases, legacy$cases),
      same_numbers(comparable$population, legacy$population),
      same_numbers(comparable$incidence, legacy$incidence)
    )
  })

  # Publish a complete set in one rename, after every check passes.
  outputs <- list(
    age_mapping = mapping,
    kreis_weekly_13 = kreis_13,
    kreis_weekly_7 = kreis_7,
    national_all400_13 = all_13,
    national_all400_7 = all_7,
    national_balanced_13 = balanced_13,
    national_balanced_7 = balanced_7,
    balanced_kreis_codes = balanced_codes,
    unknown_age_qc = unknown_qc
  )
  stage <- tempfile(".Altsgruppen_ZeitlicheEntwicklung_", tmpdir = dirname(output_dir))
  stopifnot(dir.create(stage))
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  for (name in names(outputs)) saveRDS(outputs[[name]], file.path(stage, paste0(name, ".rds")))
  if (!file.rename(stage, output_dir)) {
    stop("Could not publish the validated outputs at ", output_dir, call. = FALSE)
  }

  cat(sprintf("13 validation items passed. Saved %d RDS files in %s\n", length(outputs), output_dir))
  invisible(outputs)
}

if (sys.nframe() == 0L) run_andre_age_aggregation()
