# Strukturvariablen auf Kreisebene (400 Kreise x Jahr 2020-2023) aufbereiten.
# Eingabe : data_raw/*_flat.csv (GENESIS), BBSR-CSV, data_processed/modellauswahl/covid_long.rds (Bevoelkerung)
# Ausgabe : data_processed/modellauswahl/struct_kreis_year.rds  (ags x year, abgeleitete Indikatoren)
#           data_processed/modellauswahl/struct_kreis_const.rds (ags: Typologien + Mittelwert je Indikator)
#           results/modellauswahl/tables/struct_kreis_year.csv, struct_na_summary.csv
#
# Alle Raten beziehen sich auf die Bezugsbevoelkerung der RKI-Daten (gleiche Nenner
# wie bei der Inzidenz). Berlin = 1 Kreis, Hamburg/Berlin aus den Bundesland-Zeilen.

source("Scripts/modellauswahl/00_setup.R")

kreis <- readRDS(file.path(DIR_CLEAN, "kreis_key.rds"))
AGS   <- kreis$ags
GRID  <- CJ(ags = AGS, year = YEARS)

# ---- Hilfsfunktionen ----------------------------------------------------------
# num() und read_gen() (GENESIS-Flat-Dateien) stehen in Scripts/modellauswahl/00_setup.R.
pick <- function(d, v, w2 = "", w3 = "", name = v) {
  r <- d[var == v & a2 == w2 & a3 == w3, .(ags, year, value)]
  setnames(r, "value", name); r
}
rate <- function(num_dt, den_dt, name, scale = 1000) {   # Zaehler / Nenner * scale
  r <- merge(num_dt, den_dt, by = c("ags", "year"))
  r[, (name) := get(names(num_dt)[3]) / get(names(den_dt)[3]) * scale]
  r[, .SD, .SDcols = c("ags", "year", name)]
}

# ---- 1. Bevoelkerung und Altersstruktur (aus den RKI-Daten) -------------------
cov <- readRDS(file.path(DIR_CLEAN, "covid_long.rds"))
P   <- unique(cov[, .(ags, age_num, year, pop)])
rm(cov)
popg <- function(lo, hi, name) {
  r <- P[age_num >= lo & age_num <= hi, .(v = sum(pop)), by = .(ags, year)]
  setnames(r, "v", name); r
}
pops <- Reduce(function(a, b) merge(a, b, by = c("ags", "year")), list(
  popg(0, 80, "pop_total"), popg(0, 5, "pop_0_5"), popg(0, 13, "pop_0_13"),
  popg(6, 17, "pop_6_17"), popg(18, 39, "pop_18_39"), popg(40, 59, "pop_40_59"),
  popg(60, 69, "pop_60_69"), popg(70, 79, "pop_70_79"), popg(80, 80, "pop_80p"),
  popg(15, 24, "pop_15_24"), popg(15, 64, "pop_15_64"), popg(65, 80, "pop_65p")))
demo <- copy(pops)
for (g in c("0_5", "6_17", "18_39", "40_59", "60_69", "70_79", "80p", "65p"))
  demo[, paste0("anteil_", g) := get(paste0("pop_", g)) / pop_total * 100]

# Kontrolle gegen GENESIS 12411 (Fortschreibung): Summe beider Geschlechter und aller Altersgruppen
g12411 <- read_gen("12411-0018 Bevölkerung nach Geschlecht, Altersgruppen und Kreisen.csv")
g12411 <- g12411[, .(g = sum(value)), by = .(ags, year)]
chk <- merge(pops[, .(ags, year, pop_total)], g12411, by = c("ags", "year"))
chk[, rel := pop_total / g - 1]
cat("Bevoelkerung RKI vs. GENESIS 12411: relative Abweichung (Median / 1% / 99%):\n")
print(round(quantile(chk$rel, c(.5, .01, .99), na.rm = TRUE), 4))

# ---- 2. Flaeche und Dichte ------------------------------------------------------
fl <- fread(file.path(DIR_RAW, "11111-0002 Gebietsfläche nach Kreise.csv"), sep = ";",
            encoding = "UTF-8", colClasses = "character")
fl <- fl[, .(ags = substr(`1_variable_attribute_code`, 1, 5), year = as.integer(substr(time, 1, 4)),
             flaeche_km2 = num(value))]
