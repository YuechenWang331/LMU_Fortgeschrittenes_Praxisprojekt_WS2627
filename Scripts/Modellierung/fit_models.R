# Source from the project root. Supply one explicit specification and a set of model IDs.
source("Scripts/Modellierung/prepare_model_data.R", local = TRUE)
source("Scripts/Modellierung/model_formulas.R", local = TRUE)

# Pass weekly explicitly to override the saved enriched panel.
load_model_data <- function(data_spec, weekly = NULL, imputed_population = NULL) {
  age_scheme <- data_spec$age_scheme
  if (length(age_scheme) != 1L || !age_scheme %in% data_options$age_scheme) {
    stop("Specify a supported age scheme.", call. = FALSE)
  }
  if (is.null(weekly)) {
    weekly <- readRDS(file.path(paths$model_data, paste0("kreis_weekly_", age_scheme, ".rds")))
  }
  prepare_model_data(weekly, data_spec, imputed_population)
}

set_model_contrasts <- function(data, columns, spec, formulas, data_spec) {
  references <- spec$references
  if (!all(names(references) %in% columns)) {
    stop("References must name active categorical columns.", call. = FALSE)
  }
  defaults <- c(kreistyp = reference_levels$kreistyp, period = reference_levels$period,
                age_group = reference_levels$age_group[[data_spec$age_scheme]])
  for (column in columns) {
    value <- data[[column]]
    labels <- if (is.factor(value)) levels(droplevels(value)) else as.character(sort(unique(value)))
    value <- factor(value, levels = labels)
    if (nlevels(value) < 2L) stop("Too few levels in ", column, ".", call. = FALSE)
    if (spec$contrast == "treatment") {
      ref <- unname(references[column])
      if (length(ref) == 0L || is.na(ref)) ref <- unname(defaults[column])
      if (identical(column, formulas$week) && (length(ref) == 0L || is.na(ref))) ref <- labels[1L]
      if (length(ref) == 0L || is.na(ref) || !ref %in% labels) {
        stop("Supply an observed treatment reference for ", column, ".", call. = FALSE)
      }
      value <- relevel(value, ref)
      contrasts(value) <- contr.treatment(levels(value))
    } else {
      contrasts(value) <- contr.sum(levels(value))
    }
    data[[column]] <- value
  }
  data
}

validate_model_matrix <- function(data, formula, terms, categorical, period, id) {
  for (term in terms) {
    columns <- strsplit(term, ":", fixed = TRUE)[[1L]]
    columns[columns == ".model_period"] <- period
    factors <- intersect(columns, categorical)
    if (length(factors) > 1L) {
      observed <- nrow(unique(data[factors]))
      expected <- prod(vapply(data[factors], nlevels, integer(1)))
      if (observed < expected) {
        stop(id, " has ", expected - observed, " empty cells for ", term, ".", call. = FALSE)
      }
    }
  }
  matrix <- stats::model.matrix(formula, data)
  decomposition <- qr(matrix)
  rank <- decomposition$rank
  if (rank < ncol(matrix)) {
    aliases <- colnames(matrix)[decomposition$pivot[seq.int(rank + 1L, ncol(matrix))]]
    stop(id, " has a rank-deficient fixed design: ", paste(head(aliases, 8L), collapse = ", "),
         call. = FALSE)
  }
  if (nrow(matrix) <= rank) stop(id, " has no residual degrees of freedom.", call. = FALSE)
  rank
}

