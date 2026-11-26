# RKI-Phaseneinteilung (offizielle Wellen und Unterphasen) als Tabelle (KW -> Datum).
# Quelle der Phasen: RKI, Epidemiologisches Bulletin 38/2022, Tab. 1 (Stand: 15.09.2022),
#   "Dritte Aktualisierung der Retrospektiven Phaseneinteilung der COVID-19-Pandemie in Deutschland".
# Ausgabe: data_processed/modellauswahl/rki_phases.rds, results/modellauswahl/tables/rki_phases.csv
# Die fruehere Vergleichsgrafik (RKI-Phasen vs. eigene Wellen) wurde immer von Scripts/modellauswahl/11_figures.R
# ueberschrieben (fig08 = Projekt-Wellen W1-W8) und ist deshalb entfallen.

source("Scripts/modellauswahl/00_setup.R")

# ---- 1. Phasentabelle (KW / Jahr) --------------------------------------------------------------
ph <- data.table(
  phase = c("0", "1", "2", "2a", "2b", "3", "4", "5", "6", "6a", "6b", "7", "7a", "7b", "8"),
  name  = c("sporadische Faelle", "Erste Welle", "Sommerplateau 2020", "Sommerplateau 2020 (a)", "Sommerplateau 2020 (b)",
            "Zweite Welle", "Dritte Welle (Alpha)", "Sommerplateau 2021", "Vierte Welle (Delta)",
            "Delta Sommer", "Delta Herbst/Winter", "Fuenfte Welle (Omikron BA.1/BA.2)",
            "Omikron BA.1", "Omikron BA.2", "Sechste Welle (Omikron BA.5)"),
  type  = c("Vorphase", "Welle", "Plateau", "Unterphase", "Unterphase", "Welle", "Welle", "Plateau", "Welle",
            "Unterphase", "Unterphase", "Welle", "Unterphase", "Unterphase", "Welle"),
  kw_start = c(5, 10, 21, 21, 31, 40, 9, 24, 31, 31, 40, 52, 52, 9, 22),
  y_start  = c(2020, 2020, 2020, 2020, 2020, 2020, 2021, 2021, 2021, 2021, 2021, 2021, 2021, 2022, 2022),
  kw_end   = c(9, 20, 39, 30, 39, 8, 23, 30, 51, 39, 51, 21, 8, 21, NA),
  y_end    = c(2020, 2020, 2020, 2020, 2020, 2021, 2021, 2021, 2021, 2021, 2021, 2022, 2022, 2022, NA)
)
# Montag der ISO-Kalenderwoche
iso_monday <- function(year, kw) {
  jan4 <- as.Date(sprintf("%d-01-04", year))
  jan4 - (as.integer(format(jan4, "%u")) - 1) + 7 * (kw - 1)
}
ph[, start := iso_monday(y_start, kw_start)]
ph[, end   := fifelse(is.na(kw_end), as.Date(NA), iso_monday(y_end, kw_end) + 6)]   # Sonntag der End-KW
ph[, end_open := is.na(kw_end)]                                                   # Phase 8: Ende nicht definiert
saveRDS(ph, file.path(DIR_CLEAN, "rki_phases.rds"))
fwrite(ph, file.path(DIR_TAB, "rki_phases.csv"))
print(ph[, .(phase, name, type, start, end)])
cat("gespeichert: data_processed/modellauswahl/rki_phases.rds, results/modellauswahl/tables/rki_phases.csv\n")
