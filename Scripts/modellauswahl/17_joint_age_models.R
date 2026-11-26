# Gemeinsames Modell ueber alle Altersgruppen je Welle: NB-GLMM mit Kreis- und raeumlichem Zufallseffekt
# (Statistik V "Gemischte Modelle"/GLMM und geoadditive Modelle; Lineare Modelle Kap. 6 Interaktionen, Kap. 9).
# Frage: Unterscheidet sich der Effekt des Kreistyps zwischen den Altersgruppen (Kreistyp x Altersgruppe)?
# In 12_models_wave_age.R hat jede Welle x Altersgruppe ein eigenes Modell; Unterschiede zwischen Altersgruppen
# lassen sich dort nicht testen, weil dieselben 400 Kreise in allen Gruppen vorkommen (abhaengige Schaetzer).
# Hier stehen alle 7 Altersgruppen einer Welle in einem Modell (400 Kreise x 7 = 2800 Zeilen):
#   int     : cases ~ grp + grp:kt + grp:state + grp:(z_sgb2 + z_p65 + z_ltour)
#                     + (1 | Kreis) + raeumlicher Kreis-Effekt (MRF) + offset                       (Hauptmodell)
#             -> Kreistyp-Effekt je Altersgruppe; Bundesland und Kovariaten wie in 12 altersspezifisch
#   const   : wie int, aber ein Kreistyp-Effekt fuer alle Altersgruppen (kt statt grp:kt)
#   int_re  : wie int, Bundesland als Zufallseffekt (Land + Land x Altersgruppe) statt Fixed Effect
#             (Evidenz zur offenen Frage "Bundesland Fixed oder Random Effect")
#   int_nosp: wie int ohne raeumlichen Effekt (Hauptmodell bis 21.11.2026; Vergleich)
# Abhaengigkeit wird auf drei Ebenen modelliert: Altersgruppen desselben Kreises (unstrukturierter Kreis-Effekt
# s(ags, bs = "re")), Kreise desselben Landes (Bundesland), Nachbarkreise (Markov-Random-Field ueber die
# Kreis-Nachbarschaft aus 16_spatial.R, s(ags_m, bs = "mrf"), Rang K_MRF). Kreis-Effekt = unstrukturierter +
# raeumlich strukturierter Teil (BYM-artige Zerlegung). Ohne MRF waren die Kreis-Residuen raeumlich autokorreliert
# (Moran's I 0,14-0,22, alle Wellen p < 0,05); mit MRF 0,0-0,1 (siehe Spalten I_resid*).
# Rang des MRF (Pruefung W2, W6-W8, 21.11.2026): k = 100, 200, 399 aendern die Kreistyp-Koeffizienten um
# hoechstens 0,03, das AIC um < 5 und den Wald-Test nicht; voller Rang ueberkorrigiert z.T. (W2: I = -0,11).
# Achtung raeumliche Konfundierung: Der Kreistyp ist selbst raeumlich geklumpt; der MRF kann einen Teil seines
# Effekts aufnehmen. Hier werden die Effekte mit MRF eher groesser (Vergleich int_nosp).
# Schaetzung mit mgcv (bam, fREML), NB-Familie mit einem gemeinsamen theta fuer alle Altersgruppen.
# Geprueft (W4, ohne MRF): gam mit ML-Schaetzung liefert die Kreistyp-Koeffizienten bis auf 0,002 gleich.
# Tests: Wald-Test "Kreistyp-Effekt in allen Altersgruppen gleich" (3 Typen x 6 Differenzen = 18 Kontraste),
#   je Typ (6 Kontraste); konditionales AIC (mgcv) const - int, int_re - int, int_nosp - int; Moran's I der
#   Kreis-Residuen (Mittel der Pearson-Residuen ueber die Altersgruppen; Permutationstest).
# GEE (Statistik V "Marginale Modelle"/GEE) als Alternative: gleicher Praediktor ohne Zufallseffekte, Quasi-Poisson,
#   Arbeitskorrelation "unabhaengig" mit robuster (Sandwich-)Kovarianz, geclustert nach Kreis (sandwich::vcovCL);
#   eine austauschbare Arbeitskorrelation braeuchte geepack (nicht installiert). Quasi-Poisson gewichtet grosse
#   Kreise staerker.
# Braucht data_processed/modellauswahl/kreis_nb.rds aus 16_spatial.R.
# Ausgabe: results/modellauswahl/tables/joint_kt_coef.csv (spec int, int_re, int_nosp, gee), joint_tests.csv (p = Hauptmodell,
#          p_nosp = ohne MRF, p_gee = GEE), data_processed/modellauswahl/joint_models.rds

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(mgcv))

WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
cv <- model_covariates()
kw <- merge(readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES],
            cv[, .(ags, kt, z_sgb2, z_p65, z_ltour)], by = "ags")
TERMS <- c(ktT2_staedtisch = "T2", ktT3_laendl_Verdichtung = "T3", ktT4_duenn_besiedelt = "T4")

# Kreis-Nachbarschaft (16_spatial.R) fuer MRF und Moran's I
nbo <- readRDS(file.path(DIR_CLEAN, "kreis_nb.rds"))
nbl <- setNames(lapply(nbo$nb, as.integer), nbo$ags)
W <- matrix(0, 400, 400); for (i in seq_along(nbo$nb)) W[i, nbo$nb[[i]]] <- 1 / length(nbo$nb[[i]])
set.seed(20261121); PERM <- replicate(999, sample.int(400))
moran <- function(x) {
  z <- x - mean(x); den <- sum(z^2); I <- sum(z * (W %*% z)) / den; P <- matrix(z[PERM], 400)
  c(I = I, p = (1 + sum(colSums(P * (W %*% P)) / den >= I)) / (ncol(PERM) + 1))
}
K_MRF <- 100

SP  <- "s(ags, bs = 're') + s(ags_m, bs = 'mrf', k = K_MRF, xt = list(nb = nbl))"
FIX <- "grp:state + grp:(z_sgb2 + z_p65 + z_ltour)"
FORMS <- list(
  int      = as.formula(paste("cases ~ grp + grp:kt +", FIX, "+", SP, "+ offset(lpop)")),
  const    = as.formula(paste("cases ~ grp + kt +", FIX, "+", SP, "+ offset(lpop)")),
  int_re   = as.formula(paste("cases ~ grp + grp:kt + grp:(z_sgb2 + z_p65 + z_ltour) + s(state, bs = 're') +",
                              "s(state, grp, bs = 're') +", SP, "+ offset(lpop)")),
  int_nosp = as.formula(paste("cases ~ grp + grp:kt +", FIX, "+ s(ags, bs = 're') + offset(lpop)")))
F_GEE <- as.formula(paste("cases ~ grp + grp:kt +", FIX, "+ offset(lpop)"))

# bam speichert am Ende Devianzresiduen als sqrt(dev.resids); bei Zellen mit 0 Faellen wird dev.resids numerisch
# minimal negativ -> Warnung "NaNs produced". Tritt auch bei ganzzahligen Fallzahlen auf und betrifft nur diese
# gespeicherten Residuen, nicht die Schaetzung; nur diese eine Warnung wird unterdrueckt.
fit_bam <- function(f, d) withCallingHandlers(
  bam(f, data = d, family = nb(), method = "fREML", discrete = TRUE, nthreads = 1),
  warning = function(w) if (conditionMessage(w) == "NaNs produced") invokeRestart("muffleWarning"))

