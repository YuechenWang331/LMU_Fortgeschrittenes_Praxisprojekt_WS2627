# Phase 2: Deskriptive Analyse (Stand 21.11.2026)

Skripte: `07_agegroups.R`, `08_waves.R`, `09_urban_rural.R`. Alles rein deskriptiv, Kreisebene (ökologisch), gemeldete Inzidenzen mit RKI-Nennern.

## Daten und Definitionen

- `data_processed/modellauswahl/covid_agegrp.rds`: Kreis × Woche × Altersgruppe, in Klimas **grobem** (0–5, 6–17, 18–39, 40–59, 60–69, 70–79, 80+) und **feinem** Schema (0–2, 3–5, 6–9, 10–14, 15–17, 18–24, 25–29, 30–39, 40–49, 50–59, 60–69, 70–79, 80+). Spalten `inc` (RKI-Nenner) und `inc_gen` (GENESIS-skalierter Nenner).
- `data_processed/modellauswahl/waves.rds`: Phaseneinteilung. **Hauptdefinition = RKI** (Epidemiologisches Bulletin 38/2022, Tab. 1, Stand 15.09.2022; Entscheidung vom 21.11.2026). Die RKI-Grenzen gelten für W1–W5, die Plateaus und den Beginn von W6. Das Ende der RKI-Phase 8 („sechste Welle“) ist nicht definiert; die Teilung ab Sommer 2022 (Ende W6, W7, R23) ist die eigene Grenze aus den Minima der bundesweiten Wocheninzidenz (Wochenstart Montag). **Entschieden (21.11.2026):** Die Gruppe legt diese Grenzen selbst fest; sie gelten als endgültige Einteilung der Hauptanalyse.

| Phase | Zeitraum | Wochen | Charakter | Grenzen |
|---|---|---|---|---|
| V20 | 30.12.2019 – 24.02.2020 | 9 | sporadische Fälle | eigen |
| W1 | 02.03. – 11.05.2020 | 11 | Wildtyp (RKI: erste Welle, KW 10–20/2020) | RKI |
| S20 | 18.05. – 21.09.2020 | 19 | Sommerplateau 2020 (KW 21–39) | RKI |
| W2 | 28.09.2020 – 22.02.2021 | 22 | zweite Welle (KW 40/2020–8/2021) | RKI |
| W3 | 01.03. – 07.06.2021 | 15 | dritte Welle, Alpha (KW 9–23/2021) | RKI |
| S21 | 14.06. – 26.07.2021 | 7 | Sommerplateau 2021 (KW 24–30) | RKI |
| W4 | 02.08. – 20.12.2021 | 21 | vierte Welle, Delta (KW 31–51/2021) | RKI |
| W5 | 27.12.2021 – 23.05.2022 | 22 | fünfte Welle, Omikron BA.1/BA.2 (KW 52/2021–21/2022) | RKI |
| W6 | 30.05. – 22.08.2022 | 13 | sechste Welle, Omikron BA.5, Sommer (Beginn KW 22/2022) | RKI-Beginn, Ende eigen |
| W7 | 29.08. – 14.11.2022 | 12 | Herbstwelle 2022 (Gipfel Okt. 2022), endet am Minimum Ende November | eigen |
| W8 | 21.11.2022 – 06.03.2023 | 16 | Winter 2022/23: zwei kleine Gipfel (Dez. ca. 275, Feb. ca. 135 je 100.000 pro Woche) | eigen |
| R23 | 13.03. – 25.12.2023 | 42 | Restphase, sehr niedrige Werte, Meldeverhalten unsicher; nicht in der Hauptanalyse | eigen |

**Änderung 21.11.2026:** W7 endet am Minimum Ende November 2022 (Vorschlag aus der Gruppe). Der Winter 2022/23 wird als eigene Welle W8 geführt, weil 76 % der Fälle der früheren Restphase (ca. 2,0 von 2,6 Mio.) auf diese 15–16 Wochen entfallen; die kumulative Inzidenz liegt bei ca. 2.400 je 100.000 (zum Vergleich W2: 2.597). Der Gipfel der Dezember-Phase (ca. 275) liegt in der Größenordnung des W2-Gipfels (ca. 210). W8 hat zwei Gipfel und ist daher kein glatter Einzelgipfel; Testverhalten in dieser Zeit wurde nicht geprüft.

Die frühere, rein datengetriebene Einteilung (Minima der geglätteten Inzidenz; Grenzen 0–2 Wochen anders, W1 begann am 30.12.2019 und dauerte 23 Wochen) wurde ersetzt. Beim Wechsel änderten sich die Rangkorrelationen zwischen Kreisinzidenz und Strukturmerkmalen im Median um 0,004 (95 %: 0,024, max. 0,065), beim Kreistyp kein Vorzeichenwechsel; die inhaltlichen Aussagen unten bleiben gleich. Die Zahlen im Abschnitt „Beobachtungen“ und in „Raummaße: Entscheidung“ wurden am 21.11.2026 mit den aktuellen Daten (RKI-Wellen, Fälle ohne Altersangabe verteilt) einzeln neu geprüft und angepasst. Plot: `results/modellauswahl/figures/fig08_rki_phasen.png`.

