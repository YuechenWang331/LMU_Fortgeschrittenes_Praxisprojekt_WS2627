# COVID-19-Daten (RKI SurvStat) in ein langes Format bringen.
# Eingabe : data_raw/Count_COVID_LK_Week_RKI_2020_2024.RData  (Array Alter x Kreis x Woche)
#           data_raw/Incidence_COVID_LK_Week_RKI_2020_2024.RData (nur zur Kontrolle)
#           data_raw/Count_Bev_LK_RKI_2020_2024.RData           (Bezugsbevoelkerung)
# Ausgabe : data_processed/modellauswahl/covid_long.rds   (ags, age, week, year, cases, pop, inc)
#           data_processed/modellauswahl/covid_age_unknown.rds (Faelle ohne Altersangabe)

source("Scripts/modellauswahl/00_setup.R")

key  <- readRDS(file.path(DIR_CLEAN, "key_rki_to_ags.rds"))
cnt  <- readRDS(file.path(DIR_RAW, "Count_COVID_LK_Week_RKI_2020_2024.RData"))
inc0 <- readRDS(file.path(DIR_RAW, "Incidence_COVID_LK_Week_RKI_2020_2024.RData"))
bev  <- readRDS(file.path(DIR_RAW, "Count_Bev_LK_RKI_2020_2024.RData"))

# --- 1. Struktur pruefen ------------------------------------------------------
stopifnot(dim(cnt) == c(82, 411, 261), identical(dim(cnt), dim(inc0)),
          nrow(key) == dim(cnt)[2], sum(is.na(cnt)) == 0)
ages  <- dimnames(cnt)[[1]]                       # "0".."79","80+","NA"
wk    <- dimnames(cnt)[[3]]                       # "2019-12-30_2020", ...
wk_date <- as.Date(sub("_.*$", "", wk))
wk_year <- as.integer(sub("^.*_", "", wk))        # Jahr laut RKI-Zuordnung der Woche
stopifnot(all(diff(wk_date) == 7))                # lueckenlose Wochen
cat("Wochen pro Jahr:\n"); print(table(wk_year))

# --- 2. Array -> lang (Reihenfolge der 2. Dimension = Position in key) --------
long <- data.table(
  pos   = rep(rep(key$pos, each = length(ages)), times = length(wk)),
  age   = rep(ages, times = length(wk) * nrow(key)),
  widx  = rep(seq_along(wk), each = length(ages) * nrow(key)),
  cases = as.vector(cnt),
  inc_rki = as.vector(inc0)
)
# Reihenfolge von as.vector(): Alter (schnellst), dann Kreis, dann Woche
long[, ags_orig := key$ags_orig[match(pos, key$pos)]]
long[, `:=`(week = wk_date[widx], year = wk_year[widx])]
long[, c("pos", "widx") := NULL]

# Kontrolle: Position/Alter stimmen (Stichprobe aus dem Array)
chk <- long[ags_orig == key$ags_orig[7] & age == "40" & week == wk_date[100]]
stopifnot(chk$cases == cnt["40", 7, 100])

# --- 3. Untersuchungszeitraum 2020-2023 ----------------------------------------
long <- long[year %in% YEARS]
cat("Zeitraum:", format(min(long$week)), "bis", format(max(long$week)), "\n")

# --- 4. Berlin zusammenfassen ---------------------------------------------------
long[, ags := fifelse(substr(ags_orig, 1, 2) == BERLIN_PREFIX, BERLIN_AGS, ags_orig)]

# Faelle ohne Altersangabe separat halten
unk <- long[age == "NA", .(cases = sum(cases)), by = .(ags, week, year)]
saveRDS(unk, file.path(DIR_CLEAN, "covid_age_unknown.rds"))
long <- long[age != "NA"]

cas <- long[, .(cases = sum(cases), inc_rki_mean = mean(inc_rki)),
            by = .(ags, age, week, year)]

# Faelle ohne Alter proportional verteilen (Entscheidung 21.11.2026, siehe reports/modellauswahl/phase1_datenaudit.md):
# je Kreis x Woche nach der Altersverteilung der Faelle mit bekanntem Alter. Annahme: Faelle ohne Alter
# haben dieselbe Altersverteilung. Wochen ohne bekannte Faelle (2 Faelle) bleiben unverteilt.
# cases_obs = gemeldete Faelle mit Altersangabe; cases = inkl. verteilter Faelle (nicht mehr ganzzahlig).
# Sensitivitaet (Vergleich mit/ohne Verteilung): Scripts/modellauswahl/14_sens_age_unknown.R
setnames(cas, "cases", "cases_obs")
cas <- merge(cas, unk[, .(ags, week, unk = cases)], by = c("ags", "week"), all.x = TRUE)
cas[, known := sum(cases_obs), by = .(ags, week)]
cas[, cases := cases_obs + fifelse(!is.na(unk) & known > 0, unk * cases_obs / known, 0)]
cat("Faelle ohne Alter verteilt:", round(sum(cas$cases) - sum(cas$cases_obs)), "von", sum(unk$cases), "\n")
cas[, c("unk", "known") := NULL]

