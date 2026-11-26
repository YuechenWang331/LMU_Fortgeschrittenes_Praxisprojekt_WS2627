# Vergleich grobes (7 Gruppen) vs. feines (13 Gruppen) Altersschema (Klima: beide rechnen, am Ende vergleichen).
# Liest nur fertige Tabellen aus 09_urban_rural.R (deskriptiv) und 12_models_wave_age.R (NB-Modelle);
# es wird nichts neu geschaetzt. Die feinen Gruppen sind Teilmengen der groben:
#   0-5 = 0-2 + 3-5; 6-17 = 6-9 + 10-14 + 15-17; 18-39 = 18-24 + 25-29 + 30-39; 40-59 = 40-49 + 50-59;
#   60-69, 70-79 und 80+ sind in beiden Schemata identisch (Kontrolle: identische Schaetzer).
# Fragen:
#   1. Verdeckt eine grobe Gruppe unterschiedliche Raumeffekte ihrer Untergruppen?
#      -> je Welle x grober Gruppe x Kreistyp-Term: Spannweite der feinen IRR und Heterogenitaetstest (Cochran-Q)
#   2. Fuehren beide Schemata zu denselben Aussagen? -> Richtung und Signifikanz grob vs. fein
# Q-Test: behandelt die feinen Schaetzer als unabhaengig. Sie stammen aus denselben 400 Kreisen und sind
# positiv korreliert; die Varianz ihrer Differenzen ist dann kleiner als angenommen -> der Test ist eher
# konservativ (findet Heterogenitaet eher zu selten). p-Werte nicht fuer multiples Testen korrigiert.
# Ausgabe: results/modellauswahl/tables/scheme_compare_model.csv (je feiner Gruppe), scheme_compare_summary.csv
#          (je Welle x grober Gruppe x Term), scheme_compare_descr.csv (deskriptive Verhaeltnisse)

source("Scripts/modellauswahl/00_setup.R")

lo_f <- vapply(AGE_SCHEMES$fine, `[`, numeric(1), 1)
hi_f <- vapply(AGE_SCHEMES$fine, `[`, numeric(1), 2)
MAP  <- data.table(fine = GR_FINE, coarse = age_group(lo_f, "coarse"))
stopifnot(all(hi_f <= vapply(AGE_SCHEMES$coarse, `[`, numeric(1), 2)[MAP$coarse]))   # fein ist in grob verschachtelt
MAP[, n_sub := .N, by = coarse]
TERMS <- c(ktT2_staedtisch = "T2", ktT3_laendl_Verdichtung = "T3", ktT4_duenn_besiedelt = "T4")

# ---- 1. Modelle (Hauptmodell m1) -------------------------------------------------------------
rd <- function(f) fread(file.path(DIR_TAB, f))[spec == "m1" & term %in% names(TERMS)][, term := TERMS[term]]
mc <- rd("model_nb_coef.csv"); mf <- rd("model_nb_coef_fine.csv")

same <- merge(mc[grp %in% MAP[n_sub == 1, coarse]], mf, by = c("wave", "grp", "term"))
stopifnot(nrow(same) == 8 * 3 * 3, max(abs(same$estimate.x - same$estimate.y)) < 1e-8)

cmp <- merge(MAP, mf[, .(wave, fine = grp, term, est_f = estimate, se_f = se, irr_f = irr, lo_f = lo, hi_f = hi)], by = "fine")
cmp <- merge(cmp, mc[, .(wave, coarse = grp, term, est_c = estimate, se_c = se, irr_c = irr, lo_c = lo, hi_c = hi)],
             by = c("wave", "coarse", "term"))
cmp[, `:=`(sig_f = lo_f > 1 | hi_f < 1, sig_c = lo_c > 1 | hi_c < 1)]
cmp[, fine := factor(fine, GR_FINE)]
setorder(cmp, wave, term, fine)

sm <- cmp[n_sub > 1, {
  w <- 1 / se_f^2; m <- sum(w * est_f) / sum(w); Q <- sum(w * (est_f - m)^2)
  .(k = .N, irr_c = irr_c[1], sig_c = sig_c[1], irr_f_min = min(irr_f), irr_f_max = max(irr_f),
    spanne_log = max(est_f) - min(est_f), max_abw_log = max(abs(est_f - est_c)),
    Q = Q, p_Q = pchisq(Q, .N - 1, lower.tail = FALSE),
    n_sig_f = sum(sig_f),
    # Untergruppe signifikant in Gegenrichtung zum groben Schaetzer
    widerspruch = any(sig_f & sign(est_f) != sign(est_c[1])),
    # grob nicht signifikant, aber mindestens eine Untergruppe signifikant
    verdeckt = !sig_c[1] & any(sig_f),
    # grob signifikant, aber keine Untergruppe (meist nur geringere Fallzahl)
    verduennt = sig_c[1] & !any(sig_f))
}, by = .(wave, coarse, term)]

fwrite(cmp[, .(wave, coarse, fine, n_sub, term, irr_c, lo_c, hi_c, irr_f, lo_f, hi_f, est_c, se_c, est_f, se_f, sig_c, sig_f)],
       file.path(DIR_TAB, "scheme_compare_model.csv"))
