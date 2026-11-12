# LMU Fortgeschrittenes Praxisprojekt WS 2026/27
# Aufgabe 3: Explorative Analyse der zeitlichen COVID-19-Entwicklung, 2020–2023
# Nur lokale R-Ausfuehrung: Keine Rohdaten an externe KI-Dienste uebertragen.
# Start: im Projektverzeichnis (RStudio-Projekt) ausfuehren.
# Benoetigte Pakete: data.table, ggplot2

library(data.table)
library(ggplot2)


# -----------------------------------------------------------------------------
# 1. Eingaben / Ausgaben
# -----------------------------------------------------------------------------
in_week <- "data_processed/rki_weekly_long.rds"
in_pop  <- "data_processed/rki_population_annual.rds"
out_dir <- "results/zeitliche_entwicklung"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

stopifnot(file.exists(in_week), file.exists(in_pop))
w <- as.data.table(readRDS(in_week))
p <- as.data.table(readRDS(in_pop))

stopifnot(
  all(c("geo_code", "age_group", "week_start", "iso_year", "iso_week",
        "count", "incidence") %in% names(w)),
  all(c("geo_code", "age_group", "year", "population") %in% names(p))
)

w[, `:=`(
  geo_code = as.character(geo_code),
  age_group = as.character(age_group),
  week_start = as.Date(week_start),
  iso_year = as.integer(iso_year),
  count = as.numeric(count),
  incidence = as.numeric(incidence)
)]
p[, `:=`(
  geo_code = as.character(geo_code),
  age_group = as.character(age_group),
  year = as.integer(year),
  population = as.numeric(population)
)]

w <- w[iso_year %in% 2020:2023]
p <- p[year %in% 2020:2023]

if (anyDuplicated(w, by = c("geo_code", "age_group", "week_start"))) {
  stop("Doppelte Kreis-Alter-Woche-Schluessel in den RKI-Wochendaten.")
}
if (anyDuplicated(p, by = c("geo_code", "age_group", "year"))) {
  stop("Doppelte Kreis-Alter-Jahr-Schluessel in den Bevoelkerungsdaten.")
}
if (anyNA(w[, .(geo_code, age_group, week_start, iso_year)])) {
  stop("Fehlende Schluesselvariablen in den Wochendaten.")
}
if (anyNA(p[, .(geo_code, age_group, year)])) {
  stop("Fehlende Schluesselvariablen in den Bevoelkerungsdaten.")
}

n_regions <- uniqueN(w$geo_code)
all_weeks <- sort(unique(w$week_start))
expected_weeks <- seq(as.Date("2019-12-30"), as.Date("2023-12-25"), by = "week")
expected_ages <- c(as.character(0:79), "80+", "NA")

if (!setequal(unique(w$age_group), expected_ages)) {
  warning("Die Alterskategorien weichen von 0:79, 80+ und NA ab.")
}
if (n_regions != 400L) {
  warning("Anzahl der Kreise ist nicht 400: ", n_regions)
}
if (!setequal(all_weeks, expected_weeks)) {
  warning("Die ISO-Wochen 2020–2023 sind nicht vollstaendig / enthalten zusaetzliche Wochen.")
}
if (any(format(all_weeks, "%u") != "1")) {
  warning("Nicht alle week_start-Daten sind Montage.")
}

# -----------------------------------------------------------------------------
# 2. Alter unbekannt ausschliessen, RKI-Jahresbevoelkerung zuordnen
#    WICHTIG: Bei der Jahreszuordnung iso_year benutzen, nicht year(week_start).
# -----------------------------------------------------------------------------
known <- w[!is.na(age_group) & age_group != "NA"]
known <- merge(
  known,
  p,
  by.x = c("geo_code", "age_group", "iso_year"),
  by.y = c("geo_code", "age_group", "year"),
  all.x = TRUE,
  sort = FALSE
)

known[, age_number := suppressWarnings(as.integer(age_group))]
known[age_group == "80+", age_number := 80L]
if (anyNA(known$age_number)) stop("Unbekannte Alterskategorie entdeckt.")

# Vorlaeufige breite Altersgruppen fuer die EDA, keine finale Projektentscheidung.
known[, age_bin := fcase(
  age_number <= 17L, "0-17",
  age_number <= 39L, "18-39",
  age_number <= 59L, "40-59",
  age_number <= 79L, "60-79",
  age_number >= 80L, "80+"
)]
age_levels <- c("0-17", "18-39", "40-59", "60-79", "80+")
known[, age_bin := factor(age_bin, levels = age_levels)]

