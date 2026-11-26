# Modelle je Welle x Altersgruppe: Negativbinomial-Regression der Faelle auf Raumtyp
# (Kreisebene, n = 400, Offset = log Bezugsbevoelkerung der Phase).
#   m0      : Kreistyp + Bundesland                                    (nur Bundesland kontrolliert)
#   m1      : Kreistyp + Bundesland + SGB-II-Quote + Anteil 65+ + Tourismus  (Hauptmodell)
#   m1_nokt : wie m1 ohne Kreistyp                                      (fuer Likelihood-Ratio-Test des Raumtyps)
#   m2      : log(Dichte) statt Kreistyp                                (Robustheit)
#   m3      : m1 + BBSR-Lage                                             (Zusatz)
#   m1_gen  : wie m1 mit GENESIS-skalierter Bevoelkerung als Offset      (Sensitivitaet Nenner)
# Referenz Kreistyp: 1 kreisfreie Grossstadt. exp(Koeffizient) = Inzidenzverhaeltnis (IRR) gegenueber Grossstaedten
# bei gleichem Bundesland und gleichen Kovariaten.
# Achtung: oekologische Analyse (Kreisebene); Zusammenhaenge gelten fuer Kreise, nicht fuer Personen.
# Ausgabe: results/modellauswahl/tables/model_nb_coef{,_fine}.csv, model_nb_fit{,_fine}.csv, model_nb_diag{,_fine}.csv
#          (Diagnose m1), data_processed/modellauswahl/model_nb{,_fine}.rds (inkl. Residuen je Kreis fuer 16_spatial.R)

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages({library(MASS); library(sandwich)})

const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
wv    <- readRDS(file.path(DIR_CLEAN, "waves.rds"))
WAVES <- wv$phases[type == "Welle", id]

cv <- model_covariates()                                     # Kovariaten: Scripts/modellauswahl/00_setup.R

SPECS <- list(
  m0      = cases ~ kt + state + offset(log(pop_rki)),
  m1      = F_M1,                                            # = cases ~ kt + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki))
  m1_nokt = cases ~ state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki)),
  m2      = cases ~ z_ldichte + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki)),
  m3      = cases ~ kt + lage + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki)),
  m1_gen  = cases ~ kt + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_gen))
)

fit_nb <- function(f, d) {
  warn <- character(0)
  fit <- withCallingHandlers(
    tryCatch(quiet_nonint(glm.nb(f, data = d, control = glm.control(maxit = 100))), error = function(e) NULL),
    warning = function(w) { warn <<- c(warn, conditionMessage(w)); invokeRestart("muffleWarning") })
  list(fit = fit, warn = paste(unique(warn), collapse = " | "))
}

tidy_fit <- function(fit, d, wave, grp, spec, warn) {
  s  <- summary(fit)$coefficients
  rn <- rownames(s)
  Vc <- tryCatch(sandwich::vcovCL(fit, cluster = d$state, type = "HC1"), error = function(e) NULL)
  se_cl <- if (is.null(Vc)) rep(NA_real_, length(rn)) else sqrt(diag(Vc))[rn]
  data.table(wave = wave, grp = grp, spec = spec, term = rn, estimate = s[, 1], se = s[, 2], se_cl = se_cl,
             p = s[, 4], theta = fit$theta, aic = AIC(fit), n = nrow(d), warn = warn)[
    grepl("^(kt|lage|z_)", term)]
}

# Diagnose je Kreis (nur Hauptmodell m1): Pearson-Residuum und Einfluss auf die Kreistyp-Koeffizienten
# (shift = groesste Verschiebung eines Kreistyp-Koeffizienten in Standardfehlern, wenn der Kreis fehlt;
# Ein-Schritt-Naeherung ueber dfbeta). Hamburg und Berlin haben mit Bundesland-Effekt Hebelwert 1:
# Residuum 0, kein Einfluss auf den Kreistyp.
diag_fit <- function(fit, d, wave, grp) {
  kt <- grep("^kt", names(coef(fit)))
  db <- dfbeta(fit)[, kt, drop = FALSE]
  data.table(wave = wave, grp = grp, ags = d$ags, fitted = fitted(fit), pearson = residuals(fit, "pearson"),
             shift = apply(abs(sweep(db, 2, sqrt(diag(vcov(fit)))[kt], "/")), 1, max),
             disp = sum(residuals(fit, "pearson")^2) / fit$df.residual)
}

