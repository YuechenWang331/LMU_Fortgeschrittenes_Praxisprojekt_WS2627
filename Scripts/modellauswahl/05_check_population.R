# Kontrolle der Bezugsbevoelkerung: RKI (infer_population) vs. GENESIS 12411 (Fortschreibung).
# Frage: Warum weichen die Werte 2022/2023 ab, und wie stark wirkt sich das auf Inzidenzen aus?
# Ausgabe: results/modellauswahl/tables/pop_check_*.csv, results/modellauswahl/figures/pop_check_*.png

source("Scripts/modellauswahl/00_setup.R")
const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))

# ---- GENESIS 12411: Kreis x Jahr x Altersgruppe (beide Geschlechter, Eisenach 2020 im Wartburgkreis) ----
g <- read_genesis_12411()

# Altersgruppen von 12411 -> grobe Gruppen, die sich exakt aus Einzeljahren bilden lassen
grp <- c(ALT000B03 = "0-5", ALT003B06 = "0-5",
         ALT006B10 = "6-17", ALT010B15 = "6-17", ALT015B18 = "6-17",
         ALT018B20 = "18-39", ALT020B25 = "18-39", ALT025B30 = "18-39", ALT030B35 = "18-39", ALT035B40 = "18-39",
         ALT040B45 = "40-59", ALT045B50 = "40-59", ALT050B55 = "40-59", ALT055B60 = "40-59",
         ALT060B65 = "60+", ALT065B75 = "60+", ALT075UM = "60+")
stopifnot(all(unique(g$alt) %in% names(grp)))
g[, grp := grp[alt]]
G <- g[, .(g = sum(g)), by = .(ags, year, grp)]
Gtot <- g[, .(g = sum(g)), by = .(ags, year)]

# ---- RKI-Bevoelkerung -----------------------------------------------------------------
cov <- readRDS(file.path(DIR_CLEAN, "covid_long.rds"))
P <- unique(cov[, .(ags, age_num, year, pop)])
P[, grp := fcase(age_num <= 5, "0-5", age_num <= 17, "6-17", age_num <= 39, "18-39",
                 age_num <= 59, "40-59", default = "60+")]
R <- P[, .(r = sum(pop)), by = .(ags, year, grp)]
Rtot <- P[, .(r = sum(pop)), by = .(ags, year)]

# ---- 1. National und nach Jahr ----------------------------------------------------------
tot <- merge(Rtot, Gtot, by = c("ags", "year"))
tot[, rel := r / g - 1]
nat <- tot[, .(rki = sum(r), genesis = sum(g), diff_pct = round((sum(r) / sum(g) - 1) * 100, 2),
               median_pct = round(median(rel) * 100, 2), p05_pct = round(quantile(rel, .05) * 100, 2),
               p95_pct = round(quantile(rel, .95) * 100, 2), min_pct = round(min(rel) * 100, 2),
               max_pct = round(max(rel) * 100, 2), n_abs_ueber_3pct = sum(abs(rel) > .03)), by = year]
cat("== RKI vs. GENESIS 12411, Gesamtbevoelkerung (Differenz in %) ==\n"); print(nat)
fwrite(nat, file.path(DIR_TAB, "pop_check_national.csv"))

# ---- 2. Verlauf: Sprung zwischen 2021 und 2022? ---------------------------------------------
chg <- merge(tot[year == 2021, .(ags, r21 = r, g21 = g)], tot[year == 2022, .(ags, r22 = r, g22 = g)], by = "ags")
chg[, `:=`(chg_rki = r22 / r21 - 1, chg_gen = g22 / g21 - 1, rki22_vs_gen21 = r22 / g21 - 1)]
cat("\n== Veraenderung 2021->2022 (Median / 5% / 95%) ==\n")
print(round(rbind(RKI = quantile(chg$chg_rki, c(.5, .05, .95)), GENESIS = quantile(chg$chg_gen, c(.5, .05, .95)),
                  `RKI2022 vs GENESIS2021` = quantile(chg$rki22_vs_gen21, c(.5, .05, .95))) * 100, 2))

