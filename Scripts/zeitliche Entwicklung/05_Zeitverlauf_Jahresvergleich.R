# Fortgeschrittenes Praxisprojekt - Explorative zeitliche Entwicklung (2020-2023)
# Deutschlandweit aggregierte Meldewochen; keine Alters- oder Kreistypvergleiche.
# Im RStudio-Projektstamm ausfuehren:
# source("Scripts/05_Zeitverlauf_Jahresvergleich.R")
# Lokale Daten nicht in externe KI-Dienste hochladen.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

input_path <- "data_processed/rki_weekly_long.rds"
output_dir <- "results/zeitliche_entwicklung"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(file.exists(input_path))

observations <- as.data.table(readRDS(input_path))
needed_columns <- c("geo_code", "age_group", "week_start", "iso_year", "iso_week", "count")
stopifnot(all(needed_columns %in% names(observations)))

observations[, `:=`(
  geo_code = as.character(geo_code),
  age_group = as.character(age_group),
  week_start = as.Date(week_start),
  iso_year = as.integer(iso_year),
  iso_week = as.integer(iso_week),
  count = as.numeric(count)
)]
observations <- observations[iso_year %in% 2020:2023]

if (anyNA(observations[, ..needed_columns])) {
  stop("Fehlende Werte in Schluessel- oder Fallzahlspalten; bitte pruefen.")
}
if (any(!is.finite(observations$count) | observations$count < 0)) {
  stop("Ungueltige Fallzahlen; bitte pruefen.")
}
if (anyDuplicated(observations, by = c("geo_code", "age_group", "week_start"))) {
  stop("Doppelte Kreis-Alter-Woche-Kombinationen; bitte pruefen.")
}
expected_week_starts <- seq(as.Date("2019-12-30"), as.Date("2023-12-25"), by = "week")
stopifnot(
  uniqueN(observations$geo_code) == 400L,
  setequal(unique(observations$week_start), expected_week_starts),
  uniqueN(observations$age_group) == 82L,
  nrow(observations) == 400L * 82L * 209L
)

# Alle Altersangaben einschliesslich unbekanntes Alter in die Gesamtsumme einbeziehen.
weekly_total <- observations[, .(weekly_cases = sum(count)),
  by = .(iso_year, iso_week, week_start)]
setorder(weekly_total, week_start)
stopifnot(nrow(weekly_total) == 209L)

# Jahresbezogene ISO-Meldewochen (2020 enthaelt 53 Wochen).
yearly_overview <- weekly_total[, {
  peak_index <- which.max(weekly_cases)
  .(
    weeks_in_year = .N,
    total_reported_cases = sum(weekly_cases),
    mean_weekly_cases = mean(weekly_cases),
    median_weekly_cases = median(weekly_cases),
    peak_iso_week = iso_week[peak_index],
    peak_week_start = week_start[peak_index],
    peak_weekly_cases = weekly_cases[peak_index]
  )
}, by = iso_year]
setorder(yearly_overview, iso_year)

fwrite(weekly_total, file.path(output_dir, "Zeitverlauf_Wochenfaelle_Deutschland.csv"))
fwrite(yearly_overview, file.path(output_dir, "Zeitverlauf_Jahresuebersicht.csv"))

# Jahres-Facetten: y-Skalen werden absichtlich freigegeben, um 2020/2021/2023
# sichtbar zu machen. Absolute Hoehen nur mit gemeinsamen Skalen vergleichen!
facet_plot <- ggplot(weekly_total, aes(x = iso_week, y = weekly_cases)) +
  geom_line(color = "#215E83", linewidth = 0.9) +
  geom_point(
    data = weekly_total[, .SD[which.max(weekly_cases)], by = iso_year],
    color = "#B34B3C", size = 2.0
  ) +
  facet_wrap(~iso_year, scales = "free_y", ncol = 2) +
  scale_x_continuous(breaks = c(1, 13, 26, 39, 52)) +
  scale_y_continuous(labels = function(values) format(
    round(values), big.mark = ".", scientific = FALSE, trim = TRUE
  )) +
  labs(
    title = "Gemeldete COVID-19-Faelle nach ISO-Meldejahr",
    subtitle = "Jahresansichten mit eigenen y-Skalen – nur fuer zeitliche Muster, nicht fuer Hoehenvergleich",
    x = "ISO-Meldewoche", y = "Gemeldete Faelle pro Woche",
    caption = "Quelle: RKI/SurvStat via rsurvstat; 400 harmonisierte Kreise; inklusive unbekanntem Alter."
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave(
  filename = file.path(output_dir, "Zeitverlauf_Jahresfacetten.png"),
  plot = facet_plot, width = 12, height = 8, dpi = 200
)

# Vergleich der absoluten Jahressummen. Durch Veraenderungen im Test- und
# Meldegeschehen nicht als Vergleich der tatsaechlichen Infektionszahlen lesen.
bar_plot <- ggplot(yearly_overview,
  aes(x = factor(iso_year), y = total_reported_cases)) +
  geom_col(fill = "#215E83", width = 0.65) +
  scale_y_continuous(
    labels = function(values) format(
      round(values), big.mark = ".", scientific = FALSE, trim = TRUE
    ),
    expand = expansion(mult = c(0, 0.08))
  ) +
  labs(
    title = "Gesamte gemeldete COVID-19-Faelle pro ISO-Jahr",
    subtitle = "Summen der Wochenfaelle; Test- und Meldepraxis koennen sich zwischen Jahren unterscheiden",
    x = "ISO-Meldejahr", y = "Gemeldete Faelle insgesamt",
    caption = "Quelle: RKI/SurvStat via rsurvstat; 400 harmonisierte Kreise; inklusive unbekanntem Alter."
  ) + theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave(
  filename = file.path(output_dir, "Zeitverlauf_Jahressummen.png"),
  plot = bar_plot, width = 10, height = 6, dpi = 200
)

cat("\nZeitliche Entwicklung: deutschlandweiter Jahresvergleich\n")
cat("Wochen:", nrow(weekly_total), "| Kreise:", uniqueN(observations$geo_code), "\n\n")
print(yearly_overview)
cat("\nErgebnisse in:", output_dir, "\n")
cat("Die Jahresmaxima sind keine automatisch definierten Infektionswellen.\n")
