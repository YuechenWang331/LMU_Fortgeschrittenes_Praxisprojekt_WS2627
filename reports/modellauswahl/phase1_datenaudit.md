# Phase 1: Datenaudit und Kreis-Verknüpfung

Stand: 21.11.2026. Skripte: `Scripts/modellauswahl/01_kreis_key.R`, `02_clean_covid.R`, `03_audit_structural.R`
(aus dem Wurzelordner des Gruppen-Repos ausführen: `Rscript Scripts/modellauswahl/01_kreis_key.R`, …). Rohdaten in `data_raw/` bleiben unverändert.

## Entscheidungen

| Thema | Entscheidung |
|---|---|
| Berlin | 12 Bezirke (AGS 11001–11012) zu einem Kreis 11000 zusammengefasst (Fälle und Bevölkerung addiert, Inzidenz neu berechnet) → **400 Kreise** |
| Verknüpfungsschlüssel | 5-stelliger AGS, nie der Name (44 Namen doppelt, z. B. Stadt/Landkreis Ansbach) |
| Zeitraum | 2020–2023 laut Protokoll: 209 Wochen (2019-12-30 bis 2023-12-25; 2020 hat 53 Wochen). 2024 wird ausgeschnitten |
| Fälle ohne Altersangabe | 33.042 (0,085 %), Rohwerte in `covid_age_unknown.rds`. **Seit 21.11.2026 proportional verteilt** (siehe Abschnitt unten): `cases` enthält die verteilten Fälle, `cases_obs` die gemeldeten Fälle mit Altersangabe |
| Fehlende Bevölkerungszellen | 29 Kombinationen Kreis × Einzelalter × Jahr (alle mit 0 Fällen); aus Nachbarjahren interpoliert bzw. aufgefüllt |
| Kontrolle | Eigene Inzidenz (Fälle/Bevölkerung·100.000) stimmt mit der gelieferten RKI-Inzidenz überein. Seit 26.11.2026 wird dafür nur mit den Fällen **mit** Altersangabe gerechnet, weil die RKI-Inzidenz die Fälle ohne Alter nicht enthält: Geprüft werden **Quantile**, nicht jede Zelle: 1., 50. und 99. Perzentil des Verhältnisses liegen bei 0,99986 / 1,00000 / 1,00014; `02_clean_covid.R` bricht ab, wenn eines davon um mehr als 0,1 % von 1 abweicht. Von 3.584.203 vergleichbaren Zellen weichen 378 (0,01 %) um mehr als 0,1 % ab, höchstens um 0,46 %, keine um mehr als 1 % (nachgerechnet am 26.11.2026). Die Wirkung der verteilten Fälle ohne Alter wird getrennt ausgegeben. Daten unverändert. |

## Ergebnis COVID-Daten (`data_processed/modellauswahl/covid_long.rds`)

400 Kreise × 81 Altersjahre (0–79, 80+) × 209 Wochen = 6.771.600 Zeilen.
Spalten: `ags, age, week, year, cases_obs, cases, pop, pop_imputed, inc, age_num`.
Fälle mit bekanntem Alter 2020–2023: 38.848.313 (2020: 1,78 Mio; 2021: 5,44 Mio; 2022: 30,17 Mio; 2023: 1,46 Mio).

### Verteilung der Fälle ohne Altersangabe (Entscheidung 21.11.2026)

- **Methode:** Je Kreis × Woche werden die Fälle ohne Alter nach der Altersverteilung der Fälle mit bekanntem Alter derselben Kreis-Woche auf die Altersjahre verteilt (`Scripts/modellauswahl/02_clean_covid.R`). 2 Fälle in Wochen ohne bekannte Fälle bleiben unverteilt. `cases` ist dadurch nicht mehr ganzzahlig.
- **Grund:** Die Fälle ohne Alter sind national selten (0,085 %), aber stark konzentriert: Vechta (03460) W5 16 %, Leer (03457) W5 10 %, Herne (05916) W3 5 % der Fälle. Ohne Verteilung wären die altersspezifischen Inzidenzen dieser Kreise entsprechend unterschätzt.
- **Annahme:** Fälle ohne Altersangabe haben dieselbe Altersverteilung wie die übrigen Fälle desselben Kreises in derselben Woche.
- **Sensitivität** (`Scripts/modellauswahl/14_sens_age_unknown.R`, Hauptmodell m1, grobes Schema, 168 Kreistyp-Koeffizienten): mittlere Änderung der log-IRR 0,0008, maximal 0,0088 (W5); Signifikanz (95 %, unkorrigiert) ändert sich bei 2 grenzwertigen Koeffizienten (W5 80+ Typ 2: 1,064 → 1,068; W8 60–69 Typ 3: 0,916 → 0,916). Ergebnisse: `results/modellauswahl/tables/sens_age_unknown_*.csv`.
- **Entschieden (21.11.2026):** Die proportionale Verteilung ist die Hauptanalyse; die Sensitivitätsanalyse oben (ohne Verteilung) wird als Robustheitsprüfung berichtet.