fwrite(sm, file.path(DIR_TAB, "scheme_compare_summary.csv"))

# Likelihood-Ratio-Test des Raumtyps (3 Parameter) je Zelle: grob vs. feine Untergruppen
lr_c <- fread(file.path(DIR_TAB, "model_nb_fit.csv"))[spec == "m1", .(wave, coarse = grp, p_c = lr_kt_p)]
lr_f <- fread(file.path(DIR_TAB, "model_nb_fit_fine.csv"))[spec == "m1", .(wave, fine = grp, p_f = lr_kt_p)]
lr <- merge(merge(lr_f, MAP[n_sub > 1], by = "fine"), lr_c, by = c("wave", "coarse"))[
  , .(sig_c = p_c[1] < .05, n_sig_f = sum(p_f < .05), k = .N), by = .(wave, coarse)]

# ---- 2. Deskriptiv: Verhaeltnis Kreistyp / Bundeswert (aus 09) --------------------------------------
dc <- fread(file.path(DIR_TAB, "urban_kreistyp_wave_age.csv"))[, .(kreistyp, phase, coarse = grp, ratio_c = ratio)]
df <- fread(file.path(DIR_TAB, "urban_kreistyp_wave_age_fine.csv"))[, .(kreistyp, phase, fine = grp, ratio_f = ratio)]
de <- merge(merge(df, MAP[n_sub > 1], by = "fine"), dc, by = c("kreistyp", "phase", "coarse"))[grepl("^W", phase)]
ds <- de[, .(ratio_c = ratio_c[1], ratio_f_min = min(ratio_f), ratio_f_max = max(ratio_f),
             min_bei = fine[which.min(ratio_f)], max_bei = fine[which.max(ratio_f)],
             max_abw_log = max(abs(log(ratio_f / ratio_c))),
             richtung_wechselt = any(ratio_f > 1) & any(ratio_f < 1)), by = .(phase, kreistyp, coarse)]
fwrite(ds, file.path(DIR_TAB, "scheme_compare_descr.csv"))

# ---- Zusammenfassung -------------------------------------------------------------------------
cat("Kontrolle: 60-69, 70-79, 80+ in beiden Schemata identisch (", nrow(same), "Koeffizienten)\n")
cat("\n== Modelle: Welle x geteilte Gruppe x Term =", nrow(sm), "Zellen ==\n")
cat("Heterogenitaet der Untergruppen (Q-Test p < 0,05):", sum(sm$p_Q < .05), "von", nrow(sm),
    sprintf("(bei reinem Zufall ca. %.0f erwartet)\n", .05 * nrow(sm)))
cat("Widerspruch (Untergruppe signifikant in Gegenrichtung):", sum(sm$widerspruch), "\n")
cat("Verdeckt (grob n.s., Untergruppe signifikant):", sum(sm$verdeckt),
    "| verduennt (grob signifikant, keine Untergruppe):", sum(sm$verduennt), "\n")
cat("Spanne der feinen log-IRR innerhalb einer groben Gruppe: Median", round(median(sm$spanne_log), 3),
    "| max", round(max(sm$spanne_log), 3), "\n")
cat("Korrelation grob vs. gewichtetes Mittel der Untergruppen:",
    round(cmp[n_sub > 1, .(m = sum(est_f / se_f^2) / sum(1 / se_f^2), c = est_c[1]), by = .(wave, coarse, term)][, cor(m, c)], 3), "\n")
cat("\nHeterogene Zellen (p_Q < 0,05):\n")
print(sm[p_Q < .05, .(wave, coarse, term, irr_c = round(irr_c, 2), irr_f = sprintf("%.2f–%.2f", irr_f_min, irr_f_max),
                      p_Q = signif(p_Q, 2), widerspruch, verdeckt)][order(p_Q)])
cat("\nNach grober Gruppe:\n")
print(sm[, .(zellen = .N, heterogen = sum(p_Q < .05), verdeckt = sum(verdeckt), verduennt = sum(verduennt),
             spanne_median = round(median(spanne_log), 3)), by = coarse])
cat("\n== LR-Test Raumtyp gesamt: grob signifikant vs. Anzahl signifikanter Untergruppen ==\n")
print(lr[, .N, by = .(grob_signifikant = sig_c, untergruppen_signifikant = n_sig_f > 0)][order(-grob_signifikant, -untergruppen_signifikant)])
cat("\n== Deskriptiv (Verhaeltnis Kreistyp/Bund): Richtungswechsel innerhalb einer groben Gruppe ==\n")
cat(sum(ds$richtung_wechselt), "von", nrow(ds), "Zellen; groesste Abweichungen:\n")
print(ds[order(-max_abw_log)][1:8, .(phase, kreistyp = substr(kreistyp, 1, 1), coarse, ratio_c,
                                     fein = sprintf("%.2f (%s) – %.2f (%s)", ratio_f_min, min_bei, ratio_f_max, max_bei))])
