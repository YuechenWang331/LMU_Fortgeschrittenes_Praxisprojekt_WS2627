# Sensitivitaetsanalyse: Faelle ohne Altersangabe proportional auf die Altersjahre verteilen.
# Je Kreis x Woche werden die Faelle ohne Alter (covid_age_unknown.rds) nach der Altersverteilung
# der Faelle mit bekanntem Alter derselben Kreis-Woche verteilt. Wochen ohne bekannte Faelle: nicht verteilbar.
# Seit 21.11.2026 ist die Verteilung Teil der Hauptanalyse (02_clean_covid.R); dieses Skript vergleicht mit cases_obs.
# Danach Hauptmodell m1 (wie 12_models_wave_age.R, grobes Schema) neu und Vergleich der Kreistyp-IRR.
# Ausgabe: results/modellauswahl/tables/sens_age_unknown_coef.csv, sens_age_unknown_kreis.csv

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(MASS))

cov   <- readRDS(file.path(DIR_CLEAN, "covid_long.rds"))
unk   <- readRDS(file.path(DIR_CLEAN, "covid_age_unknown.rds"))
wv    <- readRDS(file.path(DIR_CLEAN, "waves.rds"))
const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
WAVES <- wv$phases[type == "Welle", id]

# ---- 1. Verteilen ------------------------------------------------------------------------------
tot <- cov[, .(known = sum(cases_obs)), by = .(ags, week)]      # cases_obs = ohne Verteilung (02_clean_covid.R)
u <- merge(unk[, .(ags, week, unk = cases)], tot, by = c("ags", "week"), all.x = TRUE)
cat("Faelle ohne Alter:", sum(u$unk), " davon nicht verteilbar (keine bekannten Faelle in der Woche):",
    sum(u[is.na(known) | known == 0, unk]), "\n")
d <- merge(cov[, .(ags, age_num, week, cases = cases_obs, pop)], u[known > 0, .(ags, week, unk, known)],
           by = c("ags", "week"), all.x = TRUE)
d[, cases_adj := cases + fifelse(is.na(unk), 0, unk * cases / known)]
stopifnot(abs(sum(d$cases_adj) - sum(d$cases) - sum(u[known > 0, unk])) < 1e-3)

# ---- 2. Kreis x Welle x grobe Altersgruppe -----------------------------------------------------
d <- merge(d, wv$week_phase, by = "week")[phase %in% WAVES]
d[, grp := age_group(age_num, "coarse")]
kw <- d[, .(cases = sum(cases), cases_adj = sum(cases_adj), pop = sum(pop)), by = .(ags, phase, grp, week)][
  , .(cases = sum(cases), cases_adj = sum(cases_adj), pop_rki = mean(pop)), by = .(ags, phase, grp)]
kreis_chg <- kw[, .(cases = sum(cases), cases_adj = sum(cases_adj)), by = .(ags, phase)][
  , anstieg_pct := round((cases_adj / cases - 1) * 100, 2)][order(-anstieg_pct)]
kreis_chg <- merge(kreis_chg, const[, .(ags, name_rki, kreistyp_code)], by = "ags")[order(-anstieg_pct)]
cat("\nGroesste Aenderungen (Kreis x Welle):\n"); print(head(kreis_chg, 8))
fwrite(kreis_chg, file.path(DIR_TAB, "sens_age_unknown_kreis.csv"))

# ---- 3. Hauptmodell m1 mit und ohne Verteilung -------------------------------------------------
cv <- merge(model_covariates()[, .(ags, kt, z_sgb2, z_p65, z_ltour)],     # Kovariaten wie in 12 (00_setup.R)
            const[, .(ags, state = factor(state))], by = "ags")
kw <- merge(kw, cv, by = "ags")
res <- rbindlist(lapply(WAVES, function(w) rbindlist(lapply(GR_COARSE, function(g) {
  x <- kw[phase == w & grp == g]
  rbindlist(lapply(c("cases", "cases_adj"), function(y) {
    f <- as.formula(paste(y, "~ kt + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki))"))
    s <- summary(quiet_nonint(glm.nb(f, data = x, control = glm.control(maxit = 100))))$coefficients
    s <- s[grepl("^kt", rownames(s)), , drop = FALSE]
    data.table(wave = w, grp = g, version = y, term = rownames(s), est = s[, 1], se = s[, 2])
  }))
}))))
cmp <- dcast(res, wave + grp + term ~ version, value.var = c("est", "se"))
cmp[, `:=`(irr = round(exp(est_cases), 3), irr_adj = round(exp(est_cases_adj), 3),
           diff_logirr = round(est_cases_adj - est_cases, 4),
           sig = abs(est_cases / se_cases) > 1.96, sig_adj = abs(est_cases_adj / se_cases_adj) > 1.96)]
fwrite(cmp[, .(wave, grp, term, irr, irr_adj, diff_logirr, sig, sig_adj)], file.path(DIR_TAB, "sens_age_unknown_coef.csv"))

cat("\n== Aenderung der Kreistyp-log-IRR (m1, grob) ==\n")
cat("mittel |diff|:", round(mean(abs(cmp$diff_logirr)), 4), " max |diff|:", max(abs(cmp$diff_logirr)), "\n")
print(cmp[, .(mittel_abs = round(mean(abs(diff_logirr)), 4), max_abs = max(abs(diff_logirr))), by = wave])
cat("Signifikanz (95 %) geaendert in", sum(cmp$sig != cmp$sig_adj), "von", nrow(cmp), "Koeffizienten\n")
print(cmp[sig != sig_adj | abs(diff_logirr) > .01, .(wave, grp, term, irr, irr_adj, sig, sig_adj)])
