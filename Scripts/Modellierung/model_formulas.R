# Source from the project root. Formula construction does not fit models.
source("Scripts/Modellierung/config.R", local = TRUE)

validate_model_spec <- function(spec, data_spec, model_ids) {
  required <- c("response", "family", "weighting", "random_effects", "contrast", "missing")
  optional <- c("age_var", "period_var", "week_var", "references", "precision_column", "slope",
                "temporal_fixed_effects", "temporal_correlation", "phase_time", "acf_lags")
  if (!is.list(spec) || anyDuplicated(names(spec)) || !all(required %in% names(spec)) ||
      !all(names(spec) %in% c(required, optional))) {
    stop("Supply an explicit model specification with supported fields.", call. = FALSE)
  }
  check <- function(value, choices, label) {
    if (length(value) != 1L || is.na(value) || !value %in% choices) {
      stop("Invalid ", label, ".", call. = FALSE)
    }
  }
  check(spec$response, names(model_options$response_family), "response")
  check(spec$family, model_options$response_family[[spec$response]], "family for this response")
  check(spec$weighting, model_options$weighting, "weighting")
  check(spec$random_effects, model_options$random_effects, "random-effects structure")
  check(spec$contrast, c("treatment", "sum"), "contrast")
  check(spec$missing, c("error", "complete_cases"), "sample missing-data policy")
  check(data_spec$structure, names(structure_terms), "prepared data structure")
  check(data_spec$time_resolution, data_options$time_resolution, "prepared time resolution")
  check(data_spec$age_scheme, data_options$age_scheme, "prepared age scheme")
  if (!length(model_ids) || anyDuplicated(model_ids) || !all(model_ids %in% model_options$model_id)) {
    stop("Select unique model IDs from M0a–M3.", call. = FALSE)
  }
  fixed_clock <- temporal_fixed_effects(spec, data_spec)
  check(fixed_clock, model_options$temporal_fixed_effects, "temporal fixed effects")
  if (fixed_clock == "week" && data_spec$time_resolution == "phase") {
    stop("Week fixed effects require weekly data.", call. = FALSE)
  }
  correlation <- temporal_specification(spec, data_spec)
  check(correlation$structure, model_options$temporal_correlation, "temporal correlation")
  if (correlation$structure != "none" && !spec$family %in% names(correlated_gaussian_engines)) {
    stop("Residual temporal correlation is supported only for Gaussian lm and lmm.", call. = FALSE)
  }
  if (!is.null(spec$acf_lags) && (!is.numeric(spec$acf_lags) || !length(spec$acf_lags) ||
      any(!is.finite(spec$acf_lags) | spec$acf_lags <= 0 | spec$acf_lags * 2 != trunc(spec$acf_lags * 2)) ||
      anyDuplicated(spec$acf_lags))) {
    stop("acf_lags must contain unique positive elapsed lags in whole or half weeks.", call. = FALSE)
  }
  if (data_spec$time_resolution == "phase" && correlation$active) {
    check(spec$phase_time, model_options$phase_time, "phase time anchor")
  } else if (!is.null(spec$phase_time)) {
    stop("phase_time applies to phase residual correlation or diagnostics.", call. = FALSE)
  }
  mixed <- spec$family %in% c("lmm", "poisson_glmm", "negative_binomial_glmm")
  if (mixed != (spec$random_effects != "none")) {
    stop("Random effects must match the selected model family.", call. = FALSE)
  }
  if (spec$weighting == "duration" && data_spec$time_resolution != "phase") {
    stop("Duration weighting requires phase data.", call. = FALSE)
  }
  if (spec$weighting == "precision" && is.null(spec$precision_column)) {
    stop("Precision weighting requires an externally computed precision column.", call. = FALSE)
  }
  if (xor(spec$weighting == "precision", !is.null(spec$precision_column))) {
    stop("Provide precision_column only for precision weighting.", call. = FALSE)
  }
  if (xor(spec$random_effects == "random_slopes", !is.null(spec$slope))) {
    stop("Provide a slope column for a correlated district intercept and slope.", call. = FALSE)
  }
  for (name in intersect(names(spec), c("age_var", "period_var", "week_var",
                                        "precision_column", "slope"))) {
    value <- spec[[name]]
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
        make.names(value) != value || startsWith(value, ".model_")) {
      stop("Expected a syntactic input column name for ", name, ".", call. = FALSE)
    }
  }
  if (!is.null(spec$references) && (!is.character(spec$references) ||
      is.null(names(spec$references)) || anyDuplicated(names(spec$references)) ||
      anyNA(spec$references) || any(!nzchar(names(spec$references))) || spec$contrast != "treatment")) {
    stop("Provide treatment references as a named character vector.", call. = FALSE)
  }
}

