# Gemeinsame Einstellungen: Pfade, Pakete, Konstanten und Hilfsfunktionen.
# Alle Skripte starten mit source("Scripts/modellauswahl/00_setup.R") und werden aus dem
# Wurzelordner des Gruppen-Repos ausgefuehrt, z.B.:  Rscript Scripts/modellauswahl/01_kreis_key.R
# Gesamte Pipeline in der richtigen Reihenfolge:  Rscript Scripts/modellauswahl/run_all.R

suppressPackageStartupMessages({
  library(data.table)
})

DIR_RAW   <- "data_raw"
DIR_CLEAN <- "data_processed/modellauswahl"
DIR_FIG   <- "results/modellauswahl/figures"
DIR_TAB   <- "results/modellauswahl/tables"

# Untersuchungszeitraum laut Protokoll (29.10.2026): 2020-2023
YEARS <- 2020:2023

# Berlin: 12 Bezirke (AGS 11001-11012) werden zu einem Kreis (AGS 11000) zusammengefasst
BERLIN_PREFIX <- "11"
BERLIN_AGS    <- "11000"

STATES <- c("01" = "Schleswig-Holstein", "02" = "Hamburg", "03" = "Niedersachsen", "04" = "Bremen",
            "05" = "Nordrhein-Westfalen", "06" = "Hessen", "07" = "Rheinland-Pfalz", "08" = "Baden-Wuerttemberg",
            "09" = "Bayern", "10" = "Saarland", "11" = "Berlin", "12" = "Brandenburg",
            "13" = "Mecklenburg-Vorpommern", "14" = "Sachsen", "15" = "Sachsen-Anhalt", "16" = "Thueringen")

# ---- Altersgruppen (Klima, Mail vom 12.11.2026) ----------------------------------------------
# Beide Schemata sind Vereinigungen der Einzeljahre; age_num 80 steht fuer die Sammelgruppe 80+.
AGE_SCHEMES <- list(
  coarse = list(`0-5` = c(0, 5), `6-17` = c(6, 17), `18-39` = c(18, 39), `40-59` = c(40, 59),
                `60-69` = c(60, 69), `70-79` = c(70, 79), `80+` = c(80, 80)),
  fine   = list(`0-2` = c(0, 2), `3-5` = c(3, 5), `6-9` = c(6, 9), `10-14` = c(10, 14), `15-17` = c(15, 17),
                `18-24` = c(18, 24), `25-29` = c(25, 29), `30-39` = c(30, 39), `40-49` = c(40, 49),
                `50-59` = c(50, 59), `60-69` = c(60, 69), `70-79` = c(70, 79), `80+` = c(80, 80))
)
GR_COARSE <- names(AGE_SCHEMES$coarse)
GR_FINE   <- names(AGE_SCHEMES$fine)

# Einzelalter (0..80) -> Name der Altersgruppe im Schema
age_group <- function(age_num, scheme = "coarse") {
  lo <- vapply(AGE_SCHEMES[[scheme]], `[`, numeric(1), 1)
  names(lo)[findInterval(age_num, lo)]
}

# ---- GENESIS-Flat-Dateien --------------------------------------------------------------------
# Wertsymbole: "-" = genau Null; ".", "x", "/", "...", "" = unbekannt/gesperrt -> NA
num <- function(x) {
  x <- trimws(x)
  out <- suppressWarnings(as.numeric(sub(",", ".", x, fixed = TRUE)))
  out[x == "-"] <- 0
  out
}