## Strukturvariablen: Abdeckung

Alle Dateien lassen sich auf alle 400 Kreise verknüpfen, wenn man zwei Kodierungsbesonderheiten beachtet:

1. **Hamburg und Berlin** stehen in den GENESIS-Dateien nur als Bundesland (`1_variable_code == "DLAND"`, Code `02` bzw. `11`), nicht als Kreis. Die Berlin-Bezirke dort nicht zusätzlich verwenden (Doppelzählung).
2. **Pendler-Dateien** sind auf Gemeindeebene. Kreis-AGS = Stellen 2–6 des Codes (`P081165004046` → `08116`), dann auf Kreis aggregieren.
3. Sonderzeichen in den Werten: `-` = genau 0; `.`, `x`, `/` = unbekannt/gesperrt (= NA, nicht 0).

| Nr. | Thema (Klima, 12.11.) | Tabelle | Datei | Jahre | Kreise | Anmerkung |
|---|---|---|---|---|---|---|
| 1 | Altersstruktur | 12411 | `12411-0018 …csv` | 2020–2024 | 400 | Geschlecht × 17 Altersgruppen |
| 2 | Pendler | 19321 | `ein-/auspendelnde21–23` | 2021–2023 | 400 | Gemeindeebene → aggregieren; **2020 fehlt**; nur Summen je Gemeinde, keine Pendlerströme (Anteil innerhalb/zwischen Regionen nicht ableitbar, Pendlersaldo schon); bis 55 % unbekannte Zellen bei den Auspendlern auf Gemeindeebene |
| 3 | Grundsicherung | 22811 | `grundsicherung_flat.csv` | 2020–2023 | 400 | nur nach Leistungsart, **ohne** Alter/Geschlecht. Tabellen 22121 und 22151 nicht heruntergeladen |
| 4 | Pflegestatistik | 22411 | `pflegestat_flat.csv` | **nur 2021, 2023** | 400 | |
| 5 | Kitas | 22541 | `tageseinrichtungen_flat.csv` | 2020–2023 | 400 | Stichtag 1. März; mit Altersgruppen der Kinder |
| 6 | Bildungserfolg | 21111 | `abschlusse_flat.csv` | 2020–2023 | 400 | ca. 4,6 % unbekannt (Schuljahre) |
| 7 | Schutzsuchende | 12531 | `schutzsuchende_flat.csv` | 2020–2023 | 400 | ca. 4 % unbekannt |
| 8 | Arbeitslosigkeit | 13211 | `arbeitslose_flat.csv` | 2020–2023 | 400 | Absolutzahlen; für eine Quote Nenner nötig |
| 9 | Tourismus | 45412 | `tourismus_flat.csv` | 2020–2023 | 400 | 2020: 6,7 % unbekannt |
| 10 | Beschäftigte Gemeinden | 74111 | `beschaeftigte_flat.csv` | 2020–2023 | 400 | Vollzeitäquivalente im öffentlichen Dienst der Gemeinden |
| 11 | Lohn und Einkommen | 73111 | **nicht vorhanden** | | | muss heruntergeladen werden |
| – | Bodennutzung | 33111 | **nicht vorhanden** | | | Idee für Urbanisierung (Siedlungs-/Verkehrsfläche) |
| – | Rasterdaten Zensus 2022 | | **nicht vorhanden** | | | Idee für Urbanisierung (Anteil Bevölkerung in dichten Rasterzellen) |
| – | IAB-Maßnahmentabelle | | **nicht vorhanden** | | | Corona-Maßnahmen, optional |

Bereits vorhanden für das Urbanisierungsmaß: Fläche (`11111-0002`, 2020–2023, 400 Kreise) → Bevölkerungsdichte;
BBSR Siedlungsstruktureller Kreistyp 2020 (1 kreisfreie Großstadt 67, 2 städtischer Kreis 133, 3 ländlicher Kreis mit Verdichtungsansätzen 98, 4 dünn besiedelter ländlicher Kreis 102);
BBSR Raumtyp Lage 2020 (1 sehr zentral 106, 2 zentral 145, 3 peripher 131, 4 sehr peripher 18).
Beide BBSR-Dateien sind **Latin-1** kodiert und haben 401 Zeilen: Eisenach (16056) steht dort noch als eigener Kreis, ist aber seit 2021 im Wartburgkreis (16063) aufgegangen. Beide haben dieselbe Kategorie (Kreistyp 4, Lage 3); `04_clean_structural.R` legt sie deshalb ausdrücklich zusammen (mit Prüfung). Die Häufigkeiten oben gelten für die 400 Kreise der Analyse (in der Rohdatei: Kreistyp 4 = 103, Lage 3 = 132). Geändert 24.11.2026; die Ergebnisse ändern sich dadurch nicht (Eisenach war vorher stillschweigend herausgefallen).
Die `raumgliederungen-referenzen-*.xlsx` wurden noch nicht geprüft.