kt_coefs <- function(m, V = vcov(m)) {
  b <- coef(m); i <- grep("^grp.+:kt", names(b)); V <- V[i, i]
  nm <- names(b)[i]
  data.table(grp = sub("^grp(.+):kt.*$", "\\1", nm), term = TERMS[sub("^grp.+:(kt.*)$", "\\1", nm)],
             est = b[i], se = sqrt(diag(V)), coef = nm)
}
# Wald-Test: Kreistyp-Effekt in allen Altersgruppen gleich (Differenzen zur ersten Altersgruppe)
wald_equal <- function(m, terms, V = vcov(m)) {
  b <- coef(m); k <- kt_coefs(m)[term %in% terms]
  C <- do.call(rbind, lapply(terms, function(t) {
    x <- k[term == t]; ref <- match(x$coef[x$grp == GR_COARSE[1]], names(b))
    t(vapply(x$coef[x$grp != GR_COARSE[1]], function(cn) { r <- numeric(length(b)); r[match(cn, names(b))] <- 1; r[ref] <- -1; r },
             numeric(length(b))))
  }))
  cb <- C %*% b; chi2 <- as.numeric(t(cb) %*% solve(C %*% V %*% t(C), cb))
  data.table(chi2 = chi2, df = nrow(C), p = pchisq(chi2, nrow(C), lower.tail = FALSE))
}
wald_all <- function(m, V = vcov(m)) rbind(wald_equal(m, TERMS, V)[, test := "alle Typen"],
                                           rbindlist(lapply(TERMS, function(t) wald_equal(m, t, V)[, test := t])))
# Moran's I der Kreis-Residuen: Pearson-Residuen je Kreis ueber die Altersgruppen gemittelt
moran_kreis <- function(m, d) {
  r <- data.table(ags = as.character(d$ags), r = residuals(m, "pearson"))[, .(r = mean(r)), by = ags]
  moran(r[match(nbo$ags, ags), r])
}

coefs <- list(); tests <- list()
for (w in WAVES) {
  d <- as.data.frame(kw[phase == w])
  d$grp <- factor(d$grp, GR_COARSE); d$state <- factor(d$state); d$ags <- factor(d$ags); d$lpop <- log(d$pop_rki)
  d$ags_m <- factor(as.character(d$ags), levels = nbo$ags)             # gleiche Reihenfolge wie die Nachbarschaft
  t0 <- Sys.time()
  m <- lapply(FORMS, fit_bam, d = d)
  for (sp in c("int", "int_re", "int_nosp")) coefs[[length(coefs) + 1]] <- kt_coefs(m[[sp]])[, `:=`(wave = w, spec = sp)]
  gee <- glm(F_GEE, family = quasipoisson, data = d)
  Vg <- sandwich::vcovCL(gee, cluster = d$ags, type = "HC0")
  coefs[[length(coefs) + 1]] <- kt_coefs(gee, Vg)[, `:=`(wave = w, spec = "gee")]
  te <- wald_all(m$int)
  te[, `:=`(p_nosp = wald_all(m$int_nosp)$p, p_gee = wald_all(gee, Vg)$p)]
  invisible(capture.output(vc <- gam.vcomp(m$int, conf.lev = .95)))      # gam.vcomp druckt sonst
  vc <- if (is.list(vc)) vc$vc else vc
  mi <- moran_kreis(m$int, d); mi0 <- moran_kreis(m$int_nosp, d)
  tests[[length(tests) + 1]] <- te[, `:=`(wave = w, dAIC_const = AIC(m$const) - AIC(m$int),
                                          dAIC_re = AIC(m$int_re) - AIC(m$int), dAIC_nosp = AIC(m$int_nosp) - AIC(m$int),
                                          theta = m$int$family$getTheta(TRUE), sd_kreis = vc["s(ags)", "std.dev"],
                                          edf_mrf = sum(m$int$edf[grepl("ags_m", names(m$int$edf))]),
                                          I_resid = mi[["I"]], p_I_resid = mi[["p"]], I_resid_nosp = mi0[["I"]], p_I_resid_nosp = mi0[["p"]])]
  cat(sprintf("%s: %.0f s | Wald (Kreistyp x Alter, df 18) p = %.2g (ohne MRF %.2g) | Moran I Kreis-Residuen %.2f (ohne MRF %.2f) | dAIC ohne MRF %.1f\n",
              w, as.numeric(difftime(Sys.time(), t0, units = "secs")), te[test == "alle Typen", p], te[test == "alle Typen", p_nosp],
              mi[["I"]], mi0[["I"]], AIC(m$int_nosp) - AIC(m$int)))
}
coefs <- rbindlist(coefs); tests <- rbindlist(tests)
coefs[, `:=`(irr = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se), coef = NULL)]

