# Option III (Diskussion, 25.11.2026): Hauptmodell A1 + raeumlicher Effekt in EINEM Modell (INLA).
#
# Hintergrund: Mit glmmTMB/mgcv ging nur entweder "theta je Altersgruppe" (A1, 22_main_model_tmb.R) oder
# "MRF-Raumeffekt mit gemeinsamem theta" (17_joint_age_models.R, int). INLA kann beides zusammen:
#   - 7 Likelihoods (eine je Altersgruppe), jede NB mit eigenem theta (size);
#   - Kreis-Effekt als gemeinsamer Faktor mit eigener Ladung je Altersgruppe (wie rr(0 + grp | ags, d = 1) in A1):
#     Faktor u_k bei 0-5 mit Ladung 1, in den anderen Gruppen als copy mit frei geschaetzter Ladung beta_a;
#   - u_k ist entweder iid (= A1, Kontrolle) oder BYM2 (= raeumlich strukturiert + unstrukturiert,
#     Mischungsanteil phi; Riebler et al. 2016, skaliert).
# Festes Modell wie A1 je Welle:  grp + grp:kt + grp:state + grp:(z_sgb2 + z_p65 + z_ltour) + offset(log pop)
#
# Unterschiede zu A1, die man nennen muss:
#   - Bayesianisch (INLA, Laplace-Naeherung). Priors: feste Effekte N(0, 1000) (INLA-Standard);
#     Kreis-Praezision PC-Prior P(sd > 1) = 0,01; phi PC-Prior P(phi < 0,5) = 2/3; Ladungen N(1, 10);
#     size: INLA-Standard. Keine Randregel noetig: der Prior haelt theta bei 40-59 endlich.
#   - INLA verlangt ganzzahlige Fallzahlen -> Faelle werden gerundet (verteilte Faelle ohne Altersangabe
#     machen sie sonst nicht ganzzahlig). Rundungsfehler hoechstens 0,5 Faelle je Zelle.
#   - Kontrolle: Die iid-Version reproduziert A1 (geprueft W5: Korrelation der Kreistyp-Koeffizienten 1,000,
#     mittlere |Differenz| < 0,001, Posterior-SD/ML-SE 1,03).
# Test "Kreistyp-Effekt in allen Altersgruppen gleich" (18 Kontraste wie in 22): Wald-artig aus 2000
#   Posterior-Ziehungen (Mittelwert und Kovarianz der Kontraste), dazu Holm ueber die 8 Wellen.
#   Das ist eine Naeherung an den frequentistischen Test, kein Bayes-Faktor.
# Modellvergleich iid vs. BYM2: DIC und WAIC (kleiner = besser); Moran's I der Kreis-Residuen.
# Laufzeit: ca. 15 Minuten seriell (INLA_THREADS = 1:1; 8 Wellen x 2 Modelle, BYM2 je 1-2 Minuten).
# Braucht: INLA (nicht auf CRAN):
#   install.packages("INLA", repos = c(getOption("repos"), INLA = "https://inla.r-inla-download.org/R/stable"))
#   data_processed/modellauswahl/kreis_nb.rds (16_spatial.R), results/modellauswahl/tables/main_kt_coef.csv (22) fuer den Vergleich.
# Ausgabe: results/modellauswahl/tables/inla_kt_coef.csv, inla_tests.csv, inla_hyper.csv; data_processed/modellauswahl/inla_models.rds

source("Scripts/modellauswahl/00_setup.R")
if (!requireNamespace("INLA", quietly = TRUE)) stop("Paket INLA fehlt (Installation siehe Kopf des Skripts).")
suppressPackageStartupMessages(library(INLA))

WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
cv <- model_covariates()
kw <- merge(readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES],
            cv[, .(ags, kt, z_sgb2, z_p65, z_ltour)], by = "ags")
TERMS <- c(ktT2_staedtisch = "T2", ktT3_laendl_Verdichtung = "T3", ktT4_duenn_besiedelt = "T4")
G <- length(GR_COARSE)