# Every requested model uses the same complete sample, weights and offsets.
build_fit_sample <- function(prepared, spec, formulas, data_spec) {
  data <- as.data.frame(prepared)
  keys <- c("geo_code", "age_group", if (is.null(formulas$week)) "period" else "week_start")
  if (!all(keys %in% names(data)) || anyNA(data[keys]) || anyDuplicated(data[keys])) {
    stop("Prepared observation keys must be present, complete and unique.", call. = FALSE)
  }
  if (any(startsWith(names(data), ".model_"))) stop("Reserved .model_ input column.", call. = FALSE)
  terms <- unique(unlist(formulas$terms, use.names = FALSE))
  fixed <- unique(unlist(strsplit(terms, ":", fixed = TRUE), use.names = FALSE))
  period_interaction <- ".model_period" %in% fixed
  fixed <- setdiff(fixed, ".model_period")
  categorical <- intersect(c(formulas$age, formulas$period, formulas$week,
                             "kreistyp", "location_type"), fixed)
  if (period_interaction) categorical <- union(categorical, formulas$period)
  weight <- if (spec$weighting == "precision") spec$precision_column else
    unname(weight_columns[spec$weighting][!is.na(weight_columns[spec$weighting])])
  offset <- if (spec$response == "count") c(count_offset_column, "exposure")
  temporal <- temporal_specification(spec, data_spec)
  time <- if (temporal$active) temporal$time_column
  needed <- unique(c(keys, fixed, categorical, formulas$response, weight, offset, time))
  absent <- setdiff(needed, names(data))
  if (length(absent)) stop("Missing model columns: ", paste(absent, collapse = ", "), call. = FALSE)

  for (column in unique(c(formulas$response, weight, offset, setdiff(fixed, categorical)))) {
    value <- data[[column]]
    if (!is.numeric(value) || any(is.nan(value) | is.infinite(value))) {
      stop(column, " must be numeric with finite non-missing values.", call. = FALSE)
    }
  }
  if (length(weight) && any(data[[weight]] <= 0, na.rm = TRUE)) {
    stop("Weights must be positive.", call. = FALSE)
  }
  if (spec$response == "count") {
    count <- data[[formulas$response]]
    if (any(count < 0 | count != trunc(count), na.rm = TRUE)) {
      stop("Count responses must be nonnegative integers.", call. = FALSE)
    }
    exposure <- data$exposure
    log_exposure <- data[[count_offset_column]]
    if (any(exposure <= 0, na.rm = TRUE) || any(xor(is.na(exposure), is.na(log_exposure))) ||
        !isTRUE(all.equal(log_exposure[!is.na(exposure)], log(exposure[!is.na(exposure)])))) {
      stop("Count models require log exposure offsets with positive matching exposures.", call. = FALSE)
    }
  }
  if (temporal$active) {
    expected_time <- if (is.null(formulas$week)) {
      calendar <- phase_calendar_time(data_spec$split_postw5)
      calendar[[time]][match(data$period, calendar$period)]
    } else elapsed_weeks(data$week_start)
    if (!is.numeric(data[[time]]) || any(!is.finite(data[[time]])) ||
        anyNA(expected_time) || any(data[[time]] != expected_time)) {
      stop("Temporal coordinates must match the study calendar.", call. = FALSE)
    }
  }
  keep <- stats::complete.cases(data[needed])
  if (!all(keep) && spec$missing == "error") stop("Incomplete fitting sample.", call. = FALSE)
  if (!any(keep)) stop("No complete observations for this specification.", call. = FALSE)
  for (column in categorical) {
    if (!setequal(unique(stats::na.omit(data[[column]])), unique(data[[column]][keep]))) {
      stop("Complete-case filtering removed a level of ", column, ".", call. = FALSE)
    }
  }
  excluded <- data[!keep, keys, drop = FALSE]
  included <- data[keep, keys, drop = FALSE]
  data <- data[keep, , drop = FALSE]
  if (!is.null(formulas$week) && period_interaction) {
    calendar <- unique(data[c(formulas$week, formulas$period)])
    if (anyDuplicated(calendar[[formulas$week]])) {
      stop("Each week must belong to exactly one period.", call. = FALSE)
    }
  }
  data <- set_model_contrasts(data, categorical, spec, formulas, data_spec)
  for (column in names(formulas$encodings)) {
    value <- data[[formulas$encodings[[column]]]]
    data[[column]] <- contrasts(value)[as.integer(value), , drop = FALSE]
  }
  if (length(weight)) data$.model_weights <- data[[weight]]
  if (temporal$active) {
    data$.model_series <- interaction(data$geo_code, data$age_group, drop = TRUE, lex.order = TRUE)
  }
  if (spec$random_effects != "none") {
    data$geo_code <- factor(data$geo_code)
    groups <- list(district = data$geo_code)
    if (spec$random_effects == "kreis_age") {
      data$.model_kreis_age <- interaction(data$geo_code, data[[formulas$age]], drop = TRUE)
      groups$district_age <- data$.model_kreis_age
      if (temporal$structure != "none") {
        membership <- unique(data[c(".model_kreis_age", ".model_series")])
        if (anyDuplicated(membership$.model_kreis_age) || anyDuplicated(membership$.model_series)) {
          stop("Correlated district-age random intercepts must match the residual series.",
               call. = FALSE)
        }
      }
    }
    for (group in groups) {
      if (nlevels(group) < 2L || nlevels(group) >= nrow(data)) {
        stop("Random intercepts require multiple groups and repeated observations.", call. = FALSE)
      }
    }
    if (spec$random_effects == "random_slopes" &&
        !any(vapply(split(data[[spec$slope]], data$geo_code),
                    function(x) length(unique(x)) > 1L, logical(1)))) {
      stop("The random slope requires within-district variation.", call. = FALSE)
    }
  }
  rownames(data) <- as.character(which(keep))
  if (temporal$active) {
    data$.model_time <- data[[time]]
    if (anyDuplicated(data[c(".model_series", ".model_time")])) {
      stop("Residual series must have unique elapsed times.", call. = FALSE)
    }
  }
  if (temporal$structure != "none") {
    if (temporal$structure == "ar1" && any(data$.model_time != trunc(data$.model_time))) {
      stop("AR(1) requires integer elapsed weeks. Choose CAR(1) or an integer phase anchor.",
           call. = FALSE)
    }
    if (!anyDuplicated(data$.model_series)) {
      stop("Residual correlation requires repeated observations within a district-age series.",
           call. = FALSE)
    }
    if (length(weight)) {
      data$.model_variance <- 1 / data$.model_weights
      if (any(!is.finite(data$.model_variance))) stop("Inverse weights must be finite.", call. = FALSE)
    }
    data <- data[order(data$.model_series, data$.model_time), , drop = FALSE]
  }
  list(data = data, categorical = categorical, keys = included, excluded = excluded,
       weight = if (length(weight)) weight else NULL, temporal = temporal,
       sample_times = if (temporal$active) data[[time]][match(rownames(included), rownames(data))])
}