# ---- 3. Nach Altersgruppe ---------------------------------------------------------------------
ag <- merge(R, G, by = c("ags", "year", "grp"))
ag[, rel := r / g - 1]
agt <- ag[, .(rki = sum(r), genesis = sum(g), diff_pct = round((sum(r) / sum(g) - 1) * 100, 2),
              p05_pct = round(quantile(rel, .05) * 100, 2), p95_pct = round(quantile(rel, .95) * 100, 2)),
          by = .(year, grp)][order(year, grp)]
cat("\n== nach Altersgruppe (Differenz RKI vs GENESIS in %) ==\n"); print(agt[year >= 2021], nrows = 30)
fwrite(agt, file.path(DIR_TAB, "pop_check_agegroup.csv"))

# ---- 4. Wo sind die Abweichungen? (2022) ------------------------------------------------------------
t22 <- merge(tot[year == 2022], const[, .(ags, name_rki, state, kreisart, kreistyp_code)], by = "ags")
cat("\n== 2022: Differenz nach Kreisart / Kreistyp (Median, Mittel in %) ==\n")
print(t22[, .(n = .N, median = round(median(rel) * 100, 2), mean = round(mean(rel) * 100, 2)), by = .(kreisart, kreistyp_code)][order(kreisart, kreistyp_code)])
cat("\n== 2022: nach Bundesland (Median in %) ==\n")
print(t22[, .(n = .N, median = round(median(rel) * 100, 2), min = round(min(rel) * 100, 1), max = round(max(rel) * 100, 1)), by = state][order(state)])
cat("\n== 2022: groesste Abweichungen ==\n")
print(t22[order(-abs(rel))][1:10, .(ags, name_rki, rki = round(r), genesis = g, rel_pct = round(rel * 100, 1))])
fwrite(t22[, .(ags, name_rki, state, kreisart, kreistyp_code, rki = r, genesis = g, rel_pct = rel * 100)],
       file.path(DIR_TAB, "pop_check_kreis_2022.csv"))

# ---- 5. Wirkung auf die Inzidenz 2022 (Kreisebene, Summe aller Altersgruppen) ------------------------
cases22 <- cov[year == 2022, .(cases = sum(cases)), by = ags]
cases22 <- merge(cases22, t22[, .(ags, r, g)], by = "ags")
cases22[, `:=`(inc_rki = cases / r * 1e5, inc_gen = cases / g * 1e5)]
cat("\n== Kumulative Inzidenz 2022 je 100.000: RKI-Nenner vs. GENESIS-Nenner ==\n")
cat("Spearman-Rangkorrelation:", round(cor(cases22$inc_rki, cases22$inc_gen, method = "spearman"), 4), "\n")
cases22[, `:=`(rank_rki = frank(inc_rki), rank_gen = frank(inc_gen))]
cat("Rangverschiebung (Median / 95% / Max):", median(abs(cases22$rank_rki - cases22$rank_gen)),
    quantile(abs(cases22$rank_rki - cases22$rank_gen), .95), max(abs(cases22$rank_rki - cases22$rank_gen)), "\n")
cat("Relative Aenderung der Inzidenz (5% / 50% / 95%):",
    round(quantile(cases22$inc_gen / cases22$inc_rki - 1, c(.05, .5, .95)) * 100, 2), "\n")

# ---- 6. Grafik --------------------------------------------------------------------------------------------
png(file.path(DIR_FIG, "pop_check_rel_diff.png"), width = 1400, height = 700, res = 140)
par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
boxplot(rel * 100 ~ year, data = tot, ylab = "RKI vs. GENESIS 12411 (%)", xlab = "Jahr",
        main = "Gesamtbevoelkerung je Kreis", outline = TRUE, pch = 20, cex = .5)
abline(h = 0, lty = 2)
plot(t22$g, t22$rel * 100, log = "x", pch = 20, cex = .6, xlab = "GENESIS-Bevoelkerung 2022 (log)",
     ylab = "RKI vs. GENESIS (%)", main = "2022: Abweichung nach Kreisgroesse")
abline(h = 0, lty = 2)
dev.off()
cat("\ngespeichert: results/modellauswahl/tables/pop_check_*.csv, results/modellauswahl/figures/pop_check_rel_diff.png\n")