# Nachbarschaft (wie 16/17/22) als Graph fuer BYM2 und fuer Moran's I
nbo <- readRDS(file.path(DIR_CLEAN, "kreis_nb.rds"))
ADJ <- Matrix::sparseMatrix(i = rep(seq_along(nbo$nb), lengths(nbo$nb)), j = unlist(nbo$nb), x = 1, dims = c(400, 400))
W <- matrix(0, 400, 400); for (i in seq_along(nbo$nb)) W[i, nbo$nb[[i]]] <- 1 / length(nbo$nb[[i]])
set.seed(20261121); PERM <- replicate(999, sample.int(400))
moran <- function(x) {
  z <- x - mean(x); den <- sum(z^2); I <- sum(z * (W %*% z)) / den; P <- matrix(z[PERM], 400)
  c(I = I, p = (1 + sum(colSums(P * (W %*% P)) / den >= I)) / (ncol(PERM) + 1))
}

PREC <- list(prec = list(prior = "pc.prec", param = c(1, 0.01)))
F_KREIS <- list(
  iid  = "f(k1, model = 'iid', hyper = PREC)",
  bym2 = paste("f(k1, model = 'bym2', graph = ADJ, scale.model = TRUE, constr = TRUE,",
               "hyper = c(PREC, list(phi = list(prior = 'pc', param = c(0.5, 2/3)))))"))
BETA <- list(beta = list(fixed = FALSE, prior = "normal", param = c(1, 0.1)))
N_SAMP <- 2000
# Rechenfaeden: Mit mehreren Threads ist INLA nicht exakt reproduzierbar (DIC/WAIC und Posterior-Modus
# aendern sich zwischen zwei Laeufen mit identischen Daten, externe Pruefung 26.11.2026). Standard daher "1:1"
# (seriell, weitgehend reproduzierbar: ein zweiter serieller Lauf am 26.11.2026 war in 5 von 8 Wellen identisch,
# in W1, W3 und W8 wich das DIC um bis zu 50 ab; Testschluesse, phi und Vorzeichen von dDIC/dWAIC blieben gleich).
# Schneller, aber nicht bitgenau: INLA_THREADS=4:1 Rscript Scripts/modellauswahl/24_spatial_theta_inla.R
INLA_THREADS <- Sys.getenv("INLA_THREADS", "1:1")