fl[ags == "16056", ags := "16063"]                               # Eisenach -> Wartburgkreis (siehe read_gen)
fl <- fl[, .(flaeche_km2 = sum(flaeche_km2)), by = .(ags, year)][ags %in% AGS & year %in% YEARS]
stopifnot(!anyDuplicated(fl, by = c("ags", "year")))
dens <- merge(fl, pops[, .(ags, year, pop_total)], by = c("ags", "year"))
dens[, dichte := pop_total / flaeche_km2]
dens[, pop_total := NULL]

# ---- 3. Soziale Mindestsicherung (22811) -----------------------------------------
gs <- read_gen("grundsicherung_flat.csv")
gs_chk <- merge(pick(gs, "ESML01", "ARTDGSNW1", name = "a"), pick(gs, "ESML01", "ARTDGSNW2", name = "b"), by = c("ags", "year"))
gs_chk <- merge(gs_chk, pick(gs, "ESML01", "ZUSAMMEN01", name = "z"), by = c("ags", "year"))
cat("\nGrundsicherung: Anteil Zeilen mit NW1+NW2 == zusammen:",
    round(mean(gs_chk$a + gs_chk$b == gs_chk$z, na.rm = TRUE), 4), "\n")
sozial <- Reduce(function(a, b) merge(a, b, by = c("ags", "year"), all = TRUE), list(
  rate(pick(gs, "ESML01", "ZUSAMMEN01", name = "x"), pops[, .(ags, year, pop_total)], "sgb2_je1000"),
  rate(pick(gs, "ESML01", "ARTDLNW2", name = "x"), pops[, .(ags, year, pop_65p)], "grundsicherung_alter_je1000_65p"),
  rate(pick(gs, "ESML01", "ARTDLNW1", name = "x"), pops[, .(ags, year, pop_total)], "hilfe_lebensunterhalt_je1000"),
  rate(pick(gs, "ESML01", "ARTDLNW3", name = "x"), pops[, .(ags, year, pop_total)], "asylbewerberleistung_je1000")))

# ---- 4. Arbeitslosigkeit (13211) --------------------------------------------------
al <- read_gen("arbeitslose_flat.csv")
alo_tot <- pick(al, "ERWP06", name = "tot")
arbeit <- Reduce(function(a, b) merge(a, b, by = c("ags", "year"), all = TRUE), list(
  rate(alo_tot, pops[, .(ags, year, pop_15_64)], "alo_je100_15_64", 100),
  rate(pick(al, "ERWP06", "ARBEITSLOS13", name = "x"), pops[, .(ags, year, pop_15_24)], "alo_jung_je100_15_24", 100),
  rate(pick(al, "ERWP06", "ARBEITSLOS05", name = "x"), alo_tot, "alo_langzeit_anteil", 100),
  rate(pick(al, "ERWP06", "ARBEITSLOS08", name = "x"), alo_tot, "alo_auslaender_anteil", 100)))

# ---- 5. Beschaeftigte der Gemeinden/Gemeindeverbaende (74111), Vollzeitaequivalente ------
be <- read_gen("beschaeftigte_flat.csv")
oed <- rate(pick(be, "ERW054", name = "x"), pops[, .(ags, year, pop_total)], "oed_beschaeftigte_vze_je1000")

# ---- 6. Pflegestatistik (22411): nur 2021 und 2023 ---------------------------------
pf <- read_gen("pflegestat_flat.csv")
pflege <- Reduce(function(a, b) merge(a, b, by = c("ags", "year"), all = TRUE), list(
  rate(pick(pf, "PFL003", "PFLSTAT1", name = "x"), pops[, .(ags, year, pop_65p)], "pflegeheim_plaetze_je1000_65p"),
  rate(pick(pf, "PFL004", "PFLSTAT1", name = "x"), pops[, .(ags, year, pop_65p)], "pflegeheim_personal_je1000_65p"),
  rate(pick(pf, "PFL014", "PFLAMB1", name = "x"), pops[, .(ags, year, pop_65p)], "pflegedienst_personal_je1000_65p")))

# ---- 7. Kindertagesbetreuung (22541) ---------------------------------------------
kt <- read_gen("tageseinrichtungen_flat.csv")
# Genehmigte Plaetze (PLZ005) gibt es nur insgesamt (ohne Altersaufteilung); Nenner: Kinder 0-13 Jahre
kita <- Reduce(function(a, b) merge(a, b, by = c("ags", "year"), all = TRUE), list(
  rate(pick(kt, "PLZ005", name = "x"), pops[, .(ags, year, pop_0_13)], "kita_plaetze_je1000_0_13"),
  rate(pick(kt, "PER005", "PERSONAL002B", name = "x"), pops[, .(ags, year, pop_0_13)], "kita_paed_personal_je1000_0_13")))

