# Stadt-Land-Vergleich: Inzidenz je Altersgruppe und Welle nach Raumtyp, plus
# explorative Rangkorrelationen mit den Strukturvariablen (Kreisebene, n = 400).
# Ausgabe: data_processed/modellauswahl/covid_wave_kreis.rds (Kreis x Phase x Altersgruppe),
#          results/modellauswahl/tables/urban_*.csv, corr_wave_age_struct.csv, corr_within_state.csv
# Abbildungen (fig05-fig07, fig09) erzeugt Scripts/modellauswahl/11_figures.R aus diesen Tabellen.
# Achtung: Kreisebene = oekologische Analyse, Zusammenhaenge gelten fuer Kreise, nicht fuer Personen.
# Raummasse (Entscheidung 21.11.2026): Ost/West entfaellt, stattdessen Bundesland als Kontrolle (Spalte state);
# Dichte-Quartile entfallen; Hauptmass Kreistyp,
# Robustheit log(Dichte) stetig, Lage als Zusatz. Kreisart nur deskriptiv.
# Beide Altersschemata (grob/fein, Klima) werden gerechnet (Entscheidung 21.11.2026); Dateien des feinen
# Schemas haben das Suffix _fine (covid_wave_kreis_fine.rds, urban_*_fine.csv, corr_*_fine.csv).

source("Scripts/modellauswahl/00_setup.R")   # GR_COARSE, GR_FINE, STATES

ag_all <- readRDS(file.path(DIR_CLEAN, "covid_agegrp.rds"))
wv    <- readRDS(file.path(DIR_CLEAN, "waves.rds"))
const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
WAVES <- wv$phases[type == "Welle", id]

