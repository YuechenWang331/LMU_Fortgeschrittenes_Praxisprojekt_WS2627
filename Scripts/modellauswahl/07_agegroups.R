# Wochendaten je Kreis in die von Klima genannten Altersgruppen aggregieren.
# Grob: 0-5, 6-17, 18-39, 40-59, 60-69, 70-79, 80+
# Fein: 0-2, 3-5, 6-9, 10-14, 15-17, 18-24, 25-29, 30-39, 40-49, 50-59, 60-69, 70-79, 80+
# Beide Schemata sind Vereinigungen der Einzeljahre. Nenner in zwei Varianten:
#   pop_rki (Hauptanalyse), pop_gen (Sensitivitaet, siehe 06_pop_sensitivity.R)
# Ausgabe: data_processed/modellauswahl/covid_agegrp.rds  (scheme, grp, ags, week, year, cases, pop_rki, pop_gen, inc, inc_gen)

source("Scripts/modellauswahl/00_setup.R")

cov <- readRDS(file.path(DIR_CLEAN, "covid_long.rds"))
adj <- readRDS(file.path(DIR_CLEAN, "pop_genesis_adj.rds"))
d <- merge(cov[, .(ags, age_num, week, year, cases, pop_rki = pop)],
           adj[, .(ags, age_num, year, pop_gen)], by = c("ags", "age_num", "year"))
stopifnot(nrow(d) == nrow(cov), !anyNA(d$pop_gen))
rm(cov, adj)

# Gruppengrenzen: AGE_SCHEMES in Scripts/modellauswahl/00_setup.R
agg <- function(scheme) {
  groups <- AGE_SCHEMES[[scheme]]
  rbindlist(lapply(names(groups), function(gn) {
    lo <- groups[[gn]][1]; hi <- groups[[gn]][2]
    x <- d[age_num >= lo & age_num <= hi,
           .(cases = sum(cases), pop_rki = sum(pop_rki), pop_gen = sum(pop_gen)),
           by = .(ags, week, year)]
    x[, `:=`(scheme = scheme, grp = gn)]
  }))
}
out <- rbind(agg("coarse"), agg("fine"))
out[, `:=`(inc = cases / pop_rki * 1e5, inc_gen = cases / pop_gen * 1e5)]
# Achtung: Faktorstufen enthalten beide Schemata hintereinander; in Abbildungen die Reihenfolge
# je Schema explizit setzen (GR_COARSE / GR_FINE)
out[, grp := factor(grp, levels = unique(c(GR_COARSE, GR_FINE)))]
setcolorder(out, c("scheme", "grp", "ags", "week", "year", "cases", "pop_rki", "pop_gen", "inc", "inc_gen"))
setorder(out, scheme, grp, ags, week)

# Kontrolle: Summe ueber Altersgruppen = Summe ueber Einzeljahre
stopifnot(all.equal(out[scheme == "coarse", sum(cases)], d[, sum(cases)]),
          all.equal(out[scheme == "fine", sum(cases)], d[, sum(cases)]))
cat("Zeilen:", nrow(out), " (grob:", out[scheme == "coarse", .N], " fein:", out[scheme == "fine", .N], ")\n")
cat("Faelle gesamt:", format(d[, sum(cases)], big.mark = ","), "\n")
print(out[scheme == "coarse", .(cases = sum(cases), pop2022 = round(mean(pop_rki[year == 2022]) * uniqueN(ags))),
          by = grp])
saveRDS(out, file.path(DIR_CLEAN, "covid_agegrp.rds"))
cat("gespeichert: data_processed/modellauswahl/covid_agegrp.rds\n")
