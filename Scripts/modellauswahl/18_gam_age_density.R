# Bevoelkerungsdichte x Alter als glatte Flaeche (Tensorprodukt-Glaetter; Statistik V "Glaettung in z1- und
# z2-Richtung", Tensorprodukte). Daten wie 13_gam_age.R: Kreis x Einzelalter (0-79) x Welle, NB, Kreis-Zufallseffekt.
#   surf : cases ~ agef + s(z_ld) + ti(age, z_ld) + Kovariaten + Kreis-RE + offset
#          s(z_ld) = Haupteffekt der (log-)Dichte, nicht-linear; ti() = Wechselwirkung Alter x Dichte ohne
#          Haupteffekte (agef nimmt das bundesweite Altersprofil auf, wie in 13).
#   dens : cases ~ agef + s(age, by = z_ld) + ...     (wie 13: Effekt linear in log-Dichte, Steigung glatt im Alter)
#   kt   : cases ~ ktO + agef + s(age, by = ktO) + ...  (wie 13: vier BBSR-Kreistypen)
# Fragen: Braucht der Dichteeffekt eine nicht-lineare Form (surf vs. dens)? Beschreibt die stetige Dichte die
# Inzidenz besser als die vier Kreistypen (surf/dens vs. kt)? -> Evidenz zur offenen Frage "Kreistyp oder Dichte".
# Vergleich ueber das konditionale AIC von mgcv (gleiche Daten, gleiche Kovariaten und Kreis-Zufallseffekte).
# Ausgabe: results/modellauswahl/tables/gam_surface_grid.csv (log-IRR je Alter x Dichte, relativ zum Kreis mit mittlerer Dichte),
#          gam_surface_contrast.csv (90. vs. 10. Perzentil der Dichte je Alter, surf und dens), gam_surface_tests.csv
# Braucht data_processed/modellauswahl/covid_wave_age.rds aus 13_gam_age.R.

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(mgcv))

WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
# Basisdimensionen: by-Glaetter wie 13; Dichte-Haupteffekt; Tensor (Alter, Dichte).
# Pruefung K_TI (W3, W5, W8; 21.11.2026): edf des Tensors steigt mit k weiter (10x6: 35-40 von 45; 15x8: 62-77 von 98;
# 20x10: 84-109 von 171), das AIC sinkt weiter. Die Kontrastkurve 90./10. Perzentil aendert sich von 10x6 auf 15x8
# um bis zu 0,07, von 15x8 auf 20x10 nur noch um bis zu 0,026 (log-IRR) -> 15x8. Die Flaeche kann bei hoher
# Flexibilitaet auch kreisspezifische Altersprofile aufnehmen (Dichte ist ein Kreismerkmal); siehe Doku.
K_BY <- 15; K_Z <- 8; K_TI <- c(15, 8)
KTL  <- c("T1", "T2", "T3", "T4")

const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
cv <- merge(model_covariates()[, .(ags, kreistyp_code, dichte_mean, z_ld = z_ldichte, z_sgb2, z_p65, z_ltour)],
            const[, .(ags, state)], by = "ags")
dat <- readRDS(file.path(DIR_CLEAN, "covid_wave_age.rds"))[age_num <= 79 & phase %in% WAVES]
dat <- merge(dat, cv[, .(ags, state, kreistyp_code, z_ld, z_sgb2, z_p65, z_ltour)], by = "ags")
dat[, `:=`(age = as.numeric(age_num), agef = factor(age_num), lpop = log(pop_rki))]

COV <- GAM_COV   # Scripts/modellauswahl/00_setup.R: Bundesland und Kovariaten altersspezifisch wie in 13 (seit 24.11.2026)
FORMS <- list(
  kt   = sprintf("cases ~ ktO + agef + s(age, by = ktO, k = %d) + %s + offset(lpop)", K_BY, COV),
  dens = sprintf("cases ~ agef + s(age, by = z_ld, k = %d) + %s + offset(lpop)", K_BY, COV),
  surf = sprintf("cases ~ agef + s(z_ld, k = %d) + ti(age, z_ld, k = c(%d, %d)) + %s + offset(lpop)", K_Z, K_TI[1], K_TI[2], COV))
fit_gam <- function(f, d) withCallingHandlers(           # Warnung "NaNs produced": siehe 17_joint_age_models.R
  bam(as.formula(f), data = d, family = nb(), method = "fREML", discrete = TRUE, nthreads = 1),
  warning = function(w) if (conditionMessage(w) == "NaNs produced") invokeRestart("muffleWarning"))

# Dichte-Raster: 5. bis 95. Perzentil der Kreise; Referenz = Median-Kreis; Kontrast 90. vs. 10. Perzentil
z_ref <- median(cv$z_ld); z_p10 <- quantile(cv$z_ld, .10, names = FALSE); z_p90 <- quantile(cv$z_ld, .90, names = FALSE)
z_grid <- seq(quantile(cv$z_ld, .05), quantile(cv$z_ld, .95), length.out = 25)
to_dichte <- function(z) exp(mean(log(cv$dichte_mean)) + z * sd(log(cv$dichte_mean)))   # z -> Einwohner/km2
ages <- 0:79

