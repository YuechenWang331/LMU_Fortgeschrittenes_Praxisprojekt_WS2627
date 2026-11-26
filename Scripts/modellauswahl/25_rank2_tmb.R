# Kandidat fuer das Abschlussmodell (26.11.2026, nach externer Pruefung): A1 mit ZWEI Kreis-Faktoren.
#
# Hintergrund: A1 (22_main_model_tmb.R) erklaert die gemeinsame Abweichung eines Kreises ueber alle 7 Altersgruppen
# mit EINEM Faktor u_k (reduzierter Rang 1, je Altersgruppe eine Ladung). Nach A1 korrelieren die Pearson-Residuen
# derselben Kreise aber noch zwischen benachbarten Altersgruppen (z.B. 0-5 mit 6-17), was ein Faktor nicht abbilden
# kann. Hier: gleiches Modell wie A1 (feste Effekte, Offset, theta je Altersgruppe, Randregel), nur
# rr(0 + grp | ags, d = 2) statt d = 1. A1 ist derzeit der Vorschlag fuer das Hauptmodell (in der Gruppe noch nicht entschieden); dieses Skript liefert die Vergleichsgrundlage.
#
# Startwerte: Das Rang-2-Modell hat lokale Optima (W2: zwei Loesungen, beide konvergiert mit positiv definiter
# Hessematrix, logLik-Abstand ca. 15, Wald-p 0,004 bzw. 0,039). Deshalb je Welle R2_STARTS Startwerte
# (glmmTMB-Standard + Zufallsladungen mit festen Seeds); gewaehlt wird die Loesung mit der hoechsten Loglikelihood
# unter denen mit Konvergenz und positiv definiter Hessematrix, NICHT nach p-Wert. Alle Starts stehen in rank2_starts.csv.
# Randregel wie in 22: theta > 1e4 oder nicht positiv definite Hessematrix -> theta dieser Gruppe(n) auf 1e4 fest.
#   Achtung: Mit zwei Faktoren erreichen mehr Altersgruppen diese Grenze als in A1 (der zweite Faktor uebernimmt
#   einen Teil der Ueberdispersion). Feste Grenzwerte und die nicht ganzzahligen Fallzahlen (verteilte Faelle ohne
#   Alter) machen AIC-Vergleiche zu einer Naeherung; welche Gruppen fest sind, steht in rank2_tests.csv.
# Tests wie in 22: Wald-Test "Kreistyp-Effekt in allen Altersgruppen gleich" (df 18), Holm ueber die 8 Wellen.
# Diagnose: Korrelation der Pearson-Residuen (bedingt auf die Kreis-Faktoren) zwischen den Altersgruppen
#   derselben Kreise, fuer A1 und Rang 2 (rank2_resid_cor.csv). Nur beschreibend: Bedingte Residuen sind selbst
#   bei richtigem Modell nicht unkorreliert (die geschaetzten Kreis-Faktoren nehmen bei 7 Zeilen je Kreis viel auf;
#   mit Rang 2 werden einzelne Korrelationen deutlich negativ). Ein Urteil braucht eine Referenz aus Simulationen
#   des jeweiligen Modells (externe Pruefung fuer A1, W2, 0-5 mit 6-17: 0,711 gegen 95 %-Bereich -0,11 bis 0,08).
# Laufzeit: ca. 25 Minuten (8 Wellen x (1 + R2_STARTS) Anpassungen, teils mit Randregel-Neuanpassung).
# Umgebungsvariable: R2_STARTS=5 (Standard; 1 = nur glmmTMB-Standardstart)
# Braucht: glmmTMB; results/modellauswahl/tables/main_kt_coef.csv (22) als Kontrolle, dass A1 hier identisch reproduziert wird.
# Ausgabe: results/modellauswahl/tables/rank2_tests.csv, rank2_starts.csv, rank2_kt_coef.csv, rank2_alt_jung.csv,
#          rank2_resid_cor.csv; data_processed/modellauswahl/rank2_models.rds (dieselben Tabellen)

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(glmmTMB))

WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
cv <- model_covariates()
kw <- merge(readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES],
            cv[, .(ags, kt, z_sgb2, z_p65, z_ltour)], by = "ags")