- `data_processed/modellauswahl/covid_wave_kreis.rds`: **Basis für die Modelle**, kumulative Inzidenz je Kreis × Phase × Altersgruppe (`cuminc` mit RKI-Nenner, `cuminc_gen` mit GENESIS-Nenner; Nenner = Mittel der Wochenbevölkerung der Phase).

## Abbildungen (`results/modellauswahl/figures/`)

| Datei | Inhalt |
|---|---|
| `fig01_national_gesamt.png` | Bundesweite Wocheninzidenz mit Wellen |
| `fig02_national_altersgruppen.png` | Wocheninzidenz je Altersgruppe |
| `fig03_alter_zeit_heatmap.png` | Einzelalter × Woche |
| `fig04_altersprofil_je_welle.png` | Inzidenz der Altersgruppe / Gesamtinzidenz je Welle |
| `fig05_woche_kreistyp_alter.png` | Wochenverlauf je BBSR-Kreistyp und Altersgruppe (y-Achse seit 26.11.2026 pseudo-logarithmisch: unterhalb von etwa 2 linear, damit Wochen ohne Fälle sichtbar bleiben; vorher fielen sie still aus der Log-Achse) |
| `fig06_verhaeltnis_kreistyp_welle_alter.png` | Raumtyp relativ zum Bundeswert, Welle × Altersgruppe |
| `fig07_korrelation_welle_alter.png` | Rangkorrelationen Kreisinzidenz × Strukturmerkmale |
| `fig08_rki_phasen.png` | Projekt-Wellen W1–W8 farbig, Pausen und Restphase grau (identisch mit fig01; Vorlage für den Abbildungsstil; Dateiname historisch) |
| `fig09_raummass_im_bundesland.png` | Rangkorrelation Kreistyp und Dichte mit Kreisinzidenz, mit und ohne Kontrolle des Bundeslands (Ränge je Land zentriert) |
| `fig16_karte_kreistyp.png` | Karte: BBSR-Kreistyp der 400 Kreise mit Ländergrenzen (aus `16_spatial.R`, siehe `reports/modellauswahl/phase3_modelle.md` Teil 4) |
| `fig17_karte_inzidenz_welle.png` | Karten: kumulative Inzidenz je Kreis relativ zum Bundeswert, je Welle (alle Altersgruppen) |

Für fig02 und fig04–fig09 gibt es zusätzlich Versionen für Klimas **feines** Altersschema (13 Gruppen) mit Suffix `_fine`, z. B. `fig06_verhaeltnis_kreistyp_welle_alter_fine.png`.

Alle Abbildungen werden zuletzt von `Scripts/modellauswahl/11_figures.R` im einheitlichen Stil (Theme in `Scripts/modellauswahl/00_theme.R`) erzeugt; `08_waves.R`, `09_urban_rural.R` und `10_plot_rki_phases.R` schreiben nur noch Daten und Tabellen (seit 21.11.2026, vorher einfachere Abbildungen, die von 11 überschrieben wurden). Stil: lineare Achse bei Zeitreihen, farbige Linien und blasse Flächen je Welle (W1–W8 feste Farben, farbenblindenfreundlich), grau außerhalb der Wellen, weiße Wellenlabels, fette Überschrift mit Untertitel. Das Skript startet sich bei Bedarf selbst mit UTF-8-Locale neu (sonst erscheinen Umlaute als „..“).

Tabellen: `results/modellauswahl/tables/waves_summary.csv`, `urban_kreistyp_wave_age.csv`, `urban_kreisart_wave_age.csv`, `corr_wave_age_struct.csv`.

## Beobachtungen

**Gesamtverlauf.** Kumulative gemeldete Inzidenz je 100.000: W1 212, W2 2.597, W3 1.524, W4 3.896, **W5 22.901**, W6 6.840, W7 4.931, W8 2.408 (RKI-basierte Wellen, Fälle ohne Altersangabe verteilt, Stand 21.11.2026; Quelle `results/modellauswahl/tables/waves_summary.csv`). W5 dominiert: 19,3 der insgesamt 38,9 Mio. gemeldeten Fälle (2020–2023) fallen in diese 22 Wochen.

