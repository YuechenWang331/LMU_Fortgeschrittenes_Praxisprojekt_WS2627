# Korrigierte Version: Facet-spezifische W6-Markierung (nur 2022),
# um die x-Achsen 2020, 2021 und 2023 nicht zu verzerren.
# LMU Fortgeschrittenes Praxisprojekt
# Zeitliche Entwicklung: Vergleich der gemeldeten Wochenfaelle mit RKI-Phasen
# Ausfuehrung aus dem RStudio-Projektstamm:
# source("Scripts/zeitliche Entwicklung/06_RKI_Phasenvergleich.R")
#
# Daten bleiben lokal. Keine Dateien werden an externe Dienste gesendet.
# Quelle der retrospektiven Phasengrenzen:
# RKI, Epidemiologisches Bulletin 38/2022, S. 4, Tabelle 1:
# https://edoc.rki.de/bitstream/handle/176904/10260/EB-38-2022-Phaseneinteilung.pdf?sequence=1
# Anmerkung: RKI-Welle 6 beginnt in KW 22/2022; ihr Ende war im
# Quellenstand 15.09.2022 noch NICHT festgelegt. Das Skript weist ihr
# deshalb keine willkuerliche Endwoche zu.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

input_file <- "results/zeitliche_entwicklung/Zeitverlauf_Wochenfaelle_Deutschland.csv"
output_dir <- "results/zeitliche_entwicklung"
stopifnot(file.exists(input_file))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

weekly_cases <- fread(input_file)
expected <- c("iso_year", "iso_week", "week_start", "weekly_cases")
stopifnot(all(expected %in% names(weekly_cases)))
weekly_cases[, `:=`(
  iso_year = as.integer(iso_year),
  iso_week = as.integer(iso_week),
  week_start = as.Date(week_start),
  weekly_cases = as.numeric(weekly_cases)
)]
setorder(weekly_cases, week_start)
stopifnot(
  nrow(weekly_cases) == 209L,
  !anyNA(weekly_cases[, ..expected]),
  !anyDuplicated(weekly_cases, by = c("iso_year", "iso_week")),
  all(is.finite(weekly_cases$weekly_cases) & weekly_cases$weekly_cases >= 0),
  setequal(weekly_cases$iso_year, 2020:2023)
)

# RKI-Wellen mit DEFINIERTEM Anfang und Ende (Stand 15.09.2022).
# Sommerplateaus sind keine Wellen und werden hier nicht als Wellen gezaehlt.
rki_waves <- data.table(
  wave = 1:5,
  description = c(
    "Erste COVID-19-Welle",
    "Zweite COVID-19-Welle",
    "Dritte COVID-19-Welle (Alpha)",
    "Vierte COVID-19-Welle (Delta)",
    "Fuenfte COVID-19-Welle (Omikron BA.1/BA.2)"
  ),
  start_year = c(2020L, 2020L, 2021L, 2021L, 2021L),
  start_week = c(10L, 40L, 9L, 31L, 52L),
  end_year = c(2020L, 2021L, 2021L, 2021L, 2022L),
  end_week = c(20L, 8L, 23L, 51L, 21L)
)

key_week <- paste(weekly_cases$iso_year, weekly_cases$iso_week, sep = "-")
start_idx <- match(paste(rki_waves$start_year, rki_waves$start_week, sep = "-"), key_week)
end_idx <- match(paste(rki_waves$end_year, rki_waves$end_week, sep = "-"), key_week)
stopifnot(!anyNA(start_idx), !anyNA(end_idx))
rki_waves[, `:=`(
  start_date = weekly_cases$week_start[start_idx],
  end_date = weekly_cases$week_start[end_idx] + 6
)]

# Nur deskriptive Auswertung innerhalb der von RKI definierten Wellen.
wave_summary <- rbindlist(lapply(seq_len(nrow(rki_waves)), function(i) {
  r <- rki_waves[i]
  subset <- weekly_cases[week_start >= r$start_date & week_start <= r$end_date]
  peak <- subset[which.max(weekly_cases)]
  data.table(
    welle = r$wave,
    rki_bezeichnung = r$description,
    beginn = as.character(r$start_date),
    ende = as.character(r$end_date),
    anzahl_wochen = nrow(subset),
    gemeldete_faelle = sum(subset$weekly_cases),
    maximum_meldewoche = sprintf("%04d-KW%02d", peak$iso_year, peak$iso_week),
    maximum_wochenbeginn = as.character(peak$week_start),
    maximum_wochenfaelle = peak$weekly_cases
  )
}))