## Altersgruppen laut Klima

Grob: 0–5, 6–17, 18–39, 40–59, 60–69, 70–79, 80+.
Fein: 0–2, 3–5, 6–9, 10–14, 15–17, 18–24, 25–29, 30–39, 40–49, 50–59, 60–69, 70–79, 80+.
Beide sind Vereinigungen der Einzeljahre in `covid_long.rds` und lassen sich direkt bilden.

## Aufbereitete Strukturvariablen (`Scripts/modellauswahl/04_clean_structural.R`)

Ausgabe: `data_processed/modellauswahl/struct_kreis_year.rds` (400 Kreise × 2020–2023 = 1.600 Zeilen, auch als CSV in `results/modellauswahl/tables/`)
und `data_processed/modellauswahl/struct_kreis_const.rds` (400 Zeilen: Land, Kreisart SK/LK, BBSR-Kreistyp und -Lage, Mittelwert jedes Indikators über 2020–2023 mit Endung `_mean`).
Fehlende Werte je Indikator: `results/modellauswahl/tables/struct_na_summary.csv`.

Alle Raten verwenden die Bezugsbevölkerung der RKI-Daten (gleicher Nenner wie bei der Inzidenz).

| Gruppe | Indikatoren (Spaltennamen) | Hinweise |
|---|---|---|
| Altersstruktur | `anteil_0_5, _6_17, _18_39, _40_59, _60_69, _70_79, _80p, _65p` (in %), `pop_*` | aus den RKI-Einzeljahren, passend zu Klimas Altersgruppen |
| Dichte | `flaeche_km2`, `dichte` (Einw./km²) | |
| Soziales | `sgb2_je1000`, `grundsicherung_alter_je1000_65p`, `hilfe_lebensunterhalt_je1000`, `asylbewerberleistung_je1000` | Tabelle 22811 hat keine Alters-/Geschlechtsaufteilung |
| Arbeit | `alo_je100_15_64`, `alo_jung_je100_15_24`, `alo_langzeit_anteil`, `alo_auslaender_anteil` | keine offizielle Arbeitslosenquote (Nenner: Bevölkerung 15–64 bzw. 15–24) |
| Öff. Dienst | `oed_beschaeftigte_vze_je1000` | für Hamburg, Bremen, Bremerhaven, Berlin immer NA; inhaltlich schwer zu deuten |
| Pflege | `pflegeheim_plaetze_je1000_65p`, `pflegeheim_personal_je1000_65p`, `pflegedienst_personal_je1000_65p` | nur 2021 und 2023, sonst NA (für Modelle `_mean` nutzen) |
| Kita | `kita_plaetze_je1000_0_13`, `kita_paed_personal_je1000_0_13` | Plätze nur gesamt (ohne Altersaufteilung); Nenner Kinder 0–13 |
| Schutzsuchende | `schutzsuchende_je1000` | ca. 10 Kreise NA je Jahr (u. a. das ganze Saarland) |
| Tourismus | `uebernachtungen_je_einw`, `betriebe_je100000` | 2020: 25 Kreise NA. Gästebetten (GAST03) sind in der Datei durchgehend „-“ und werden nicht verwendet |
| Schule | `schule_ohne_abschluss_anteil`, `schule_hochschulreife_anteil` | Abgänger nach Schulort, nicht Wohnort; manche Kreise ohne Gymnasium haben 0 % |
| Pendler | `pendler_ein_je1000`, `pendler_aus_je1000`, `pendler_saldo_je1000` | nur 2021–2023. Summen der Gemeinden enthalten auch Pendeln innerhalb des Kreises; belastbar ist vor allem der Saldo |
| Typologie | `kreisart` (aus RKI-Namen SK/LK), `kreistyp_code` (1–4), `lage_code` (1–4) | „Stadtkreis“ ≠ BBSR-Typ 1: 39 kreisfreie Städte haben BBSR-Typ 2–4 |

### Wichtige Befunde bei der Aufbereitung

