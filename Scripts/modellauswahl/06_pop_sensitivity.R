# Sensitivitaets-Nenner: RKI-Einzeljahr-Bevoelkerung auf GENESIS 12411 skalieren.
# Idee: In jeder Zelle Kreis x Jahr x GENESIS-Altersgruppe wird die RKI-Bevoelkerung
# (Einzeljahre) mit G/R multipliziert, so dass die Gruppensumme exakt GENESIS entspricht
# (Verteilung innerhalb der Gruppe bleibt wie bei RKI). 2020/2021 sind praktisch unveraendert.
# Hinweis: Die Gruppe "75 und aelter" enthaelt 75-79 und 80+; beide erhalten denselben Faktor.
#
# Ausgabe: data_processed/modellauswahl/pop_genesis_adj.rds  (ags, age_num, year, pop_rki, pop_gen, faktor, alt)
#          results/modellauswahl/tables/pop_sensitivity_impact.csv

source("Scripts/modellauswahl/00_setup.R")

# ---- GENESIS 12411 (beide Geschlechter) je Kreis x Jahr x Altersgruppe ----------------------
G <- read_genesis_12411()
stopifnot(!anyNA(G$g))

# ---- RKI-Bevoelkerung in GENESIS-Altersgruppen einteilen ---------------------------------------------
cov <- readRDS(file.path(DIR_CLEAN, "covid_long.rds"))
P <- unique(cov[, .(ags, age_num, year, pop)])
setnames(P, "pop", "pop_rki")
codes  <- c("ALT000B03", "ALT003B06", "ALT006B10", "ALT010B15", "ALT015B18", "ALT018B20", "ALT020B25",
            "ALT025B30", "ALT030B35", "ALT035B40", "ALT040B45", "ALT045B50", "ALT050B55", "ALT055B60",
            "ALT060B65", "ALT065B75", "ALT075UM")
breaks <- c(0, 3, 6, 10, 15, 18, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 75, Inf)
stopifnot(setequal(codes, unique(G$alt)))
P[, alt := as.character(cut(age_num, breaks, labels = codes, right = FALSE))]
stopifnot(!anyNA(P$alt))

R <- P[, .(r = sum(pop_rki)), by = .(ags, year, alt)]
F <- merge(R, G, by = c("ags", "year", "alt"))
F[, faktor := fifelse(r > 0 & g > 0, g / r, 1)]
cat("Zellen mit Faktor-Fallback 1 (r oder g = 0):", F[r <= 0 | g <= 0, .N], "\n")
cat("\nSkalierungsfaktor G/R nach Jahr (Median / 5% / 95% / Min / Max):\n")
print(F[, .(median = round(median(faktor), 4), p05 = round(quantile(faktor, .05), 4),
            p95 = round(quantile(faktor, .95), 4), min = round(min(faktor), 3), max = round(max(faktor), 3)),
        by = year][order(year)])

adj <- merge(P, F[, .(ags, year, alt, faktor)], by = c("ags", "year", "alt"))
adj[, pop_gen := pop_rki * faktor]
setcolorder(adj, c("ags", "age_num", "year", "pop_rki", "pop_gen", "faktor", "alt"))
setorder(adj, ags, year, age_num)
stopifnot(nrow(adj) == nrow(P))

# Kontrolle: Gruppensummen und Gesamtsumme stimmen mit GENESIS ueberein
chk <- merge(adj[, .(s = sum(pop_gen)), by = .(ags, year, alt)], G, by = c("ags", "year", "alt"))
cat("\nmax. |Summe(pop_gen) - GENESIS| je Zelle:", max(abs(chk$s - chk$g)), "\n")
nat <- adj[, .(rki = sum(pop_rki), gen = sum(pop_gen)), by = year][order(year)]
print(nat)
saveRDS(adj, file.path(DIR_CLEAN, "pop_genesis_adj.rds"))

# ---- Wirkung auf altersgruppenspezifische Inzidenz (Klimas grobe Gruppen) -----------------------------------
cases <- cov[, .(cases = sum(cases)), by = .(ags, age_num, year)]
d <- merge(cases, adj[, .(ags, age_num, year, pop_rki, pop_gen)], by = c("ags", "age_num", "year"))
d[, grp := age_group(age_num, "coarse")]
D <- d[year %in% c(2022, 2023), .(cases = sum(cases), r = sum(pop_rki), g = sum(pop_gen)), by = .(ags, year, grp)]
D[, `:=`(inc_rki = cases / r * 1e5, inc_gen = cases / g * 1e5)]
imp <- D[, .(
  pop_diff_pct_national = round((sum(g) / sum(r) - 1) * 100, 2),
  inc_national_rki = round(sum(cases) / sum(r) * 1e5), inc_national_gen = round(sum(cases) / sum(g) * 1e5),
  inc_change_pct_p05 = round(quantile(inc_gen / inc_rki - 1, .05, na.rm = TRUE) * 100, 2),
  inc_change_pct_median = round(median(inc_gen / inc_rki - 1, na.rm = TRUE) * 100, 2),
  inc_change_pct_p95 = round(quantile(inc_gen / inc_rki - 1, .95, na.rm = TRUE) * 100, 2),
  spearman = round(cor(inc_rki, inc_gen, method = "spearman", use = "complete.obs"), 4)
), by = .(year, grp)]
imp[, grp := factor(grp, levels = GR_COARSE)]
setorder(imp, year, grp)
cat("\n== Wirkung auf kumulative Inzidenz je 100.000, Kreis x grobe Altersgruppe ==\n"); print(imp)
fwrite(imp, file.path(DIR_TAB, "pop_sensitivity_impact.csv"))
cat("\ngespeichert: data_processed/modellauswahl/pop_genesis_adj.rds, results/modellauswahl/tables/pop_sensitivity_impact.csv\n")