TERMS <- c(ktT2_staedtisch = "T2", ktT3_laendl_Verdichtung = "T3", ktT4_duenn_besiedelt = "T4")
G <- length(GR_COARSE)
R2_STARTS <- as.integer(Sys.getenv("R2_STARTS", "5"))
SEEDS <- c(101, 202, 303, 404, 505, 606, 707, 808, 909)[seq_len(max(0, R2_STARTS - 1))]

# ---- Modell wie in 22 (Formel, Optimierer, Randregel), Kreis-Faktor mit Rang d ------------------------------
CTRL <- glmmTMBControl(optCtrl = list(iter.max = 5000, eval.max = 10000))
THETA_MAX <- 1e4
form <- function(rank) as.formula(sprintf(
  "cases ~ grp + grp:kt + grp:state + grp:(z_sgb2 + z_p65 + z_ltour) + rr(0 + grp | ags, d = %d) + offset(lpop)", rank))
fit_tmb <- function(f, d, ...) withCallingHandlers(
  glmmTMB(f, dispformula = ~ 0 + grp, family = nbinom2, data = d, control = CTRL, ...),
  warning = function(w) {
    m <- conditionMessage(w)
    if (grepl("non-integer counts", m) || grepl("non-positive-definite Hessian", m)) invokeRestart("muffleWarning")
  })
# Randregel wie fit_main() in 22; start = optionale Startwerte der Ladungen (theta), bleiben fuer die Neuanpassung
fit_rule <- function(rank, d, start_theta = NULL) {
  st0 <- if (is.null(start_theta)) list() else list(theta = start_theta)
  m <- if (length(st0)) fit_tmb(form(rank), d, start = st0) else fit_tmb(form(rank), d)
  bd <- m$fit$par[names(m$fit$par) == "betadisp"]
  fix <- bd > log(THETA_MAX)
  if (!isTRUE(m$sdr$pdHess) && !any(fix)) fix <- bd == max(bd)
  if (any(fix)) {
    s <- pmin(bd, log(THETA_MAX)); s[fix] <- log(THETA_MAX)
    m <- fit_tmb(form(rank), d, start = c(st0, list(betadisp = unname(s))),
                 map = list(betadisp = factor(ifelse(fix, NA, seq_along(bd)))))
  }
  attr(m, "theta_fix") <- paste(levels(d$grp)[fix], collapse = ", ")
  m
}
ok_fit <- function(m) !is.null(m) && m$fit$convergence == 0 && isTRUE(m$sdr$pdHess)

kt_coefs <- function(m) {
  b <- fixef(m)$cond; V <- vcov(m)$cond; i <- grep("^grp.+:kt", names(b)); nm <- names(b)[i]
  data.table(grp = sub("^grp(.+):kt.*$", "\\1", nm), term = TERMS[sub("^grp.+:(kt.*)$", "\\1", nm)],
             est = unname(b[i]), se = unname(sqrt(diag(V)[i])), coef = nm)
}
wald_equal <- function(m, terms = TERMS) {            # wie in 22: Differenzen zur ersten Altersgruppe
  b <- fixef(m)$cond; V <- vcov(m)$cond; k <- kt_coefs(m)[term %in% terms]
  C <- do.call(rbind, lapply(terms, function(t) {
    x <- k[term == t]; ref <- match(x$coef[x$grp == GR_COARSE[1]], names(b))
    t(vapply(x$coef[x$grp != GR_COARSE[1]], function(cn) { r <- numeric(length(b)); r[match(cn, names(b))] <- 1; r[ref] <- -1; r },
             numeric(length(b))))
  }))
  cb <- C %*% b; chi2 <- as.numeric(t(cb) %*% solve(C %*% V %*% t(C), cb))
  c(chi2 = chi2, df = nrow(C), p = pchisq(chi2, nrow(C), lower.tail = FALSE))
}
# Verhaeltnis der Kreistyp-IRR 80+ zu 0-5 (je Typ), mit Kovarianz aus derselben Anpassung
alt_jung <- function(m) {
  b <- fixef(m)$cond; V <- vcov(m)$cond
  rbindlist(lapply(names(TERMS), function(tn) {
    i1 <- paste0("grp", GR_COARSE[G], ":", tn); i0 <- paste0("grp", GR_COARSE[1], ":", tn)
    dd <- b[[i1]] - b[[i0]]; se <- sqrt(V[i1, i1] + V[i0, i0] - 2 * V[i1, i0])
    data.table(term = TERMS[[tn]], ratio = exp(dd), lo = exp(dd - 1.96 * se), hi = exp(dd + 1.96 * se))
  }))
}
# Korrelation der Pearson-Residuen zwischen Altersgruppen derselben Kreise (Kreise x Altersgruppen)
resid_cor <- function(m, d) {
  r <- dcast(data.table(ags = d$ags, grp = d$grp, r = residuals(m, type = "pearson")), ags ~ grp, value.var = "r")
  cm <- cor(as.matrix(r[, GR_COARSE, with = FALSE]))
  ij <- which(lower.tri(cm), arr.ind = TRUE)
  data.table(grp1 = GR_COARSE[ij[, 2]], grp2 = GR_COARSE[ij[, 1]], r = cm[ij])
}

