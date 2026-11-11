# Fortgeschrittenes Praxisprojekt - COVID-19: Zeitliche Entwicklung
# Deutschlandweite Wocheninzidenz mit farbig markierten RKI-Wellen 1 bis 5
#
# Im RStudio-Projektstamm ausfuehren:
# source("Scripts/zeitliche Entwicklung/07_RKI_Wellen_Deutschland_gesamt.R")
#
# Die Grafik baut auf "01_Deutschland_gesamt.png" auf: gleiche Kennzahl,
# gleiche Datenquelle, ein durchgehender Zeitverlauf 2020-2023.
# Hier wird die INZIDENZ (Faelle je 100.000 Einwohner und Woche) dargestellt,
# nicht die absolute woechentliche Fallzahl.
#
# RKI-Wellengrenzen: Epidemiologisches Bulletin 38/2022, Tabelle 1,
# Stand 15.09.2022.
# https://edoc.rki.de/bitstream/handle/176904/10260/EB-38-2022-Phaseneinteilung.pdf?sequence=1
# Die Phasen nach W5 werden NICHT als "wellenfrei" interpretiert.
#
# Die Daten verbleiben lokal. Dieses Skript aendert keine Rohdaten.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

# -----------------------------------------------------------------------------
# 1. Datengrundlage (bereits in der EDA berechnete nationale Wocheninzidenz)
# -----------------------------------------------------------------------------
input_file <- "results/zeitliche_entwicklung/05_Nationale_Wocheninzidenz_Gesamt.csv"
output_dir <- "results/zeitliche_entwicklung"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(input_file)) {
  stop(
    "Eingabedatei fehlt: ", input_file, "\n",
    "Bitte zuerst 'Scripts/zeitliche Entwicklung/Zeitliche_Entwicklung_EDA.R' ausfuehren."
  )
}

weekly <- fread(input_file)
required <- c("iso_year", "week_start", "incidence", "coverage")
if (!all(required %in% names(weekly))) {
  stop("In der Eingabedatei fehlen Spalten: ",
       paste(setdiff(required, names(weekly)), collapse = ", "))
}

weekly[, `:=`(
  iso_year = as.integer(iso_year),
  week_start = as.Date(week_start),
  incidence = as.numeric(incidence),
  coverage = as.numeric(coverage)
)]

weekly <- weekly[
  iso_year %in% 2020:2023 &
    !is.na(week_start) &
    is.finite(incidence) &
    is.finite(coverage) & coverage >= 0.99
]
setorder(weekly, week_start)

stopifnot(
  nrow(weekly) == 209L,
  !anyDuplicated(weekly, by = "week_start"),
  all(weekly$incidence >= 0),
  all(format(weekly$week_start, "%u") == "1")
)

# -----------------------------------------------------------------------------
# 2. RKI-Wellen 1-5: retrospektive offizielle Zeitfenster
# -----------------------------------------------------------------------------
rki_waves <- data.table(
  wave = factor(paste0("W", 1:5), levels = paste0("W", 1:5)),
  start_date = as.Date(c(
    "2020-03-02", "2020-09-28", "2021-03-01",
    "2021-08-02", "2021-12-27"
  )),
  end_date = as.Date(c(
    "2020-05-17", "2021-02-28", "2021-06-13",
    "2021-12-26", "2022-05-29"
  ))
)

# Farben bewusst gut unterscheidbar gewaehlt.
wave_colors <- c(
  W1 = "#0072B2",  # Blau
  W2 = "#E69F00",  # Orange
  W3 = "#009E73",  # Gruen (Alpha)
  W4 = "#CC79A7",  # Violett (Delta)
  W5 = "#D55E00"   # Rot-Orange (Omikron)
)

rki_waves[, label_date := as.Date(
  (as.numeric(start_date) + as.numeric(end_date)) / 2,
  origin = "1970-01-01"
)]

