# GAM mit Alter in Einzeljahren (0-79): je Welle ein Negativbinomial-Modell
#   cases ~ Alter (Faktor) + Raummass + s(age, by = Raummass) + Bundesland + s(age, by = Bundesland)
#           + s(age, by = SGB-II) + s(age, by = 65+) + s(age, by = Tourismus) + Kreis-Zufallseffekt + Offset
# Das Raummass wirkt dadurch altersabhaengig (glatt in Einzeljahren), ohne Altersgruppen vorab festzulegen.
# Aenderung 24.11.2026: Bundesland und Kovariaten wirken wie im Hauptmodell (22_main_model_tmb.R) altersspezifisch
# (GAM_COV in Scripts/modellauswahl/00_setup.R). Vorher hatten sie in allen Altersjahren dieselbe Wirkung; altersspezifische
# Unterschiede zwischen den Laendern (z.B. Schultests) konnten so in die Raumtyp-Kurven geraten.
# Alters-Haupteffekt als Faktor (Aenderung 21.11.2026): er beschreibt nur das bundesweite Altersprofil (Stoerparameter,
# mit Spruengen z.B. an Schulaltersgrenzen). Der fruehere Glaetter s(age, k = 25) war ausgeschoepft (edf ~ k - 1,
# edf stieg mit k weiter); als Faktor passt das Modell deutlich besser (AIC), die Raumeffekt-Kurven aendern sich
# dabei um hoechstens ca. 0,002 (log-IRR). Geglaettet werden nur die Differenzen zwischen Raumtypen (by-Glaetter).
# 80+ ist in den Daten eine Sammelgruppe und wird hier nicht modelliert (siehe Gruppenmodelle in 12_models_wave_age.R).
# Kreis-Zufallsachsenabschnitt (400 Stufen): die Einzeljahre eines Kreises sind nicht unabhaengig; der Raumtyp wird
# zwischen Kreisen geschaetzt, die Standardfehler beruecksichtigen die Streuung zwischen den Kreisen.
#   kt_rki : Raumtyp (BBSR-Kreistyp, Referenz Grossstadt) x Alter, RKI-Nenner      (Hauptmodell)
#   kt_gen : wie kt_rki mit GENESIS-skaliertem Nenner                              (Sensitivitaet)
#   kt_const: Raumtyp mit konstantem Effekt ueber das Alter                        (Vergleichsmodell)
#   dens   : log(Dichte), standardisiert, x Alter                                  (Robustheit)
#            nur s(age, by = z_ld) ohne zusaetzliches z_ld: ein Glaetter mit numerischer by-Variable wird in mgcv
#            nicht zentriert und enthaelt den linearen Haupteffekt von z_ld schon (sonst doppelt, nicht identifizierbar).
# Ausgabe: data_processed/modellauswahl/covid_wave_age.rds, data_processed/modellauswahl/gam_age_curves.rds, results/modellauswahl/tables/gam_age_*.csv
# Umgebungsvariablen:
#   WAVES_RUN="W5"  beschraenkt auf einzelne Wellen (Test; Ausgabedateien mit Suffix, z.B. gam_age_curves_W5.rds)
#   BOOT_B=100      Kreis-Bootstrap mit 100 Wiederholungen (0 = aus, Standard)
#   BOOT_CORES=4    Anzahl paralleler R-Prozesse fuer den Bootstrap (Standard: alle Kerne - 1; Windows: 1)
# Die Bootstrap-Stichproben werden vorab seriell gezogen; das Ergebnis haengt daher nicht von BOOT_CORES ab.

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(mgcv))

wv    <- readRDS(file.path(DIR_CLEAN, "waves.rds"))
const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
ALL_WAVES <- wv$phases[type == "Welle", id]
WAVES <- ALL_WAVES
wr <- Sys.getenv("WAVES_RUN", ""); if (nzchar(wr)) WAVES <- intersect(WAVES, strsplit(wr, ",")[[1]])
BOOT_B <- as.integer(Sys.getenv("BOOT_B", "0"))   # Anzahl Kreis-Bootstrap-Wiederholungen (0 = aus)
BOOT_CORES <- as.integer(Sys.getenv("BOOT_CORES",
  if (.Platform$OS.type == "windows") "1" else max(1L, parallel::detectCores() - 1L)))
K_BY  <- 15   # Basisdimension der Differenzglaetter (Raumeffekt x Alter)