# Vergleich mit den getrennten Modellen (12, Hauptmodell m1)
sep <- fread(file.path(DIR_TAB, "model_nb_coef.csv"))[spec == "m1" & term %in% names(TERMS),
  .(wave, grp, term = TERMS[term], est_sep = estimate, se_sep = se)]
coefs <- merge(coefs, sep, by = c("wave", "grp", "term"), all.x = TRUE)
setcolorder(coefs, c("wave", "spec", "grp", "term", "est", "se", "irr", "lo", "hi", "est_sep", "se_sep"))
setorder(coefs, wave, spec, term, grp)
fwrite(coefs, file.path(DIR_TAB, "joint_kt_coef.csv"))
setcolorder(tests, c("wave", "test", "chi2", "df", "p", "p_nosp", "p_gee"))
fwrite(tests, file.path(DIR_TAB, "joint_tests.csv"))
saveRDS(list(coefs = coefs, tests = tests), file.path(DIR_CLEAN, "joint_models.rds"))

# ---- Zusammenfassung -------------------------------------------------------------------------
sig <- function(x) x[, lapply(.SD, function(v) if (is.numeric(v)) signif(v, 2) else v)]
cat("\n== Wald-Test: Kreistyp-Effekt in allen Altersgruppen gleich? (p-Werte, unkorrigiert; Hauptmodell mit MRF) ==\n")
print(sig(dcast(tests, wave ~ test, value.var = "p")))
cat("\n== Raeumliche Autokorrelation der Kreis-Residuen und AIC (positiv = Hauptmodell int besser) ==\n")
print(unique(tests[, .(wave, I_resid = round(I_resid, 2), p_I = signif(p_I_resid, 2), I_ohne_MRF = round(I_resid_nosp, 2),
                       p_I_ohne = signif(p_I_resid_nosp, 2), dAIC_nosp = round(dAIC_nosp, 1), dAIC_const = round(dAIC_const, 1),
                       dAIC_re = round(dAIC_re, 1), theta = round(theta), sd_kreis = round(sd_kreis, 3), edf_mrf = round(edf_mrf))]))
ci <- coefs[spec == "int"]
cmp <- function(s, lab) {
  x <- merge(ci[, .(wave, grp, term, e1 = est, s1 = se)], coefs[spec == s, .(wave, grp, term, e2 = est, s2 = se)], by = c("wave", "grp", "term"))
  cat(sprintf("%-40s Korrelation %.3f | mittlere |Differenz| %.3f | SE-Verhaeltnis (Median) %.2f\n", lab,
              cor(x$e1, x$e2), mean(abs(x$e1 - x$e2)), median(x$s2 / x$s1)))
}
cat("\n== Kreistyp-log-IRR: Hauptmodell (mit MRF) im Vergleich ==\n")
cat(sprintf("%-40s Korrelation %.3f | mittlere |Differenz| %.3f | SE-Verhaeltnis (Median) %.2f\n", "getrennte Modelle (12, m1)",
            cor(ci$est, ci$est_sep), mean(abs(ci$est - ci$est_sep)), median(ci$se_sep / ci$se)))
cmp("int_nosp", "ohne raeumlichen Effekt"); cmp("int_re", "Bundesland als Random Effect"); cmp("gee", "GEE (unabhaengig, robust)")
cat("signifikante Kreistyp-Koeffizienten (von 168): mit MRF", sum(ci$lo > 1 | ci$hi < 1), "| ohne MRF",
    coefs[spec == "int_nosp", sum(lo > 1 | hi < 1)], "\n")
cat("\nWald-Test ohne MRF und GEE (alle Typen):\n")
print(sig(tests[test == "alle Typen", .(wave, p, p_nosp, p_gee)]))
cat("\nIRR Typ 4 vs. Grossstadt je Altersgruppe (Hauptmodell; * = 95 %-KI ohne 1):\n")
x <- ci[term == "T4"][, lab := sprintf("%.2f%s", irr, fifelse(lo > 1 | hi < 1, "*", ""))]
print(dcast(x, grp ~ wave, value.var = "lab")[match(GR_COARSE, grp)])