fit_wave <- function(w, spec) {
  d <- as.data.frame(kw[phase == w])
  d$grp <- factor(d$grp, GR_COARSE); d$state <- factor(d$state); d$lpop <- log(d$pop_rki)
  d <- d[order(d$grp, match(d$ags, nbo$ags)), ]
  X <- model.matrix(~ grp + grp:kt + grp:state + grp:(z_sgb2 + z_p65 + z_ltour), d)
  stopifnot(qr(X)$rank == ncol(X))
  bn <- sprintf("b%03d", seq_len(ncol(X))); cmap <- setNames(colnames(X), bn); colnames(X) <- bn
  n <- nrow(d); ga <- as.integer(d$grp)
  Y <- matrix(NA_real_, n, G); Y[cbind(seq_len(n), ga)] <- round(d$cases)
  dat <- c(list(Y = Y, lpop = d$lpop), as.list(as.data.frame(X)))
  k <- match(d$ags, nbo$ags)
  for (a in seq_len(G)) dat[[paste0("k", a)]] <- ifelse(ga == a, k, NA)
  fo <- as.formula(paste("Y ~ -1 +", paste(bn, collapse = " + "), "+", F_KREIS[[spec]], "+",
                         paste(sprintf("f(k%d, copy = 'k1', hyper = BETA)", 2:G), collapse = " + "), "+ offset(lpop)"))
  r <- inla(fo, family = rep("nbinomial", G), data = dat, num.threads = INLA_THREADS,
            control.compute = list(dic = TRUE, waic = TRUE, config = TRUE),
            control.predictor = list(compute = TRUE, link = rep(1, n)))
  if (r$mode$mode.status != 0) warning(w, " ", spec, ": INLA mode.status = ", r$mode$mode.status)

  # Kreistyp-Koeffizienten
  ib <- bn[grepl("^grp.+:kt", cmap)]; nm <- cmap[ib]; s <- r$summary.fixed[ib, ]
  co <- data.table(wave = w, spec = spec, grp = sub("^grp(.+):kt.*$", "\\1", nm), term = TERMS[sub("^grp.+:(kt.*)$", "\\1", nm)],
                   est = s$mean, se = s$sd, q_lo = s$`0.025quant`, q_hi = s$`0.975quant`)
  # Wald-artiger Test aus Posterior-Ziehungen: Differenzen zur ersten Altersgruppe je Typ
  # inla.posterior.sample waehlt die Hyperparameter-Konfigurationen mit dem R-Zufallsgenerator, nur die latenten
  # Ziehungen mit `seed`: R-Seed je Welle x Modell setzen, damit der Test nicht von der Reihenfolge der Laeufe abhaengt
  set.seed(20261125 + 10 * match(w, WAVES) + match(spec, names(F_KREIS)))
  smp <- inla.posterior.sample(N_SAMP, r, selection = setNames(as.list(rep(1, length(ib))), ib), seed = 20261125)
  B <- sapply(smp, function(x) x$latent[paste0(ib, ":1"), 1])
  rownames(B) <- ib
  wald <- function(terms) {
    D <- do.call(rbind, lapply(terms, function(t) {
      ref <- ib[co$term == t & co$grp == GR_COARSE[1]]
      B[ib[co$term == t & co$grp != GR_COARSE[1]], , drop = FALSE] - matrix(B[ref, ], sum(co$term == t) - 1, N_SAMP, byrow = TRUE)
    }))
    m <- rowMeans(D); chi2 <- as.numeric(t(m) %*% solve(cov(t(D)), m))
    data.table(chi2 = chi2, df = length(m), p = pchisq(chi2, length(m), lower.tail = FALSE))
  }
  te <- rbind(wald(TERMS)[, test := "alle Typen"], rbindlist(lapply(TERMS, function(t) wald(t)[, test := t])))

  # Hyperparameter: theta je Altersgruppe, Kreis-SD, phi, Ladungen
  h <- r$summary.hyperpar
  hn <- rownames(h)
  lab <- vapply(hn, function(x) {
    if (startsWith(x, "size")) return(paste("theta", GR_COARSE[if (grepl("\\[", x)) as.integer(sub(".*\\[(\\d+)\\]$", "\\1", x)) else 1L]))
    if (startsWith(x, "Precision")) return("Praezision Kreis (0-5)")
    if (startsWith(x, "Phi")) return("phi (raeumlicher Anteil)")
    paste("Ladung", GR_COARSE[as.integer(sub("^Beta for k(\\d+)$", "\\1", x))])
  }, "", USE.NAMES = FALSE)
  hy <- data.table(wave = w, spec = spec, param = lab, mean = h$mean, median = h$`0.5quant`, lo = h$`0.025quant`, hi = h$`0.975quant`)

  # Pearson-Residuen (Posterior-Mittel von mu, theta = Posterior-Median je Gruppe) -> Moran's I je Kreis
  mu <- r$summary.fitted.values$mean
  th <- hy[startsWith(param, "theta ")][match(paste("theta", GR_COARSE), param), median][ga]
  res <- (round(d$cases) - mu) / sqrt(mu + mu^2 / th)
  rk <- data.table(ags = d$ags, r = res)[, .(r = mean(r)), by = ags]
  mi <- moran(rk[match(nbo$ags, ags), r])
  phi <- hy[param == "phi (raeumlicher Anteil)"]
  te[, `:=`(wave = w, spec = spec, DIC = r$dic$dic, WAIC = r$waic$waic,
            phi = if (nrow(phi)) phi$mean else NA_real_, phi_lo = if (nrow(phi)) phi$lo else NA_real_,
            phi_hi = if (nrow(phi)) phi$hi else NA_real_,
            sd_kreis_05 = 1 / sqrt(hy[param == "Praezision Kreis (0-5)", median]),
            I_resid = mi[["I"]], p_I_resid = mi[["p"]], secs = r$cpu.used[["Total"]], threads = INLA_THREADS)]
  list(co = co, te = te, hy = hy)
}