a1_pub <- fread(file.path(DIR_TAB, "main_kt_coef.csv"))
tests <- list(); starts <- list(); coefs <- list(); aj <- list(); rc <- list()
for (w in WAVES) {
  t0 <- Sys.time()
  d <- as.data.frame(kw[phase == w])
  d$grp <- factor(d$grp, GR_COARSE); d$state <- factor(d$state); d$ags <- factor(d$ags); d$lpop <- log(d$pop_rki)

  a1 <- fit_rule(1, d)                                   # = Modellvorschlag A1
  if (!ok_fit(a1)) stop(w, ": A1 nicht konvergiert")
  k1 <- kt_coefs(a1)
  dev <- max(abs(k1$est - a1_pub[wave == w][match(paste(k1$grp, k1$term), paste(grp, term)), est]))
  if (dev > 1e-4) warning(w, ": A1 weicht von main_kt_coef.csv ab (max |Diff| ", signif(dev, 2), ")")

  th0 <- c(list(NULL), lapply(SEEDS, function(s) { set.seed(s); x <- rnorm(2 * G - 1, sd = .18); x[1] <- .25; x }))
  cand <- lapply(th0, function(th) tryCatch(fit_rule(2, d, th), error = function(e) NULL))
  ok <- vapply(cand, ok_fit, TRUE)
  if (!any(ok)) stop(w, ": kein Rang-2-Start konvergiert")
  ll <- vapply(cand, function(m) if (is.null(m)) NA_real_ else as.numeric(logLik(m)), 0)
  best <- which(ok)[which.max(ll[ok])]
  r2 <- cand[[best]]
  starts[[w]] <- data.table(wave = w, start = c("Standard", paste("Seed", SEEDS)),
    conv = vapply(cand, function(m) if (is.null(m)) NA_integer_ else as.integer(m$fit$convergence), 0L),
    pdHess = vapply(cand, function(m) !is.null(m) && isTRUE(m$sdr$pdHess), TRUE),
    logLik = ll, AIC = vapply(cand, function(m) if (is.null(m)) NA_real_ else AIC(m), 0),
    p_wald = vapply(cand, function(m) if (ok_fit(m)) wald_equal(m)[["p"]] else NA_real_, 0),
    theta_fix = vapply(cand, function(m) if (is.null(m)) NA_character_ else attr(m, "theta_fix"), ""),
    gewaehlt = seq_along(cand) == best)

  wa <- wald_equal(a1); wr <- wald_equal(r2)
  tests[[w]] <- data.table(wave = w, AIC_A1 = AIC(a1), AIC_R2 = AIC(r2), dAIC = AIC(a1) - AIC(r2),
    chi2_A1 = wa[["chi2"]], p_A1 = wa[["p"]], chi2_R2 = wr[["chi2"]], p_R2 = wr[["p"]],
    p_R2_standard = if (ok[1]) wald_equal(cand[[1]])[["p"]] else NA_real_,
    n_starts = length(cand), n_ok = sum(ok), ll_spanne = diff(range(ll[ok])),
    theta_fix_A1 = attr(a1, "theta_fix"), theta_fix_R2 = attr(r2, "theta_fix"))
  k2 <- kt_coefs(r2)
  coefs[[w]] <- merge(k1[, .(grp, term, est_a1 = est, se_a1 = se)], k2[, .(grp, term, est_r2 = est, se_r2 = se)],
                      by = c("grp", "term"))[, wave := w]
  aj[[w]] <- rbind(alt_jung(a1)[, model := "A1"], alt_jung(r2)[, model := "Rang 2"])[, wave := w]
  rc[[w]] <- rbind(resid_cor(a1, d)[, model := "A1"], resid_cor(r2, d)[, model := "Rang 2"])[, wave := w]
  cat(sprintf("%s: %.0f s | %d/%d Starts ok, logLik-Spanne %.2g | dAIC (A1 - Rang 2) %.1f | Wald p A1 %.2g, Rang 2 %.2g | theta fest: A1 [%s], Rang 2 [%s]\n",
              w, as.numeric(difftime(Sys.time(), t0, units = "secs")), sum(ok), length(cand), diff(range(ll[ok])),
              AIC(a1) - AIC(r2), wa[["p"]], wr[["p"]], attr(a1, "theta_fix"), attr(r2, "theta_fix")))
}
tests <- rbindlist(tests); starts <- rbindlist(starts); coefs <- rbindlist(coefs); aj <- rbindlist(aj); rc <- rbindlist(rc)
tests[, `:=`(holm_A1 = p.adjust(p_A1, "holm"), holm_R2 = p.adjust(p_R2, "holm"),
             holm_R2_standard = p.adjust(p_R2_standard, "holm"))]
