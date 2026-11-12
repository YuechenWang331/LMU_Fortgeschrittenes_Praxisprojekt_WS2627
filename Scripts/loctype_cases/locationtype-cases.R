# Analyse: Zusammenhang zwischen BBSR-Location Type und COVID-19-Fallzahlen
# Projektkontext:
# Die Hauptfragestellung laut Protokoll lautet: "Wie hängen regionale Merkmale wie der
# Urbanisierungsgrad mit der wöchentlichen COVID-19-Meldeinzidenz auf Kreisebene in Deutschland zusammen?"

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(tidyr)
})

project_root <- "/Users/hilal/Desktop/LMU_Fortgeschrittenes_Praxisprojekt_WS2627"

# ------------------------------------------------------------------------------
# 1. Definitionen: BBSR-Location Types / Raumtypen nach Lage
# ------------------------------------------------------------------------------
# Die Zuordnung zu den Raumtypen erfolgt anhand der potenziell erreichbaren Tagesbevölkerung 
# innerhalb einer Fahrzeit von bis zu zwei Stunden.
# Dabei werden weiter entfernte Gemeinden entsprechend ihrer Fahrzeit geringer gewichtet und 
# die resultierenden Zentralitätswerte im Vergleich zur bundesweiten Verteilung in vier 
# Kategorien eingeteilt.
# Raum Typen:
#    - sehr zentral
#    - zentral
#    - peripher
#    - sehr peripher
#
# "sehr zentral": Kreise in oder direkt im Kern starker Ballungsräume; sehr hohe Bevölkerungs-
# dichte, starke zentralörtliche Funktionen, hohe Versorgungs- und Anbindungskapazität.
# "zentral": Kreise mit klarer regionaler Zentralität, aber weniger starkem Städtekern als
# die sehr zentralen Gebiete; weiterhin gute Erreichbarkeit und zentrale Versorgungsfunktion.
# "peripher": eher räumlich am Rand oder außerhalb des Kernbereichs großer Zentren; geringere
# zentrale Funktion und längere Wege zu größeren urbanen Zentren.
# "sehr peripher": stark ländlich geprägte, dünn besiedelte und räumlich abgelegene Gebiete
# mit geringer zentraler Anbindung und weniger urbaner Infrastruktur.

# Quelle / Grundlage: BBSR (Bundesinstitut für Bau-, Stadt- und Raumforschung),
# Raumgliederungen / Referenztabellen zu Raumabgrenzungen / Raumtyp nach Lage (Location Type).
# https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/deutschland/kreise/Raumtypen2010_krs/Raumtypen2010_Kreise.html

location_type_lookup <- tibble::tibble(
  location_type_code = c("1", "2", "3", "4"),
  location_type_label = c("sehr zentral", "zentral", "peripher", "sehr peripher")
)

# ------------------------------------------------------------------------------
# 2. Daten laden
# ------------------------------------------------------------------------------
# Die Daten wurden in den processed-Dateien aufbereitet. Wir nutzen:
# - raumgliederungen_kreis_2023.rds: BBSR-Regionstypen je Kreis
# - rki_weekly_long.rds: wöchentliche COVID-19-Fälle je Kreis und Alter
# - population_kreis.rds: Bevölkerungsdaten je Kreis und Jahr

geo_types <- readRDS(file.path(project_root, "data_processed", "raumgliederungen_kreis_2023.rds")) %>%
  transmute(
    geo_code = as.character(geo_code),
    location_type_code = as.character(location_type_code)
  ) %>%
  left_join(location_type_lookup, by = "location_type_code")

weekly_cases <- readRDS(file.path(project_root, "data_processed", "rki_weekly_long.rds")) %>%
  as.data.frame() %>%
  transmute(
    geo_code = as.character(geo_code),
    iso_year = as.integer(iso_year),
    count = as.numeric(count)
  ) %>%
  filter(!is.na(geo_code), !is.na(iso_year), !is.na(count), count >= 0) %>%
  left_join(geo_types %>% select(geo_code, location_type_label), by = "geo_code") %>%
  filter(!is.na(location_type_label))

annual_population <- readRDS(file.path(project_root, "data_processed", "population_kreis.rds")) %>%
  as.data.frame() %>%
  transmute(
    geo_code = as.character(geo_code),
    year = as.integer(year),
    population = as.numeric(population)
  ) %>%
  filter(!is.na(population), population > 0) %>%
  left_join(geo_types %>% select(geo_code, location_type_label), by = "geo_code") %>%
  filter(!is.na(location_type_label)) %>%
  group_by(geo_code, year, location_type_label) %>%
  summarise(population_total = sum(population, na.rm = TRUE), .groups = "drop")

