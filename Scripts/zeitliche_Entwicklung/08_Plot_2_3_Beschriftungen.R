# Fortgeschrittenes Praxisprojekt - Zeitliche Entwicklung (2020-2023)
# Plot 2: Jahresmaxima mit ISO-Kalenderwoche beschriften
# Plot 3: Exakte Jahresfallzahlen oberhalb der Balken anzeigen
#
# Im Stammverzeichnis des RStudio-Projekts ausfuehren:
# source("Scripts/zeitliche Entwicklung/08_Plot_2_3_Beschriftungen.R")
#
# Verwendet ausschliesslich lokal erzeugte, aggregierte Daten.
# Veraendert keine Rohdaten und ueberschreibt keine bisherigen Grafiken.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

# 1. Eingaben und Ausgabeordner -----------------------------------------------
input_file <- "results/zeitliche_entwicklung/Zeitverlauf_Wochenfaelle_Deutschland.csv"
output_dir <- "results/zeitliche_entwicklung"

if (!file.exists(input_file)) {
  stop("Eingabedatei fehlt. Bitte zuerst 05_Zeitverlauf_Jahresvergleich.R ausfuehren.")
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

weekly_total <- fread(input_file)
required <- c("iso_year", "iso_week", "week_start", "weekly_cases")
stopifnot(all(required %in% names(weekly_total)))

weekly_total[, `:=`(
  iso_year = as.integer(iso_year),
  iso_week = as.integer(iso_week),
  week_start = as.Date(week_start),
  weekly_cases = as.numeric(weekly_cases)
)]
setorder(weekly_total, week_start)

stopifnot(
  nrow(weekly_total) == 209L,
  !anyNA(weekly_total[, ..required]),
  setequal(unique(weekly_total$iso_year), 2020:2023),
  !anyDuplicated(weekly_total, by = c("iso_year", "iso_week")),
  all(is.finite(weekly_total$weekly_cases)),
  all(weekly_total$weekly_cases >= 0)
)

# Deutsche Tausendertrennung fuer die Achsen und Datenbeschriftung.
format_de <- function(x) {
  format(round(x), big.mark = ".", scientific = FALSE, trim = TRUE)
}

# 2. Jahresmaxima und Jahressummen aus denselben Wochenwerten -----------------
peaks <- weekly_total[, .SD[which.max(weekly_cases)], by = iso_year]
peaks[, kw_label := sprintf("KW %02d/%d", iso_week, iso_year)]

annual <- weekly_total[, .(
  total_reported_cases = sum(weekly_cases)
), by = iso_year]
setorder(annual, iso_year)
annual[, total_label := format_de(total_reported_cases)]

# 3. Plot 2: Wochenfallzahlen mit beschrifteten Jahresmaxima ------------------
plot_2 <- ggplot(weekly_total, aes(x = week_start, y = weekly_cases)) +
  geom_line(color = "#215E83", linewidth = 0.8) +
  geom_point(
    data = peaks,
    color = "#B34B3C", size = 2.8
  ) +
  geom_label(
    data = peaks,
    aes(label = kw_label),
    color = "#973E32", fill = "white",
    size = 3.6, fontface = "bold",
    vjust = -0.75,
    label.size = 0.2,
    show.legend = FALSE
  ) +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  scale_y_continuous(
    labels = format_de,
    expand = expansion(mult = c(0.02, 0.18))
  ) +
  labs(
    title = "Gemeldete COVID-19-Faelle in Deutschland, 2020-2023",
    subtitle = "Wochenfallzahlen nach ISO-Meldewoche; Jahresmaxima mit Kalenderwoche",
    x = "Meldewoche (Beginn: Montag)",
    y = "Gemeldete Faelle pro Woche"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.caption = element_text(size = 9)
  )

ggsave(
  file.path(output_dir, "Zeitverlauf_Wochenfaelle_Peaks_KW.png"),
  plot = plot_2, width = 12.5, height = 6.2, dpi = 220
)

# 4. Plot 3: Jahresgesamtzahlen direkt ueber den Balken -----------------------
plot_3 <- ggplot(
  annual,
  aes(x = factor(iso_year), y = total_reported_cases)
) +
  geom_col(fill = "#215E83", width = 0.65) +
  geom_text(
    aes(label = total_label),
    vjust = -0.65, size = 4.7,
    fontface = "bold", color = "#233B4C"
  ) +
  scale_y_continuous(
    labels = format_de,
    expand = expansion(mult = c(0, 0.16))
  ) +
  labs(
    title = "Gesamte gemeldete COVID-19-Faelle pro ISO-Jahr",
    subtitle = "Exakte Jahressummen der gemeldeten Wochenfaelle",
    x = "ISO-Meldejahr",
    y = "Gemeldete Faelle insgesamt"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.caption = element_text(size = 9)
  )

ggsave(
  file.path(output_dir, "Zeitverlauf_Jahressummen_mit_Zahlen.png"),
  plot = plot_3, width = 10.5, height = 6.5, dpi = 220
)

# 5. Werte fuer die Abschlusskontrolle ----------------------------------------
cat("\nPlot 2: ISO-Kalenderwochen der Jahresmaxima:\n")
print(peaks[, .(iso_year, iso_week, week_start, weekly_cases)])
cat("\nPlot 3: Exakte Jahresfallzahlen:\n")
print(annual[, .(iso_year, total_reported_cases)])
cat("\nZwei neue PNG-Dateien wurden gespeichert in: ", output_dir, "\n", sep = "")
