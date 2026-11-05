# Variablenübersicht

**Projekt:** Zusammenhang zwischen Strukturmerkmalen und Inzidenzverläufen in den Altersgruppen (COVID-19)  
**Stand:** 05.11.2026

Dieses Variable Dictionary beschreibt ausschließlich die sechs bereinigten **Kerndatensätze** unter `data_processed/`. Ältere Zwischenprodukte und Dashboard-Dateien sind nicht enthalten. Die Beispiele veranschaulichen Werteformate bzw. mögliche Kategorien; sie sind keine Auswertungsergebnisse.

## Datensätze

| Datei | Inhalt / Zeitraum | Variablen |
|---|---|---|
| `area_kreis_2023.rds` | Kreisfläche, Gebietsstand 2023 | `geo_code`, `area_km2` |
| `raumgliederungen_kreis_2023.rds` | BBSR-Raumgliederungen, Gebietsstand 2023 | `geo_code`, `kreistyp_code`, `kreistyp_label`, `location_type_code`, `location_type_label`, `administrative_type_code`, `administrative_type_label` |
| `population_kreis.rds` | Destatis-Bevölkerung nach Altersgruppen, 2020–2023 | `geo_code`, `year`, `age_name`, `population` |
| `rki_weekly_long.rds` | Wöchentliche COVID-19-Fälle und Inzidenz, ISO-Jahre 2020–2023 | `geo_code`, `age_group`, `week_start`, `iso_year`, `iso_week`, `count`, `incidence` |
| `rki_monthly_long.rds` | Monatlich aggregierte COVID-19-Fälle und Inzidenz, 2020–2023 | `geo_code`, `age_group`, `month`, `year`, `count`, `incidence` |
| `rki_population_annual.rds` | RKI/SurvStat-Bevölkerungsdaten nach Einzelalter, 2020–2023 | `geo_code`, `age_group`, `year`, `population` |

## 1. COVID-19

| Variable | Beschreibung | Beispiele / Kategorien |
|---|---|---|
| `count` | Anzahl gemeldeter COVID-19-Fälle je Kreis und Altersgruppe; in `rki_weekly_long.rds` pro Woche, in `rki_monthly_long.rds` Summe der zugeordneten Wochen. | `0`; `12` |
| `incidence` | COVID-19-Fälle je **100.000 Einwohner** der jeweiligen Altersgruppe. Wöchentlich: RKI-Wert, für Berlin nach Zusammenfassung neu berechnet. Monatlich: `count / population * 100000` auf Basis der RKI-Jahresbevölkerung; **keine 7-Tage-Inzidenz**. | `0`; `112.23`; `NA` bei fehlendem Nenner |

## 2. Geografie und regionale Strukturmerkmale

| Variable | Beschreibung | Beispiele / Kategorien |
|---|---|---|
| `geo_code` | Fünfstelliger amtlicher Kreisschlüssel als **Zeichenkette**; einheitlich auf die 400 Kreise des Gebietsstands 2023 harmonisiert. | `01001` (Flensburg); `11000` (Berlin); `16063` (Wartburgkreis) |
| `area_km2` | Gebietsfläche eines Kreises in Quadratkilometern, Stand **2023**. | `56.73`; `118.65` (km²) |
| `kreistyp_code` | BBSR-Code des **siedlungsstrukturellen Kreistyps** (`KTU2023`). | `1`; `4` |
| `kreistyp_label` | Bezeichnung des siedlungsstrukturellen Kreistyps (`KTU_NAME`). | `Kreisfreie Großstadt`; `Dünn besiedelter ländlicher Kreis` |
| `location_type_code` | BBSR-Code des **Raumtyps nach Lage** (`RLK2023`). | `1`; `2` |
| `location_type_label` | Bezeichnung des Raumtyps nach Lage (`RLK_NAME`). | `sehr zentral`; `zentral` |
| `administrative_type_code` | BBSR-Code des **administrativen Kreistyps** (`SLK2023`). | `1`; `2` |
| `administrative_type_label` | Bezeichnung des administrativen Kreistyps (`SLK_NAME`). | `Kreisfreie Stadt`; `Landkreis` |

## 3. Zeit

| Variable | Beschreibung | Beispiele / Kategorien |
|---|---|---|
| `year` | Kalenderjahr der Bevölkerungsangabe bzw. des zugeordneten Monats; 2020–2023. | `2020`; `2023` |
| `month` | Monat der Monatsaggregation als Datum des **ersten Monatstags**. Die Zuordnung einer Kalenderwoche erfolgt nach ihrem **Montag** (`week_start`), wie im Skript von Yuechen. | `2020-01-01`; `2020-02-01` |
| `week_start` | Montag der jeweiligen RKI-Kalenderwoche (Datumswert). Kann für ISO-Woche 1/2020 noch im Dezember 2019 liegen. | `2019-12-30`; `2020-01-06` |
| `iso_year` | ISO-Kalenderjahr der Beobachtungswoche; nicht immer identisch mit dem Kalenderjahr von `week_start`. | `2020`; `2023` |
| `iso_week` | ISO-Kalenderwochennummer. | `1`; `53` |

## 4. Bevölkerung und Altersgruppen

| Variable | Beschreibung | Beispiele / Kategorien |
|---|---|---|
| `population` | Personenanzahl je Kreis, Jahr und Altersgruppe. In `population_kreis.rds`: **Destatis**, Männer und Frauen summiert. In `rki_population_annual.rds`: aus **RKI/SurvStat** abgeleitete altersspezifische Bevölkerungswerte für die Inzidenzberechnung; einzelne Werte können fehlen. | `1299`; `1410`; ggf. `NA` in RKI-Daten |
| `age_name` | Altersgruppenbezeichnung aus der **Destatis**-Tabelle 12411-0018; breitere Altersintervalle, nicht identisch mit den RKI-Einzelaltern. | `unter 3 Jahre`; `3 bis unter 6 Jahre`; `75 Jahre und mehr` |
| `age_group` | Alterskategorie der **RKI**-Daten: Einzelalter von `0` bis `79` und offene Gruppe `80+`, jeweils als Zeichenkette. In wöchentlichen und monatlichen Falldaten zusätzlich die Kategorie `NA` (Alter unbekannt). | `0`; `1`; `79`; `80+`; `NA` |

## Hinweise zur Vergleichbarkeit

- **Räumliche Harmonisierung:** Alle sechs Datensätze verwenden 400 Kreise. Für die Destatis-Bevölkerung wurde Eisenach (`16056`) im Jahr 2020 dem Wartburgkreis (`16063`) zugerechnet; in den RKI-Daten wurden die zwölf Berliner Bezirke (`11001`–`11012`) zu Berlin (`11000`) zusammengefasst.
- **Zeitliche Aggregation:** Monatliche Fälle sind Summen der Wochen, zugeordnet nach deren Montag. Die Woche ab `2019-12-30` gehört damit zu Dezember 2019 und wird aus `rki_monthly_long.rds` ausgeschlossen, bleibt aber in `rki_weekly_long.rds` (ISO-Jahr 2020) enthalten.
- **Inzidenz und Altersgruppen:** Wochen- und Monatsinzidenzen beziehen sich auf unterschiedliche Zeiträume und sind nicht unmittelbar gleichzusetzen. Destatis-`age_name` und RKI-`age_group` müssen vor altersgruppenspezifischen Joins ggf. auf gemeinsame Altersintervalle aggregiert werden.

> Änderungen an den sechs bereinigten Datensätzen bitte in dieser Übersicht nachführen.