**Altersprofil (Abb. 4).**
- W1 und W2: Höchste Werte bei 80+ (rund 1,5-fache Gesamtinzidenz), niedrigste bei 0–5 und 6–17. Vermutlich auch Teststrategie (gezielte Tests bei Älteren und Symptomatischen).
- W3–W5: 6–17 deutlich über dem Durchschnitt, in W4 etwa doppelt so hoch (Faktor 2,05), in W5 1,7; 70+ niedrig. Zeitlich passend zur Schultestpflicht, ob das die Ursache ist, lässt sich aus diesen Daten nicht trennen (Klima hat auf diesen Artefakt hingewiesen).
- W6/W7: 18–59 am höchsten, 0–5 am niedrigsten; in R23 liegt 80+ weit vorn (2.597 vs. 337 bei 0–5), vermutlich Testen nach Risikogruppen.

**Stadt–Land (Abb. 5, 6).** Die Wochenverläufe der vier BBSR-Kreistypen liegen auf Bundesebene eng beieinander, relevante Unterschiede stecken in den kumulativen Werten:
- W1: Großstädte über dem Durchschnitt bei Jüngeren (0–5: 1,13), dünn besiedelte Kreise darunter (0,74–0,86 in allen Gruppen).
- W4 (Delta): umgekehrt, ländliche Kreise (Typ 3/4) bei Erwachsenen 17–30 % über dem Bundeswert (Typ 4, 80+: 1,30), Großstädte 8–15 % darunter.
- W5: ländlichere Kreise leicht darüber bei 6–59 (1,05–1,10), Großstädte 6–9 % darunter.
- W6: Verhältnisse nahe 1 (0,85–1,11), Großstädte bei 6–17 15 % darunter.
- W7: Großstädte in allen Altersgruppen 6–18 % unter dem Bundeswert (6–17: 0,82), die übrigen Typen nahe 1 (0,95–1,09).
- Stadtkreis vs. Landkreis (Verhältnis der kumulativen Inzidenz): >1 bei Kindern und Jugendlichen in W1/W2 (W1, 0–5: 1,17; W2, 6–17: 1,23), in W4 bei Kindern und Jugendlichen noch knapp über 1 (1,03–1,05), bei Erwachsenen darunter (0,85–0,92), ab W5 in allen Gruppen <1 (6–17: W5 0,93, W6 0,81, W7 0,78).
- Das Muster ist also **weder stabil über die Wellen noch über die Altersgruppen**, was zur Fragestellung passt.

**Raummaße untereinander (Spearman).** Dichte und BBSR-Kreistyp ρ = −0,81, Dichte und Stadtkreis ρ = 0,74, Kreistyp und Stadtkreis nur −0,49. 39 der 106 Stadtkreise sind laut BBSR keine „Großstädte“ (Typ 2–4). Die Maße messen also Verschiedenes, wie Klima im Kickoff angesprochen hat.

**Korrelationen (Abb. 7, explorativ).**
- Mit dem Raumtyp selbst sind die Rangkorrelationen meist schwach (|ρ| ≤ 0,2); Ausnahmen W5 (18–39: ρ = 0,43 für Kreistyp, also ländlichere Kreise höher; 6–17 und 40–59 ca. 0,3), W8 bei 60+ (−0,23 bis −0,29, also städtischere Kreise höher) und W1 (leicht negativ, bis −0,20).
- **West/Ost ist stark mit den Inzidenzen verknüpft und wechselt das Vorzeichen:** W1 −0,3 bis −0,5, W4 +0,4 bis +0,5, W6 −0,4 bis −0,6, W7 bis −0,5 bei Älteren. Die Ost-Variable (Bundesländer 12–16, Berlin nicht gezählt) muss in jedem Modell kontrolliert werden, sonst vermischt sich Stadt/Land mit Ost/West. *(Stand vor der Entscheidung vom 21.11.2026: Die Ost/West-Variable entfällt, kontrolliert wird stattdessen das Bundesland, siehe Abschnitt „Raummaße: Entscheidung“.)*
- Soziale Indikatoren (SGB-II-Quote, Arbeitslosenquote) korrelieren in W1 und W5 negativ (bis −0,6), in W4 schwächer (bis −0,4); in W6/W7 kaum (Ausnahme Arbeitslosenquote bei 6–17 in W6: −0,35); in W8 dagegen positiv (0,22–0,48).

## Einschränkungen

- Gemeldete Inzidenz ≠ Infektionen: Testumfang, Meldeverhalten und Teststrategien ändern sich über die Zeit und nach Alter (W1, Schultests, R23).
- Ökologische Analyse: Aussagen gelten für Kreise, nicht für Personen.
- Phasen und Varianten sind eine grobe Einteilung. Strukturmerkmale sind Kreis-Mittelwerte 2020–2023.
- Korrelationen sind nicht adjustiert und nicht mit Unsicherheitsmaßen versehen; sie dienen nur der Orientierung.
- Berlin = 1 Kreis (Bezirke zusammengelegt); Eisenach 2020 im Wartburgkreis.