fwrite(wave_summary, file.path(output_dir, "RKI_Wellen_1_bis_5_Zusammenfassung.csv"))
fwrite(rki_waves, file.path(output_dir, "RKI_Phasengrenzen_1_bis_5.csv"))

# RKI-Welle 6: nur der definierte Beginn, keine erfundene Endwoche.
wave6_start <- weekly_cases[iso_year == 2022L & iso_week == 22L, week_start]
stopifnot(length(wave6_start) == 1L)

# Teilstuecke der RKI-Wellen je ISO-Jahr fuer den Jahresfacetten-Plot.
# Die kleineren y-Skalen sind NUR zum Erkennen der zeitlichen Muster gedacht.
parts <- rbindlist(lapply(2020:2023, function(y) {
  year_data <- weekly_cases[iso_year == y]
  year_start <- min(year_data$week_start)
  year_end <- max(year_data$week_start) + 6
  rbindlist(lapply(seq_len(nrow(rki_waves)), function(i) {
    r <- rki_waves[i]
    left <- max(r$start_date, year_start)
    right <- min(r$end_date, year_end)
    if (left > right) return(NULL)
    data.table(iso_year = y, wave = r$wave,
               xmin = as.Date(left), xmax = as.Date(right),
               midpoint = as.Date((as.numeric(left) + as.numeric(right))/2,
                                  origin = "1970-01-01"))
  }), fill = TRUE)
}), fill = TRUE)

# W6-Markierung ausschliesslich im 2022-Facet anzeigen.
# Ohne iso_year wird geom_vline in allen Facets wiederholt und zieht
# die freien x-Achsen fuer 2020, 2021 und 2023 unnoetig in die Laenge.
wave6_marker <- data.table(
  iso_year = 2022L,
  marker_date = as.Date(wave6_start)
)

# Plot: Schatten = zeitlich definierte Wellen 1-5; gestrichelte Linie = Anfang Welle 6.
plot_waves <- ggplot(weekly_cases, aes(x = week_start, y = weekly_cases)) +
  geom_rect(
    data = parts,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
    inherit.aes = FALSE, fill = "#B7D3E4", alpha = 0.40
  ) +
  geom_line(color = "#215E83", linewidth = 0.75) +
  geom_text(
    data = parts,
    aes(x = midpoint, y = Inf, label = paste0("W", wave)),
    inherit.aes = FALSE, vjust = 1.2, size = 3.0, color = "#34495E"
  ) +
  geom_vline(
    data = wave6_marker,
    aes(xintercept = as.numeric(marker_date)),
    inherit.aes = FALSE,
    linetype = "dashed", color = "#B34B3C"
  ) +
  facet_wrap(~iso_year, scales = "free", ncol = 2) +
  scale_x_date(date_breaks = "3 months", date_labels = "%m/%y") +
  scale_y_continuous(labels = function(x) format(
    round(x), big.mark = ".", scientific = FALSE, trim = TRUE
  )) +
  labs(
    title = "Gemeldete COVID-19-Faelle und RKI-Welleneinteilung",
    subtitle = paste(
      "Schattiert: Wellen 1-5 gemaess RKI (Stand 15.09.2022).",
      "Gestrichelte Linie: Beginn der sechsten Welle (KW 22/2022)."
    ),
    x = "Meldewoche (Montag)", y = "Gemeldete Faelle pro Woche",
    caption = paste(
      "Quelle: RKI/SurvStat via rsurvstat; RKI Epid. Bull. 38/2022, Tab. 1.",
      "Freie y-Skalen; W6-Ende im Quellenstand offen; 2023 ohne Phasenzuordnung."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        axis.text.x = element_text(angle = 35, hjust = 1),
        plot.caption = element_text(size = 8))

ggsave(file.path(output_dir, "RKI_Phasen_Zeitverlauf_2020_2023_korrigiert.png"),
       plot = plot_waves, width = 13, height = 8, dpi = 200)

cat("\nRKI-Wellen 1-5 (offizielle retrospektive Grenzen):\n")
print(wave_summary)
cat("\nBeginn der sechsten Welle: KW 22/2022 (Ende im RKI-Quellstand offen).\n")
cat("2023 nicht mit einer unbelegten RKI-Wellennummer versehen.\n")
cat("Ausgaben in:", output_dir, "\n")