1. **Eisenach 2020:** In GENESIS ist Eisenach (16056) 2020 noch ein eigener Kreis, in den RKI-Daten steckt es schon im Wartburgkreis (16063). Alle 2020er Werte (und die Fläche) wurden zusammengelegt, sonst wären die Raten dort um ca. 25 % verzerrt.
2. **Bevölkerung 2022/2023 (Skript `05_check_population.R`):** Die RKI-Bevölkerung stimmt für 2020/2021 exakt mit GENESIS 12411 überein (Abweichung 0,00 %). Ab 2022 gibt es einen Bruch: RKI 84,36 Mio. vs. GENESIS 83,12 Mio. (+1,5 %), 2023: 84,67 vs. 83,46 Mio. Auf Kreisebene −4,9 % bis +9,8 % (5.–95. Perzentil: −1,2 % bis +5,1 %); 71 Kreise weichen um mehr als 3 % ab. Die RKI-Werte wachsen 2021→2022 im Median um 1,3 %, die GENESIS-Werte nicht (−0,05 %). Das passt zur Zensus-2022-Revision in GENESIS, während die RKI-Nenner auf der alten Fortschreibung beruhen (nicht überprüft, ob das so dokumentiert ist). Größte Abweichungen in Universitäts- und Mittelstädten (Landshut +9,8 %, Trier +8,6 %, Bamberg, Kempten, Regensburg, Halle, Köln).
   Nach Altersgruppe (2022, national): 0–5 Jahre +3,2 %, 18–39 +2,5 %, 6–17 +2,0 %, 40–59 +0,7 %, 60+ +0,9 %. Wirkung auf die kumulative Inzidenz 2022 je Kreis: Rangkorrelation 0,987; Median der Rangverschiebung 8 von 400 Plätzen (95 %: 44, max. 92). Entscheidung (Vorschlag, noch nicht mit Klima/Finn abgestimmt): Hauptanalyse mit den RKI-Nennern (passend zu den gelieferten Inzidenzen), Sensitivitätsanalyse mit GENESIS-Nennern (Skalierung je Kreis × Altersgruppe × Jahr) für 2022/2023.
3. Kreisart: Region Hannover und Städteregion Aachen haben kein LK/SK-Präfix und wurden als Landkreis gesetzt.

## Sensitivitäts-Nenner (`Scripts/modellauswahl/06_pop_sensitivity.R`)

`data_processed/modellauswahl/pop_genesis_adj.rds`: je Kreis × Einzelalter × Jahr die RKI-Bevölkerung (`pop_rki`), die auf GENESIS 12411 skalierte Bevölkerung (`pop_gen`) und der Faktor (`faktor` = GENESIS / RKI in der jeweiligen GENESIS-Altersgruppe). Skaliert wird in den 17 GENESIS-Altersgruppen (unter 3, 3–5, 6–9, 10–14, …, 60–64, 65–74, 75+); die Verteilung der Einzeljahre innerhalb einer Gruppe bleibt wie bei RKI. Die Gruppensummen stimmen exakt mit GENESIS überein (Abweichung < 1e-9). „75+“ enthält 75–79 und 80+, beide bekommen denselben Faktor.

Faktoren: 2020 ≈ 1 (0,974–1,009), 2021 = 1, 2022 Median 0,986 (Zellen von 0,80 bis 1,18), 2023 Median 0,987 (0,78 bis 1,17).

Wirkung auf die kumulative Inzidenz je Kreis × grobe Altersgruppe (Median der relativen Änderung; Rangkorrelation zwischen beiden Varianten):

| Altersgruppe | 2022 Änderung | 2022 ρ | 2023 Änderung | 2023 ρ |
|---|---|---|---|---|
| 0–5 | +2,8 % | 0,994 | +2,5 % | 0,999 |
| 6–17 | +1,8 % | 0,990 | +1,9 % | 0,999 |
| 18–39 | +2,2 % | 0,975 | +2,0 % | 0,997 |
| 40–59 | +0,7 % | 0,985 | +0,6 % | 0,997 |
| 60–69 | +0,5 % | 0,993 | +0,5 % | 0,997 |
| 70–79 | +0,6 % | 0,994 | +0,6 % | 0,996 |
| 80+ | +1,3 % | 0,993 | +1,4 % | 0,996 |

Einzelne Kreise ändern sich bis etwa +7 % (95. Perzentil), nach unten bis etwa −2,5 % (5. Perzentil). Gesamtes Fazit: Die Rangfolge der Kreise innerhalb einer Altersgruppe ist stabil (ρ ≥ 0,975); die Niveaus verschieben sich bei den Jüngeren um 2–3 %, bei den Älteren um 0,5–1,5 %. Verwendung: Modelle einmal mit `pop_rki` (Hauptanalyse) und einmal mit `pop_gen` (Sensitivität) rechnen und die Koeffizienten vergleichen.

## Offene Punkte

- Fehlende Tabellen nachladen (73111, ggf. 33111, Zensus-Raster) und mit Klima klären, welche Grundsicherungstabelle gemeint ist.
- Pflegestatistik hat nur 2 Stichtage: Verwendung als zeitkonstantes Merkmal oder weglassen.
- Strukturvariablen sind nur auf Kreisebene verfügbar → Auswertung ist ökologisch (Aggregatebene).