# Liest eine GENESIS-Flat-Datei und liefert (ags, year, a2, a3, var, value) fuer die 400 Kreise und YEARS.
# Hamburg/Berlin stehen in vielen Dateien nur als Bundesland (DLAND 02/11); Kreis-Zeilen haben Vorrang.
# Pendler-Dateien (pendler = TRUE) sind Gemeindeebene: "P" + 12-stelliger AGS, Kreis = Stellen 2-6.
read_gen <- function(f, pendler = FALSE, ags_keep = readRDS(file.path(DIR_CLEAN, "kreis_key.rds"))$ags) {
  d  <- fread(file.path(DIR_RAW, f), sep = ";", encoding = "UTF-8",
              colClasses = "character", showProgress = FALSE)
  lv <- d$`1_variable_code`
  at <- d$`1_variable_attribute_code`
  if (pendler) {
    ags  <- substr(at, 2, 6)                       # "P" + 12-stelliger AGS
    prio <- rep(1L, nrow(d)); keep <- lv == "PGEMEIN"
  } else {
    ags <- fcase(lv == "KREISE", substr(at, 1, 5),
                 lv == "DLAND" & at == "02", "02000",   # Hamburg
                 lv == "DLAND" & at == "11", "11000",   # Berlin
                 default = NA_character_)
    prio <- fifelse(lv == "KREISE", 1L, 2L)
    keep <- !is.na(ags) & !(substr(ags, 1, 2) == "11" & ags != "11000")  # keine Berlin-Bezirke
  }
  a2 <- if ("2_variable_attribute_code" %in% names(d)) d$`2_variable_attribute_code` else ""
  a3 <- if ("3_variable_attribute_code" %in% names(d)) d$`3_variable_attribute_code` else ""
  out <- data.table(ags = ags, year = as.integer(substr(d$time, 1, 4)), a2 = a2, a3 = a3,
                    var = d$value_variable_code, value = num(d$value), prio = prio)[keep]
  if (!pendler) {                                  # Kreis-Zeile hat Vorrang vor Bundesland-Zeile
    setorder(out, ags, year, a2, a3, var, prio)
    out <- unique(out, by = c("ags", "year", "a2", "a3", "var"))
  }
  # Eisenach (16056) ist 2020 in GENESIS noch ein eigener Kreis, in den RKI-Daten (Bevoelkerung
  # 2020 = Wartburgkreis + Eisenach) aber schon im Wartburgkreis (16063) enthalten -> zusammenlegen
  out[ags == "16056", ags := "16063"]
  if (!pendler) out <- out[, .(value = if (anyNA(value)) NA_real_ else sum(value)),
                           by = .(ags, year, a2, a3, var)]
  out <- out[ags %in% ags_keep & year %in% YEARS]
  stopifnot(pendler || !anyDuplicated(out, by = c("ags", "year", "a2", "a3", "var")))
  if (pendler) out[, prio := NULL]
  out[]
}

# GENESIS 12411 (Bevoelkerung, beide Geschlechter): Kreis x Jahr x GENESIS-Altersgruppe (alt)
read_genesis_12411 <- function() {
  read_gen("12411-0018 Bevölkerung nach Geschlecht, Altersgruppen und Kreisen.csv")[
    , .(g = sum(value)), by = .(ags, year, alt = a3)]
}

# ---- Modelle ---------------------------------------------------------------------------------
# Seit der Verteilung der Faelle ohne Altersangabe (02_clean_covid.R) sind die Fallzahlen nicht mehr
# ganzzahlig. glm.nb warnt dann bei jeder Anpassung "non-integer x = ..." - die Warnung kommt nur aus
# der AIC-Berechnung des Poisson-Startfits (glm.nb > glm.fitter > aic > dpois). Koeffizienten, Theta
# und AIC des NB-Modells nutzen die stetige Loglik (lgamma) und sind nicht betroffen (geprueft 21.11.2026).
# quiet_nonint() unterdrueckt nur diese eine Warnung; alle anderen bleiben sichtbar.
quiet_nonint <- function(expr) withCallingHandlers(expr, warning = function(w)
  if (startsWith(conditionMessage(w), "non-integer x")) invokeRestart("muffleWarning"))

# Kreis-Kovariaten der NB-Modelle (12, 14, 16): Kreistyp (Referenz: kreisfreie Grossstadt), BBSR-Lage und
# z-standardisierte Kovariaten (Mittelwerte 2020-2023; vorlaeufige Auswahl, siehe reports/modellauswahl/phase3_modelle.md).
# Das Bundesland (state) kommt aus den Falldaten bzw. wird im Skript ergaenzt.
model_covariates <- function() {
  z  <- function(x) as.numeric(scale(x))
  cv <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))[
    , .(ags, kreistyp_code, lage_code, dichte_mean, sgb2 = sgb2_je1000_mean, p65 = anteil_65p_mean,
        tour = uebernachtungen_je_einw_mean)]
  cv[, `:=`(kt = factor(kreistyp_code, 1:4, c("T1_Grossstadt", "T2_staedtisch", "T3_laendl_Verdichtung", "T4_duenn_besiedelt")),
            lage = factor(lage_code, 1:4, paste0("L", 1:4)),
            z_ldichte = z(log(dichte_mean)), z_sgb2 = z(sgb2), z_p65 = z(p65), z_ltour = z(log(tour)))]
  stopifnot(nrow(cv) == 400, !anyNA(cv[, .(kt, lage, z_ldichte, z_sgb2, z_p65, z_ltour)]))
  cv[]
}
# Hauptmodell m1 (Offset: RKI-Bevoelkerung der Phase)
F_M1 <- cases ~ kt + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki))

