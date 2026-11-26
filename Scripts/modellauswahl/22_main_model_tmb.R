# Hauptmodell (Entscheidung 24.11.2026): gemeinsames NB-GLMM je Welle ueber alle 7 Altersgruppen mit
# altersgruppenspezifischer Dispersion (glmmTMB).
#
# Warum nicht mehr 17_joint_age_models.R ("int", NB mit Kreis-RE + MRF) als Hauptmodell:
#   Dort teilen sich alle Altersgruppen ein theta. Die Pearson-Dispersion je Altersgruppe lag damit zwischen
#   0,26-0,51 (40-59) und 1,7-3,4 (0-5) bzw. 1,6-2,6 (80+): Konfidenzintervalle bei 0-5 und 80+ zu schmal,
#   bei Erwachsenen zu breit. Ein eigenes theta je Altersgruppe verbessert die Anpassung stark
#   (LR-Test df 6, siehe main_tests.csv) und aendert die Standardfehler um etwa 15-30 %, der raeumliche
#   Effekt (MRF) dagegen nur um 1-3 %. Beides zusammen geht mit den installierten Paketen nicht
#   (mgcv: ein theta; glmmTMB: kein MRF, raeumliche Kovarianz ueber Schwerpunkte konvergierte nicht).
#   17 laeuft deshalb weiter als Sensitivitaetsanalyse fuer den raeumlichen Effekt (und GEE).
#
# Modell je Welle (400 Kreise x 7 Altersgruppen = 2800 Zeilen):
#   cases ~ grp + grp:kt + grp:state + grp:(z_sgb2 + z_p65 + z_ltour) + rr(0 + grp | ags, d = 1) + offset(log pop)
#   Familie nbinom2, dispformula = ~ grp (eigenes theta je Altersgruppe), ML (TMB, Laplace).
#   Kreis-Effekt: ein gemeinsamer Kreis-Faktor mit eigener Ladung je Altersgruppe (reduzierter Rang 1).
#   Gegenueber einem einfachen (1 | ags) ist das AIC besser (W2 -27, W5 -167); die Kreistyp-Koeffizienten
#   aendern sich um hoechstens 0,002 (geprueft 24.11.2026 fuer W2, W5, W6).
#   Randregel fuer theta: Bei 40-59 laeuft theta in einzelnen Wellen gegen sehr grosse Werte (kaum Ueberdispersion
#   ueber den Kreis-Effekt hinaus); dann ist die Hessematrix nicht positiv definit.
#   Regel: theta je Altersgruppe frei schaetzen; liegt ein Schaetzer ueber THETA_MAX = 1e4 oder ist die Hessematrix
#   nicht positiv definit, wird theta dieser Gruppe(n) auf THETA_MAX festgehalten und neu angepasst. Welche Gruppen
#   das betrifft, steht in main_tests.csv (theta_fix).
#   THETA_MAX ist eine numerische Obergrenze, NICHT "gleich Poisson": Varianz / Poisson-Varianz = 1 + mu/theta liegt
#   bei den grossen Fallzahlen noch deutlich ueber 1 (W5, 40-59: Median 2,07; externe Pruefung 26.11.2026).
#   Die Kreistyp-Koeffizienten aendern sich durch die Grenze um hoechstens 0,001 (geprueft W2, W5, W6; extern mit
#   Grenze 1e6: hoechstens 0,00024, kein KI-Wechsel).
#   LR-Test "theta gleich" (df 6, unten): In Wellen mit festgehaltenem theta hat das Modell nur 5 freie
#   theta-Differenzen und einen Parameter auf dem Rand -> chi2(6)-p-Wert dort nur grobe Naeherung (auch df 5 waere
#   nicht exakt); fuer einen formalen Test parametrischer Bootstrap mit derselben Randregel.
#   Optimierer: iter.max 5000 (mit dem Standard 300 bricht glmmTMB ohne Konvergenz ab).
#   Die Fallzahlen sind wegen der verteilten Faelle ohne Altersangabe nicht ganzzahlig; die Warnung
#   "non-integer counts" wird unterdrueckt (die NB-Loglikelihood nutzt lgamma und ist stetig).
# Vergleich: gleiches Modell mit gemeinsamem theta (dispformula = ~ 1) -> LR-Test "theta gleich" (df 6).
# Tests: Wald-Test "Kreistyp-Effekt in allen Altersgruppen gleich" (18 Kontraste, je Typ 6), dazu
#   Bonferroni und Holm ueber die 8 Wellen; Moran's I der Kreis-Residuen (keine raeumliche Komponente im Modell).
# Braucht: data_processed/modellauswahl/kreis_nb.rds (16_spatial.R), results/modellauswahl/tables/joint_kt_coef.csv (17) fuer den Vergleich.
# Ausgabe: results/modellauswahl/tables/main_kt_coef.csv, main_tests.csv, main_dispersion.csv; data_processed/modellauswahl/main_models.rds

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(glmmTMB))

WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
cv <- model_covariates()
kw <- merge(readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES],
            cv[, .(ags, kt, z_sgb2, z_p65, z_ltour)], by = "ags")
TERMS <- c(ktT2_staedtisch = "T2", ktT3_laendl_Verdichtung = "T3", ktT4_duenn_besiedelt = "T4")

# Moran's I der Kreis-Residuen (wie in 17_joint_age_models.R)
nbo <- readRDS(file.path(DIR_CLEAN, "kreis_nb.rds"))
W <- matrix(0, 400, 400); for (i in seq_along(nbo$nb)) W[i, nbo$nb[[i]]] <- 1 / length(nbo$nb[[i]])
set.seed(20261121); PERM <- replicate(999, sample.int(400))
moran <- function(x) {
  z <- x - mean(x); den <- sum(z^2); I <- sum(z * (W %*% z)) / den; P <- matrix(z[PERM], 400)
  c(I = I, p = (1 + sum(colSums(P * (W %*% P)) / den >= I)) / (ncol(PERM) + 1))
}

CTRL <- glmmTMBControl(optCtrl = list(iter.max = 5000, eval.max = 10000))
THETA_MAX <- 1e4
F_MAIN <- cases ~ grp + grp:kt + grp:state + grp:(z_sgb2 + z_p65 + z_ltour) + rr(0 + grp | ags, d = 1) + offset(lpop)
fit_tmb <- function(disp, d, ...) withCallingHandlers(
  glmmTMB(F_MAIN, dispformula = disp, family = nbinom2, data = d, control = CTRL, ...),
  warning = function(w) {
    m <- conditionMessage(w)
    if (grepl("non-integer counts", m) || grepl("non-positive-definite Hessian", m)) invokeRestart("muffleWarning")
  })
# Hauptmodell mit Randregel: dispformula = ~ 0 + grp, d.h. betadisp = log(theta) je Altersgruppe
fit_main <- function(d) {
  m <- fit_tmb(~ 0 + grp, d)
  bd <- m$fit$par[names(m$fit$par) == "betadisp"]
  fix <- bd > log(THETA_MAX)
  if (!isTRUE(m$sdr$pdHess) && !any(fix)) fix <- bd == max(bd)      # sonst die Gruppe mit dem groessten theta
  if (any(fix)) {
    st <- pmin(bd, log(THETA_MAX)); st[fix] <- log(THETA_MAX)
    m <- fit_tmb(~ 0 + grp, d, start = list(betadisp = unname(st)),
                 map = list(betadisp = factor(ifelse(fix, NA, seq_along(bd)))))
  }
  attr(m, "theta_fix") <- paste(levels(d$grp)[fix], collapse = ", ")
  m
}