# ------------------------------------------------------------------------------
# 3. Kennzahlen je Location Type und Jahr berechnen
# ------------------------------------------------------------------------------
# Wir aggregieren die wöchentlichen Fälle auf jährlicher Ebene, damit wir die Fälle
# nach Lage-/Raumtyp vergleichen können. Zusätzlich berechnen wir Fälle pro 100.000
# Einwohner, da unterschiedliche Kreistypen sehr unterschiedliche Bevölkerungsgrößen haben.

annual_cases <- weekly_cases %>%
  group_by(iso_year, location_type_label) %>%
  summarise(total_cases = sum(count, na.rm = TRUE), .groups = "drop") %>%
  rename(year = iso_year)

annual_cases_by_type <- annual_cases %>%
  left_join(
    annual_population %>%
      group_by(year, location_type_label) %>%
      summarise(population_total = sum(population_total, na.rm = TRUE), .groups = "drop"),
    by = c("year", "location_type_label")
  ) %>%
  mutate(
    cases_per_100k = (total_cases / population_total) * 100000,
    location_type_label = factor(
      location_type_label,
      levels = c("sehr zentral", "zentral", "peripher", "sehr peripher")
    )
  ) %>%
  filter(!is.na(population_total)) %>%
  arrange(year, location_type_label)

print("=== Gesamtfälle nach Location Type und Jahr ===")
print(annual_cases_by_type %>% select(year, location_type_label, total_cases, population_total, cases_per_100k))

# ------------------------------------------------------------------------------
# 4. Deskriptive Vergleichsanalyse
# ------------------------------------------------------------------------------
# Der einfachste Vergleich ist die absolute Zahl gemeldeter Fälle je Lage-/Raumtyp.
# Für eine fairere Regionseinteilung ist die Rate pro 100.000 Einwohner meist sinnvoller.

case_rank <- annual_cases_by_type %>%
  group_by(year) %>%
  mutate(rank_case_total = dense_rank(desc(total_cases))) %>%
  ungroup()

print("=== Rangfolge nach Gesamtfällen innerhalb jedes Jahres ===")
print(case_rank %>% select(year, location_type_label, total_cases, rank_case_total))

# ------------------------------------------------------------------------------
# 5. Plot: Zeitlicher Verlauf nach Location Type
# ------------------------------------------------------------------------------
# Diese Grafik zeigt, ob die Differenz zwischen den Lage-/Raumtypen im Zeitverlauf stabil,
# stärker oder schwächer wird.