## Nächste Schritte (Vorschlag)

1. Mit Finn klären: Wellen- vs. Gesamtzeitraum-Ansatz, Altersgruppen vs. Alter als stetige Größe.
2. Modell je Welle: Negativbinomial (Offset log Bevölkerung) oder Quasipoisson auf `covid_wave_kreis.rds`, Kovariaten: Raummaß, Altersstruktur, soziale Indikatoren, Bundesland als Kontrolle (siehe Abschnitt „Raummaße: Entscheidung“); danach ein gemeinsames Modell mit Alter als glatter Funktion (GAM) und Wechselwirkung Raum × Alter.
3. ~~Residuen auf räumliche Autokorrelation prüfen~~ erledigt (21.11.2026): Kreisgrenzen, Karten und Moran's I in `16_spatial.R`, Ergebnisse in `reports/modellauswahl/phase3_modelle.md` Teil 4.
4. Sensitivität: `cuminc_gen` statt `cuminc`.

## Feines Altersschema (Stand 21.11.2026)

Entscheidung: Alle Auswertungen werden mit beiden Klima-Schemata gerechnet (grob: 7 Gruppen, fein: 13 Gruppen) und am Ende verglichen. `09_urban_rural.R` läuft jetzt für beide; die Ergebnisse des feinen Schemas haben das Suffix `_fine`:
`data_processed/modellauswahl/covid_wave_kreis_fine.rds`, `results/modellauswahl/tables/urban_kreistyp_wave_age_fine.csv`, `urban_kreisart_wave_age_fine.csv`, `corr_wave_age_struct_fine.csv`, `results/modellauswahl/figures/fig05–fig07_*_fine.png`. Die Dateien des groben Schemas sind unverändert (geprüft: `corr_wave_age_struct.csv` identisch zum Stand vor der Umstellung). Je Korrelation sind mindestens 392 Kreise vorhanden.

## Raummaße: Entscheidung (21.11.2026)

Die Variable Ost/West und die Dichte-Quartile (`dichte_q`) entfallen. **Ost/West wird durch das Bundesland (16 Länder, Spalte `state`) als Kontrollvariable ersetzt** (Fixed Effect oder Random Intercept; nicht als Raummaß). Verwendung der Raummaße:

| Maß | Rolle | Begründung |
|---|---|---|
| BBSR-Kreistyp (4 Stufen) | **Hauptmaß** für Urbanisierung | amtlich, interpretierbar, kategorial |
| log(Bevölkerungsdichte), stetig | Robustheitsprüfung | kein Informationsverlust wie bei Quartilen |
| BBSR-Lage (4 Stufen) | Zusatz (erweitertes Modell/Sensitivität), nicht gleichzeitig als zweites Hauptmaß | misst Zentralität, nicht Urbanisierung |
| Kreisart (SK/LK) | nur deskriptiv (`urban_kreisart_wave_age*.csv`) | Verwaltungsstatus, überschneidet sich mit Kreistyp |

Zusammenhang der Maße (Spearman, 400 Kreise): log(Dichte) und Kreistyp −0,81, log(Dichte) und Lage −0,78, Kreistyp und Lage 0,78, Stadtkreis und log(Dichte) 0,74. Die Maße sind also stark kollinear und sollten nicht ungeprüft gemeinsam in ein Modell. Kreistyp × Lage: Kreistyp 1 liegt nur in Lage 1–2; Kreistyp 4 überwiegend in Lage 3–4.

Begründung für die Kontrolle: Ost/West hängt mit der Inzidenz zusammen (Verhältnis der mittleren kumulativen Inzidenz Ost/West je nach Welle z. B. 0,4–0,5 in W1, 1,7–2,0 in W4, 0,5–0,7 in W6) und mit dem Kreistyp (Anteil östlicher Kreise: Typ 1 13 %, Typ 2 5 %, Typ 3 24 %, Typ 4 35 %).

Rangkorrelation Inzidenz × Kreistyp, gesamt vs. innerhalb der Bundesländer (Ränge global, dann je Land zentriert; `corr_within_state*.csv`), Auswahl, grobes Schema:

| Welle / Alter | gesamt | innerhalb Land |
|---|---|---|
| W4, 80+ | 0,23 | 0,06 |
| W4, 18–39 | 0,18 | 0,05 |
| W5, 18–39 | 0,43 | 0,38 |
| W5, 0–5 | 0,18 | −0,02 |
| W8, 70–79 | −0,29 | −0,20 |

In W4 verschwindet der Zusammenhang fast ganz, in W5 (18–39) und W8 (70–79) bleibt er überwiegend bestehen. Alles explorativ, Kreisebene (ökologisch); Bundesland fängt auch Landespolitik und Meldeunterschiede auf, nicht nur Ost/West.