kt_coefs <- function(m) {
  b <- fixef(m)$cond; V <- vcov(m)$cond; i <- grep("^grp.+:kt", names(b)); nm <- names(b)[i]
  data.table(grp = sub("^grp(.+):kt.*$", "\\1", nm), term = TERMS[sub("^grp.+:(kt.*)$", "\\1", nm)],
             est = unname(b[i]), se = unname(sqrt(diag(V)[i])), coef = nm)
}
# Wald-Test: Kreistyp-Effekt in allen Altersgruppen gleich (Differenzen zur ersten Altersgruppe)
wald_equal <- function(m, terms) {
  b <- fixef(m)$cond; V <- vcov(m)$cond; k <- kt_coefs(m)[term %in% terms]
  C <- do.call(rbind, lapply(terms, function(t) {
    x <- k[term == t]; ref <- match(x$coef[x$grp == GR_COARSE[1]], names(b))
    t(vapply(x$coef[x$grp != GR_COARSE[1]], function(cn) { r <- numeric(length(b)); r[match(cn, names(b))] <- 1; r[ref] <- -1; r },
             numeric(length(b))))
  }))
  cb <- C %*% b; chi2 <- as.numeric(t(cb) %*% solve(C %*% V %*% t(C), cb))
  data.table(chi2 = chi2, df = nrow(C), p = pchisq(chi2, nrow(C), lower.tail = FALSE))
}
wald_all <- function(m) rbind(wald_equal(m, TERMS)[, test := "alle Typen"],
                              rbindlist(lapply(TERMS, function(t) wald_equal(m, t)[, test := t])))

coefs <- list(); tests <- list(); disp <- list()
for (w in WAVES) {
  d <- as.data.frame(kw[phase == w])
  d$grp <- factor(d$grp, GR_COARSE); d$state <- factor(d$state); d$ags <- factor(d$ags); d$lpop <- log(d$pop_rki)
  t0 <- Sys.time()
  m  <- fit_main(d)             # Hauptmodell: theta je Altersgruppe (mit Randregel)
  m0 <- fit_tmb(~ 1, d)         # Vergleich: gemeinsames theta
  if (m$fit$convergence != 0 || !isTRUE(m$sdr$pdHess)) stop(w, ": Hauptmodell nicht konvergiert (", m$fit$message, ")")
  coefs[[w]] <- kt_coefs(m)[, wave := w]
  lr <- 2 * (as.numeric(logLik(m)) - as.numeric(logLik(m0)))
  r <- residuals(m, type = "pearson")
  rk <- data.table(ags = as.character(d$ags), r = r)[, .(r = mean(r)), by = ags]
  mi <- moran(rk[match(nbo$ags, ags), r])
  tests[[w]] <- wald_all(m)[, `:=`(wave = w, LR_theta = lr, p_LR_theta = pchisq(lr, 6, lower.tail = FALSE),
                                   dAIC_theta = AIC(m0) - AIC(m), conv_m0 = m0$fit$convergence,
                                   theta_fix = attr(m, "theta_fix"),
                                   I_resid = mi[["I"]], p_I_resid = mi[["p"]])]
  vk <- VarCorr(m)$cond$ags
  disp[[w]] <- data.table(wave = w, grp = d$grp, theta = predict(m, type = "disp"), r2 = r^2)[
    , .(theta = theta[1], pearson_disp = mean(r2), n_abs3 = sum(r2 > 9)), by = .(wave, grp)][
    , sd_kreis := sqrt(diag(vk))[match(paste0("grp", grp), rownames(vk))]]
  cat(sprintf("%s: %.0f s | Wald (Kreistyp x Alter, df 18) p = %.2g | LR theta je Altersgruppe = %.0f | Moran I Kreis-Residuen %.2f (p %.3f)\n",
              w, as.numeric(difftime(Sys.time(), t0, units = "secs")), tests[[w]][test == "alle Typen", p], lr, mi[["I"]], mi[["p"]]))
}
coefs <- rbindlist(coefs); tests <- rbindlist(tests); disp <- rbindlist(disp)
coefs[, `:=`(irr = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se), coef = NULL)]
# Mehrfachtests ueber die 8 Wellen (globaler Test "alle Typen")
tests[test == "alle Typen", `:=`(p_bonf = pmin(1, p * .N), p_holm = p.adjust(p, "holm"))]