# Datenpunkte je RKI-Welle; ausserhalb der Wellen bleibt die Linie grau.
wave_lines <- rbindlist(lapply(seq_len(nrow(rki_waves)), function(i) {
  current <- rki_waves[i]
  points <- weekly[
    week_start >= current$start_date & week_start <= current$end_date
  ]
  points[, wave := current$wave]
  points
}))
wave_lines[, wave := factor(as.character(wave), levels = levels(rki_waves$wave))]

stopifnot(nrow(wave_lines) > 0L)

# Die Beschriftung liegt oberhalb der gesamten Kurve und ueberlappt keine Peaks.
y_max <- max(weekly$incidence)
rki_waves[, label_y := 1.115 * y_max]
y_upper <- 1.24 * y_max

# -----------------------------------------------------------------------------
# 3. Eine durchgehende Deutschlandkurve mit 5 farbigen Wellen
# -----------------------------------------------------------------------------
p_waves <- ggplot(weekly, aes(x = week_start, y = incidence)) +
  # Zarte Hintergrundfelder machen Beginn und Ende der Wellen sichtbar.
  geom_rect(
    data = rki_waves,
    aes(xmin = start_date, xmax = end_date,
        ymin = -Inf, ymax = Inf, fill = wave),
    inherit.aes = FALSE,
    alpha = 0.13,
    color = NA
  ) +
  # Gesamte Zeitreihe; grau markiert nicht zu W1-W5 gehoerende Zeitraeume.
  geom_line(color = "#82909A", linewidth = 0.65, na.rm = TRUE) +
  # Die Abschnitte innerhalb der RKI-Wellen sind deutlich eingefaerbt.
  geom_line(
    data = wave_lines,
    aes(color = wave, group = wave),
    linewidth = 1.05,
    show.legend = TRUE
  ) +
  # Wellen direkt auf der Grafik beschriften.
  geom_label(
    data = rki_waves,
    aes(x = label_date, y = label_y, label = wave, color = wave),
    inherit.aes = FALSE,
    size = 4.2,
    fontface = "bold",
    fill = "white",
    label.size = 0,
    label.padding = grid::unit(0.22, "lines"),
    show.legend = FALSE
  ) +
  scale_color_manual(
    values = wave_colors,
    limits = names(wave_colors),
    name = "RKI-Welle"
  ) +
  scale_fill_manual(values = wave_colors, guide = "none") +
  scale_x_date(
    date_breaks = "3 months",
    date_labels = "%m/%Y",
    expand = expansion(mult = c(0.005, 0.005))
  ) +
  scale_y_continuous(
    limits = c(0, y_upper),
    labels = function(x) format(round(x), big.mark = ".",
                                scientific = FALSE, trim = TRUE),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = "Gemeldete COVID-19-Faelle und RKI-Welleneinteilung",
    subtitle = "RKI-Wellen 1-5 farbig hervorgehoben; uebriger Zeitverlauf grau",
    x = "Meldewoche (Montag)",
    y = "Gemeldete Faelle je 100.000 Einwohner / Woche"
  ) +
  guides(color = guide_legend(nrow = 1, override.aes = list(linewidth = 2))) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(face = "bold", size = 15),
    legend.position = "bottom",
    plot.caption = element_text(size = 8, hjust = 0),
    plot.margin = margin(14, 18, 12, 12)
  )

png_file <- file.path(output_dir, "RKI_Wellen_Deutschland_gesamt_Farben.png")
pdf_file <- file.path(output_dir, "RKI_Wellen_Deutschland_gesamt_Farben.pdf")

ggsave(png_file, plot = p_waves, width = 14, height = 7, dpi = 220)
ggsave(pdf_file, plot = p_waves, width = 14, height = 7)

cat("Deutschlandweite Wocheninzidenz mit W1-W5 gespeichert:\n")
cat("- ", png_file, "\n", sep = "")
cat("- ", pdf_file, "\n", sep = "")
cat("Hinweis: Wocheninzidenz, NICHT absolute Fallzahl.\n")
cat("Hinweis: Ab W6 und 2023 keine zusaetzlichen offiziellen Wellen markiert.\n")