# Fehlende / ungueltige Nenner duerfen nicht als Null behandelt werden.
# Zaehler und Nenner muessen dieselbe Teilpopulation abdecken.
known[, usable := is.finite(count) & count >= 0 &
                 is.finite(population) & population > 0]

# -----------------------------------------------------------------------------
# 3. Datenqualitaet: Vollstaendigkeit und Inzidenz-Plausibilitaet
# -----------------------------------------------------------------------------
age_sizes <- c("0-17" = 18L, "18-39" = 22L, "40-59" = 20L,
               "60-79" = 20L, "80+" = 1L)

qa_week <- known[, .(
  observed_cells = .N,
  usable_cells = sum(usable),
  missing_case_cells = sum(!is.finite(count)),
  invalid_population_cells = sum(!is.finite(population) | population <= 0)
), by = .(iso_year, week_start, age_bin)]
qa_week[, expected_cells := as.integer(n_regions * age_sizes[as.character(age_bin)])]
qa_week[, coverage := usable_cells / expected_cells]
setorder(qa_week, week_start, age_bin)

qa_overview <- data.table(
  merkmal = c(
    "Anzahl Kreise", "Anzahl ISO-Wochen", "Wochen vollstaendig (2020-2023)",
    "Beobachtungen gesamt", "Beobachtungen mit bekanntem Alter",
    "Fehlende Fallzahlen (bekanntes Alter)",
    "Ungueltige/fehlende Bevoelkerungsnenner (bekanntes Alter)",
    "Nicht verwendbare Beobachtungen", "Kleinste Zellabdeckung"
  ),
  wert = as.character(c(
    n_regions,
    length(all_weeks),
    as.character(setequal(all_weeks, expected_weeks)),
    nrow(w),
    nrow(known),
    sum(!is.finite(known$count)),
    sum(!is.finite(known$population) | known$population <= 0),
    sum(!known$usable),
    round(min(qa_week$coverage), 4)
  ))
)

# Uebereinstimmung zwischen bereitgestellter RKI-Inzidenz und Neuberechnung
# pruefen; Differenzen koennen durch Rundung und Definitionen entstehen.
comparison <- known[usable & is.finite(incidence)]
comparison[, abs_diff := abs(incidence - 1e5 * count / population)]
qa_incidence <- comparison[, .(
  n_comparable = .N,
  median_absolute_difference = median(abs_diff),
  p99_absolute_difference = as.numeric(quantile(abs_diff, 0.99))
)]

fwrite(qa_overview, file.path(out_dir, "01_Qualitaetsuebersicht.csv"))
fwrite(qa_week, file.path(out_dir, "02_Woechentliche_Abdeckung.csv"))
fwrite(qa_incidence, file.path(out_dir, "03_Inzidenz_Plausibilitaet.csv"))

# -----------------------------------------------------------------------------
# 4. Woechentliche bundesweite Raten, bevoelkerungsgewichtet
# -----------------------------------------------------------------------------
# Keine ungewichteten Mittelwerte der Kreis-Inzidenzen bilden!
valid <- known[usable == TRUE]
national_age <- valid[, .(
  cases = sum(count),
  population = sum(population)
), by = .(iso_year, week_start, age_bin)]

national_age <- merge(
  national_age,
  qa_week[, .(iso_year, week_start, age_bin, coverage)],
  by = c("iso_year", "week_start", "age_bin"),
  all.x = TRUE,
  sort = FALSE
)
national_age[, incidence := 1e5 * cases / population]
setorder(national_age, week_start, age_bin)

national_all <- valid[, .(
  cases = sum(count),
  population = sum(population)
), by = .(iso_year, week_start)]
national_all[, incidence := 1e5 * cases / population]

# 81 bekannte RKI-Einzelalter je Kreis; 400 harmonisierte Kreise.
national_all <- merge(
  national_all,
  qa_week[, .(usable_cells = sum(usable_cells)), by = .(iso_year, week_start)],
  by = c("iso_year", "week_start"),
  all.x = TRUE,
  sort = FALSE
)
national_all[, coverage := usable_cells / (n_regions * sum(age_sizes))]
setorder(national_all, week_start)

fwrite(national_age, file.path(out_dir, "04_Nationale_Wocheninzidenz_Alter.csv"))
fwrite(national_all, file.path(out_dir, "05_Nationale_Wocheninzidenz_Gesamt.csv"))