# Adjustierung der GAMs mit Einzeljahren (13_gam_age.R, 18_gam_age_density.R), seit 24.11.2026 wie im Hauptmodell
# (22_main_model_tmb.R) altersspezifisch: Bundesland als Fixed Effect plus glatte Abweichung je Land ueber das Alter
# (s(age, by = state), je Land zentriert), Kovariaten mit glatt altersabhaengiger Steigung (numerische by-Glaetter
# sind nicht zentriert und enthalten den linearen Effekt bereits, daher kein zusaetzliches z_*), Kreis-Zufallseffekt.
# Vorher: state + z_sgb2 + z_p65 + z_ltour (gleiche Wirkung in allen Altersjahren).
K_GAM_ADJ <- 8
GAM_COV <- sprintf(paste("state + s(age, by = state, k = %1$d) + s(age, by = z_sgb2, k = %1$d) + s(age, by = z_p65, k = %1$d)",
                         "+ s(age, by = z_ltour, k = %1$d) + s(ags, bs = 're')"), K_GAM_ADJ)

# 26 Strukturmerkmale der Kreise fuer PCA und Clusteranalyse (19, 21): Mittelwerte 2020-2023, ohne die Raummasse
# (Dichte, Kreistyp, Lage). Fehlende Werte: Median des Bundeslands, wo das Land keinen Wert hat bundesweit
# (oeffentl. Beschaeftigte fehlen fuer Hamburg, Bremen, Bremerhaven, Berlin; Schutzsuchende fuer das Saarland,
# Kassel und Spree-Neisse). Tourismus logarithmiert. Attribut "n_imputiert": Anzahl ersetzter Werte je Merkmal.
STRUCT_VARS <- c(anteil_0_5 = "anteil_0_5_mean", anteil_6_17 = "anteil_6_17_mean", anteil_18_39 = "anteil_18_39_mean",
  anteil_65p = "anteil_65p_mean", sgb2 = "sgb2_je1000_mean", grundsich_alter = "grundsicherung_alter_je1000_65p_mean",
  hilfe_lu = "hilfe_lebensunterhalt_je1000_mean", asylbl = "asylbewerberleistung_je1000_mean",
  alo = "alo_je100_15_64_mean", alo_jung = "alo_jung_je100_15_24_mean", alo_langzeit = "alo_langzeit_anteil_mean",
  alo_ausl = "alo_auslaender_anteil_mean", oed_besch = "oed_beschaeftigte_vze_je1000_mean",
  pflegeheim_plaetze = "pflegeheim_plaetze_je1000_65p_mean", pflegeheim_pers = "pflegeheim_personal_je1000_65p_mean",
  pflegedienst_pers = "pflegedienst_personal_je1000_65p_mean", kita_plaetze = "kita_plaetze_je1000_0_13_mean",
  kita_pers = "kita_paed_personal_je1000_0_13_mean", schutzsuchende = "schutzsuchende_je1000_mean",
  log_tourismus = "uebernachtungen_je_einw_mean", betriebe = "betriebe_je100000_mean",
  ohne_abschluss = "schule_ohne_abschluss_anteil_mean", hochschulreife = "schule_hochschulreife_anteil_mean",
  einpendler = "pendler_ein_je1000_mean", auspendler = "pendler_aus_je1000_mean", pendlersaldo = "pendler_saldo_je1000_mean")
struct_matrix <- function() {
  X <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))[, c("ags", "state", STRUCT_VARS), with = FALSE]
  setnames(X, STRUCT_VARS, names(STRUCT_VARS))
  X[, log_tourismus := log(log_tourismus)]
  n_imp <- X[, lapply(.SD, function(v) sum(is.na(v))), .SDcols = names(STRUCT_VARS)]
  for (v in names(STRUCT_VARS)) {
    X[, (v) := fifelse(is.na(get(v)), median(get(v), na.rm = TRUE), get(v)), by = state]   # Median des Landes
    X[, (v) := fifelse(is.na(get(v)), median(get(v), na.rm = TRUE), get(v))]              # sonst bundesweit
  }
  stopifnot(nrow(X) == 400, !anyNA(X))
  setattr(X, "n_imputiert", n_imp)
  X[]
}