# ---- 8. Schutzsuchende (12531) -----------------------------------------------------
sc <- read_gen("schutzsuchende_flat.csv")
schutz <- rate(pick(sc, "BEV030", name = "x"), pops[, .(ags, year, pop_total)], "schutzsuchende_je1000")

# ---- 9. Tourismus (45412) ----------------------------------------------------------
to <- read_gen("tourismus_flat.csv")
# GAST03 (angebotene Gaestebetten) ist in der Datei durchgehend "-" und wird nicht verwendet.
tou <- Reduce(function(a, b) merge(a, b, by = c("ags", "year")), list(
  pick(to, "GAST02", name = "uebernachtungen"), pick(to, "GAST04", name = "betriebe")))
tourismus <- merge(tou, pops[, .(ags, year, pop_total)], by = c("ags", "year"))
tourismus[, `:=`(uebernachtungen_je_einw = uebernachtungen / pop_total,
                 betriebe_je100000 = betriebe / pop_total * 1e5)]
tourismus <- tourismus[, .(ags, year, uebernachtungen_je_einw, betriebe_je100000)]

# ---- 10. Schulabschluesse (21111), Abgaenger nach Schulort --------------------------
ab <- read_gen("abschlusse_flat.csv")
ab_tot <- pick(ab, "BILABS", name = "tot")
schule <- Reduce(function(a, b) merge(a, b, by = c("ags", "year"), all = TRUE), list(
  rate(pick(ab, "BILABS", "BILABS11", name = "x"), ab_tot, "schule_ohne_abschluss_anteil", 100),
  rate(pick(ab, "BILABS", "BILABS15", name = "x"), ab_tot, "schule_hochschulreife_anteil", 100)))

# ---- 11. Pendler (19321), 2021-2023: Gemeindesummen je Kreis ---------------------------
pend <- rbindlist(lapply(c("einpendelnde21", "einpendelnde22", "einpendelnde23",
                           "auspendelnde21", "auspendelnde22", "auspendelnde23"), function(b) {
  d <- read_gen(paste0(b, "_flat.csv"), pendler = TRUE)
  d <- d[a2 == "" & a3 == "" & var %in% c("PEN001", "PEN002")]       # beide Geschlechter, alle Alter
  d[, .(value = sum(value, na.rm = TRUE), n_na = sum(is.na(value))), by = .(ags, year, var)]
}))
pend <- dcast(pend, ags + year ~ var, value.var = c("value", "n_na"))
pend[, `:=`(ein = value_PEN001, aus = value_PEN002)]
pendler <- merge(pend[, .(ags, year, ein, aus, n_na = n_na_PEN001 + n_na_PEN002)],
                 pops[, .(ags, year, pop_total)], by = c("ags", "year"))
pendler[, `:=`(pendler_ein_je1000 = ein / pop_total * 1000, pendler_aus_je1000 = aus / pop_total * 1000,
               pendler_saldo_je1000 = (ein - aus) / pop_total * 1000,
               pendler_n_unbekannt = n_na)]
pendler <- pendler[, .(ags, year, pendler_ein_je1000, pendler_aus_je1000, pendler_saldo_je1000, pendler_n_unbekannt)]

# ---- 12. Zusammenfuehren: Kreis x Jahr -------------------------------------------------
parts <- list(demo, dens, sozial, arbeit, oed, pflege, kita, schutz, tourismus, schule, pendler)
sy <- Reduce(function(a, b) merge(a, b, by = c("ags", "year"), all.x = TRUE), parts, init = GRID)
setorder(sy, ags, year)
stopifnot(nrow(sy) == 400 * length(YEARS), !anyDuplicated(sy, by = c("ags", "year")))