coefs[, `:=`(sig_a1 = abs(est_a1) > 1.96 * se_a1, sig_r2 = abs(est_r2) > 1.96 * se_r2)]
setcolorder(coefs, "wave"); setorder(coefs, wave, term, grp)
setcolorder(aj, c("wave", "model")); setcolorder(rc, c("wave", "model"))

fwrite(tests, file.path(DIR_TAB, "rank2_tests.csv"))
fwrite(starts, file.path(DIR_TAB, "rank2_starts.csv"))
fwrite(coefs, file.path(DIR_TAB, "rank2_kt_coef.csv"))
fwrite(aj, file.path(DIR_TAB, "rank2_alt_jung.csv"))
fwrite(rc, file.path(DIR_TAB, "rank2_resid_cor.csv"))
saveRDS(list(tests = tests, starts = starts, coefs = coefs, alt_jung = aj, resid_cor = rc),
        file.path(DIR_CLEAN, "rank2_models.rds"))

# ---- Zusammenfassung ------------------------------------------------------------------------
cat("\n== A1 vs. Rang 2: Kreistyp x Alter (df 18), Holm ueber 8 Wellen ==\n")
print(tests[, .(wave, dAIC = round(dAIC, 1), holm_A1 = signif(holm_A1, 3), holm_R2 = signif(holm_R2, 3),
                holm_R2_standard = signif(holm_R2_standard, 3), n_ok, ll_spanne = signif(ll_spanne, 2), theta_fix_R2)])
cat(sprintf("\nKreistyp-Koeffizienten (168): r = %.4f, mittlere |Diff| = %.4f, Wechsel 'KI ohne 0' %d von %d\n",
            coefs[, cor(est_a1, est_r2)], coefs[, mean(abs(est_a1 - est_r2))], coefs[, sum(sig_a1 != sig_r2)], nrow(coefs)))
cat("\nResidualkorrelation 0-5 mit 6-17 und 70-79 mit 80+ (gleicher Kreis):\n")
print(dcast(rc[(grp1 == "0-5" & grp2 == "6-17") | (grp1 == "70-79" & grp2 == "80+")],
            wave ~ model + grp1, value.var = "r", fun.aggregate = function(x) round(x, 3)))
cat("\nVerhaeltnis der T4-IRR 80+ zu 0-5:\n")
print(dcast(aj[term == "T4"], wave ~ model, value.var = "ratio", fun.aggregate = function(x) round(x, 3)))