# Differenz des linearen Praediktors zwischen zwei Dichtewerten je Alter (alle anderen Terme heben sich auf)
contrast <- function(fit, d, z1, z0) {
  nd <- function(z) data.frame(age = ages, agef = factor(ages, levels = levels(d$agef)), z_ld = z,
                               ktO = factor("T1", levels = KTL, ordered = TRUE),
                               state = factor(levels(d$state)[1], levels = levels(d$state)),
                               z_sgb2 = 0, z_p65 = 0, z_ltour = 0, ags = factor(levels(d$ags)[1], levels = levels(d$ags)), lpop = 0)
  D <- predict(fit, nd(z1), type = "lpmatrix", discrete = FALSE) - predict(fit, nd(z0), type = "lpmatrix", discrete = FALSE)
  V <- vcov(fit, unconditional = TRUE)
  data.table(age = ages, est = as.numeric(D %*% coef(fit)), se = sqrt(rowSums((D %*% V) * D)))
}

grid <- list(); ctr <- list(); tests <- list()
for (w in WAVES) {
  d <- as.data.frame(dat[phase == w])
  d$ags <- factor(d$ags); d$state <- factor(d$state)
  d$ktO <- factor(KTL[d$kreistyp_code], levels = KTL, ordered = TRUE); contrasts(d$ktO) <- contr.treatment(KTL)
  t0 <- Sys.time()
  m <- lapply(FORMS, fit_gam, d = d)
  grid[[w]] <- rbindlist(lapply(z_grid, function(z) contrast(m$surf, d, z, z_ref)[, z_ld := z]))[, wave := w]
  ctr[[w]] <- rbind(contrast(m$surf, d, z_p90, z_p10)[, spec := "surf"], contrast(m$dens, d, z_p90, z_p10)[, spec := "dens"])[, wave := w]
  st <- as.data.table(summary(m$surf)$s.table, keep.rownames = "smooth")[grepl("z_ld", smooth)]
  a <- vapply(m, AIC, numeric(1))
  tests[[w]] <- data.table(wave = w, edf_s_dichte = st[smooth == "s(z_ld)", edf], p_s_dichte = st[smooth == "s(z_ld)", `p-value`],
                           edf_ti = st[grepl("^ti", smooth), edf], p_ti = st[grepl("^ti", smooth), `p-value`],
                           aic_kt = a[["kt"]], aic_dens = a[["dens"]], aic_surf = a[["surf"]])
  cat(sprintf("%s: %.0f s | AIC kt %.0f, dens %.0f, surf %.0f | ti(Alter, Dichte): edf %.1f, p = %.2g\n", w,
              as.numeric(difftime(Sys.time(), t0, units = "secs")), a[["kt"]], a[["dens"]], a[["surf"]],
              tests[[w]]$edf_ti, tests[[w]]$p_ti))
}
grid <- rbindlist(grid); ctr <- rbindlist(ctr); tests <- rbindlist(tests)
grid[, `:=`(dichte = to_dichte(z_ld), irr = exp(est))]
ctr[, `:=`(irr = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se))]
tests[, `:=`(dAIC_dens_surf = aic_dens - aic_surf, dAIC_kt_surf = aic_kt - aic_surf, dAIC_kt_dens = aic_kt - aic_dens)]
fwrite(grid[, .(wave, age, z_ld = round(z_ld, 4), dichte = round(dichte, 1), est = round(est, 5), se = round(se, 5), irr = round(irr, 4))],
       file.path(DIR_TAB, "gam_surface_grid.csv"))
fwrite(ctr[, .(wave, spec, age, est = round(est, 5), se = round(se, 5), irr = round(irr, 4), lo = round(lo, 4), hi = round(hi, 4))],
       file.path(DIR_TAB, "gam_surface_contrast.csv"))
fwrite(tests, file.path(DIR_TAB, "gam_surface_tests.csv"))

cat(sprintf("\nDichte: Median-Kreis %.0f, 10. Perzentil %.0f, 90. Perzentil %.0f Einwohner/km2\n",
            to_dichte(z_ref), to_dichte(z_p10), to_dichte(z_p90)))
cat("\n== Modellvergleich (konditionales AIC; positiv = zweites Modell besser) ==\n")
print(tests[, .(wave, dAIC_dens_surf = round(dAIC_dens_surf, 1), dAIC_kt_surf = round(dAIC_kt_surf, 1),
                dAIC_kt_dens = round(dAIC_kt_dens, 1), edf_s_dichte = round(edf_s_dichte, 1),
                edf_ti = round(edf_ti, 1), p_ti = signif(p_ti, 2))])
cat("\n== IRR 90. vs. 10. Perzentil der Dichte (Flaeche surf; * = 95 %-KI ohne 1) an ausgewaehlten Altern ==\n")
x <- ctr[spec == "surf" & age %in% c(3, 10, 16, 25, 40, 55, 70, 79)][, lab := sprintf("%.2f%s", irr, fifelse(lo > 1 | hi < 1, "*", ""))]
print(dcast(x, age ~ wave, value.var = "lab"))