# Omitted temporal fields preserve the existing mean and independent-residual fit.
temporal_fixed_effects <- function(spec, data_spec) {
  if (!is.null(spec$temporal_fixed_effects)) return(spec$temporal_fixed_effects)
  if (data_spec$time_resolution == "weekly") "week" else "period"
}

temporal_specification <- function(spec, data_spec) {
  correlation <- if (is.null(spec$temporal_correlation)) "none" else spec$temporal_correlation
  list(structure = correlation, active = !identical(correlation, "none") || !is.null(spec$acf_lags),
       time_column = if (data_spec$time_resolution == "weekly") "elapsed_week" else
         unname(phase_time_columns[spec$phase_time]),
       phase_time = spec$phase_time, lags = spec$acf_lags,
       origin = study_config$time_origin, unit = "weeks", series = c("geo_code", "age_group"))
}

# Weekly period interactions use numeric contrasts for each categorical operand.
model_formulas <- function(spec, data_spec, model_ids) {
  validate_model_spec(spec, data_spec, model_ids)
  age <- if (is.null(spec$age_var)) "age_group" else spec$age_var
  period <- if (is.null(spec$period_var)) "period" else spec$period_var
  weekly <- data_spec$time_resolution == "weekly"
  week <- if (is.null(spec$week_var)) "week_start" else spec$week_var
  structure <- structure_terms[[data_spec$structure]]
  if (anyDuplicated(c(age, period, structure, if (weekly) week))) {
    stop("Age, period, week and structural terms must use distinct columns.", call. = FALSE)
  }
  fixed_clock <- temporal_fixed_effects(spec, data_spec)
  weekly_fixed <- fixed_clock == "week"
  interaction_period <- if (weekly_fixed) ".model_period" else period
  base <- c(age, if (weekly_fixed) week else period)
  age_time <- paste(age, interaction_period, sep = ":")
  structure_time <- paste(structure, interaction_period, sep = ":")
  # Each structural predictor interacts with age and time separately.
  age_structure <- paste(age, structure, sep = ":")
  three_way <- paste(age, structure, interaction_period, sep = ":")
  m1 <- c(base, age_time, structure)
  m2a <- c(m1, structure_time)
  m2b <- c(m2a, age_structure)
  hierarchy <- list(M0a = base, M0b = c(base, age_time), M1 = m1, M2a = m2a,
                    M2b = m2b, M3 = c(m2b, three_way))
  response <- unname(response_columns[[spec$response]])
  offset <- if (spec$response == "count") paste0("offset(", count_offset_column, ")")
  random <- switch(spec$random_effects, none = NULL, kreis = "(1 | geo_code)",
                   kreis_age = c("(1 | geo_code)", "(1 | .model_kreis_age)"),
                   random_slopes = paste0("(1 + ", spec$slope, " | geo_code)"))
  if (!is.null(spec$slope) &&
      !all(vapply(hierarchy[model_ids], function(terms) spec$slope %in% terms, logical(1)))) {
    stop("The random slope must be a fixed main effect in every requested model.", call. = FALSE)
  }
  hierarchy <- hierarchy[model_ids]
  interaction_terms <- unique(grep(".model_period", unlist(hierarchy), fixed = TRUE, value = TRUE))
  encoded <- intersect(c(age, "kreistyp", "location_type"),
                       unlist(strsplit(interaction_terms, ":", fixed = TRUE)))
  encodings <- setNames(c(character(), if (length(interaction_terms)) period, encoded),
                        c(if (length(interaction_terms)) ".model_period",
                          if (length(encoded)) paste0(".model_interaction_", encoded)))
  design_terms <- lapply(hierarchy, function(terms) {
    vapply(terms, function(term) {
      if (!grepl(".model_period", term, fixed = TRUE)) return(term)
      columns <- strsplit(term, ":", fixed = TRUE)[[1L]]
      replace <- match(columns, unname(encodings))
      columns[!is.na(replace)] <- names(encodings)[replace[!is.na(replace)]]
      paste(columns, collapse = ":")
    }, character(1), USE.NAMES = FALSE)
  })
  fixed <- lapply(design_terms, function(terms) reformulate(c(terms, offset), response))
  full <- lapply(design_terms, function(terms) reformulate(c(terms, offset, random), response))
  list(fixed = fixed, full = full, terms = hierarchy, encodings = encodings, age = age, period = period,
       week = if (weekly) week, temporal_fixed_effects = fixed_clock, response = response)
}
