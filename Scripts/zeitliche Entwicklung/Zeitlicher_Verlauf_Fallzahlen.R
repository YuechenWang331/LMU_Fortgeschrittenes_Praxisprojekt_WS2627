# LMU Fortgeschrittenes Praxisprojekt WS 2026/27
# Qian - Verlauf der gemeldeten COVID-19-Faelle ueber die Zeit (2020-2023)
# Explorative Analyse: nur Gesamtdeutschland, KEINE Alters-/Kreistypvergleiche.
# Nur lokal ausfuehren; die zugrunde liegenden Daten nicht an KI-Dienste senden.
# Start im Stammverzeichnis des RStudio-Projekts:
# source("Scripts/Qian01_Zeitlicher_Verlauf_Fallzahlen.R")

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

# 1. Daten und Output ---------------------------------------------------------
input_file <- "data_processed/rki_weekly_long.rds"
out_dir <- "results/zeitliche_entwicklung/qian"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(file.exists(input_file))

w <- as.data.table(readRDS(input_file))
required <- c("geo_code", "age_group", "week_start", "iso_year", "iso_week", "count")
stopifnot(all(required %in% names(w)))

w[, `:=`(
  geo_code = as.character(geo_code),
  age_group = as.character(age_group),
  week_start = as.Date(week_start),
  iso_year = as.integer(iso_year),
  iso_week = as.integer(iso_week),
  count = as.numeric(count)
)]
w <- w[iso_year %in% 2020:2023]

# 2. Plausibilitaetspruefung --------------------------------------------------
if (anyNA(w[, .(geo_code, week_start, iso_year, iso_week)])) {
  stop("Fehlende Gebiets- oder Wochenkennungen.")
}
if (any(!is.finite(w$count)) || any(w$count < 0)) {
  stop("Fehlende, unendliche oder negative Fallzahlen: vor Auswertung klaeren.")
}
if (anyDuplicated(w, by = c("geo_code", "age_group", "week_start"))) {
  stop("Doppelte Kreis-Alter-Woche-Schluessel gefunden.")
}

expected_weeks <- seq(as.Date("2019-12-30"), as.Date("2023-12-25"), by = "week")
if (uniqueN(w$geo_code) != 400L) stop("Nicht genau 400 Kreise vorhanden.")
if (!setequal(unique(w$week_start), expected_weeks)) {
  stop("ISO-Wochen 2020-2023 sind unvollstaendig.")
}
if (any(format(unique(w$week_start), "%u") != "1")) {
  stop("week_start enthaelt andere Wochentage als Montag.")
}
if (!setequal(unique(w$age_group), c(as.character(0:79), "80+", "NA"))) {
  stop("Unerwartete Alterskategorien: unbekanntes Alter pruefen.")
}
if (nrow(w) != 400L * 82L * length(expected_weeks)) {
  stop("Unerwartete Zeilenzahl: fehlende Kreis-Alter-Woche-Kombinationen moeglich.")
}

# 3. Deutschlandweite Wochenfallzahlen ---------------------------------------
# Da die Fragestellung ALLE gemeldeten Faelle betrifft, wird auch die
# Alterskategorie "NA" (Alter unbekannt) fuer die GESAMTFALLZAHL gezaehlt.
w[, alter_unbekannt := is.na(age_group) | age_group == "NA"]
weekly <- w[, .(
  faelle_gesamt = sum(count),
  faelle_alter_bekannt = sum(count[!alter_unbekannt]),
  faelle_alter_unbekannt = sum(count[alter_unbekannt])
), by = .(iso_year, iso_week, week_start)]
setorder(weekly, week_start)

stopifnot(
  nrow(weekly) == 209L,
  all(weekly$faelle_gesamt == weekly$faelle_alter_bekannt +
        weekly$faelle_alter_unbekannt),
  isTRUE(all.equal(sum(weekly$faelle_gesamt), sum(w$count)))
)
weekly[, anteil_alter_unbekannt_prozent := fifelse(
  faelle_gesamt > 0,
  100 * faelle_alter_unbekannt / faelle_gesamt,
  NA_real_
)]

# 4. Jahresuebersicht / deskriptive Jahresmaxima -----------------------------
# ISO-Meldejahr: kann eine im Dezember des Vorjahres beginnende Woche enthalten.
annual <- weekly[, {
  j <- which.max(faelle_gesamt)
  .(
    anzahl_wochen = .N,
    faelle_gesamt = sum(faelle_gesamt),
    mittlere_wochenfaelle = mean(faelle_gesamt),
    median_wochenfaelle = median(faelle_gesamt),
    maximale_wochenfaelle = faelle_gesamt[j],
    maximum_kw = iso_week[j],
    maximum_wochenbeginn = week_start[j],
    faelle_alter_unbekannt = sum(faelle_alter_unbekannt)
  )
}, by = iso_year]
setorder(annual, iso_year)
annual[, anteil_alter_unbekannt_prozent := fifelse(
  faelle_gesamt > 0,
  100 * faelle_alter_unbekannt / faelle_gesamt,
  NA_real_
)]

fwrite(weekly, file.path(out_dir, "Qian01_Nationale_Wochenfaelle.csv"))
fwrite(annual, file.path(out_dir, "Qian02_Jahresuebersicht.csv"))

# 5. Eine klare Grafik fuer die persoenliche Teilaufgabe ---------------------
peak_weeks <- weekly[, .SD[which.max(faelle_gesamt)], by = iso_year]
# Jahresmaxima werden als Punkte markiert; keine automatische Wellendefinition.

plot_main <- ggplot(weekly, aes(x = week_start, y = faelle_gesamt)) +
  geom_line(color = "#215E83", linewidth = 0.75) +
  geom_point(data = peak_weeks, color = "#B34B3C", size = 2.4) +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE,
                                                 big.mark = ".", trim = TRUE)) +
  labs(
    title = "Gemeldete COVID-19-Faelle in Deutschland, 2020-2023",
    subtitle = "Wochenfallzahlen nach ISO-Meldewoche; Punkte: jeweiliges Jahresmaximum",
    x = "Meldewoche (Beginn: Montag)",
    y = "Gemeldete Faelle pro Woche",
    caption = paste(
      "Quelle: RKI/SurvStat via rsurvstat; 400 harmonisierte Kreise.",
      "Inklusive unbekannter Altersangaben; Datenstand des lokalen Exports pruefen."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(out_dir, "Qian03_Wochenfaelle_Deutschland.png"),
       plot_main, width = 12, height = 5.8, dpi = 200)

cat("\nQian: Zeitlicher Verlauf der COVID-19-Faelle\n")
cat("Wochen:", nrow(weekly), "| Kreise:", uniqueN(w$geo_code), "\n")
cat("Dateien im Ordner:", out_dir, "\n\n")
print(annual)
cat("\nHinweis: Jahresmaxima sind keine automatisch bestimmten Infektionswellen.\n")
cat("ISO-Woche 1/2020 beginnt am 30.12.2019.\n")