# Pair residuals only within series at the requested elapsed lag.
residual_acf <- function(residual, data, lags) {
  series <- split(seq_len(nrow(data)), data$.model_series)
  time <- data$.model_time
  rbindlist(lapply(lags, function(lag) {
    pairs <- lapply(series, function(rows) {
      earlier <- match(time[rows] - lag, time[rows])
      valid <- !is.na(earlier) & is.finite(residual[rows]) & is.finite(residual[rows[earlier]])
      cbind(residual[rows[earlier[valid]]], residual[rows[valid]])
    })
    paired <- do.call(rbind, pairs)
    n_pairs <- nrow(paired)
    correlation <- if (n_pairs > 1L && all(apply(paired, 2L, stats::sd) > 0)) {
      stats::cor(paired[, 1L], paired[, 2L])
    } else NA_real_
    data.table(lag_weeks = lag, n_pairs = n_pairs,
               n_series = sum(vapply(pairs, nrow, integer(1)) > 0L), correlation = correlation)
  }))
}

correlated_fit_args <- function(formula, data, spec, sample) {
  mixed <- spec$family == "lmm"
  groups <- if (mixed) "geo_code/.model_series" else ".model_series"
  form <- as.formula(paste("~ .model_time |", groups))
  correlation <- if (sample$temporal$structure == "ar1") nlme::corAR1(form = form) else
    nlme::corCAR1(form = form)
  args <- list(data = data, correlation = correlation, method = "ML", na.action = stats::na.fail)
  if (!is.null(sample$weight)) args$weights <- nlme::varFixed(~ .model_variance)
  if (mixed) {
    args$fixed <- formula
    args$random <- switch(spec$random_effects, kreis = ~ 1 | geo_code,
                          kreis_age = ~ 1 | geo_code/.model_series,
                          random_slopes = as.formula(paste("~", spec$slope, "| geo_code")))
  } else args$model <- formula
  args
}