run_scheme <- function(sch, GR, sfx) {
  cat("\n##########  Altersschema:", sch, " ##########\n")
  ag <- ag_all[scheme == sch]

  # ---- 1. Kumulative Inzidenz je Kreis x Phase x Altersgruppe ----------------------------------------
  d  <- merge(ag, wv$week_phase, by = "week")
  kw <- d[, .(cases = sum(cases), pop_rki = mean(pop_rki), pop_gen = mean(pop_gen), n_weeks = .N),
          by = .(ags, phase, grp)]
  kw[, `:=`(cuminc = cases / pop_rki * 1e5, cuminc_gen = cases / pop_gen * 1e5)]
  kw[, grp := factor(grp, levels = GR)]
  kw[, state := const$state[match(ags, const$ags)]]
  kw[, state_name := STATES[state]]
  saveRDS(kw, file.path(DIR_CLEAN, paste0("covid_wave_kreis", sfx, ".rds")))

  # ---- 2. Raumtypen -----------------------------------------------------------------------------------------
  const[, kreistyp := factor(kreistyp_code, 1:4, c("1 kreisfreie Grossstadt", "2 staedtischer Kreis",
                                                    "3 laendl. Kreis m. Verdichtung", "4 duenn besiedelt laendl."))]
  cat("Kreisart x BBSR-Kreistyp:\n"); print(table(const$kreisart, const$kreistyp_code))
  cat("\nRangkorrelation (Spearman) der Raummasse untereinander:\n")
  print(round(cor(const[, .(dichte = dichte_mean, kreistyp = kreistyp_code, lage = lage_code,
                            sk = as.integer(kreisart == "Stadtkreis"))], method = "spearman"), 2))
  cat("\nDichte (Einw./km2) je BBSR-Kreistyp: Median / Min / Max\n")
  print(const[, .(n = .N, median = round(median(dichte_mean)), min = round(min(dichte_mean)), max = round(max(dichte_mean))), by = kreistyp][order(kreistyp)])

  # ---- 3. Welle x Altersgruppe: Verhaeltnis zur Bundesinzidenz je Raumtyp ----------------------------------------
  agg_ratio <- function(by_col, dt = merge(kw, const[, c("ags", by_col), with = FALSE], by = "ags")) {
    x <- dt[phase %in% WAVES, .(cases = sum(cases), pop = sum(pop_rki)), by = c(by_col, "phase", "grp")]
    nat <- dt[phase %in% WAVES, .(cases = sum(cases), pop = sum(pop_rki)), by = .(phase, grp)][, nat := cases / pop][, c("phase", "grp", "nat")]
    x <- merge(x, nat, by = c("phase", "grp"))
    x[, `:=`(cuminc = cases / pop * 1e5, ratio = cases / pop / nat)]
    x[, phase := factor(phase, levels = WAVES)]
    x
  }
  rt <- agg_ratio("kreistyp")
  fwrite(rt[, .(kreistyp, phase, grp, cuminc = round(cuminc), ratio = round(ratio, 3))][order(kreistyp, phase, grp)],
         file.path(DIR_TAB, paste0("urban_kreistyp_wave_age", sfx, ".csv")))

  rk <- agg_ratio("kreisart")
  fwrite(rk[, .(kreisart, phase, grp, cuminc = round(cuminc), ratio = round(ratio, 3))][order(kreisart, phase, grp)],
         file.path(DIR_TAB, paste0("urban_kreisart_wave_age", sfx, ".csv")))
  cat("\nStadtkreis relativ zu Landkreis (Verhaeltnis der kumulativen Inzidenz), Welle x Altersgruppe:\n")
  sl <- dcast(rk, phase + grp ~ kreisart, value.var = "cuminc")[, ratio_SK_LK := round(Stadtkreis / Landkreis, 2)]
  print(dcast(sl, grp ~ phase, value.var = "ratio_SK_LK")[match(GR, grp)])

  # ---- 4. Explorative Rangkorrelationen Kreis x Welle x Altersgruppe -----------------------------------------------
  covars <- c(dichte = "dichte_mean", kreistyp = "kreistyp_code", lage = "lage_code", anteil_65p = "anteil_65p_mean",
              anteil_0_5 = "anteil_0_5_mean", anteil_18_39 = "anteil_18_39_mean", sgb2 = "sgb2_je1000_mean",
              alo = "alo_je100_15_64_mean", schutzsuchende = "schutzsuchende_je1000_mean",
              pendler_saldo = "pendler_saldo_je1000_mean", tourismus = "uebernachtungen_je_einw_mean",
              hochschulreife = "schule_hochschulreife_anteil_mean", kita_plaetze = "kita_plaetze_je1000_0_13_mean")
  cv <- const[, c("ags", unname(covars)), with = FALSE]
  setnames(cv, unname(covars), names(covars))
  x <- merge(kw[phase %in% WAVES], cv, by = "ags")
  cors <- rbindlist(lapply(names(covars), function(v) {
    x[, .(rho = suppressWarnings(cor(cuminc, get(v), method = "spearman", use = "complete.obs")),
          n = sum(!is.na(get(v)) & !is.na(cuminc))), by = .(phase, grp)][, covariate := v]
  }))
  cors[, `:=`(phase = factor(phase, levels = WAVES), covariate = factor(covariate, levels = rev(names(covars))))]
  fwrite(cors[, .(phase, grp, covariate, rho = round(rho, 3), n)][order(phase, grp, covariate)],
         file.path(DIR_TAB, paste0("corr_wave_age_struct", sfx, ".csv")))

  # Rangkorrelation innerhalb der Bundeslaender: Raenge global bilden, dann je Bundesland zentrieren.
  # Entfernt Unterschiede zwischen den Laendern (Kontrolle fuer Bundesland); Kreise aus Stadtstaaten
  # (HH, B) fallen dabei weg, kleine Laender tragen wenig bei.
  within_rho <- function(y, z, g) {
    ok <- !is.na(y) & !is.na(z)
    y <- rank(y[ok]); z <- rank(z[ok]); g <- g[ok]
    cor(y - ave(y, g), z - ave(z, g))
  }
  wcors <- rbindlist(lapply(names(covars), function(v) {
    x[, .(rho = suppressWarnings(cor(cuminc, get(v), method = "spearman", use = "complete.obs")),
          rho_im_land = within_rho(cuminc, get(v), state)), by = .(phase, grp)][, covariate := v]
  }))
  fwrite(wcors[, .(phase, grp, covariate, rho = round(rho, 3), rho_im_land = round(rho_im_land, 3))][order(phase, grp, covariate)],
         file.path(DIR_TAB, paste0("corr_within_state", sfx, ".csv")))
  cat("\n== Kreistyp: Rangkorrelation gesamt vs. innerhalb der Bundeslaender ==\n")
  print(dcast(wcors[covariate == "kreistyp"], grp ~ phase, value.var = c("rho", "rho_im_land"))[match(GR, grp)][,
        lapply(.SD, function(z) if (is.numeric(z)) round(z, 2) else z)])
  cat("\nAnzahl Kreise je Korrelation (min):", min(cors$n), "\n")
  cat("\n== Rangkorrelation mit Kreistyp (1 Grossstadt ... 4 duenn besiedelt) ==\n")
  print(dcast(cors[covariate == "kreistyp"], grp ~ phase, value.var = "rho")[match(GR, grp)][, (WAVES) := lapply(.SD, round, 2), .SDcols = WAVES])
  cat("\ngespeichert (Schema ", sch, "): covid_wave_kreis", sfx, ".rds, urban_*", sfx, ".csv, corr_*", sfx, ".csv\n", sep = "")
}

run_scheme("coarse", GR_COARSE, "")
run_scheme("fine",   GR_FINE,   "_fine")