# Vergleich mit 17 (int = NB mit gemeinsamem theta + Kreis-RE + MRF; gee = GEE, robuste SE nach Kreis)
j17 <- fread(file.path(DIR_TAB, "joint_kt_coef.csv"))[spec %in% c("int", "gee"), .(wave, spec, grp, term, est, se)]
j17 <- dcast(j17, wave + grp + term ~ spec, value.var = c("est", "se"))
coefs <- merge(coefs, j17, by = c("wave", "grp", "term"), all.x = TRUE)
setnames(coefs, c("est_int", "se_int", "est_gee", "se_gee"), c("est_mrf", "se_mrf", "est_gee", "se_gee"))
setcolorder(coefs, c("wave", "grp", "term", "est", "se", "irr", "lo", "hi"))
setorder(coefs, wave, term, grp)
setcolorder(tests, c("wave", "test", "chi2", "df", "p", "p_bonf", "p_holm"))
fwrite(coefs, file.path(DIR_TAB, "main_kt_coef.csv"))
fwrite(tests, file.path(DIR_TAB, "main_tests.csv"))
fwrite(disp, file.path(DIR_TAB, "main_dispersion.csv"))
saveRDS(list(coefs = coefs, tests = tests, disp = disp), file.path(DIR_CLEAN, "main_models.rds"))

# ---- Zusammenfassung -------------------------------------------------------------------------
sig <- function(x) x[, lapply(.SD, function(v) if (is.numeric(v)) signif(v, 2) else v)]
cat("\n== Wald-Test: Kreistyp-Effekt in allen Altersgruppen gleich? ==\n")
print(sig(tests[test == "alle Typen", .(wave, chi2, p, p_bonf, p_holm, LR_theta, dAIC_theta, theta_fix, I_resid, p_I_resid)]))
cat("\n== theta und Pearson-Dispersion je Altersgruppe ==\n")
print(dcast(disp, grp ~ wave, value.var = "theta", fun.aggregate = function(x) signif(x, 3))[match(GR_COARSE, grp)])
print(dcast(disp, grp ~ wave, value.var = "pearson_disp", fun.aggregate = function(x) round(x, 2))[match(GR_COARSE, grp)])
cat("\n== Kreistyp-log-IRR: Hauptmodell im Vergleich ==\n")
cat(sprintf("mit MRF (17, gemeinsames theta): Korrelation %.3f | mittlere |Differenz| %.3f | SE-Verhaeltnis 17/Haupt (Median) %.2f\n",
            cor(coefs$est, coefs$est_mrf), mean(abs(coefs$est - coefs$est_mrf)), median(coefs$se_mrf / coefs$se)))
cat(sprintf("GEE (17):                        Korrelation %.3f | mittlere |Differenz| %.3f\n",
            cor(coefs$est, coefs$est_gee), mean(abs(coefs$est - coefs$est_gee))))
cat("SE-Verhaeltnis 17 (MRF) / Hauptmodell je Altersgruppe (Median):\n")
print(coefs[, .(se_mrf_zu_haupt = round(median(se_mrf / se), 2), se_gee_zu_haupt = round(median(se_gee / se), 2)), by = grp][match(GR_COARSE, grp)])
cat("signifikante Kreistyp-Koeffizienten (von 168, unkorrigiert):", coefs[, sum(lo > 1 | hi < 1)],
    "| mit MRF (17):", coefs[, sum(abs(est_mrf / se_mrf) > 1.96)], "\n")
cat("\nIRR Typ 4 vs. Grossstadt je Altersgruppe (* = 95 %-KI ohne 1, unkorrigiert):\n")
x <- coefs[term == "T4"][, lab := sprintf("%.2f%s", irr, fifelse(lo > 1 | hi < 1, "*", ""))]
print(dcast(x, grp ~ wave, value.var = "lab")[match(GR_COARSE, grp)])