# ---- 1. Daten: Kreis x Einzelalter x Welle ----------------------------------------------------------
# Wird bei jedem Lauf neu gebildet (wenige Sekunden), damit geaenderte Wellengrenzen (waves.rds) sicher ankommen.
f_data <- file.path(DIR_CLEAN, "covid_wave_age.rds")
cov <- readRDS(file.path(DIR_CLEAN, "covid_long.rds"))
adj <- readRDS(file.path(DIR_CLEAN, "pop_genesis_adj.rds"))
d <- merge(cov[, .(ags, age_num, week, year, cases, pop_rki = pop)], adj[, .(ags, age_num, year, pop_gen)],
           by = c("ags", "age_num", "year"))
rm(cov, adj)
d <- merge(d, wv$week_phase, by = "week")
d <- d[phase %in% ALL_WAVES,
       .(cases = sum(cases), pop_rki = mean(pop_rki), pop_gen = mean(pop_gen), n_weeks = .N), by = .(ags, age_num, phase)]
saveRDS(d, f_data)
cat("gespeichert:", f_data, " Zeilen:", nrow(d), "\n")
dat <- d[age_num <= 79]
rm(d)

z <- function(x) as.numeric(scale(x))
cv <- const[, .(ags, state, kreistyp_code, dichte_mean, sgb2 = sgb2_je1000_mean, p65 = anteil_65p_mean,
                tour = uebernachtungen_je_einw_mean)]
cv[, `:=`(z_ld = z(log(dichte_mean)), z_sgb2 = z(sgb2), z_p65 = z(p65), z_ltour = z(log(tour)))]
KTL <- c("T1", "T2", "T3", "T4")
cv[, ktO := factor(KTL[kreistyp_code], levels = KTL, ordered = TRUE)]
contrasts(cv$ktO) <- contr.treatment(KTL)
cv[, `:=`(state = factor(state), ags = factor(ags))]
dat <- merge(dat, cv[, .(ags, state, ktO, z_ld, z_sgb2, z_p65, z_ltour)], by = "ags")
dat[, `:=`(age = as.numeric(age_num), agef = factor(age_num))]
# merge() verliert das contrasts-Attribut -> neu setzen
dat[, ktO := factor(as.character(ktO), levels = KTL, ordered = TRUE)]
contrasts(dat$ktO) <- contr.treatment(KTL)

COV <- GAM_COV   # Scripts/modellauswahl/00_setup.R: Bundesland und Kovariaten altersspezifisch (seit 24.11.2026)
FORMS <- list(
  kt_rki   = sprintf("cases ~ ktO + agef + s(age, by = ktO, k = %d) + %s + offset(lpop_rki)", K_BY, COV),
  kt_gen   = sprintf("cases ~ ktO + agef + s(age, by = ktO, k = %d) + %s + offset(lpop_gen)", K_BY, COV),
  kt_const = sprintf("cases ~ ktO + agef + %s + offset(lpop_rki)", COV),
  dens     = sprintf("cases ~ agef + s(age, by = z_ld, k = %d) + %s + offset(lpop_rki)", K_BY, COV)
)

# nthreads = 1: OpenMP fehlt in vielen R-Installationen (z.B. macOS-Standard-R), dann bringt nthreads > 1 nichts
# ausser Warnungen. Parallelisiert wird stattdessen der Bootstrap ueber Prozesse (BOOT_CORES).
fit_gam <- function(spec, d) {
  t0 <- Sys.time()
  fit <- bam(as.formula(FORMS[[spec]]), data = d, family = nb(), method = "fREML", discrete = TRUE, nthreads = 1)
  attr(fit, "secs") <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  fit
}