fit_one_model <- function(formula, fixed_formula, sample, spec, rank) {
  family <- spec$family
  correlated <- sample$temporal$structure != "none"
  warnings <- messages <- character()
  start <- proc.time()[["elapsed"]]
  data <- sample$data
  args <- list(formula = formula, data = data, na.action = stats::na.fail)
  if (!is.null(sample$weight)) args$weights <- quote(.model_weights)
  engine <- if (!correlated) switch(family, lm = stats::lm, lmm = lme4::lmer, poisson = stats::glm,
                   quasipoisson = stats::glm, negative_binomial = MASS::glm.nb,
                   poisson_glmm = lme4::glmer, negative_binomial_glmm = lme4::glmer.nb)
  if (family == "lmm") args$REML <- FALSE
  if (family %in% c("poisson", "poisson_glmm")) args$family <- stats::poisson(link = "log")
  if (family == "quasipoisson") args$family <- stats::quasipoisson(link = "log")
  engine_name <- family
  fit <- tryCatch(withCallingHandlers({
    if (correlated) {
      engine_name <- unname(correlated_gaussian_engines[[family]])
      args <- correlated_fit_args(fixed_formula, data, spec, sample)
      engine <- if (family == "lmm") nlme::lme else nlme::gls
    }
    do.call(engine, args)
  },
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  ), error = identity)
  elapsed <- proc.time()[["elapsed"]] - start
  failed <- inherits(fit, "error")
  converged <- singular <- NA
  convergence <- correlation <- autocorrelation <- NULL
  if (!failed) {
    fit_rows <- if (correlated) {
      if (family == "lmm") rownames(fit$residuals) else names(fit$residuals)
    } else rownames(stats::model.frame(fit))
    if (stats::nobs(fit) != nrow(data) || !identical(fit_rows, rownames(data))) {
      stop("The model engine changed the common fitting sample.", call. = FALSE)
    }
    if (correlated) {
      convergence <- list(iterations = fit$numIter,
                          ap_var_status = if (is.character(fit$apVar)) fit$apVar)
      converged <- !any(grepl("converg|iteration limit", warnings, ignore.case = TRUE))
      rho <- unname(coef(fit$modelStruct$corStruct, unconstrained = FALSE))
      correlation <- list(structure = sample$temporal$structure, rho_per_week = rho,
                          phase_time = sample$temporal$phase_time,
                          series = c("geo_code", "age_group"))
    } else if (inherits(fit, "merMod")) {
      if (length(lme4::fixef(fit)) != rank) {
        stop("The model engine dropped prevalidated fixed effects.", call. = FALSE)
      }
      info <- fit@optinfo
      convergence <- info$conv
      singular <- lme4::isSingular(fit)
      diagnostics <- info$conv$lme4$messages
      converged <- all(info$conv$opt == 0) &&
        !any(!grepl("boundary (singular) fit", diagnostics, fixed = TRUE))
    } else if (inherits(fit, "glm")) {
      convergence <- if (inherits(fit, "negbin")) fit$th.warn else NULL
      converged <- isTRUE(fit$converged) && is.null(convergence)
    }
    if (length(sample$temporal$lags)) {
      autocorrelation <- list(pearson = residual_acf(
        stats::residuals(fit, type = "pearson"), data, sample$temporal$lags
      ))
      if (correlated) autocorrelation$normalized <- residual_acf(
        stats::residuals(fit, type = "normalized"), data, sample$temporal$lags
      )
    }
  }
  list(model = if (!failed) fit, formula = formula, engine = engine_name, rank = rank,
       n_attempted = nrow(data), n = if (!failed) nrow(data) else NA_integer_,
       runtime_seconds = elapsed, warnings = warnings, messages = messages,
       converged = converged, convergence = convergence, singular = singular,
       residual_correlation = correlation, residual_acf = autocorrelation,
       error = if (failed) conditionMessage(fit))
}