# Bei auffaellig geringer Zellenabdeckung die betreffenden Wochen nicht plotten.
coverage_threshold <- 0.99
plot_age <- national_age[is.finite(incidence) & coverage >= coverage_threshold]
plot_all <- national_all[is.finite(incidence) & coverage >= coverage_threshold]
if (nrow(plot_age) == 0L || nrow(plot_all) == 0L) {
  stop("Keine hinreichend vollstaendigen Wochen fuer die Grafiken. QA-Dateien pruefen.")
}

# -----------------------------------------------------------------------------
# 5. Drei komplementaere Grafiken
# -----------------------------------------------------------------------------
common_theme <- theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom")

p_all <- ggplot(plot_all, aes(x = week_start, y = incidence)) +
  geom_line(color = "#265A84", linewidth = 0.65) +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  labs(
    title = "COVID-19: Woechentliche Inzidenz in Deutschland",
    subtitle = "Alle bekannten Altersgruppen, 2020–2023 (ISO-Kalenderwochen)",
    x = "Woche (Montag)", y = "Gemeldete Faelle je 100.000 / Woche"
  ) + common_theme

ggsave(file.path(out_dir, "01_Deutschland_gesamt.png"),
       p_all, width = 11, height = 5.2, dpi = 180)

p_age <- ggplot(plot_age, aes(x = week_start, y = incidence,
                              color = age_bin, group = age_bin)) +
  geom_line(linewidth = 0.65) +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  labs(
    title = "COVID-19: Vergleich der Altersgruppen",
    subtitle = "Einheitliche y-Achse fuer einen quantitativen Vergleich",
    x = "Woche (Montag)", y = "Gemeldete Faelle je 100.000 / Woche",
    color = "Altersgruppe"
  ) + common_theme

##ggsave(file.path(out_dir, "02_Altersgruppen_gleiche_Skala.png"),
##       p_age, width = 11, height = 6, dpi = 180)

p_facets <- ggplot(plot_age, aes(x = week_start, y = incidence)) +
  geom_line(color = "#265A84", linewidth = 0.5) +
  facet_wrap(~ age_bin, ncol = 1L, scales = "free_y") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "COVID-19: Zeitliche Muster nach Altersgruppe",
    subtitle = "Achtung: Jede Teilgrafik hat eine eigene y-Achse",
    x = "Woche (Montag)", y = "Faelle je 100.000 / Woche"
  ) + common_theme

##ggsave(file.path(out_dir, "03_Altersgruppen_Verlaeufe_Facets.png"),
##       p_facets, width = 10, height = 10, dpi = 180)

p_heat <- ggplot(plot_age, aes(x = week_start, y = age_bin, fill = incidence)) +
  geom_tile(width = 7, height = 0.90) +
  scale_fill_viridis_c(trans = "sqrt") +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  labs(
    title = "COVID-19: Heatmap der Wocheninzidenzen nach Altersgruppe",
    subtitle = "Farbskala mit Wurzeltransformation fuer bessere Lesbarkeit",
    x = "Woche (Montag)", y = "Altersgruppe",
    fill = "Faelle / 100.000"
  ) + common_theme

##ggsave(file.path(out_dir, "04_Altersgruppen_Heatmap.png"),
##       p_heat, width = 11, height = 4.5, dpi = 180)

# -----------------------------------------------------------------------------
# 6. Explorative Peak-Tabelle (Jahresmaxima, keine Definition von Epidemiewellen)
# -----------------------------------------------------------------------------
peaks <- plot_age[, .SD[which.max(incidence)], by = .(iso_year, age_bin)]
peaks <- peaks[, .(
  iso_year, age_bin, peak_week = week_start,
  peak_incidence = incidence, cases_at_peak = cases,
  coverage_at_peak = coverage
)]
setorder(peaks, iso_year, age_bin)
fwrite(peaks, file.path(out_dir, "06_Jahresmaxima_nach_Altersgruppe.csv"))

cat("\nExplorative Zeitreihenanalyse: Ausgaben in ", out_dir, "\n", sep = "")
print(qa_overview)
print(qa_incidence)
print(peaks)
cat("\nWichtig: Maxima sind deskriptiv; sie beweisen keine kausalen Effekte.\n")
cat("Hinweis: Die ISO-Woche 1/2020 beginnt am 30.12.2019.\n")