out <- list()
for (w in WAVES) for (spec in names(F_KREIS)) {
  out[[paste(w, spec)]] <- x <- fit_wave(w, spec)
  t1 <- x$te[test == "alle Typen"]
  cat(sprintf("%s %-4s: %3.0f s | DIC %.0f | Wald (Kreistyp x Alter, df 18) p = %.2g | phi %s | Moran I Kreis-Residuen %.2f (p %.3f)\n",
              w, spec, t1$secs, t1$DIC, t1$p, if (is.na(t1$phi)) "  -  " else sprintf("%.2f", t1$phi), t1$I_resid, t1$p_I_resid))
}
coefs <- rbindlist(lapply(out, `[[`, "co")); tests <- rbindlist(lapply(out, `[[`, "te")); hyper <- rbindlist(lapply(out, `[[`, "hy"))
coefs[, `:=`(irr = exp(est), lo = exp(q_lo), hi = exp(q_hi))]
tests[test == "alle Typen", `:=`(p_bonf = pmin(1, p * .N), p_holm = p.adjust(p, "holm")), by = spec]
tests[, dDIC_vs_iid := DIC - DIC[spec == "iid"], by = .(wave, test)]
tests[, dWAIC_vs_iid := WAIC - WAIC[spec == "iid"], by = .(wave, test)]

# Vergleich mit A1 (22_main_model_tmb.R)
a1 <- fread(file.path(DIR_TAB, "main_kt_coef.csv"))[, .(wave, grp, term, est_a1 = est, se_a1 = se)]
coefs <- merge(coefs, a1, by = c("wave", "grp", "term"), all.x = TRUE)
setcolorder(coefs, c("wave", "spec", "grp", "term", "est", "se", "irr", "lo", "hi"))
setorder(coefs, spec, wave, term, grp)
setcolorder(tests, c("wave", "spec", "test", "chi2", "df", "p", "p_bonf", "p_holm"))
setorder(tests, spec, wave)
fwrite(coefs, file.path(DIR_TAB, "inla_kt_coef.csv"))
fwrite(tests, file.path(DIR_TAB, "inla_tests.csv"))
fwrite(hyper, file.path(DIR_TAB, "inla_hyper.csv"))
saveRDS(list(coefs = coefs, tests = tests, hyper = hyper), file.path(DIR_CLEAN, "inla_models.rds"))

# ---- Zusammenfassung -------------------------------------------------------------------------
cat("\n== Kontrolle: iid-Version gegen A1 ==\n")
print(coefs[spec == "iid", .(r = round(cor(est, est_a1), 3), mittl_abs_diff = round(mean(abs(est - est_a1)), 4),
                             sd_zu_se = round(median(se / se_a1), 2)), by = wave])
cat("\n== BYM2 (A1 + Raumeffekt) gegen A1 ==\n")
print(coefs[spec == "bym2", .(r = round(cor(est, est_a1), 3), mittl_abs_diff = round(mean(abs(est - est_a1)), 3),
                              sd_zu_se = round(median(se / se_a1), 2)), by = wave])
cat("\n== Tests je Welle: Kreistyp x Alter (df 18), Holm ueber 8 Wellen; DIC/WAIC BYM2 - iid; phi; Moran's I ==\n")
print(dcast(tests[test == "alle Typen"], wave ~ spec, value.var = c("p_holm", "I_resid"),
            fun.aggregate = function(x) signif(x, 2)))
print(tests[test == "alle Typen" & spec == "bym2", .(wave, dDIC_vs_iid = round(dDIC_vs_iid), dWAIC_vs_iid = round(dWAIC_vs_iid),
                                                     phi = round(phi, 2), phi_lo = round(phi_lo, 2), phi_hi = round(phi_hi, 2))])
cat("\nIRR Typ 4 vs. Grossstadt je Altersgruppe, BYM2 (* = 95 %-Kredibilitaetsintervall ohne 1, unkorrigiert):\n")
x <- coefs[spec == "bym2" & term == "T4"][, lab := sprintf("%.2f%s", irr, fifelse(lo > 1 | hi < 1, "*", ""))]
print(dcast(x, grp ~ wave, value.var = "lab")[match(GR_COARSE, grp)])
cat("signifikante Kreistyp-Koeffizienten (von 168, unkorrigiert): A1",
    fread(file.path(DIR_TAB, "main_kt_coef.csv"))[, sum(lo > 1 | hi < 1)], "| INLA iid", coefs[spec == "iid", sum(lo > 1 | hi < 1)],
    "| INLA BYM2", coefs[spec == "bym2", sum(lo > 1 | hi < 1)], "\n")
