# Run from the project root. This script covers the provisional empirical round.
source("Scripts/Modellierung/fit_models.R")
library(ggplot2)

run_initial_models <- function() {
  out <- "results/Modellierung/Initial"
  report <- "reports/Modellierung/Erste_Modellierung.md"
  for (path in c(file.path(out, c("models", "tables", "plots")), dirname(report))) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  tables <- function(x, name) fwrite(x, file.path(out, "tables", paste0(name, ".csv")), na = "")
  plot_file <- function(p, name, width = 10, height = 6) {
    ggsave(file.path(out, "plots", paste0(name, ".pdf")), p, width = width, height = height, device = "pdf")
  }
  data_spec <- list(age_scheme = "7", structure = "kreistyp", time_resolution = "phase",
                    include_p0 = FALSE, split_postw5 = FALSE, kreistyp_version = "dynamic",
                    missing_strategy = "unbalanced", aggregation = "arithmetic",
                    phase_missing = "complete", phase_type_tie = "error")
  data <- load_model_data(data_spec)
  lags <- diff(sort(unique(data$phase_mid_week)))
  base <- list(weighting = "unweighted", contrast = "treatment", missing = "complete_cases",
               temporal_fixed_effects = "period", temporal_correlation = "none",
               phase_time = "midpoint", acf_lags = sort(unique(lags)))
  families <- c(raw_lm = "lm", raw_lmm = "lmm", log_lm = "lm", log_lmm = "lmm",
                poisson = "poisson", negbin = "negative_binomial")
  responses <- setNames(rep(c("incidence", "log1p", "count"), each = 2L), names(families))
  input_sha <- digest::digest(file.path(paths$model_data, "kreis_weekly_7.rds"), algo = "sha256", file = TRUE)
  pipeline_files <- file.path("Scripts/Modellierung", c("config.R", "prepare_model_data.R", "model_formulas.R", "fit_models.R"))
  pipeline_sha <- digest::digest(vapply(pipeline_files, digest::digest, "", algo = "sha256", file = TRUE),
                                 algo = "sha256")
  invisible(lapply(c("lme4", "MASS"), loadNamespace))
  versions <- c(R = as.character(getRversion()),
                vapply(c("lme4", "MASS", "data.table"), function(p) as.character(packageVersion(p)), ""))
  data_sha <- digest::digest(as.data.frame(data), algo = "sha256")
  common_keys <- NULL
  registry <- list()
  fit <- function(name, id) {
    model_spec <- c(base, list(family = families[[name]], response = responses[[name]],
                    random_effects = if (families[[name]] == "lmm") "kreis" else "none"))
    signature <- list(input_sha = input_sha, pipeline_sha = pipeline_sha, data_sha = data_sha,
                      versions = versions, data_spec = data_spec, model_spec = model_spec, model_id = id)
    key <- digest::digest(signature, algo = "sha256")
    file <- file.path(out, "models", paste0(name, "_", id, "_", key, ".rds"))
    cached <- file.exists(file)
    if (cached) {
      entry <- readRDS(file)
      stopifnot(identical(entry$signature, signature))
    } else {
      result <- fit_models(data, model_spec, id)
      entry <- list(signature = signature, result = result)
      staged <- tempfile(tmpdir = dirname(file))
      saveRDS(entry, staged)
      if (!file.rename(staged, file)) stop("Could not publish ", file)
    }
    result <- entry$result
    if (is.null(common_keys)) common_keys <<- result$sample_keys
    stopifnot(identical(common_keys, result$sample_keys))
    z <- result$fits[[id]]
    encode <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")
    registry[[paste(name, id)]] <<- data.table(
      specification = name, model_id = id, decision_ids = paste(sprintf("e%02d", 1:13), collapse = ";"),
      dependence_decision = "e10-3", data_spec = encode(data_spec), model_spec = encode(model_spec),
      software_versions = encode(versions), engine = z$engine, formula = encode(z$formula),
      input_sha256 = input_sha, prepared_sha256 = data_sha, pipeline_sha256 = pipeline_sha,
      sample_sha256 = digest::digest(common_keys, algo = "sha256"), model_file = file,
      n_input = result$n_input, n_sample = result$n_sample, n_excluded = nrow(result$excluded_keys),
      n_districts = uniqueN(common_keys$geo_code), rank = z$rank, estimation = result$estimation,
      status = if (!is.null(z$error)) "error" else if (isFALSE(z$converged)) "nonconverged" else "fitted",
      converged = z$converged, singular = z$singular,
      runtime_seconds = z$runtime_seconds, warnings = paste(z$warnings, collapse = " | "),
      messages = paste(z$messages, collapse = " | "), convergence = encode(z$convergence),
      error = if (is.null(z$error)) "" else z$error, cache_hit = cached
    )
    message(name, " ", id, if (cached) " cached" else " fitted")
    z
  }
  initial <- setNames(lapply(names(families), function(name) fit(name, "M0b")), names(families))
  tables(rbindlist(registry), "m0b_registry")
  tables(common_keys, "sample_keys")
  sample_rows <- match(do.call(paste, common_keys), do.call(paste, data[, names(common_keys), with = FALSE]))
  stopifnot(!anyNA(sample_rows))
  sample <- data[sample_rows]
  tables(data[!sample_rows], "excluded_sample")
  fit_stats <- function(z, name, id) {
    model <- z$model
    if (is.null(model)) return(data.table(specification = name, model_id = id))
    count <- responses[[name]] == "count"
    rp <- residuals(model, type = "pearson")
    likelihood <- logLik(model)
    fitted_count <- if (count) fitted(model) else NULL
    ri_sd <- if (inherits(model, "merMod")) attr(lme4::VarCorr(model)$geo_code, "stddev")[[1L]] else NA_real_
    data.table(specification = name, model_id = id, response = responses[[name]],
      n = nobs(model), log_likelihood = as.numeric(likelihood), likelihood_df = attr(likelihood, "df"),
      aic = AIC(model), bic = BIC(model),
      pearson_dispersion = if (count) sum(rp^2) / df.residual(model) else NA_real_,
      nb_theta = if (inherits(model, "negbin")) model$theta else NA_real_,
      district_intercept_sd = ri_sd,
      residual_sd = if (!count) sigma(model) else NA_real_,
      observed_zero_fraction = if (count) mean(sample$cases == 0) else NA_real_,
      expected_zero_fraction = if (inherits(model, "negbin")) {
        mean(dnbinom(0, mu = fitted_count, size = model$theta))
      } else if (count) mean(dpois(0, fitted_count)) else NA_real_)
  }
  comparison <- rbindlist(lapply(names(initial), function(name) fit_stats(initial[[name]], name, "M0b")), fill = TRUE)
  tables(comparison, "m0b_fit_comparison")
  acf_table <- function(models, id) rbindlist(lapply(names(models), function(name) {
    a <- copy(models[[name]]$residual_acf$pearson)
    if (!is.null(a)) a[, `:=`(specification = name, model_id = id)]
    a
  }))
  acf <- acf_table(initial, "M0b")
  tables(acf, "m0b_residual_acf")

  # Carry forward Gaussian identity and NB log-link candidates with distinct estimands.
  usable <- function(z) !is.null(z$model) && !isFALSE(z$converged) && !isTRUE(z$singular)
  stopifnot(usable(initial$raw_lmm), usable(initial$negbin),
            comparison[specification == "negbin", aic] < comparison[specification == "poisson", aic])
  retained <- c("raw_lmm", "negbin")
  ids <- model_options$model_id
  hierarchy <- setNames(lapply(retained, function(name) {
    setNames(lapply(ids, function(id) if (id == "M0b") initial[[name]] else fit(name, id)), ids)
  }), retained)
  stopifnot(all(vapply(unlist(hierarchy, recursive = FALSE), usable, logical(1))))
  hierarchy_stats <- rbindlist(lapply(retained, function(name) {
    rbindlist(lapply(ids, function(id) fit_stats(hierarchy[[name]][[id]], name, id)))
  }))
  hierarchy_stats[, `:=`(delta_aic = aic - min(aic), delta_bic = bic - min(bic)), by = specification]
  tables(hierarchy_stats, "hierarchy_fit_comparison")
  all_stats <- unique(rbindlist(list(comparison, hierarchy_stats[, names(comparison), with = FALSE])),
                      by = c("specification", "model_id"))
  hierarchy_acf <- rbindlist(lapply(ids, function(id) {
    acf_table(setNames(lapply(hierarchy, `[[`, id), retained), id)
  }))
  tables(hierarchy_acf, "hierarchy_residual_acf")
  all_acf <- unique(rbindlist(list(acf, hierarchy_acf)), by = c("specification", "model_id", "lag_weeks"))
  acf_summary <- all_acf[, .(max_abs_residual_acf = max(abs(correlation), na.rm = TRUE)),
                         by = .(specification, model_id)]
  all_registry <- Reduce(function(left, right) {
    merge(left, right, by = c("specification", "model_id"), all.x = TRUE, sort = FALSE)
  }, list(rbindlist(registry), all_stats[, !"n"], acf_summary))
  all_registry[, inference := fifelse(model_id == "M3" & specification %in% retained,
                                     "District-cluster HC1 sandwich; t(G-1)", "")]
  fwrite(all_registry, file.path(out, "model_registry.csv"), na = "")

  # Compare residual behavior on each family's fitting scale.
  set.seed(20261125)
  diagnostic <- rbindlist(lapply(names(initial), function(name) {
    m <- initial[[name]]$model
    f <- fitted(m)
    r <- residuals(m, type = "pearson")
    y <- model.response(model.frame(m))
    if (responses[[name]] == "count") {
      cdf <- if (inherits(m, "negbin")) function(k) pnbinom(k, mu = f, size = m$theta) else
        function(k) ppois(k, lambda = f)
      lower <- cdf(y - 1)
      upper <- cdf(y)
      q <- qnorm(pmin(1 - 1e-12, pmax(1e-12, lower + runif(length(y)) * (upper - lower))))
    } else q <- r / sigma(m)
    data.table(specification = name, fitted = f, pearson = r, qq_residual = q)
  }))
  diagnostics <- diagnostic[, {
    extremes <- quantile(fitted, c(0.2, 0.8))
    list(low_fitted_rms = sqrt(mean(pearson[fitted <= extremes[1L]]^2)),
         high_fitted_rms = sqrt(mean(pearson[fitted >= extremes[2L]]^2)),
         qq_abs_gt_3 = mean(abs(qq_residual) > 3))
  }, by = specification]
  diagnostics[, high_to_low_rms := high_fitted_rms / low_fitted_rms]
  tables(diagnostics, "m0b_residual_summary")
  plot_file(ggplot(diagnostic, aes(fitted, pearson)) +
    geom_point(alpha = 0.14, size = 0.35) + geom_hline(yintercept = 0, colour = "#B54A35") +
    facet_wrap(~specification, scales = "free") + theme_bw() +
    labs(x = "Angepasster Wert auf Modellskala", y = "Pearson-Residuum"), "m0b_residual_fitted")
  plot_file(ggplot(diagnostic, aes(sample = qq_residual)) +
    stat_qq(size = 0.45, alpha = 0.4) + geom_abline(colour = "#B54A35") +
    facet_wrap(~specification, scales = "free_y") + theme_bw() +
    labs(x = "Theoretisches Normalquantil", y = "Residuenquantil"), "m0b_qq")
  plot_file(ggplot(acf, aes(lag_weeks, correlation)) +
    geom_hline(yintercept = 0, colour = "grey65") + geom_point(aes(size = n_pairs), colour = "#226C7B") +
    facet_wrap(~specification) + theme_bw() +
    labs(x = "Kalenderabstand in Wochen", y = "Gepoolte Residuenkorrelation", size = "Paare"),
    "m0b_temporal_residuals")

  cluster_inference <- function(model, district) {
    mixed <- inherits(model, "merMod")
    x <- if (mixed) lme4::getME(model, "X") else model.matrix(model)
    beta <- if (mixed) lme4::fixef(model) else coef(model)
    y <- model.response(model.frame(model))
    stopifnot(length(district) == nrow(x), identical(colnames(x), names(beta)))
    if (mixed) {
      # Apply the inverse marginal random-intercept covariance within each district.
      var_e <- sigma(model)^2
      var_b <- as.numeric(lme4::VarCorr(model)$geo_code)
      n_group <- ave(rep(1, nrow(x)), district, FUN = length)
      group_sum <- rowsum(x, district)
      inv_x <- (x - group_sum[match(district, rownames(group_sum)), , drop = FALSE] *
                  (var_b / (var_e + n_group * var_b))) / var_e
      bread_inv <- crossprod(x, inv_x)
      score <- rowsum(inv_x * drop(y - x %*% beta), district)
      stopifnot(isTRUE(all.equal(unname(solve(bread_inv)), unname(as.matrix(vcov(model))),
                                 tolerance = 1e-7)))
    } else {
      # NB2 estimating equations for log means, with the fitted exposure offset.
      mu <- fitted(model)
      var_factor <- 1 + mu / model$theta
      bread_inv <- crossprod(x, x * (mu / var_factor))
      score <- rowsum(x * ((y - mu) / var_factor), district)
    }
    g <- nrow(score)
    adj <- (g / (g - 1)) * ((nrow(x) - 1) / (nrow(x) - ncol(x)))
    v <- crossprod(score %*% solve(bread_inv)) * adj
    stopifnot(all(is.finite(v)), all(diag(v) > 0))
    list(beta = beta, covariance = v, x = x, df = g - 1L)
  }
  interval <- function(est, gradient, inf) {
    gradient <- as.matrix(gradient)
    se <- sqrt(pmax(0, rowSums((gradient %*% inf$covariance) * gradient)))
    critical <- qt(0.975, inf$df)
    data.table(estimate = as.numeric(est), se = se, lower = est - critical * se,
               upper = est + critical * se, p = 2 * pt(-abs(est / se), inf$df))
  }

  # Predict all M3 cells and contrast district types against large independent cities.
  ages <- unique(readRDS(paths$age_mapping)$age_group_7)
  phases <- setdiff(study_config$periods, "P0")
  regions <- sort(unique(sample$kreistyp))
  ref <- reference_levels$kreistyp
  ref_age <- reference_levels$age_group[["7"]]
  ref_phase <- reference_levels$period
  grid <- CJ(kreistyp = regions, age_group = ages, period = phases)
  grid[, log_exposure := log(study_config$incidence_scale)]
  cell <- function(region, age, phase) which(grid$kreistyp == region &
                                               grid$age_group == age & grid$period == phase)
  predictions <- differences <- interactions <- coefficients <- list()
  for (name in retained) {
    m <- hierarchy[[name]]$M3$model
    model_rows <- model.frame(m)
    stopifnot(identical(rownames(model_rows), as.character(sample_rows)))
    inf <- cluster_inference(m, sample$geo_code)
    is_count <- responses[[name]] == "count"
    scale <- if (is_count) "log_rate" else "incidence"
    co <- interval(inf$beta, diag(length(inf$beta)), inf)
    co[, `:=`(term = names(inf$beta), specification = name, model_id = "M3",
              scale = scale, n_clusters = inf$df + 1L)]
    coefficients[[name]] <- co[grepl(":", term)]
    fixed <- if (is_count) terms(m) else terms(m, fixed.only = TRUE)
    for (col in c("kreistyp", "age_group", "period")) {
      grid[[col]] <- factor(grid[[col]], levels = levels(model_rows[[col]]))
    }
    design <- model.matrix(delete.response(fixed), grid, contrasts.arg = attr(inf$x, "contrasts"))
    stopifnot(identical(colnames(design), names(inf$beta)))
    eta <- drop(design %*% inf$beta)
    rate <- if (is_count) study_config$incidence_scale * exp(eta) else eta
    drate <- if (is_count) design * rate else design
    pred <- interval(eta, design, inf)
    if (is_count) pred[, c("estimate", "lower", "upper") :=
      lapply(.SD, function(z) study_config$incidence_scale * exp(z)),
      .SDcols = c("estimate", "lower", "upper")]
    predictions[[name]] <- cbind(copy(grid[, !"log_exposure"]), pred[, .(estimate, lower, upper)])
    predictions[[name]][, specification := name]
    pair <- grid[kreistyp != ref, .(kreistyp, age_group, period)]
    index <- seq_len(nrow(pair))
    current <- vapply(index, function(i) cell(pair$kreistyp[i], pair$age_group[i], pair$period[i]), integer(1))
    urban <- vapply(index, function(i) cell(ref, pair$age_group[i], pair$period[i]), integer(1))
    difference <- interval(rate[current] - rate[urban],
                           drate[current, , drop = FALSE] - drate[urban, , drop = FALSE], inf)
    differences[[name]] <- cbind(pair, difference)[, `:=`(specification = name,
      contrast = paste("Kreistyp minus", ref), p_holm = p.adjust(p, "holm"))]
    choices <- pair[age_group %in% c("6–17", "60–69", "80+") & period %in% c("W4", "W5", "PostW5")]
    triple <- rbindlist(lapply(seq_len(nrow(choices)), function(i) {
      row <- choices[i]
      age <- row$age_group
      phase <- row$period
      region <- row$kreistyp
      cells <- c(cell(region, age, phase), cell(ref, age, phase),
                 cell(region, ref_age, phase), cell(ref, ref_age, phase),
                 cell(region, age, ref_phase), cell(ref, age, ref_phase),
                 cell(region, ref_age, ref_phase), cell(ref, ref_age, ref_phase))
      signs <- c(1, -1, -1, 1, -1, 1, 1, -1)
      ci <- interval(sum(rate[cells] * signs), crossprod(signs, drate[cells, , drop = FALSE]), inf)
      cbind(row, ci)
    }))
    interactions[[name]] <- triple[, `:=`(specification = name, p_holm = p.adjust(p, "holm"),
                                      reference_region = ref, reference_age = ref_age,
                                      reference_phase = ref_phase)]
  }
  predicted <- rbindlist(predictions)
  gaps <- rbindlist(differences)
  triple <- rbindlist(interactions)
  stopifnot(
    nrow(predicted) == length(retained) * length(regions) * length(ages) * length(phases),
    nrow(gaps) == length(retained) * (length(regions) - 1L) * length(ages) * length(phases),
    nrow(triple) == length(retained) * (length(regions) - 1L) * 9L,
    all(is.finite(predicted$estimate)), all(gaps$lower <= gaps$upper), all(triple$lower <= triple$upper)
  )
  tables(rbindlist(coefficients), "m3_interaction_coefficients")
  tables(predicted, "m3_predicted_weekly_incidence")
  tables(gaps, "m3_district_contrasts")
  tables(triple, "m3_three_way_contrasts")
  plot_age_labels <- function(labels) sub("–", "-", labels, fixed = TRUE)
  for (dt in list(predicted, gaps)) {
    dt[, `:=`(period = factor(period, levels = phases), age_group = factor(age_group, levels = ages))]
  }
  plot_file(ggplot(predicted, aes(period, estimate, colour = kreistyp, group = kreistyp)) +
    geom_line(linewidth = 0.65) + geom_point(size = 1.15) +
    facet_grid(specification ~ age_group, labeller = labeller(age_group = plot_age_labels)) + theme_bw() +
    theme(axis.text.x = element_text(angle = 55, hjust = 1), legend.position = "bottom") +
    labs(x = "Phase", y = "Geschätzte wöchentliche Fälle je 100.000", colour = "Kreistyp"),
    "m3_predicted_incidence", 15, 6)
  displayed <- gaps[age_group %in% c("6–17", "18–39", "60–69", "80+") & period %in% c("W1", "W4", "W5", "PostW5")]
  plot_file(ggplot(displayed, aes(period, estimate, colour = kreistyp, group = kreistyp)) +
    geom_hline(yintercept = 0, colour = "grey65") +
    geom_pointrange(aes(ymin = lower, ymax = upper), position = position_dodge(width = 0.5)) +
    facet_grid(specification ~ age_group, labeller = labeller(age_group = plot_age_labels)) + theme_bw() +
    theme(legend.position = "bottom") +
    labs(x = "Phase", y = "Differenz zu Großstädten je 100.000", colour = "Kreistyp"),
    "m3_district_contrasts", 12, 6)

  triple_plot <- copy(triple)
  triple_plot[, period := factor(period, levels = phases)]
  plot_file(ggplot(triple_plot, aes(period, estimate, colour = kreistyp)) +
    geom_hline(yintercept = 0, colour = "grey65") +
    geom_pointrange(aes(ymin = lower, ymax = upper), position = position_dodge(width = 0.55)) +
    facet_grid(specification ~ age_group, labeller = labeller(age_group = plot_age_labels)) + theme_bw() +
    theme(legend.position = "bottom") +
    labs(x = "Phase", y = "Dreifachkontrast je 100.000", colour = "Kreistyp"),
    "m3_three_way_contrasts", 12, 6)

  # Generate the report from the recorded fits and contrasts.
  num <- function(x, digits = 1L) formatC(x, format = "f", digits = digits, decimal.mark = ",")
  metric <- function(name, col) comparison[specification == name, get(col)]
  acf_max <- function(name) acf[specification == name, max(abs(correlation))]
  aic_drop <- function(name) {
    hierarchy_stats[specification == name & model_id == "M0a", aic] -
      hierarchy_stats[specification == name & model_id == "M3", aic]
  }
  rural <- "Dünn besiedelte ländliche Kreise"
  top <- triple[kreistyp == rural & age_group == "80+" & period == "W5"]
  high <- gaps[kreistyp == rural & age_group == "80+" & period == "W5"]
  levels_w5 <- predicted[age_group == "80+" & period == "W5" & kreistyp %in% c(ref, rural)]
  contrast_row <- function(name) {
    g <- high[specification == name]
    t <- top[specification == name]
    city <- levels_w5[specification == name & kreistyp == ref, estimate]
    country <- levels_w5[specification == name & kreistyp == rural, estimate]
    sprintf("| %s | %s | %s | %s [%s; %s] | %s [%s; %s] | %s |",
            name, num(city), num(country), num(g$estimate), num(g$lower), num(g$upper),
            num(t$estimate), num(t$lower), num(t$upper), format.pval(t$p_holm, digits = 2))
  }
  agreement <- merge(triple[specification == "raw_lmm"], triple[specification == "negbin"],
                     by = c("kreistyp", "age_group", "period"))
  same_sign <- sign(agreement$estimate.x) == sign(agreement$estimate.y)
  supported <- same_sign & agreement$p_holm.x < 0.05 & agreement$p_holm.y < 0.05
  aic_rows <- vapply(names(families), function(name) {
    sprintf("| %s | %s | %s | %s |", name, num(metric(name, "aic")), num(metric(name, "bic")),
            num(acf_max(name), 2L))
  }, "")
  fit_status <- rbindlist(registry)
  clean <- !any(nzchar(fit_status$warnings) | nzchar(fit_status$messages) |
                  fit_status$converged %in% FALSE | fit_status$singular %in% TRUE)
  writeLines(c(
    "# Erste Modellierung",
    "",
    "## Stichprobe und Zielgrößen",
    "",
    sprintf("Die vorläufige Analyse verwendet sieben Altersgruppen, acht Phasen ohne P0 und mit gemeinsamem PostW5 sowie den dynamischen Kreistyp. Der Kreistyp einer Phase entspricht dem häufigsten Typ über ihre Kalenderwochen. Die Modelle sind ungewichtet. Von %s Kreis–Altersgruppen–Phasen gehen %s aus %s Kreisen in alle Modelle ein. %s Phasenbeobachtungen entfallen wegen unvollständiger Bevölkerungsnenner. Echte Nullwerte bleiben erhalten.",
            nrow(data), nrow(sample), uniqueN(sample$geo_code), nrow(data) - nrow(sample)),
    "",
    "Die Gauß-Modelle verwenden das arithmetische Mittel der wöchentlichen Inzidenz oder dessen log1p-Transformation. Die Zählmodelle verwenden die Phasenfallzahl mit dem Logarithmus der Personenwochen als Offset. Beide vorhergesagten Wocheninzidenzen haben dieselbe Einheit. Das arithmetische Mittel und die Expositionsrate können bei wechselnden Jahresnennern voneinander abweichen.",
    "",
    "## M0b und vorläufige Weiterführung",
    "",
    "| Spezifikation | AIC | BIC | Max. absolute Residuenkorrelation |",
    "|---|---:|---:|---:|", aic_rows,
    "",
    "AIC, BIC und Log-Likelihood sind jeweils innerhalb derselben Antwortskala vergleichbar. Sie beschreiben den Fit unter der jeweils angenommenen Kovarianz.",
    "",
    sprintf("Die Kreiszufallseffekte verbessern AIC und BIC auf beiden Gauß-Skalen. Poisson zeigt starke Überdispersion (Pearson-Quotient %s). Beim negativen Binomialmodell fällt der Quotient auf %s (θ = %s). Beobachtet werden %s %% Nullen, gegenüber %s %% unter Poisson und %s %% unter Negativ-Binomial.",
            num(metric("poisson", "pearson_dispersion"), 2), num(metric("negbin", "pearson_dispersion"), 2),
            num(metric("negbin", "nb_theta"), 2), num(100 * metric("negbin", "observed_zero_fraction"), 2),
            num(100 * metric("poisson", "expected_zero_fraction"), 2),
            num(100 * metric("negbin", "expected_zero_fraction"), 2)),
    "",
    sprintf("Beim LMM auf Originalskala beträgt die Residuen-RMS im obersten gegenüber dem untersten Fünftel der angepassten Werte das %s-Fache (Log-LMM %s). QQ-Diagramme der Gauß-Residuen und randomisierten Zählmodell-Residuen ergänzen die Diagnose. Die gepoolten Korrelationen innerhalb von Kreis und Altersgruppe verwenden tatsächliche Abstände zwischen Phasenmitten. Beim Originalskalen-LMM und beim negativen Binomialmodell erreichen sie betragsmäßig %s bzw. %s. Acht Phasen mit wechselnden Abständen liefern nur begrenzte Evidenz zur Wahl einer zeitlichen Kovarianz.",
            num(diagnostics[specification == "raw_lmm", high_to_low_rms], 2),
            num(diagnostics[specification == "log_lmm", high_to_low_rms], 2),
            num(acf_max("raw_lmm"), 2), num(acf_max("negbin"), 2)),
    "",
    sprintf("Vorläufig werden das Originalskalen-LMM für absolute Unterschiede und das negative Binomialmodell für expositionsbezogene Raten durch M0a–M3 geführt. Die M0b-Fits wurden wiederverwendet. Innerhalb dieser Spezifikationen sinkt der AIC von M0a zu M3 um %s bzw. %s. %s",
            num(aic_drop("raw_lmm")), num(aic_drop("negbin")),
            if (clean) "Die Konvergenzprüfungen waren unauffällig. Alle LMMs hatten eine positive geschätzte Kreisvarianz."
            else "Warnungen, Konvergenz und Singularität sind im Register ausgewiesen."),
    "",
    sprintf("Innerhalb des Originalskalen-LMMs liegt das AIC-Minimum bei %s, innerhalb des negativen Binomialmodells bei %s. Das BIC bevorzugt in beiden Fällen %s. M3 dient hier der Schätzung der alters- und phasenspezifischen Kreistyp-Kontraste. Auch unter M3 bleiben maximale absolute Residuenkorrelationen von %s bzw. %s.",
            hierarchy_stats[specification == "raw_lmm", model_id[which.min(aic)]],
            hierarchy_stats[specification == "negbin", model_id[which.min(aic)]],
            hierarchy_stats[specification == "raw_lmm", model_id[which.min(bic)]],
            num(acf_summary[specification == "raw_lmm" & model_id == "M3", max_abs_residual_acf], 2),
            num(acf_summary[specification == "negbin" & model_id == "M3", max_abs_residual_acf], 2)),
    "",
    "## Kreistyp, Alter und Phase",
    "",
    "M3 vergleicht vorhergesagte Inzidenzen bei identischem Alter und identischer Phase. Beim LMM wird über den Kreiszufallseffekt gemittelt. Das negative Binomialmodell wird auf 100.000 Personenwochen skaliert. Ein positiver Dreifachkontrast bedeutet, dass sich der Kreistypabstand zu Großstädten gegenüber W1 für die betrachtete Altersgruppe stärker nach oben verschoben hat als für die Referenzgruppe 18–39.",
    "",
    "Das Beispiel zeigt dünn besiedelte ländliche Kreise und kreisfreie Großstädte für Personen ab 80 Jahren in W5. Die Einheit ist wöchentliche Fälle je 100.000. Die Klammern zeigen punktweise 95-%-Intervalle.",
    "",
    "| Modell | Großstädte | Dünn besiedelte ländliche Kreise | Differenz in W5 | Dreifachkontrast gegenüber W1 und 18–39 | Holm-p des Dreifachkontrasts |",
    "|---|---:|---:|---:|---:|---:|", vapply(retained, contrast_row, ""),
    "",
    "In W5 liegt die geschätzte Inzidenz für 80+ in dünn besiedelten ländlichen Kreisen höher als in Großstädten. Der negative Dreifachkontrast zeigt zugleich, dass sich dieser Abstand von W1 zu W5 gegenüber der Altersgruppe 18–39 nach unten verschoben hat.",
    "",
    sprintf("Bei %s von %s Dreifachkontrasten für 6–17, 60–69 und 80+ in W4, W5 und PostW5 stimmen die Vorzeichen überein. Bei %s sind zusätzlich in beiden Spezifikationen die Holm-adjustierten p-Werte kleiner als 0,05. Die CSV-Tabellen enthalten alle vorhergesagten Zellen, alle Kreistypabstände zu Großstädten und die ausgewählten Dreifachkontraste. Die Koeffizienten stehen auf Identitäts- bzw. Logratenskala und ihre p-Werte sind nominal.",
            sum(same_sign), nrow(agreement), sum(supported)),
    "",
    "## Inferenz und offene Punkte",
    "",
    "Die Intervalle und Tests verwenden einen auf Kreisebene geclusterten Sandwich-Schätzer mit HC1-Korrektur und t-Approximation. Die geschätzten Varianzparameter werden eingesetzt. Für Differenzen aus dem negativen Binomialmodell wird die Delta-Methode verwendet. Holm wird getrennt pro Modell und Kontrastfamilie angewandt. Serielle Abhängigkeit innerhalb eines Kreises bleibt als Kovarianzmodell offen. Räumliche Abhängigkeit zwischen Kreisen kann die angenommene Unabhängigkeit der Cluster verletzen. Die Auswahl und Vergleiche dieser ersten Runde sind explorativ.",
    "",
    "Die Rücktransformation mit expm1 allein liefert im Allgemeinen keine arithmetische mittlere Inzidenz. Eine geeignete Rücktransformation müsste die Residuenverteilung und beim LMM auch den Zufallseffekt berücksichtigen. Die Log-Modelle bleiben daher in der M0b-Diagnostik. Das Originalskalen-LMM kann negative Werte liefern. Dynamische Kreistypen können sich zwischen Phasen in ihrer Zusammensetzung unterscheiden. Die Schätzungen beschreiben Assoziationen.",
    "",
    "## Reproduzierbarkeit",
    "",
    "Das Modellregister enthält Formeln, Entscheidungs-IDs, Prüfsummen zu Daten und Stichprobe, Fit-Status sowie Pfade zu den RDS-Dateien. Die Tabellen sample_keys.csv und excluded_sample.csv dokumentieren die gemeinsame Stichprobe. Die Modell-RDS enthalten die Cache-Signatur und die vollständigen Ergebnisse aus der bestehenden Pipeline."
  ), report)
}
run_initial_models()
