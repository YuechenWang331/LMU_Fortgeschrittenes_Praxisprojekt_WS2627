# Wellen/Phasen festlegen und die kumulative Inzidenz je Phase und Altersgruppe tabellieren.
# Phasengrenzen: RKI-Phaseneinteilung, ergaenzt um eigene Grenzen ab Sommer 2022 (siehe unten und reports/modellauswahl/phase2_deskriptiv.md).
# Ausgabe: data_processed/modellauswahl/waves.rds, results/modellauswahl/tables/waves_summary.csv
# Abbildungen (fig01-fig04) erzeugt Scripts/modellauswahl/11_figures.R.

source("Scripts/modellauswahl/00_setup.R")

ag  <- readRDS(file.path(DIR_CLEAN, "covid_agegrp.rds"))

# ---- 1. Phasentabelle (Wochenstart = Montag, Start einschliesslich) ---------------------------------
# Entscheidung (21.11.2026): RKI-Phaseneinteilung als Hauptdefinition.
# Quelle: RKI, Epidemiologisches Bulletin 38/2022, Tab. 1 (Stand 15.09.2022), siehe Scripts/modellauswahl/10_plot_rki_phases.R.
# Die RKI-Grenzen (KW -> Montag) gelten fuer V20, W1-W5, S20, S21 und den Beginn von W6 (KW 22/2022).
# Das Ende der RKI-Phase 8 ("sechste Welle") ist nicht definiert; die Aufteilung ab Sommer 2022
# (Ende W6, Ende W7, W8, R23) bleibt die eigene, aus den Minima der bundesweiten Inzidenz abgeleitete Grenze.
# W7 endet am Minimum Ende November 2022 (Woche 21.11.2022, geglaettet 208 je 100.000) nach dem Herbstgipfel (Okt. 2022).
# W8 = Winter 2022/23 (Dez.-Buckel und Feb.-Buckel, ca. 76 % der Faelle der Restphase); ab 13.03.2023 Restphase R23 (sehr niedrig).
phases <- data.table(
  start = as.Date(c("2019-12-30", "2020-03-02", "2020-05-18", "2020-09-28", "2021-03-01", "2021-06-14", "2021-08-02",
                    "2021-12-27", "2022-05-30", "2022-08-29", "2022-11-21", "2023-03-13")),
  id    = c("V20", "W1", "S20", "W2", "W3", "S21", "W4", "W5", "W6", "W7", "W8", "R23"),
  name  = c("Vorphase (sporadische Faelle)", "Welle 1 (Wildtyp)", "Sommerplateau 2020", "Welle 2 (Winter 2020/21)",
            "Welle 3 (Alpha)", "Sommerplateau 2021", "Welle 4 (Delta)", "Welle 5 (Omikron BA.1/BA.2)",
            "Welle 6 (Omikron BA.5, Sommer 2022)", "Welle 7 (Herbst 2022)", "Welle 8 (Winter 2022/23)", "Restphase 2023"),
  type  = c("Pause", "Welle", "Pause", "Welle", "Welle", "Pause", "Welle", "Welle", "Welle", "Welle", "Welle", "Pause"),
  source = c("eigen", rep("RKI", 7), "RKI (Beginn), Ende eigen", "eigen", "eigen", "eigen")
)
phases[, end := shift(start, type = "lead") - 7]       # letzter Wochenstart der Phase
phases[is.na(end), end := as.Date("2023-12-25")]
phases[, weeks := as.integer((end - start) / 7) + 1L]
weeks <- sort(unique(ag$week))
wk <- data.table(week = weeks)
wk[, phase := phases$id[findInterval(as.numeric(week), as.numeric(phases$start))]]
stopifnot(!anyNA(wk$phase), nrow(wk) == 209)
saveRDS(list(phases = phases, week_phase = wk), file.path(DIR_CLEAN, "waves.rds"))
print(phases[, .(id, name, type, start, end, weeks)])

# ---- 2. Phasenvergleich: kumulative Inzidenz je Phase und Altersgruppe ------------------------------------
ph <- merge(ag[scheme == "coarse"], wk, by = "week")
# kumulative Inzidenz je Phase = Summe der Faelle / mittlere Bevoelkerung der Phase * 1e5
cum <- ph[, .(cases = sum(cases)), by = .(phase, grp)]
popg <- ph[, .(pop = sum(pop_rki) / uniqueN(week)), by = .(phase, grp)]
cum <- merge(cum, popg, by = c("phase", "grp"))
cum[, cuminc := cases / pop * 1e5]
tot <- cum[, .(cases = sum(cases), pop = sum(pop)), by = phase][, `:=`(grp = "Gesamt", cuminc = cases / pop * 1e5)]
cum <- rbind(cum, tot[, names(cum), with = FALSE])
wide <- dcast(cum, phase ~ grp, value.var = "cuminc")
wide <- merge(phases[, .(phase = id, name, start, end, weeks)], wide, by = "phase")
wide <- wide[match(phases$id, phase)]
cols <- c("Gesamt", GR_COARSE)
wide[, (cols) := lapply(.SD, round), .SDcols = cols]
cat("\n== Kumulative gemeldete Inzidenz je 100.000 pro Phase und Altersgruppe ==\n"); print(wide[, c("phase", cols), with = FALSE])
fwrite(wide, file.path(DIR_TAB, "waves_summary.csv"))
cat("\ngespeichert: waves.rds, waves_summary.csv\n")
