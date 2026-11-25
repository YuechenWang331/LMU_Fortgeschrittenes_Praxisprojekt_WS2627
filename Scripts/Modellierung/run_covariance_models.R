# Run from the project root. Reuse the first round's sample, formulas and fits.
source("Scripts/Modellierung/fit_models.R")
library(ggplot2)

run_covariance_models <- function() {
  initial <- "results/Modellierung/Initial"
  out <- "results/Modellierung/Covariance"
  report <- "reports/Modellierung/Varianz_und_Abhaengigkeitsstruktur.md"
  for (path in c(file.path(out, c("models", "tables", "plots")), dirname(report))) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  write_table <- function(x, name) fwrite(x, file.path(out, "tables", paste0(name, ".csv")), na = "")
  write_plot <- function(p, name) {
    ggsave(file.path(out, "plots", paste0(name, ".png")), p, width = 11, height = 6)
  }
  original <- fread(file.path(initial, "model_registry.csv"))
  if (!requireNamespace("lme4", quietly = TRUE) || !requireNamespace("MASS", quietly = TRUE) ||
      !requireNamespace("nlme", quietly = TRUE)) stop("The original fitting engines are required.")
  read_original <- function(name) {
    row <- original[specification == name & model_id == "M3"]
    stopifnot(nrow(row) == 1L)
    readRDS(row$model_file)
  }
  raw <- read_original("raw_lmm")
  nb <- read_original("negbin")
  spec <- raw$signature$data_spec
  data <- load_model_data(spec)
  input_hash <- function(path) digest::digest(path, algo = "sha256", file = TRUE)
  data_sha <- digest::digest(as.data.frame(data), algo = "sha256")
  input_sha <- input_hash(file.path(paths$model_data, "kreis_weekly_7.rds"))
  pipeline_files <- file.path("Scripts/Modellierung",
                             c("config.R", "prepare_model_data.R", "model_formulas.R", "fit_models.R"))
  pipeline_sha <- digest::digest(vapply(pipeline_files, input_hash, ""), algo = "sha256")
  base_versions <- c(R = as.character(getRversion()),
                     vapply(c("lme4", "MASS", "data.table"), function(p) as.character(packageVersion(p)), ""))
  for (entry in list(raw, nb)) {
    stopifnot(identical(entry$signature$data_spec, spec), identical(entry$signature$data_sha, data_sha),
              identical(entry$signature$input_sha, input_sha),
              identical(entry$signature$pipeline_sha, pipeline_sha),
              identical(entry$signature$versions, base_versions))
  }
  keys <- raw$result$sample_keys
  stopifnot(identical(keys, nb$result$sample_keys))
  key_sha <- digest::digest(keys, algo = "sha256")
  raw_spec <- raw$signature$model_spec
  nb_spec <- nb$signature$model_spec
  make_sample <- function(model_spec) {
    f <- model_formulas(model_spec, spec, "M3")
    s <- build_fit_sample(data, model_spec, f, spec)
    stopifnot(identical(keys, s$keys))
    list(formulas = f, sample = s)
  }
  raw_sample <- make_sample(raw_spec)
  nb_sample <- make_sample(nb_spec)
  stopifnot(identical(rownames(raw_sample$sample$data), rownames(nb_sample$sample$data)))
  fits <- list()
  records <- list()
  format_spec <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")
  accept <- function(z) !is.null(z$model) && !isFALSE(z$converged) && !isTRUE(z$singular)
  register <- function(name, z, signature, parent, file, cached, sample) {
    fits[[name]] <<- list(fit = z, sample = sample, spec = signature)
    records[[name]] <<- data.table(
      specification = name, parent = parent, model_id = "M3", decisions = "e04;e05;e06;e07;e08;e09;e10;e10-3;e11;e12;e13",
      data_spec = format_spec(spec), model_spec = format_spec(signature$model_spec),
      residual_variance = signature$variance, residual_correlation = signature$model_spec$temporal_correlation,
      engine = z$engine, software = format_spec(signature$versions), formula = format_spec(z$formula),
      computational_formula = if (is.null(z$computational_formula)) "" else format_spec(z$computational_formula),
      input_sha256 = input_sha, prepared_sha256 = data_sha, pipeline_sha256 = pipeline_sha,
      sample_sha256 = key_sha, model_file = file, cache_hit = cached,
      n_sample = nrow(keys), n_districts = uniqueN(keys$geo_code),
      status = if (is.null(z$model)) "error" else if (isFALSE(z$converged)) "nonconverged" else
        if (isTRUE(z$singular)) "singular" else "fitted",
      converged = z$converged, singular = z$singular, runtime_seconds = z$runtime_seconds,
      warnings = paste(z$warnings, collapse = " | "), messages = paste(z$messages, collapse = " | "),
      convergence = format_spec(z$convergence), error = if (is.null(z$error)) "" else z$error
    )
    invisible(z)
  }
  reuse <- function(name, entry, original_name, sample) {
    file <- original[specification == original_name & model_id == "M3", model_file]
    register(name, entry$result$fits$M3, c(entry$signature, list(variance = "constant")),
             NA_character_, file, TRUE, sample$sample)
  }
  reuse("raw_kreis", raw, "raw_lmm", raw_sample)
  reuse("nb_glm", nb, "negbin", nb_sample)

  m3_cells <- function(frame) {
    interaction(frame$kreistyp, frame$age_group, frame$period, sep = " / ", drop = TRUE)
  }

  # Profile exact Gaussian likelihood by district pattern to initialize the dense nlme fit.
  gaussian_start <- function(frame, model_spec, variance, parent_model, rho_start) {
    phase <- as.integer(frame$period)
    age <- as.integer(frame$age_group)
    cell <- as.integer(m3_cells(frame))
    n_cells <- max(cell)
    districts <- lapply(split(seq_len(nrow(frame)), frame$geo_code), function(i) {
      i[order(age[i], phase[i])]
    })
    patterns <- split(districts, vapply(districts, function(i) paste(cell[i], collapse = ":"), ""))
    groups <- lapply(patterns, function(pattern) {
      i <- pattern[[1L]]
      y <- matrix(unlist(lapply(pattern, function(j) frame$incidence[j]), use.names = FALSE),
                  nrow = length(i))
      list(n = ncol(y), cells = cell[i], phase = phase[i], age = outer(age[i], age[i], "=="),
           lag = abs(outer(frame$.model_time[i], frame$.model_time[i], "-")),
           yy = tcrossprod(y), y = rowSums(y))
    })
    n_phase <- if (variance == "phase") nlevels(frame$period) else 1L
    n_random <- if (model_spec$random_effects == "kreis_age") 2L else 1L
    n_sd <- n_phase + n_random
    unpack <- function(par) {
      list(residual = rep(exp(par[seq_len(n_phase)]), length.out = nlevels(frame$period)),
           random = exp(par[n_phase + seq_len(n_random)]),
           rho = if (is.null(rho_start)) 0 else plogis(par[n_sd + 1L]))
    }
    objective <- function(par) {
      v <- unpack(par)
      precision <- matrix(0, n_cells, n_cells)
      score <- numeric(n_cells)
      criterion <- 0
      for (g in groups) {
        sd <- v$residual[g$phase]
        vmat <- v$random[1L]^2 + tcrossprod(sd) * v$rho^g$lag * g$age
        if (n_random == 2L) vmat <- vmat + v$random[2L]^2 * g$age
        u <- chol(vmat)
        inverse <- chol2inv(u)
        j <- g$cells
        precision[j, j] <- precision[j, j] + g$n * inverse
        score[j] <- score[j] + drop(inverse %*% g$y)
        criterion <- criterion + 2 * g$n * sum(log(diag(u))) + sum(inverse * g$yy)
      }
      0.5 * (nrow(frame) * log(2 * pi) + criterion -
        sum(forwardsolve(t(chol(precision)), score)^2))
    }
    fitted_phase <- if (inherits(parent_model, "lme") && !is.null(parent_model$modelStruct$varStruct)) {
      ratio <- coef(parent_model$modelStruct$varStruct, unconstrained = FALSE, allCoef = TRUE)
      unname(sigma(parent_model) * ratio[levels(frame$period)])
    } else {
      model_phase <- model.frame(parent_model)$period
      as.numeric(sqrt(tapply(residuals(parent_model)^2, model_phase, mean)))
    }
    ri <- if (inherits(parent_model, "lme")) {
      as.numeric(nlme::VarCorr(parent_model)[1L, "StdDev"])
    } else as.numeric(attr(lme4::VarCorr(parent_model)$geo_code, "stddev"))
    start <- log(c(if (n_phase > 1L) fitted_phase else sigma(parent_model),
                   ri, if (n_random == 2L) 5))
    optimize <- function(rho) {
      optim(c(start, if (!is.na(rho)) qlogis(rho)), objective, method = "L-BFGS-B",
        lower = c(rep(log(0.05), n_sd), if (!is.na(rho)) qlogis(0.001)),
        upper = c(rep(log(2000), n_sd), if (!is.na(rho)) qlogis(0.9999)),
        control = list(maxit = 120L, factr = 1e4))
    }
    attempts <- lapply(if (is.null(rho_start)) NA_real_ else rho_start, optimize)
    opt <- attempts[[which.min(vapply(attempts, `[[`, 0, "value"))]]
    if (opt$convergence != 0L) stop("Profiled Gaussian optimizer: ", opt$message)
    c(unpack(opt$par), list(profile_loglik = -opt$value, profile_convergence = opt$convergence))
  }

  # Keep likelihoods comparable by using ML for Gaussian fits and Laplace for NB mixed fits.
  execute <- function(name, model_spec, parent, variance, backend) {
    s <- make_sample(model_spec)
    f <- s$formulas
    sample <- s$sample
    frame <- sample$data
    engine_versions <- c(base_versions, engine = as.character(packageVersion(
      switch(backend, nlme = "nlme", glmmTMB = "glmmTMB", lme4 = "lme4")
    )))
    signature <- list(data_sha = data_sha, input_sha = input_sha, pipeline_sha = pipeline_sha,
                      key_sha = key_sha, data_spec = spec, model_spec = model_spec,
                      fixed = format_spec(f$fixed$M3), full = format_spec(f$full$M3),
                      variance = variance, backend = backend, versions = engine_versions, revision = 1L)
    if (backend == "nlme") signature$numerics <- "block-profiled ML; nlme reconstruction with profiled ratios and correlation"
    if (backend == "glmmTMB") {
      signature$numerics <- "sparse saturated M3 cell basis, NB GLM fixed start, nlminb"
    }
    if (model_spec$temporal_correlation == "car1") {
      # Phase gaps make the package's weekly starting correlation nearly zero at the observed lags.
      signature$car_start <- c(0.2, 0.95)
    }
    cache <- file.path(out, "models", paste0(name, "_", digest::digest(signature, algo = "sha256"), ".rds"))
    hit <- file.exists(cache)
    if (hit) {
      entry <- readRDS(cache)
      stopifnot(identical(entry$signature, signature))
      z <- entry$fit
    } else if (backend == "lme4" && model_spec$family == "lmm") {
      z <- fit_models(data, model_spec, "M3")$fits$M3
    } else {
      if (variance != "constant" && (backend != "nlme" || model_spec$family != "lmm")) {
        stop("Phase-specific residual variance requires the Gaussian nlme engine.")
      }
      alerts <- notes <- character()
      start <- proc.time()[["elapsed"]]
      model <- tryCatch(withCallingHandlers({
        if (backend == "nlme") {
          fixed <- f$fixed$M3
          environment(fixed) <- globalenv()
          args <- correlated_fit_args(fixed, frame, model_spec, sample)
          if (model_spec$temporal_correlation == "none") args$correlation <- NULL
          init <- gaussian_start(frame, model_spec, variance, fits[[parent]]$fit$model,
                                 signature$car_start)
          if (!is.null(signature$car_start)) {
            cor_formula <- formula(args$correlation)
            environment(cor_formula) <- globalenv()
            args$correlation <- nlme::corCAR1(init$rho, form = cor_formula, fixed = TRUE)
          }
          sd_ref <- init$residual[1L]
          if (variance == "phase") {
            ratios <- setNames(init$residual[-1L] / sd_ref, levels(frame$period)[-1L])
            args$weights <- nlme::varIdent(form = as.formula("~ 1 | period", env = globalenv()),
                                           fixed = ratios)
          }
          random_names <- c("geo_code", if (model_spec$random_effects == "kreis_age") ".model_series")
          args$random <- setNames(lapply(init$random, function(sd) {
            nlme::pdLogChol(matrix((sd / sd_ref)^2, 1L, 1L),
                            form = as.formula("~ 1", env = globalenv()))
          }), random_names)
          args$control <- nlme::lmeControl(msMaxIter = 150L, returnObject = FALSE,
                                           niterEM = 0L, apVar = FALSE)
          model <- do.call(nlme::lme, args)
          if (abs(as.numeric(logLik(model)) - init$profile_loglik) > 0.05) {
            stop("The reconstructed nlme likelihood disagrees with the profiled likelihood.")
          }
          model
        } else if (backend == "glmmTMB") {
          # Cell indicators span exactly the saturated M3 design with better conditioning.
          frame$.model_cell <- m3_cells(frame)
          design <- model.matrix(f$fixed$M3, frame)
          distinct <- which(!duplicated(frame$.model_cell))
          stopifnot(length(distinct) == ncol(design),
                    all(design == design[distinct[match(frame$.model_cell,
                      frame$.model_cell[distinct])], , drop = FALSE]))
          cell_start <- predict(nb$result$fits$M3$model, type = "link") - frame$log_exposure
          cell_start <- cell_start[match(levels(frame$.model_cell), frame$.model_cell)]
          cell_formula <- as.formula(paste("cases ~ 0 + .model_cell + offset(log_exposure)",
                                           "+ (1 | geo_code) + (1 | .model_kreis_age)"),
                                     env = globalenv())
          glmmTMB::glmmTMB(cell_formula, data = frame, family = glmmTMB::nbinom2(), REML = FALSE, na.action = na.fail,
                           sparseX = c(cond = TRUE),
                           start = list(beta = unname(cell_start), theta = log(c(0.2, 0.03)),
                                        betadisp = log(nb$result$fits$M3$model$theta)),
                           control = glmmTMB::glmmTMBControl(optCtrl = list(iter.max = 900L,
                                                                          eval.max = 1300L)))
        } else {
          lme4::glmer.nb(f$full$M3, data = frame, nAGQ = 1L, na.action = na.fail,
                         control = lme4::glmerControl(calc.derivs = FALSE))
        }
      }, warning = function(w) {
        alerts <<- c(alerts, conditionMessage(w))
        invokeRestart("muffleWarning")
      }, message = function(m) {
        notes <<- c(notes, conditionMessage(m))
        invokeRestart("muffleMessage")
      }), error = identity)
      elapsed <- proc.time()[["elapsed"]] - start
      z <- list(model = NULL, formula = f$full$M3, engine = backend, runtime_seconds = elapsed,
                warnings = alerts, messages = notes, converged = NA, singular = NA, convergence = NULL,
                error = NULL)
      if (inherits(model, "error")) {
        z$error <- conditionMessage(model)
      } else {
        z$model <- model
        if (inherits(model, "glmmTMB")) z$computational_formula <- formula(model)
        z$converged <- !any(grepl("converg|iteration limit|Hessian", alerts, ignore.case = TRUE))
        if (inherits(model, "glmmTMB")) {
          z$convergence <- list(optimizer = model$fit$convergence, message = model$fit$message,
                                positive_hessian = model$sdr$pdHess)
          z$converged <- z$converged && isTRUE(model$fit$convergence == 0) && isTRUE(model$sdr$pdHess)
          z$singular <- any(vapply(glmmTMB::VarCorr(model)$cond, function(m) {
            any(attr(m, "stddev") < 1e-4)
          }, logical(1)))
        } else if (inherits(model, "merMod")) {
          z$convergence <- model@optinfo$conv
          z$converged <- z$converged && all(model@optinfo$conv$opt == 0)
          z$singular <- lme4::isSingular(model)
        } else {
          profile_k <- (if (variance == "phase") nlevels(frame$period) - 1L else 0L) +
            as.integer(!is.null(signature$car_start))
          z$likelihood_df <- attr(logLik(model), "df") + profile_k
          z$convergence <- list(iterations = model$numIter, profile_status = init$profile_convergence,
                                loglik_discrepancy = as.numeric(logLik(model)) - init$profile_loglik)
          sd <- suppressWarnings(as.numeric(nlme::VarCorr(model)[, "StdDev"]))
          z$singular <- any(head(sd[is.finite(sd)], -1L) < 1e-4)
        }
      }
    }
    if (!is.null(z$model)) {
      rows <- if (inherits(z$model, "lme")) rownames(z$model$residuals) else rownames(model.frame(z$model))
      stopifnot(nobs(z$model) == nrow(frame), identical(rows, rownames(frame)))
    }
    if (!hit && !is.null(z$model)) {
      stage <- tempfile(tmpdir = dirname(cache))
      saveRDS(list(signature = signature, sample_keys = keys, fit = z), stage)
      if (!file.rename(stage, cache)) stop("Could not publish ", cache)
    }
    register(name, z, signature, parent, if (file.exists(cache)) cache else NA_character_, hit, sample)
    message(name, if (hit) " cached" else if (is.null(z$model)) paste(" failed:", z$error) else " fitted")
    z
  }

  likelihood_df <- function(z) {
    if (is.null(z$likelihood_df)) attr(logLik(z$model), "df") else z$likelihood_df
  }
  information <- function(z, penalty) -2 * as.numeric(logLik(z$model)) + penalty * likelihood_df(z)

  # Advance one covariance decision at a time, using BIC only to choose the next comparison.
  next_parent <- function(candidate, parent) {
    a <- fits[[candidate]]$fit
    b <- fits[[parent]]$fit
    if (accept(a) && information(a, log(nrow(keys))) < information(b, log(nrow(keys)))) candidate else parent
  }
  nested <- modifyList(raw_spec, list(random_effects = "kreis_age"))
  execute("raw_kreis_age", nested, "raw_kreis", "constant", "lme4")
  random_parent <- next_parent("raw_kreis_age", "raw_kreis")
  variance_spec <- fits[[random_parent]]$spec$model_spec
  execute("raw_phase_variance", variance_spec, random_parent, "phase", "nlme")
  variance_parent <- next_parent("raw_phase_variance", random_parent)
  car_spec <- modifyList(fits[[variance_parent]]$spec$model_spec, list(temporal_correlation = "car1"))
  execute("raw_car1", car_spec, variance_parent, fits[[variance_parent]]$spec$variance, "nlme")
  nb_mixed <- modifyList(nb_spec, list(family = "negative_binomial_glmm", random_effects = "kreis_age"))
  backend <- if (requireNamespace("glmmTMB", quietly = TRUE)) "glmmTMB" else "lme4"
  execute("nb_glmm", nb_mixed, "nb_glm", "constant", backend)

  fit_metrics <- function(entry, name) {
    z <- entry$fit
    m <- z$model
    if (is.null(m)) return(data.table(specification = name))
    rp <- residuals(m, type = "pearson")
    sd_by_phase <- data.table(phase = entry$sample$data$period, residual = rp)[
      , .(rms = sqrt(mean(residual^2))), by = phase]
    data.table(specification = name, log_likelihood = as.numeric(logLik(m)),
      likelihood_df = likelihood_df(z), aic = information(z, 2),
      bic = information(z, log(nrow(keys))),
      pearson_rms = sqrt(mean(rp^2)), max_to_min_phase_rms = max(sd_by_phase$rms) / min(sd_by_phase$rms),
      pearson_sum_per_df = if (entry$spec$model_spec$response == "count")
        sum(rp^2) / (nobs(m) - length(fixef_for(m))) else NA_real_,
      rho_per_week = if (inherits(m, "lme") && !is.null(m$modelStruct$corStruct))
        unname(coef(m$modelStruct$corStruct, unconstrained = FALSE)) else NA_real_,
      theta = if (inherits(m, "negbin")) m$theta else if (inherits(m, "glmmTMB")) sigma(m) else
        if (entry$spec$model_spec$family == "negative_binomial_glmm")
          unname(lme4::getME(m, "glmer.nb.theta")) else NA_real_)
  }
  fixef_for <- function(m) {
    if (inherits(m, "glmmTMB")) return(glmmTMB::fixef(m)$cond)
    if (inherits(m, "merMod")) return(lme4::fixef(m))
    if (inherits(m, "lme")) return(nlme::fixef(m))
    coef(m)
  }
  components_for <- function(m) {
    if (inherits(m, "lme")) {
      v <- nlme::VarCorr(m)
      sd <- suppressWarnings(as.numeric(v[, "StdDev"]))
      return(data.table(component = c(if (length(na.omit(sd)) == 3L) c("kreis", "kreis_age") else
        "kreis", "residual_reference"), sd = sd[is.finite(sd)]))
    }
    if (inherits(m, "glmmTMB")) {
      groups <- glmmTMB::VarCorr(m)$cond
      return(data.table(component = names(groups),
                        sd = vapply(groups, function(x) unname(attr(x, "stddev")[[1L]]), 0)))
    }
    if (inherits(m, "merMod")) {
      v <- as.data.frame(lme4::VarCorr(m))
      return(data.table(component = v$grp, sd = v$sdcor))
    }
    data.table(component = character(), sd = numeric())
  }
  metrics <- rbindlist(lapply(names(fits), function(name) fit_metrics(fits[[name]], name)), fill = TRUE)
  registry <- merge(rbindlist(records), metrics, by = "specification", all.x = TRUE, sort = FALSE)
  registry[, likelihood := fifelse(grepl("^raw_", specification), "Gaussian ML",
                                   fifelse(specification == "nb_glm", "NB2 ML", "NB2 marginal Laplace ML"))]
  fwrite(registry, file.path(out, "model_registry.csv"), na = "")
  comparison <- registry[!is.na(parent), .(specification, parent, status, aic, bic,
    delta_aic = aic - registry$aic[match(parent, registry$specification)],
    delta_bic = bic - registry$bic[match(parent, registry$specification)],
    converged, singular, rho_per_week, theta, engine)]
  write_table(comparison, "sequential_fit_comparison")
  write_table(as.data.table(keys), "sample_keys")
  fitted_models <- Filter(function(e) !is.null(e$fit$model), fits)
  components <- rbindlist(lapply(names(fitted_models), function(name) {
    m <- fitted_models[[name]]$fit$model
    v <- components_for(m)
    v[, `:=`(specification = rep(name, .N), variance = sd^2)]
    v
  }), fill = TRUE)
  components[component %in% c(".model_kreis_age", "geo_code", "Residual"), component :=
    c(".model_kreis_age" = "kreis_age", geo_code = "kreis", Residual = "residual_reference")[component]]
  write_table(components, "variance_components")

  phase_sd <- rbindlist(lapply(names(fitted_models), function(name) {
    e <- fitted_models[[name]]
    m <- e$fit$model
    if (e$spec$model_spec$response == "count") return(NULL)
    p <- unique(as.character(e$sample$data$period))
    sd <- setNames(rep(sigma(m), length(p)), p)
    if (inherits(m, "lme") && !is.null(m$modelStruct$varStruct)) {
      ratio <- coef(m$modelStruct$varStruct, unconstrained = FALSE, allCoef = TRUE)
      sd[names(ratio)] <- sigma(m) * ratio
    }
    data.table(specification = name, period = names(sd), residual_sd = unname(sd))
  }))
  write_table(phase_sd, "gaussian_phase_residual_sd")

  diagnostics <- list()
  acf <- list()
  for (name in names(fitted_models)) {
    e <- fitted_models[[name]]
    m <- e$fit$model
    frame <- e$sample$data
    if (inherits(m, "lme") && !is.null(m$modelStruct$corStruct)) {
      rp <- residuals(m, type = "pearson")
      rn <- residuals(m, type = "normalized")
    } else {
      rp <- residuals(m, type = "pearson")
      rn <- if (e$spec$model_spec$response == "incidence" && inherits(m, "merMod")) rp / sigma(m) else rp
    }
    if (inherits(m, "lme")) rn <- residuals(m, type = "normalized")
    diagnostics[[name]] <- data.table(specification = name, geo_code = as.character(frame$geo_code),
      phase = as.character(frame$period), fitted = as.numeric(fitted(m)), pearson = as.numeric(rp),
      diagnostic_residual = as.numeric(rn))
    acf[[name]] <- rbindlist(list(
      residual_acf(rp, frame, e$sample$temporal$lags)[, residual := "pearson"],
      if (e$spec$model_spec$temporal_correlation != "none")
        residual_acf(rn, frame, e$sample$temporal$lags)[, residual := "normalized"]
    ))[, specification := name]
  }
  diag_data <- rbindlist(diagnostics)
  acf <- rbindlist(acf)
  write_table(acf, "temporal_residual_dependence")
  phases <- setdiff(study_config$periods, "P0")
  diag_summary <- diag_data[, .(n = .N, mean_pearson = mean(pearson),
    rms_pearson = sqrt(mean(pearson^2)), rms_diagnostic = sqrt(mean(diagnostic_residual^2)),
    abs_gt_3 = mean(abs(diagnostic_residual) > 3)), by = .(specification, phase)]
  write_table(diag_summary, "residual_by_phase")
  plot_data <- copy(diag_data)
  plot_data[, phase := factor(phase, levels = phases)]
  write_plot(ggplot(plot_data, aes(phase, diagnostic_residual)) +
    geom_boxplot(outlier.alpha = 0.1, outlier.size = 0.4) +
    facet_wrap(~specification, scales = "free_y") + theme_bw() +
    labs(x = "Phase", y = "Standardisierte bzw. normalisierte Residuen"), "residuals_by_phase")
  write_plot(ggplot(acf, aes(lag_weeks, correlation, colour = residual)) +
    geom_hline(yintercept = 0, colour = "grey70") + geom_point(aes(size = n_pairs)) +
    facet_wrap(~specification) + theme_bw() +
    labs(x = "Abstand der Phasenmitten in Wochen", y = "Gepoolte Residuenkorrelation", size = "Paare"),
    "temporal_dependence")

  # Compare observed-cell means on the same weekly rate scale within each response family.
  sample <- raw_sample$sample$data
  ref_region <- reference_levels$kreistyp
  ref_age <- reference_levels$age_group[["7"]]
  ref_phase <- reference_levels$period
  grid <- CJ(kreistyp = levels(sample$kreistyp), age_group = levels(sample$age_group), period = phases)
  for (column in c("kreistyp", "age_group", "period")) {
    grid[[column]] <- factor(grid[[column]], levels = levels(sample[[column]]))
  }
  grid$log_exposure <- log(study_config$incidence_scale)
  grid$.model_kreis_age <- NA_character_
  grid$geo_code <- NA_character_
  pairs <- grid[kreistyp != ref_region & age_group %in% c("6–17", "60–69", "80+") &
                  period %in% c("W4", "W5", "PostW5"), .(kreistyp, age_group, period)]
  contrasts <- rbindlist(lapply(names(fitted_models), function(name) {
    entry <- fitted_models[[name]]
    m <- entry$fit$model
    count <- entry$spec$model_spec$response == "count"
    formula <- if (count) nb_sample$formulas$fixed$M3 else raw_sample$formulas$fixed$M3
    design <- model.matrix(delete.response(terms(formula)), grid,
      contrasts.arg = lapply(sample[c("kreistyp", "age_group", "period")], contrasts))
    beta <- fixef_for(m)
    if (inherits(m, "glmmTMB")) {
      columns <- paste0(".model_cell", as.character(m3_cells(grid)))
      stopifnot(setequal(columns, names(beta)))
      eta <- unname(beta[columns])
    } else {
      stopifnot(setequal(colnames(design), names(beta)))
      eta <- drop(design[, names(beta), drop = FALSE] %*% beta)
    }
    components <- components_for(m)
    intercept_variance <- sum(components$sd^2)
    scales <- if (count && length(components$sd)) c(conditional = 0, marginal = 0.5 * intercept_variance) else
      c(marginal = 0)
    rbindlist(lapply(names(scales), function(scale) {
      prediction <- if (count) study_config$incidence_scale * exp(eta + scales[[scale]]) else eta
      value <- function(k, a, p) prediction[grid$kreistyp == k & grid$age_group == a & grid$period == p]
      rbindlist(lapply(seq_len(nrow(pairs)), function(i) {
        a <- pairs$age_group[i]
        p <- pairs$period[i]
        k <- pairs$kreistyp[i]
        gap <- function(age, phase) value(k, age, phase) - value(ref_region, age, phase)
        cbind(pairs[i], data.table(specification = name, prediction = scale,
          rural_or_urban_rate = value(k, a, p), metropolitan_rate = value(ref_region, a, p),
          regional_gap = gap(a, p), three_way = gap(a, p) - gap(ref_age, p) - gap(a, ref_phase) + gap(ref_age, ref_phase)))
      }))
    }))
  }))
  contrast_cols <- c("kreistyp", "age_group", "period")
  references <- contrasts[specification %in% c("raw_kreis", "nb_glm"),
                          .(kreistyp, age_group, period, family = sub("_.*", "", specification),
                            reference_gap = regional_gap, reference_three_way = three_way)]
  contrasts[, family := sub("_.*", "", specification)]
  contrasts <- merge(contrasts, references, by = c(contrast_cols, "family"), all.x = TRUE)
  contrasts[, `:=`(change_gap = regional_gap - reference_gap, change_three_way = three_way - reference_three_way)]
  write_table(contrasts, "m3_key_contrast_changes")
  chart <- contrasts[kreistyp == "Dünn besiedelte ländliche Kreise" & prediction == "marginal"]
  chart[, `:=`(period = factor(period, levels = phases), age_label = sub("–", "-", age_group, fixed = TRUE))]
  write_plot(ggplot(chart, aes(period, three_way, colour = specification, group = specification)) +
    geom_hline(yintercept = 0, colour = "grey65") + geom_line() + geom_point() +
    facet_grid(family ~ age_label) + theme_bw() + theme(legend.position = "bottom") +
    labs(x = "Phase", y = "Dreifachkontrast je 100.000 und Woche", colour = "Spezifikation"),
    "m3_contrast_comparison")

  # Derive a symmetric district graph from the repository's simplified polygons.
  spatial <- NULL
  geography <- "data_geo/landkreise_simplify200.geojson"
  if (file.exists(geography)) {
    if (!requireNamespace("sf", quietly = TRUE)) stop("The spatial check requires sf.")
    shapes <- sf::st_read(geography, quiet = TRUE)
    districts <- sort(unique(keys$geo_code))
    stopifnot(all(districts %in% shapes$AGS))
    shapes <- sf::st_make_valid(sf::st_transform(shapes[shapes$AGS %in% districts, ], 3035))
    parts <- split(seq_len(nrow(shapes)), shapes$AGS)[districts]
    shape <- sf::st_sfc(lapply(parts, function(i) {
      sf::st_union(sf::st_geometry(shapes)[i])[[1L]]
    }), crs = 3035)
    stopifnot(!any(sf::st_is_empty(shape)))
    neighbors <- sf::st_intersects(shape)
    edges <- rbindlist(lapply(seq_along(neighbors), function(i) {
      j <- neighbors[[i]][neighbors[[i]] > i]
      data.table(i = rep(i, length(j)), j = j)
    }))
    degrees <- tabulate(c(edges$i, edges$j), nbins = length(districts))
    keep <- which(degrees > 0L)
    stopifnot(nrow(edges) > 0L, length(keep) > 2L)
    edges_out <- edges[, .(district_a = districts[i], district_b = districts[j])]
    write_table(edges_out, "spatial_adjacency")
    write_table(data.table(geo_code = districts, n_neighbors = degrees), "spatial_coverage")
    set.seed(20261125)
    draws <- replicate(499L, sample.int(length(keep)))
    graph_i <- match(edges$i, keep)
    graph_j <- match(edges$j, keep)
    moran <- function(v) {
      centered <- v - mean(v)
      length(v) / nrow(edges) * sum(centered[graph_i] * centered[graph_j]) / sum(centered^2)
    }
    district_residual <- diag_data[, .(residual = mean(diagnostic_residual)),
                                  by = .(specification, phase, geo_code)]
    spatial <- district_residual[, {
      values <- residual[match(districts[keep], geo_code)]
      stopifnot(all(is.finite(values)))
      obs <- moran(values)
      expected <- -1 / (length(keep) - 1)
      simulated <- apply(draws, 2L, function(i) moran(values[i]))
      list(moran_i = obs, expected_i = expected, n_districts = length(keep),
           n_links = nrow(edges), n_isolates = sum(degrees == 0L),
           permutations = ncol(draws),
           p_permutation = (1 + sum(abs(simulated - expected) >= abs(obs - expected))) / (1 + ncol(draws)))
    }, by = .(specification, phase)]
    spatial[, p_holm := p.adjust(p_permutation, "holm"), by = specification]
    write_table(spatial, "spatial_residual_dependence")
    spatial_plot <- copy(spatial)
    spatial_plot[, phase := factor(phase, levels = phases)]
    write_plot(ggplot(spatial_plot, aes(phase, moran_i, colour = specification, group = specification)) +
      geom_hline(yintercept = 0, colour = "grey65") + geom_line() + geom_point() +
      theme_bw() + theme(legend.position = "bottom") +
      labs(x = "Phase", y = "Moran-I der mittleren Kreisresiduen", colour = "Spezifikation"),
      "spatial_dependence")
  }

  # Summarize sequential comparisons and contrast changes in German.
  num <- function(x, digits = 2L) ifelse(is.na(x), "–",
    formatC(x, digits = digits, format = "f", decimal.mark = ","))
  compare_row <- function(i) {
    r <- comparison[i]
    sprintf("| %s | %s | %s | %s | %s |", r$specification, r$parent,
            num(r$delta_aic, 1), num(r$delta_bic, 1), r$status)
  }
  example <- contrasts[kreistyp == "Dünn besiedelte ländliche Kreise" & age_group == "80+" &
                         period == "W5" & prediction == "marginal"]
  contrast_row <- function(i) {
    r <- example[i]
    sprintf("| %s | %s | %s | %s |", r$specification, num(r$regional_gap, 1),
            num(r$three_way, 1), num(r$change_three_way, 1))
  }
  nb_cmp <- comparison[specification == "nb_glmm"]
  car <- registry[specification == "raw_car1"]
  v <- phase_sd[specification == "raw_phase_variance"]
  raw_ri <- components[specification == "raw_kreis_age"]
  nb_ri <- components[specification == "nb_glmm"]
  max_acf <- function(name, kind) {
    values <- acf[specification == name & residual == kind, correlation]
    if (length(values)) max(abs(values)) else NA_real_
  }
  spatial_text <- if (is.null(spatial)) "Es lagen keine auswertbaren Geodaten vor." else
    sprintf("Die vereinfachten Kreispolygone decken alle 400 Kreise ab. Der Intersektionsgraph hat %s ungerichtete Nachbarschaften und %s isolierte Kreise. Moran-I wurde je Phase für über Altersgruppen gemittelte Kreisresiduen berechnet. Die Werte liegen zwischen %s und %s. Bei %s von %s Modell-Phasen-Kombinationen liegt der innerhalb des Modells Holm-adjustierte Permutations-p-Wert unter 0,05.",
      spatial$n_links[1L], spatial$n_isolates[1L], num(min(spatial$moran_i)), num(max(spatial$moran_i)),
      sum(spatial$p_holm < 0.05), nrow(spatial))
  structure_sd <- function(dt) {
    if (nrow(dt)) paste(paste(dt$component, num(dt$sd), sep = " = "), collapse = ", ") else "kein auswertbarer Fit"
  }
  writeLines(c(
    "# Varianz- und Abhängigkeitsstruktur",
    "",
    "## Stichprobe und Vergleichsfolge",
    "",
    sprintf("Alle Fits verwenden die unveränderten M3-Fixed-Effects (Kreistyp × Altersgruppe × Phase) und dieselben %s Beobachtungen aus %s Kreisen wie die erste Modellierungsrunde. Die gespeicherten M3-Referenzen für das Originalskalen-LMM und das negative Binomial-GLM wurden nach Prüfung der Stichprobe und Prüfsummen wiederverwendet.",
            nrow(keys), uniqueN(keys$geo_code)),
    "",
    "Im Gauß-Zweig wurde zuerst der Kreis-Altersgruppen-Intercept geprüft. Darauf folgte eine phasenspezifische Residualvarianz, motiviert durch die ausgeprägte Heteroskedastizität im ersten Bericht und das wechselnde Inzidenzniveau zwischen Phasen. Für den nächsten Schritt wurde jeweils der konvergierte, nicht singuläre Kandidat mit niedrigerem BIC fortgeführt. Dies legt keine endgültige Baseline fest. CAR(1) wurde anschließend bei derselben Varianz- und Zufallseffektstruktur geprüft. Im Zählzweig wurde ein NB2-GLMM mit Kreis- und Kreis-Altersgruppen-Intercepts gegen das NB2-GLM verglichen.",
    "",
    "| Kandidat | Vergleichsfit | ΔAIC | ΔBIC | Fit-Status |",
    "|---|---|---:|---:|---|", vapply(seq_len(nrow(comparison)), compare_row, ""),
    "",
    "Negative Differenzen begünstigen den Kandidaten. Die Gauß-Vergleiche verwenden ML. Die Profiloptimierung schätzt die Varianzverhältnisse und gegebenenfalls ρ; nlme rekonstruiert den Fit. AIC und BIC zählen auch diese profilierten Parameter. Die NB2-Vergleiche verwenden dieselben Zählwerte und denselben Personenwochen-Offset sowie eine Laplace-Approximation der marginalen GLMM-Likelihood. Im GLMM werden dieselben gesättigten M3-Effekte numerisch als Zellmittel parametrisiert. Werte aus den beiden Antwortfamilien werden getrennt beurteilt. Die Vergleiche sind deskriptiv. Randparameter bei Zufallsvarianzen und bei CAR(1) machen reguläre χ²-Referenzen für Likelihood-Ratio-Tests ungeeignet.",
    "",
    "Die phasenspezifische Residualvarianz verbessert beide Informationskriterien deutlich. Der zusätzliche Kreis-Altersgruppen-Intercept im Gauß-Modell liegt am Rand und verbessert die Likelihood praktisch nicht. Das NB2-GLMM verbessert den Fit deutlich gegenüber dem GLM, ist aber wegen der sehr kleinen Kreis-Altersgruppen-Varianz singulär. Der Gewinn stützt die gemeinsame Erweiterung gegenüber dem GLM und liefert keine getrennte Evidenz für den Kreis-Altersgruppen-Intercept.",
    "",
    "## Varianz, Konvergenz und Zeit",
    "",
    paste0("Geschätzte Standardabweichungen für das konstante Gauß-Modell mit zwei Intercepts: ",
           structure_sd(raw_ri), ". Beim NB2-GLMM auf Logratenskala: ", structure_sd(nb_ri), "."),
    if (nrow(v)) sprintf("Im heteroskedastischen Gauß-Fit reichen die geschätzten Residual-SD je Phase von %s (%s) bis %s (%s).",
      num(min(v$residual_sd)), v$period[which.min(v$residual_sd)],
      num(max(v$residual_sd)), v$period[which.max(v$residual_sd)]) else
      "Für das heteroskedastische Modell liegt keine auswertbare Residualvarianz vor.",
    "",
    sprintf("Für CAR(1) wurde die Mitte der vorgesehenen ISO-Wochen jeder Phase verwendet. Abstände und Lücken gehen in Kalenderwochen ein. Die Korrelation wirkt innerhalb desselben Kreises und derselben Altersgruppe. Die numerische Profiloptimierung verwendete Starts bei 0,20 und 0,95 je Woche. Geschätztes ρ je Woche: %s. Die maximale absolute gepoolte Korrelation über die betrachteten Abstände beträgt beim Vergleichsfit %s und nach CAR(1) %s für Pearson- bzw. %s für normalisierte Residuen.",
            num(car$rho_per_week, 3), num(max_acf(car$parent, "pearson")),
            num(max_acf("raw_car1", "pearson")), num(max_acf("raw_car1", "normalized"))),
    "",
    sprintf("Am kürzesten beobachteten Abstand von %s Wochen entspricht das einem Korrelationswert von %s. Der CAR(1)-Parameter ist in diesem Bereich schwach identifiziert. Die Residuenkorrelation bleibt bestehen, während sich AIC und BIC verschlechtern.",
            min(raw_spec$acf_lags), format(car$rho_per_week^min(raw_spec$acf_lags), scientific = TRUE, digits = 2)),
    "",
    sprintf("Die NB2-Dispersion θ beträgt %s im GLM und %s im GLMM. Für die Residuen sind phasenspezifische RMS, der Anteil großer standardisierter Residuen und Abstandsdiagnosen exportiert. Der GLMM-Pearson-Quotient wird anhand der Zahl der Fixed Effects skaliert und dient als deskriptive Diagnose. Konvergenzwarnungen, Hessian-Diagnosen und randnahe Zufallsvarianzen stehen im Register. Bei nlme wird eine sehr kleine Zufalls-SD als Randindikator verwendet.",
            num(registry[specification == "nb_glm", theta]), num(nb_cmp$theta)),
    "",
    "## Kreistyp-Kontraste",
    "",
    "Das Beispiel vergleicht 80+ in W5 zwischen dünn besiedelten ländlichen Kreisen und Großstädten. Der Dreifachkontrast vergleicht die Änderung dieses Abstands gegenüber W1 mit der entsprechenden Änderung bei 18–39. Die Einheit ist wöchentliche Fälle je 100.000.",
    "",
    "| Spezifikation | Kreistypabstand | Dreifachkontrast | Änderung gegenüber der Familienreferenz |",
    "|---|---:|---:|---:|", vapply(seq_len(nrow(example)), contrast_row, ""),
    "",
    "In diesem Beispiel bleibt der Dreifachkontrast in allen Spezifikationen negativ. Die Änderung der Gauß-Kovarianz verschiebt ihn kaum. Beim NB2-GLMM steigt der Kreistypabstand und der negative Dreifachkontrast verstärkt sich. Wegen der randnahen Varianz ist dieser Vergleich vorläufig.",
    "",
    "Für den NB2-Vergleich werden die GLMM-Raten über die beiden normalverteilten Intercepts gemittelt. Die bedingten Werte bei Zufallseffekten null stehen zusätzlich in der CSV. Die Änderungen der Kontraste sind Punktschätzungen. Die erste Runde verwendete kreisgeclusterte Sandwich-Inferenz. Für die neuen Modelle wurden keine modellübergreifenden robusten Intervalle konstruiert.",
    "",
    "## Räumliche Residualabhängigkeit",
    "",
    spatial_text,
    "",
    "Die räumliche Diagnose ist explorativ. Sie verwendet polygonbasierte Nachbarschaft und setzt für die Permutation Austauschbarkeit voraus. Küsteninseln, Geometrievereinfachung und ungleiche Residualpräzision können das Ergebnis beeinflussen. Die räumliche Struktur bleibt eine offene Einschränkung für kreisgeclusterte Inferenz. Ein räumliches Kovarianzmodell wurde in dieser Runde nicht geschätzt.",
    "",
    "## Grenzen",
    "",
    "Acht ungleich lange Phasen begrenzen die zeitliche Identifikation. Phasenmitten sind Kalenderanker für aggregierte Beobachtungen. Die CAR(1)-Struktur ist positiv und stationär und kann gegenläufige oder phasenspezifische Korrelationen nur begrenzt abbilden. Das NB2-GLMM enthält keine zusätzliche serielle Residualkorrelation. Die Rücktransformation eines Log-Inzidenzmodells bleibt offen. Modelle, Diagnosen, Stichprobenschlüssel und Cache-Signaturen sind im Ergebnisordner abgelegt. Die Ausführung verwendete lme4, nlme, glmmTMB und sf. Für die Wiederverwendung des GLMM-Caches muss glmmTMB im R-Bibliothekspfad verfügbar sein."
  ), report)
}
run_covariance_models()