run_scheme <- function(sfx) {
  kw <- readRDS(file.path(DIR_CLEAN, paste0("covid_wave_kreis", sfx, ".rds")))
  kw <- merge(kw[phase %in% WAVES], cv, by = "ags")
  kw[, state := factor(state)]
  coefs <- list(); fits <- list(); resid <- list()
  for (w in WAVES) for (g in levels(droplevels(kw$grp))) {
    d <- kw[phase == w & grp == g]
    ft <- lapply(SPECS, fit_nb, d = d)
    for (sp in names(SPECS)) {
      r <- ft[[sp]]
      if (is.null(r$fit)) { fits[[length(fits) + 1]] <- data.table(wave = w, grp = g, spec = sp, converged = FALSE, warn = "Fehler"); next }
      if (sp != "m1_nokt") coefs[[length(coefs) + 1]] <- tidy_fit(r$fit, d, w, g, sp, r$warn)
      if (sp == "m1") resid[[length(resid) + 1]] <- diag_fit(r$fit, d, w, g)
      fits[[length(fits) + 1]] <- data.table(wave = w, grp = g, spec = sp, n = nrow(d), cases = sum(d$cases),
        theta = r$fit$theta, aic = AIC(r$fit), loglik = as.numeric(logLik(r$fit)), converged = r$fit$converged,
        warn = r$warn)
    }
  }
  coefs <- rbindlist(coefs); fits <- rbindlist(fits, fill = TRUE)
  coefs[, `:=`(irr = exp(estimate), lo = exp(estimate - 1.96 * se), hi = exp(estimate + 1.96 * se),
               lo_cl = exp(estimate - 1.96 * se_cl), hi_cl = exp(estimate + 1.96 * se_cl))]
  # Likelihood-Ratio-Test fuer den gesamten Raumtyp (3 Parameter): m1 gegen m1_nokt
  lr <- merge(fits[spec == "m1", .(wave, grp, ll1 = loglik)], fits[spec == "m1_nokt", .(wave, grp, ll0 = loglik)], by = c("wave", "grp"))
  lr[, `:=`(lr_stat = 2 * (ll1 - ll0), lr_p = pchisq(2 * (ll1 - ll0), df = 3, lower.tail = FALSE))]
  fits <- merge(fits, lr[, .(wave, grp, lr_kt_stat = lr_stat, lr_kt_p = lr_p)], by = c("wave", "grp"), all.x = TRUE)
  fits[spec != "m1", c("lr_kt_stat", "lr_kt_p") := NA_real_]
  fwrite(coefs[, c("wave", "grp", "spec", "term", "estimate", "se", "se_cl", "irr", "lo", "hi", "lo_cl", "hi_cl", "p", "theta", "aic", "n", "warn")],
         file.path(DIR_TAB, paste0("model_nb_coef", sfx, ".csv")))
  fwrite(fits, file.path(DIR_TAB, paste0("model_nb_fit", sfx, ".csv")))
  # Diagnose m1 je Zelle: Pearson-Dispersion (~1 bei passender NB-Varianz), Ausreisser, einflussreichster Kreis
  resid <- merge(rbindlist(resid), const[, .(ags, name = name_rki)], by = "ags")
  dg <- resid[, .(disp = disp[1], n_abs_resid_gt3 = sum(abs(pearson) > 3), max_shift_se = max(shift),
                  einflussreichster = name[which.max(shift)]), by = .(wave, grp)]
  fwrite(dg, file.path(DIR_TAB, paste0("model_nb_diag", sfx, ".csv")))
  resid[, disp := NULL]
  saveRDS(list(coefs = coefs, fits = fits, resid = resid), file.path(DIR_CLEAN, paste0("model_nb", sfx, ".rds")))
  list(coefs = coefs, fits = fits, resid = resid, diag = dg)
}

res <- run_scheme("")
res_f <- run_scheme("_fine")

cat("\n== Konvergenz / Warnungen (grob) ==\n")
print(res$fits[, .(n_fits = .N, nicht_konvergiert = sum(!converged | is.na(converged)), mit_warnung = sum(warn != "" & !is.na(warn))), by = spec])
cat("\n== (fein) ==\n")
print(res_f$fits[, .(n_fits = .N, nicht_konvergiert = sum(!converged | is.na(converged)), mit_warnung = sum(warn != "" & !is.na(warn))), by = spec])
cat("\nhaeufigste Warnungen (grob):\n"); print(head(res$fits[warn != "" & !is.na(warn), .N, by = warn][order(-N)], 5))

cat("\n== Diagnose m1 (grob / fein) ==\n")
for (r in list(grob = res, fein = res_f)) print(r$diag[, .(zellen = .N, disp_min = round(min(disp), 2), disp_median = round(median(disp), 2),
  disp_max = round(max(disp), 2), resid_gt3_median = median(n_abs_resid_gt3), max_shift_se = round(max(max_shift_se), 2))])
cat("Kreise, die am haeufigsten am einflussreichsten sind (grob):\n")
print(res$diag[, .N, by = einflussreichster][order(-N)][1:6])

show_irr <- function(r, sp, trm) {
  x <- r$coefs[spec == sp & term == trm]
  x[, lab := sprintf("%.2f%s", irr, fifelse(lo > 1 | hi < 1, "*", ""))]
  dcast(x, grp ~ wave, value.var = "lab")
}
cat("\n== Hauptmodell m1, IRR Kreistyp 4 (duenn besiedelt) vs. Grossstadt (* = 95%-KI ohne 1), grob ==\n")
print(show_irr(res, "m1", "ktT4_duenn_besiedelt")[match(GR_COARSE, grp)])
cat("\n== IRR Kreistyp 2 (staedtisch) ==\n")
print(show_irr(res, "m1", "ktT2_staedtisch")[match(GR_COARSE, grp)])
cat("\n== LR-Test Raumtyp gesamt (p-Wert), m1, grob ==\n")
print(dcast(res$fits[spec == "m1"], grp ~ wave, value.var = "lr_kt_p")[match(GR_COARSE, grp)][,
      lapply(.SD, function(x) if (is.numeric(x)) signif(x, 2) else x)])
cat("\n== Theta (Ueberdispersion; klein = starke Ueberdispersion), m1, grob ==\n")
print(dcast(res$fits[spec == "m1"], grp ~ wave, value.var = "theta")[match(GR_COARSE, grp)][,
      lapply(.SD, function(x) if (is.numeric(x)) round(x, 1) else x)])