# Use load_model_data(data_spec) to prepare one configured panel before fitting.
# Specify response, family, weighting, random_effects, contrast and missing policy.
# Optional age_var, period_var and week_var name alternative categorical columns.
# Treatment contrasts use the configured references or explicit named overrides.
# Weekly treatment coding uses the earliest observed week when no override is supplied.
# Sum coding has no reference level. Precision weights require an external column.
# Random slopes use a correlated district intercept and slope on one fixed main effect.
# Count weights are prior weights alongside the exposure offset.
# Return fitted objects, sample keys and diagnostics in memory. LMMs use ML.
# Within-call comparisons share the sample, weights and offset. Check keys across calls.
# Rank checks use dense matrices. Large weekly designs can require substantial memory.
# Predictions with new weekly data require the returned interaction encodings.
# Quasi-Poisson has no likelihood-based AIC. Robust inference is downstream.
# Weekly panels allow week or period fixed effects; phase panels use period effects.
# Select temporal_correlation independently of temporal_fixed_effects and random slopes.
# For phase correlation or diagnostics, choose phase_time explicitly.
# AR(1) uses integer weeks; CAR(1) accepts fractional weeks and positive rho.
# Supply acf_lags to report pooled within-series correlations at exact elapsed lags.
# Pooled correlations are descriptive; series with more pairs contribute more.
# Few phases can yield few or no pairs. Phase anchors represent whole scheduled phases.
# Correlated district-age intercepts require the random and residual groupings to match.
# nlme uses inverse prior weights as variance factors. Singularity is lme4-specific.
fit_models <- function(prepared, spec, model_ids) {
  data_spec <- attr(prepared, "data_spec")
  formulas <- model_formulas(spec, data_spec, model_ids)
  family <- spec$family
  temporal <- temporal_specification(spec, data_spec)
  package <- if (temporal$structure != "none") "nlme" else if (spec$random_effects != "none") {
    "lme4"
  } else if (family == "negative_binomial") "MASS"
  if (length(package) && !requireNamespace(package, quietly = TRUE)) {
    stop("Install ", package, " for ", family, ".", call. = FALSE)
  }
  sample <- build_fit_sample(prepared, spec, formulas, data_spec)
  ranks <- vapply(model_ids, function(id) validate_model_matrix(
    sample$data, formulas$fixed[[id]], formulas$terms[[id]], sample$categorical, formulas$period, id
  ), integer(1))
  results <- setNames(lapply(model_ids, function(id) {
    fit_one_model(formulas$full[[id]], formulas$fixed[[id]], sample, spec, ranks[[id]])
  }), model_ids)
  list(data_spec = data_spec, model_spec = spec, n_input = nrow(prepared),
       n_sample = nrow(sample$data), sample_keys = sample$keys, excluded_keys = sample$excluded,
       factor_levels = lapply(sample$data[sample$categorical], levels),
       factor_contrasts = lapply(sample$data[sample$categorical], contrasts),
       interaction_encodings = formulas$encodings,
       weight_column = sample$weight, offset_column = if (spec$response == "count") count_offset_column,
       temporal_fixed_effects = formulas$temporal_fixed_effects,
       temporal_spec = sample$temporal, sample_times = sample$sample_times,
       estimation = if (family == "lmm" || temporal$structure != "none") "ML" else family,
       fits = results)
}