# --- 5. Bezugsbevoelkerung ------------------------------------------------------
setDT(bev)
bev[, ags_orig := sub("^.*&\\[([0-9]+)\\]$", "\\1", geo_code)]
bev[, ags := fifelse(substr(ags_orig, 1, 2) == BERLIN_PREFIX, BERLIN_AGS, ags_orig)]
pop <- bev[year %in% YEARS, .(pop = sum(population)), by = .(ags, age = as.character(age_name), year)]
stopifnot(all(pop$ags %in% cas$ags))

# In der Bevoelkerungstabelle fehlen einzelne Zellen (Kreis x Einzelalter x Jahr),
# 29 Kombinationen, in denen alle gemeldeten Faelle 0 sind (kleine Kreise, Einzelalter).
# Fehlende Zellen werden aus den Nachbarjahren desselben Kreises und Alters
# interpoliert bzw. mit dem naechsten Jahr aufgefuellt, damit spaeter gebildete
# Altersgruppen-Bevoelkerungen nicht zu klein ausfallen.
grid <- CJ(ags = unique(cas$ags), age = unique(cas$age), year = YEARS)
pop  <- merge(grid, pop, by = c("ags", "age", "year"), all.x = TRUE)
pop[, pop_imputed := is.na(pop)]
cat("Bevoelkerungszellen ergaenzt:", sum(pop$pop_imputed), "\n")
pop[, pop := {
  ok <- !is.na(pop)
  if (all(ok)) pop else approx(year[ok], pop[ok], xout = year, rule = 2)$y
}, by = .(ags, age)]
stopifnot(!anyNA(pop$pop))

dat <- merge(cas, pop, by = c("ags", "age", "year"), all.x = TRUE)
cat("Zeilen ohne Bevoelkerung:", sum(is.na(dat$pop)), "\n")
cat("Zeilen mit pop == 0 oder < 1:", sum(dat$pop < 1, na.rm = TRUE), "\n")

dat[, inc := fifelse(!is.na(pop) & pop > 0, cases / pop * 1e5, NA_real_)]

# --- 6. Kontrolle gegen die vom Projektpartner gelieferte Inzidenz -------------
# (nur Kreise ohne Berlin: dort entspricht inc_rki genau einer Einheit; nur Zellen mit Faellen auf beiden Seiten)
# a) Wird die Originaltabelle reproduziert? Dafuer zaehlen nur die gemeldeten Faelle MIT Altersangabe (cases_obs),
#    denn die RKI-Inzidenz enthaelt die Faelle ohne Alter nicht.
# b) Getrennt davon: wie stark die Verteilung der Faelle ohne Altersangabe die Zellen veraendert (cases / cases_obs).
nb <- dat[ags != BERLIN_AGS & !is.na(pop) & pop > 0 & cases_obs > 0 & inc_rki_mean > 0]
qa <- quantile(nb[, cases_obs / pop * 1e5 / inc_rki_mean], c(.01, .5, .99))
cat("a) Originaltabelle: eigene Inzidenz (nur Faelle mit Alter) / RKI-Inzidenz, 1%/50%/99%-Quantil:\n")
print(round(qa, 5))
stopifnot(all(abs(qa - 1) < 1e-3))   # Abweichung > 0,1 % hiesse: falsche Zuordnung von Kreis, Alter oder Woche
cat(sprintf("b) Verteilung der Faelle ohne Alter: %d von %d Zellen veraendert; cases / cases_obs, 1%%/50%%/99%%-Quantil/Max:\n",
            nb[cases > cases_obs, .N], nrow(nb)))
print(round(quantile(nb$cases / nb$cases_obs, c(.01, .5, .99, 1)), 5))
dat[, inc_rki_mean := NULL]

# --- 7. Plausibilitaet und Speichern ---------------------------------------------
setorder(dat, ags, age, week)
dat[, age_num := as.integer(sub("\\+", "", age))]   # 80+ -> 80
cat("\nKreise:", uniqueN(dat$ags), " Alter:", uniqueN(dat$age),
    " Wochen:", uniqueN(dat$week), " Zeilen:", nrow(dat), "\n")
cat("Negative Faelle:", sum(dat$cases < 0), "\n")
cat("Faelle gesamt 2020-2023 (inkl. verteilter Faelle ohne Alter):", format(sum(dat$cases), big.mark = ".", decimal.mark = ","), "\n")
cat("Faelle ohne Alter:", format(sum(unk$cases), big.mark = ".", decimal.mark = ","), "\n")
print(dat[, .(cases = sum(cases)), by = year])

saveRDS(dat, file.path(DIR_CLEAN, "covid_long.rds"))
cat("gespeichert: data_processed/modellauswahl/covid_long.rds\n")