p_case_rate <- ggplot(
  annual_cases_by_type,
  aes(x = year, y = cases_per_100k, colour = location_type_label, group = location_type_label)
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  labs(
    title = "COVID-19-Fälle pro 100.000 Einwohner nach BBSR-Location Type",
    x = "Jahr",
    y = "Fälle pro 100.000 Einwohner",
    colour = "Location Type"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right")

print(p_case_rate)

# Optional: ebenfalls ein Absolutzahlen-Plot, falls die Größenordnung der Fälle besser sichtbar sein soll.
p_case_total <- ggplot(
  annual_cases_by_type,
  aes(x = year, y = total_cases, colour = location_type_label, group = location_type_label)
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  labs(
    title = "Absolute COVID-19-Fälle nach BBSR-Location Type",
    x = "Jahr",
    y = "Gesamtfälle",
    colour = "Location Type"
  ) +
  theme_minimal(base_size = 12)

print(p_case_total)

# ------------------------------------------------------------------------------
# Zusätzliche Analyse: Monatsdaten neben Jahresdaten
# ------------------------------------------------------------------------------
# Neben der jährlichen Auswertung kann man die Entwicklung auch monatlich betrachten.
# Dafür aggregieren wir die wöchentlichen RKI-Fälle auf Monatsebene und bilden eine
# grobe Schätzung pro 100.000 Einwohner, indem wir für alle Monate eines Jahres die
# gleiche jährliche Bevölkerungszahl verwenden. Das ist eine pragmatische Näherung,
# weil die Bevölkerungsdaten nur jährlich vorliegen und sich die Bevölkerungszahl im
# Verlauf eines Jahres für die grobe Vergleichsbetrachtung nur wenig ändert.

monthly_cases <- readRDS(file.path(project_root, "data_processed", "rki_weekly_long.rds")) %>%
  as.data.frame() %>%
  transmute(
    geo_code = as.character(geo_code),
    week_start = as.Date(week_start),
    count = as.numeric(count)
  ) %>%
  filter(!is.na(geo_code), !is.na(week_start), !is.na(count), count >= 0) %>%
  left_join(geo_types %>% select(geo_code, location_type_label), by = "geo_code") %>%
  filter(!is.na(location_type_label)) %>%
  mutate(
    month_start = as.Date(format(week_start, "%Y-%m-01")),
    year = as.integer(format(month_start, "%Y")),
    month_label = format(month_start, "%Y-%m")
  ) %>%
  group_by(year, month_label, month_start, location_type_label) %>%
  summarise(total_cases = sum(count, na.rm = TRUE), .groups = "drop") %>%
  left_join(
    annual_population %>%
      group_by(year, location_type_label) %>%
      summarise(population_total = sum(population_total, na.rm = TRUE), .groups = "drop") %>%
      mutate(population_monthly = population_total),
    by = c("year", "location_type_label")
  ) %>%
  mutate(
    cases_per_100k_monthly = (total_cases / population_monthly) * 100000,
    location_type_label = factor(
      location_type_label,
      levels = c("sehr zentral", "zentral", "peripher", "sehr peripher")
    )
  ) %>%
  arrange(month_start, location_type_label)

print("=== Monatliche Fallzahlen nach Location Type ===")
print(monthly_cases %>% select(month_label, location_type_label, total_cases, population_monthly, cases_per_100k_monthly) %>% head(20))

monthly_plot <- ggplot(
  monthly_cases,
  aes(x = month_start, y = cases_per_100k_monthly, colour = location_type_label, group = location_type_label)
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.5) +
  labs(
    title = "Monatliche COVID-19-Fälle pro 100.000 Einwohner nach BBSR-Location Type",
    x = "Monat",
    y = "Fälle pro 100.000 Einwohner",
    colour = "Location Type"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "right")

print(monthly_plot)


# Interpretation absolute Zahlen:
# - In allen Location Types steigen die gemeldeten Fallzahlen zwischen 2020 und 2022 stark an,
#   mit dem höchsten Niveau im Jahr 2022.
# - Danach fallen die absoluten Fallzahlen im Jahr 2023 wieder deutlich.
# - Sehr zentrale Kreise haben in jeder Periode die höchsten absoluten Fallzahlen, weil dort die
#   Bevölkerungszahl am größten ist und damit auch die Gesamtzahl der gemeldeten Fälle insgesamt höher ausfällt.
# - Sehr periphere Kreise weisen zwar die geringsten absoluten Zahlen auf, aber das ist teilweise
#   auch eine Folge der kleineren Bevölkerungsbasis.
#
# Interpretation relative Zahlen:
# - Im Vergleich pro 100.000 Einwohner zeigt sich ebenfalls ein sehr starkes Ansteigen bis 2022
#   und ein Rückgang im Jahr 2023 in allen Lagegruppen.
# - Die höchste relative Belastung liegt im Jahr 2022 in allen Gruppen, aber die Unterschiede zwischen
#   den Location Types sind nicht immer einheitlich. Zentral und peripher sind in manchen Jahren sogar
#   höher als sehr zentral.
# - Das zeigt: Die absolute Zahl der Fälle ist in sehr zentralen Regionen höher, aber die relative
#   Belastung pro 100.000 kann je nach Phase auch in zentralen oder peripheren Regionen ähnlich hoch
#   oder sogar höher sein.

# Interpretation der monatlichen Analyse:
# - Die monatliche Betrachtung zeigt die zeitliche Dynamik innerhalb der Pandemiewellen deutlicher,
#   etwa den Anstieg im Jahr 2021 und den sehr starken Peak 2022.
# - Die Rate pro 100.000 Einwohner ist hier eine Schätzung: Für alle Monate eines Jahres wird die
#   jährliche Bevölkerungszahl als konstanter Näherungswert verwendet.
# - Das ist für eine grobe zeitliche Vergleichsanalyse sinnvoll, aber kein exakter monatlicher
#   Inzidenzwert; für eine strengere Standardisierung wären monatliche Bevölkerungsdaten oder ein
#   Modell auf Wochen-/Kreisebene besser geeignet.

# Fazit:
# - Die Fallzahlentwicklung verläuft über die Zeit in allen Location Types ähnlich: Anstieg bis 2022,
#   danach Rückgang im Jahr 2023.
# - Sehr zentrale Kreise haben die größten absoluten Fallzahlen, aber die Bevölkerungsstandardisierung
#   zeigt, dass der Unterschied zwischen den Gruppen je nach Jahr nicht immer nur auf die Lage
#   zurückzuführen ist.
# - Für die Interpretation müssen daher absolute Zahlen und relative Raten gemeinsam bewertet werden.


# ------------------------------------------------------------------------------
# Modellierung: Kann man die Beziehung statistisch modellieren?
# ------------------------------------------------------------------------------
# 1) Lineare Regression auf Jahres-/Location-Type-Ebene
#    Das ist nur ein einfaches Demonstrationsmodell, nicht die endgültige Analyse.
loc_type_year_model <- annual_cases_by_type %>%
  mutate(
    year_centered = year - mean(year),
    location_type_label = factor(location_type_label, levels = c("sehr zentral", "zentral", "peripher", "sehr peripher"))
  )

lm_model <- lm(cases_per_100k ~ location_type_label + year_centered, data = loc_type_year_model)
summary(lm_model)

# 2) Interpretation des linearen Modells
# - Der Koeffizient für year_centered zeigt, ob die Rate im Zeitverlauf insgesamt steigt oder fällt.
# - Die Koeffizienten für die Location Types zeigen, ob die Rate in bestimmten Lagegruppen höher oder
#   niedriger ist, im Vergleich zur Referenzkategorie.
# - Die lineare Regression ist eine gute erste Schätzung, aber nicht ideal für Zähldaten mit stark
#   ungleichmäßiger Verteilung.

# 3) Typischerweise besser für Fallzahlen: Poisson/Negative-Binomial
# Es ist möglich, auf Kreisebene mit Zähldaten zu modellieren:
#   count ~ location_type + year + offset(log(population))
# Dabei ist offset(log(population)) der Logarithmus der Bevölkerungszahl, damit die Modelle
# die Rate berücksichtigen.
#
# Ein zentrales Modell wäre in R etwa:
#   glm(count ~ location_type + year + offset(log(population)), family = poisson)
# oder, falls Overdispersion vorliegt:
#   MASS::glm.nb(count ~ location_type + year + offset(log(population)))
#
# Diese Modelle sind für echte Fallzahlen besser geeignet als OLS, weil sie die natürliche
# Zählverteilung der Daten berücksichtigen.

# 3a) Konkretes Poisson-Modell auf Kreis-Ebene
# Wir bauen das Modell auf den detaillierten Fallzahlen je Kreis und Jahr auf. Dafür
# verbinden wir die RKI-Fallzahlen mit der Bevölkerungsgröße und dem BBSR-Location Type.
# Der Modelloutput liefert, ob der Location Type und die Zeit die erwartete Fallzahl
# unabhängig von der Bevölkerungsgröße beeinflussen.

poisson_df <- readRDS(file.path(project_root, "data_processed", "rki_weekly_long.rds")) %>%
  as.data.frame() %>%
  mutate(
    geo_code = as.character(geo_code),
    iso_year = as.integer(iso_year),
    count = as.numeric(count)
  ) %>%
  left_join(
    geo_types %>% select(geo_code, location_type_label),
    by = "geo_code"
  ) %>%
  filter(!is.na(location_type_label)) %>%
  group_by(geo_code, iso_year, location_type_label) %>%
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop") %>%
  left_join(
    readRDS(file.path(project_root, "data_processed", "population_kreis.rds")) %>%
      as.data.frame() %>%
      transmute(
        geo_code = as.character(geo_code),
        year = as.integer(year),
        population = as.numeric(population)
      ) %>%
      filter(!is.na(population), population > 0) %>%
      group_by(geo_code, year) %>%
      summarise(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
      rename(iso_year = year),
    by = c("geo_code", "iso_year")
  ) %>%
  filter(!is.na(population), population > 0) %>%
  mutate(
    location_type_label = factor(
      location_type_label,
      levels = c("sehr zentral", "zentral", "peripher", "sehr peripher")
    ),
    year_centered = iso_year - mean(iso_year)
  )

poisson_model <- glm(
  count ~ location_type_label + year_centered + offset(log(population)),
  family = poisson,
  data = poisson_df
)

print("=== Poisson-Modell ===")
print(summary(poisson_model))

# Interpretation des Poisson-Modells:
# - exp(Koeffizient) gibt das relative Risiko bzw. den Multiplikator der erwarteten Fallzahl an.
# - Der offset(log(population)) stellt sicher, dass der Unterschied in der Bevölkerungsgröße
#   berücksichtigt wird.
# - Die Koeffizienten für location_type_label zeigen, ob ein Lagegruppe gegenüber einer Referenzgruppe
#   eine höhere bzw. niedrigere erwartete Fallzahl hat.
# - Eine signifikante Zeitvariable zeigt, ob die erwartete Fallzahl im Zeitverlauf steigt oder fällt.

# Für den vorliegenden praktischen Projektkontext ist das Poisson-Modell meist der sinnvollste
# erste Regressionsansatz, weil wir echte Zählwerte haben und die Bevölkerungsgröße berücksichtigt.


print("=== Modellierungsansatz ===")
print("Einfacher Einstieg: lm(cases_per_100k ~ location_type + year)")
print("Eher passend für Fallzahlen: glm(count ~ location_type + year + offset(log(population)), family = poisson)")
print("Wenn die Varianz größer als der Mittelwert ist: MASS::glm.nb(...)")