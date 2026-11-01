# Variablen Übersicht

Übersicht der Variablen in den vorhandenen Datensätzen.

> **Hinweis:** Dieses Variable Dictionary wurde manuell erstellt und wird manuell gepflegt. Bitte verwendet die hier festgelegten Namenskonventionen einheitlich in allen Skripten. Neue Variablen oder Änderungen an bestehenden Variablennamen sollten hier dokumentiert werden.

## 1. COVID-19

| Variable | Beschreibung | Beispiele / Kategorien |
|------------------------|------------------------|------------------------|
| `cases` | Monatliche COVID-19-Fallzahl | `0`; `1` |
| `count` | Wöchentliche COVID-19-Fallzahl | `0`; `1` |
| `incidence` | COVID-19-Inzidenz (Definition und Einheit prüfen) | `0`; `112.23` |

## 2. Geografie & Regionale Strukturmerkmale

| Variable | Beschreibung | Beispiele / Kategorien |
|------------------------|------------------------|------------------------|
| `geo_code` | Gebietsschlüssel der geografischen Einheit | `01001`; `01002` |
| `geo_name` | Name der geografischen Einheit | Flensburg; Kiel |
| `geo_label` | Vollständige Gebietsbezeichnung | Flensburg, kreisfreie Stadt; Kiel, kreisfreie Stadt |
| `district_index` | Numerische Gebiets-ID im Datensatz | `1`; `2` |
| `district` | Name des Kreises | Heilbronn; Erlangen-Höchstadt |
| `area_km2` | Gebietsfläche in km² | `56.73`; `118.65` |
| `bundesland_code` | Bundesland-Code | `01`; `02` |
| `bundesland_name` | Name des Bundeslandes | Schleswig-Holstein; Hamburg |
| `kreis_type` | Verwaltungstyp des Kreises | Landkreis; kreisfreie Stadt; Other |
| `administrative_type_code` | Code des administrativen Kreistyps | `1`; `2` |
| `administrative_type_label` | Administrativer Kreistyp | Kreisfreie Stadt; Landkreis |
| `kreisregion_code` | Code der Kreisregion | `01059`; `01002` |
| `kreisregion_name` | Name der Kreisregion | Schleswig-Flensburg/Flensburg; Kiel |
| `kreistyp_code` | Code des siedlungsstrukturellen Kreistyps | `4`; `1` |
| `kreistyp_label` | Siedlungsstruktureller Kreistyp | Dünn besiedelter ländlicher Kreis; Kreisfreie Großstadt |
| `location_type_code` | Code des Raumtyps nach Lage | `2`; `1` |
| `location_type_label` | Raumtyp nach Lage | zentral; sehr zentral |

## 3. Zeit

| Variable | Beschreibung | Beispiele / Kategorien |
|------------------------|------------------------|------------------------|
| `year` | Bezugsjahr der Daten | `2020`; `2023` |
| `month` | Monat der Beobachtung (als Datum gespeichert) | `2020-01-01`; `2020-02-01` |
| `week_start` | Beginn der Beobachtungswoche | `2019-12-30`; `2020-01-06` |
| `iso_year` | Jahr gemäß ISO-Wochenkalender | `2020`; `2021` |
| `iso_week` | Kalenderwoche gemäß ISO-Wochenkalender | `1`; `2` |

## 4. Bevölkerung & Alter

| Variable | Beschreibung | Beispiele / Kategorien |
|------------------------|------------------------|------------------------|
| `population` | Bevölkerungszahl (Definition je nach Datenquelle) | `1410`; `1299` |
| `sex` | Geschlecht | männlich; weiblich |
| `age_group` | Alterskategorie (Codierung je nach Datenquelle) | `0`; `1` |
| `age_code` | Code der Altersgruppe | `ALT000B03`; `ALT003B06` |
| `age_name` | Bezeichnung der Altersgruppe | unter 3 Jahre; 3 bis unter 6 Jahre |
| `age_low` | Untere Altersgrenze (inklusive) | `0`; `3` |
| `age_high` | Obere Altersgrenze (exklusive, falls vorhanden) | `3`; `6` |

## Weitere Hinweise