# Altersabhaengiges log-Inzidenzverhaeltnis aus der Design-Matrix (Differenz zur Referenz), inkl. punktweiser KI
curve_kt <- function(fit, d, level) {
  ages <- 0:79
  nd <- function(l) data.frame(age = ages, agef = factor(ages, levels = levels(d$agef)),
                               ktO = factor(l, levels = KTL, ordered = TRUE), state = factor(levels(d$state)[1], levels = levels(d$state)),
                               z_sgb2 = 0, z_p65 = 0, z_ltour = 0, ags = factor(levels(d$ags)[1], levels = levels(d$ags)),
                               lpop_rki = 0, lpop_gen = 0)
  n1 <- nd("T1"); nk <- nd(level)
  n1$ktO <- factor("T1", levels = KTL, ordered = TRUE); contrasts(n1$ktO) <- contr.treatment(KTL)
  nk$ktO <- factor(level, levels = KTL, ordered = TRUE); contrasts(nk$ktO) <- contr.treatment(KTL)
  X1 <- predict(fit, n1, type = "lpmatrix", discrete = FALSE)
  Xk <- predict(fit, nk, type = "lpmatrix", discrete = FALSE)
  D <- Xk - X1
  b <- coef(fit); V <- vcov(fit, unconditional = TRUE)
  est <- as.numeric(D %*% b); se <- sqrt(rowSums((D %*% V) * D))
  data.table(age = ages, est = est, se = se)
}
curve_dens <- function(fit, d) {
  ages <- 0:79
  nd <- function(zv) data.frame(age = ages, agef = factor(ages, levels = levels(d$agef)),
                                z_ld = zv, state = factor(levels(d$state)[1], levels = levels(d$state)),
                                z_sgb2 = 0, z_p65 = 0, z_ltour = 0, ags = factor(levels(d$ags)[1], levels = levels(d$ags)),
                                lpop_rki = 0, lpop_gen = 0)
  D <- predict(fit, nd(1), type = "lpmatrix", discrete = FALSE) - predict(fit, nd(0), type = "lpmatrix", discrete = FALSE)
  b <- coef(fit); V <- vcov(fit, unconditional = TRUE)
  data.table(age = ages, est = as.numeric(D %*% b), se = sqrt(rowSums((D %*% V) * D)))
}

# Kreis-Cluster-Bootstrap (gezogen innerhalb der Bundeslaender): beruecksichtigt, dass die Einzeljahre eines Kreises
# nicht unabhaengig sind (Kreis x Alter-Struktur); liefert Standardabweichung und Perzentil-KI der Kurven.
# Die Stichproben werden vorab seriell gezogen (gleiche Zufallsfolge wie frueher in der Schleife), die Modelle dann
# parallel geschaetzt (Prozess-Forking; unter Windows seriell).
boot_wave <- function(d0, B, cores = BOOT_CORES) {
  rows_of <- split(seq_len(nrow(d0)), d0$ags)
  kr <- unique(d0[, c("ags", "state")]); kr$ags <- as.character(kr$ags)
  by_state <- split(kr$ags, kr$state)
  samps <- lapply(seq_len(B), function(b)
    unlist(lapply(by_state, function(a) a[sample.int(length(a), length(a), replace = TRUE)]), use.names = FALSE))
  one_rep <- function(b) {
    samp <- samps[[b]]
    ids <- rows_of[samp]
    db <- d0[unlist(ids, use.names = FALSE), ]
    db$ags <- factor(rep(seq_along(samp), times = lengths(ids)))
    db$state <- factor(db$state)
    r <- tryCatch({
      fk <- fit_gam("kt_rki", db); fd <- fit_gam("dens", db)
      rbind(rbindlist(lapply(KTL[-1], function(lv) curve_kt(fk, db, lv)[, term := lv])),
            curve_dens(fd, db)[, term := "z_ld"])
    }, error = function(e) NULL)
    if (!is.null(r)) r[, rep := b]
    r
  }
  est <- if (cores > 1) parallel::mclapply(seq_len(B), one_rep, mc.cores = cores) else lapply(seq_len(B), one_rep)
  ok <- vapply(est, is.data.table, logical(1))
  if (!all(ok)) cat(sprintf("  Bootstrap: %d von %d Wiederholungen fehlgeschlagen\n", sum(!ok), B))
  rbindlist(est[ok])
}

