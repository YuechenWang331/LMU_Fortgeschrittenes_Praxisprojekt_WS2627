# Methoden: Kreistyp, Alter und Zeit

Stand: 23.11.2026. Hauptanalyse mit jährlicher Kreistypzuordnung.

## 1 Daten und Zielgröße

Eingabe: `data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds`.
400 Kreise, 209 Wochen und sieben Altersgruppen. 383 Kreise haben durchgehend gültige Altersraten; 17 Kreise mit mindestens einem fehlenden Nenner werden aus der Hauptanalyse ausgeschlossen. Fehlende Werte werden nicht als null behandelt.

Für jede Woche gilt `kreistyp_code` des zugehörigen ISO-Jahres. Vier Kreise wechseln im Ausgangsdatensatz den Typ. Die Analyse beschreibt damit jährlich definierte Gruppen, nicht über alle Jahre unveränderte Typenpopulationen.

Pro Woche wird der ungewichtete Mittelwert der Kreisraten innerhalb eines Typs berechnet. Zeitraumwerte sind ungewichtete Mittelwerte dieser Wochenmittel. Bei wechselnder Gruppengröße ist dies nicht dasselbe wie ein gemeinsames Mittel aller Kreiswochen.

## 2 Altersstandardisierung

Die Referenzgewichte entsprechen den Altersanteilen der summierten Bevölkerungsnenner aller 400 Kreise im vollständigen Referenzjahr 2021. Jede Kreiswoche erhält dieselben Gewichte; danach werden die standardisierten Kreisraten gemittelt. Die jährliche Kreistypzuordnung bleibt davon unabhängig.

Die Nenner stammen aus dem bestehenden Rekonstruktionsprozess der RKI-Daten, nicht aus einer unabhängig bestätigten amtlichen Bevölkerungstabelle. Eine zweite Referenz mit gleichen Kreisgewichten wird als Sensitivität berechnet.

## 3 Zeiträume

`period_definitions.csv` enthält Anfang, Ende und Wochenzahl aller neun nicht überlappenden Zeiträume. W1–W5 folgen der bestehenden RKI-Phaseneinteilung; Vor- und Zwischenphasen bleiben enthalten. Der Abschnitt nach W5 umfasst KW 22/2022 bis KW 52/2023 und ist keine einzelne Welle.

## 4 Bootstrap und Kontraste

1.999 gemeinsame Ziehungen von 383 Kreisen mit Zurücklegen, Startwert 20261123. Jede Ziehung erhält die vollständige Historie eines Kreises einschließlich Alter, Zeit und jährlichem Kreistypwechsel. Es gibt keine feste Stratifizierung nach dem Typ von 2023.

Innerhalb von Jahr-Zeitraum-Blöcken werden gezogene Kreise nach ihrer damaligen Zugehörigkeit gemittelt. Blockwerte werden nach ihrer Wochenzahl gewichtet. So behalten alle Wochen dasselbe Gewicht. Dieselben Ziehungen werden für alle Kontraste verwendet.

Absolute Kontraste sind Differenzen; relative Kontraste sind Verhältnisse der mittleren Raten. Altersinteraktionen vergleichen zwei Alterskontraste. Zeitinteraktionen vergleichen zwei Zeitraumkontraste. Dreifachkontraste vergleichen Altersinteraktionen zwischen Zeiträumen. Relative Interaktionen sind Verhältnisse von Verhältnissen, auf Log-Skala berechnet.

Standardfehler: Standardabweichung der Bootstrap-Kontraste. Intervalle: Schätzer ± 1,96 Standardfehler; relative Intervalle nach Rücktransformation. Zweiseitige Tests verwenden dieselbe Normalapproximation. Bei nicht endlichen relativen Kontrasten oder Ziehungen werden Intervall und p-Wert als nicht verfügbar markiert, ohne künstlichen Pseudocount.

## 5 Mehrfachkorrektur

Holm-Korrektur getrennt für:

- Gesamtzeitraum: 6 Paare × 9 primäre Zielgrößen × 2 Skalen = 108 Tests.
- Neun Teilzeiträume: 972 primäre Paarvergleiche.
- Alternative Standardgewichte: 120 Vergleiche.
- Altersinteraktionen: 252 insgesamt, 2.268 innerhalb der Teilzeiträume.
- Zeitrauminteraktionen: 3.456 Tests.
- Alter-Zeitraum-Interaktionen: 9.072 Tests.

Die gezeichneten 95%-Intervalle sind punktweise, nicht simultan und nicht Holm-adjustiert. Die ausgewählten Zahlenbeispiele im Bericht ersetzen nicht die vollständigen Vergleichstabellen.

## 6 Sensitivität und Grenzen

Gespeichert werden deskriptive Wochenmittel mit verfügbaren Kreiswochen, alternativer Standardbevölkerung sowie fester 2023-Zuordnung als Gegenprüfung. Die jährliche Zuordnung ist die Hauptanalyse. Alte Dateinamen mit `sensitivity_complete_annual_types` bleiben aus Kompatibilitätsgründen erhalten und entsprechen jetzt dem Hauptansatz.

Die Inferenz ist explorativ für ein hypothetisches Ensemble vergleichbarer Kreise. Die beobachteten Kreise sind keine Zufallsstichprobe aus Deutschland. Der Bootstrap erhält die Abhängigkeit innerhalb eines Kreises, modelliert aber keine räumliche Abhängigkeit zwischen Kreisen. Meldeinzidenzen sind keine kausalen Wohnorteffekte und nicht identisch mit allen tatsächlichen Infektionen.

## 7 Reproduktion und Prüfung

Im Projektverzeichnis `run_analysis.R` und anschließend `validate_results.R` aus `Scripts/Kreistyp_Alter_Zeit/` ausführen. Die Prüfung kontrolliert Vergleichsfamilien, Schlüssel, fehlende Werte, Zeitgewichtung sowie eine unabhängige Standardisierung und drei vollständige Bootstrap-Ziehungen aus den Wochenwerten. Ergebnisse und Prüfprotokoll stehen in `results/Kreistyp_Alter_Zeit/`.