# ---- 13. Zeitkonstante Merkmale: BBSR-Typologien, Kreisart, Land ------------------------
bb <- function(f, nm) {
  d <- fread(file.path(DIR_RAW, f), sep = ";", encoding = "Latin-1", colClasses = "character")
  setnames(d, c("kennz", "name", paste0(nm, "_code"), paste0(nm, "_name")))
  d[, ags := substr(kennz, 1, 5)]
  # Die BBSR-Dateien (Stand 2020, 401 Zeilen) fuehren Eisenach (16056) noch als eigenen Kreis; in den RKI-Daten
  # gehoert es zum Wartburgkreis (16063). Zusammenlegen geht nur, wenn beide dieselbe Kategorie haben (geprueft:
  # Kreistyp 4, Lage 3) -> danach 400 Kreise, Kreistyp 67/133/98/102, Lage 106/145/131/18.
  code <- paste0(nm, "_code")
  stopifnot(d[ags == "16056", get(code)] == d[ags == "16063", get(code)])
  d <- d[ags != "16056"]
  d <- d[ags %in% AGS, c("ags", paste0(nm, c("_code", "_name"))), with = FALSE]
  stopifnot(nrow(d) == length(AGS), !anyDuplicated(d$ags))
  d
}
typ  <- merge(bb("siedlungsstrukt-kreistypen-2020.csv", "kreistyp"),
              bb("raumtypen-lage-2020.csv", "lage"), by = "ags")
typ[, `:=`(kreistyp_code = as.integer(kreistyp_code), lage_code = as.integer(lage_code))]
# Namen aus dem Latin-1-Lesen in UTF-8 umkodieren
typ[, `:=`(kreistyp_name = iconv(kreistyp_name, "latin1", "UTF-8"), lage_name = iconv(lage_name, "latin1", "UTF-8"))]

bev <- readRDS(file.path(DIR_RAW, "Count_Bev_LK_RKI_2020_2024.RData"))
setDT(bev)
ka <- unique(bev[, .(ags_orig = sub("^.*&\\[([0-9]+)\\]$", "\\1", geo_code), geo_name)])
ka[, ags := fifelse(substr(ags_orig, 1, 2) == "11", "11000", ags_orig)]
ka[, kreisart := fifelse(grepl("^SK ", geo_name), "Stadtkreis", fifelse(grepl("^LK ", geo_name), "Landkreis", NA_character_))]
ka[ags == "11000", kreisart := "Stadtkreis"]
ka[ags %in% c("03241", "05334"), kreisart := "Landkreis"]   # Region Hannover, Staedteregion Aachen (ohne LK/SK-Praefix)
ka <- unique(ka[, .(ags, kreisart)])
cat("\nKreisart (RKI-Namenspraefix):\n"); print(table(ka$kreisart, useNA = "ifany"))
stopifnot(!anyDuplicated(ka$ags))

const <- merge(kreis[, .(ags, state, name_rki)], ka, by = "ags", all.x = TRUE)
const <- merge(const, typ, by = "ags", all.x = TRUE)

# Mittelwert je Indikator ueber 2020-2023 (nur vorhandene Jahre)
ind <- setdiff(names(sy), c("ags", "year"))
mean_cols <- sy[, lapply(.SD, function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)), by = ags, .SDcols = ind]
setnames(mean_cols, ind, paste0(ind, "_mean"))
const <- merge(const, mean_cols, by = "ags")

# ---- 14. Kontrolle und Speichern ----------------------------------------------------------
na_tab <- sy[, lapply(.SD, function(x) sum(is.na(x))), by = year, .SDcols = ind]
na_long <- melt(na_tab, id.vars = "year", variable.name = "indicator", value.name = "n_na")
na_wide <- dcast(na_long, indicator ~ year, value.var = "n_na")
cat("\nFehlende Werte je Indikator (von 400 Kreisen):\n"); print(na_wide, nrows = 100)
cat("\nBBSR-Zuordnung fehlt:", sum(is.na(const$kreistyp_code)), " Kreisart fehlt:", sum(is.na(const$kreisart)), "\n")
cat("\nWertebereich (Min / Median / Max):\n")
print(t(sapply(ind, function(v) round(quantile(sy[[v]], c(0, .5, 1), na.rm = TRUE), 2))))

saveRDS(sy,    file.path(DIR_CLEAN, "struct_kreis_year.rds"))
saveRDS(const, file.path(DIR_CLEAN, "struct_kreis_const.rds"))
fwrite(sy,     file.path(DIR_TAB, "struct_kreis_year.csv"))
fwrite(na_wide, file.path(DIR_TAB, "struct_na_summary.csv"))
cat("\ngespeichert: struct_kreis_year.rds, struct_kreis_const.rds\n")