curves <- list(); tests <- list(); boots <- list(); binfo <- list()
for (w in WAVES) {
  d <- dat[phase == w]
  d[, `:=`(lpop_rki = log(pop_rki), lpop_gen = log(pop_gen))]
  d <- as.data.frame(d)                                  # mgcv arbeitet robuster mit data.frame
  d$ags <- factor(d$ags); d$state <- factor(d$state)     # Zufallseffekt und Fixed Effect brauchen Faktoren
  d$ktO <- factor(as.character(d$ktO), levels = KTL, ordered = TRUE); contrasts(d$ktO) <- contr.treatment(KTL)
  cat(sprintf("\n=== %s: n = %d Zeilen, %.0f Faelle ===\n", w, nrow(d), sum(d$cases)))
  fits <- list()
  for (sp in names(FORMS)) {
    fits[[sp]] <- fit_gam(sp, d)
    cat(sprintf("  %-9s %5.1f s  theta = %6.1f  Dev.erkl. = %.3f  AIC = %.0f\n", sp, attr(fits[[sp]], "secs"),
                fits[[sp]]$family$getTheta(TRUE), summary(fits[[sp]])$dev.expl, AIC(fits[[sp]])))
  }
  for (sp in c("kt_rki", "kt_gen")) for (lv in KTL[-1]) {
    cc <- curve_kt(fits[[sp]], d, lv)[, `:=`(wave = w, spec = sp, term = lv)]
    curves[[length(curves) + 1]] <- cc
    if (sp == "kt_rki" && lv == "T4") se_model_t4 <- cc$se        # Vergleich mit dem Bootstrap unten
  }
  curves[[length(curves) + 1]] <- curve_dens(fits$dens, d)[, `:=`(wave = w, spec = "dens", term = "z_ld")]
  if (BOOT_B > 0) {
    set.seed(20261121 + match(w, ALL_WAVES))   # Seed je Welle unabhaengig von WAVES_RUN
    t0 <- Sys.time()
    bt <- boot_wave(d, BOOT_B)
    bsum <- bt[, .(se_b = sd(est), lo_b = exp(quantile(est, .025)), hi_b = exp(quantile(est, .975)), nb = .N), by = .(term, age)]
    bsum[, `:=`(wave = w, spec = fifelse(term == "z_ld", "dens", "kt_rki"))]
    boots[[length(boots) + 1]] <- bsum
    binfo[[w]] <- data.table(wave = w, B = BOOT_B, n_ok = uniqueN(bt$rep))   # fuer Bildunterschriften (11_figures.R)
    cat(sprintf("  Bootstrap: %d Wiederholungen (%d Prozesse, %.0f s), mittleres SE-Verhaeltnis Bootstrap/Modell (kt_rki, T4): %.2f\n",
                BOOT_B, BOOT_CORES, as.numeric(difftime(Sys.time(), t0, units = "secs")),
                mean(bsum[term == "T4", se_b] / se_model_t4)))
  }
  # Tests: variiert der Effekt mit dem Alter? (Wald-Test der by-Glaetter) + AIC-Vergleich mit konstantem Effekt
  for (sp in c("kt_rki", "dens")) {
    st <- as.data.table(summary(fits[[sp]])$s.table, keep.rownames = "smooth")
    st <- st[grepl(":", smooth, fixed = TRUE) | grepl("by", smooth)]
    st <- st[grepl("ktO|z_ld", smooth)]
    tests[[length(tests) + 1]] <- st[, .(wave = w, spec = sp, smooth, edf = edf, F = F, p = `p-value`)]
  }
  tests[[length(tests) + 1]] <- data.table(wave = w, spec = "aic_kt", smooth = "AIC kt_const - kt_rki",
                                           edf = NA_real_, F = AIC(fits$kt_const) - AIC(fits$kt_rki), p = NA_real_)
  sa <- summary(fits$kt_rki)$s.table
  cat(sprintf("  edf by-Glaetter kt_rki: %s (max %d)\n",
              paste(round(sa[grep("ktO", rownames(sa)), "edf"], 1), collapse = "/"), K_BY - 1))
}
curves <- rbindlist(curves); tests <- rbindlist(tests)
curves[, `:=`(irr = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se))]
if (length(boots)) {
  boots <- rbindlist(boots)
  curves <- merge(curves, boots[, .(wave, spec, term, age, se_b, lo_b, hi_b)], by = c("wave", "spec", "term", "age"), all.x = TRUE)
}
setorder(curves, wave, spec, term, age)   # gleiche Zeilenfolge mit und ohne Bootstrap (Vergleich von Laeufen)
tag <- if (nzchar(wr)) paste0("_", gsub(",", "", wr)) else ""
# boot: Zahl der Bootstrap-Wiederholungen und davon erfolgreiche je Welle (NULL ohne Bootstrap)
saveRDS(list(curves = curves, tests = tests, boot = if (length(binfo)) rbindlist(binfo)),
        file.path(DIR_CLEAN, paste0("gam_age_curves", tag, ".rds")))
fwrite(curves[, intersect(c("wave", "spec", "term", "age", "est", "se", "irr", "lo", "hi", "se_b", "lo_b", "hi_b"), names(curves)), with = FALSE][,
       lapply(.SD, function(x) if (is.numeric(x)) round(x, 4) else x)],
       file.path(DIR_TAB, paste0("gam_age_curves", tag, ".csv")))
fwrite(tests, file.path(DIR_TAB, paste0("gam_age_tests", tag, ".csv")))
cat("\ngespeichert: gam_age_curves, gam_age_tests\n")
print(tests[spec != "aic_kt"][, .(wave, spec, smooth, edf = round(edf, 1), p = signif(p, 2))])
print(tests[spec == "aic_kt", .(wave, dAIC = round(F, 1))])
