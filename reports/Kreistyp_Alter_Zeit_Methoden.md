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


## 8 Erweiterte deskriptive Auswertung

`erweiterte_analyse.R` erzeugt die zusätzlichen Tabellen und Abbildungen. Es verwendet die bereits validierten Bootstrap-Kontraste; es wird kein neuer Test nur für ausgewählte Rangplätze berechnet.

- **Wochenvergleich:** Für alle sechs Typenpaare und alle sieben Altersgruppen sowie die standardisierte Rate werden Differenz, Verhältnis und beide Ausgangsraten gespeichert. Bei Nenner null ist das Verhältnis nicht definiert; bei Zähler null ist es null, aber nicht logarithmierbar. Die logarithmische Grafik lässt diese Werte als Lücken stehen. Keine Pseudocounts oder versteckte Glättung.
- **Kreisverteilungen:** Ein Wert je Kreis, Phase, Zielgröße und damaligem Kreistyp; bei Typwechseln getrennte Zugehörigkeitsabschnitte mit Wochenzahl. Die Boxplots fassen diese Einträge ungewichtet zusammen; Teilphasen sind markiert. Ihre Mediane unterscheiden sich vom Mittel der Wochenmediane und von der Hauptschätzung. Die weiße Raute zeigt separat das Hauptmaß mit gleichgewichteten Wochen.
- **Monate nach W5:** Mittel aller Wochen mit Montag im betreffenden Monat. Mai 2022 enthält nur den 30.05.; die Monatsmittel dürfen nicht ungewichtet zu einem Phasenmittel zusammengefasst werden. Gewichtet nach Wochenzahl reproduzieren sie die Phase.
- **Altersranglisten:** 126 Kontraste je Skala im Gesamtzeitraum. Sortierung nach absoluter Differenz der Differenzen bzw. Betrag des natürlichen Logarithmus des Interaktionsverhältnisses. Die fünf höchsten je Skala werden unabhängig von p-Werten gezeigt. Keine Rangunsicherheit oder selektionskorrigierten Intervalle; die Auswahl ist explorativ. Vier Ausgangsraten begleiten jeden Eintrag.
- **Vertiefung:** Alle Phasenwerte der Vereinigung beider Top-5-Listen werden gespeichert. Der gemeinsame Spitzenkontrast wird als Beispiel grafisch aufgelöst. Vorhandene Holm-Korrekturen über die vollständigen Familien bleiben erhalten; keine neue Korrektur nur innerhalb der Auswahl.
- **Sensitivität:** Mittel der Wochenmittel von 383 vollständigen Kreisen, Mittel ihrer Wochenmediane und Mittel der verfügbaren Wochenmittel. Alle mit jährlicher Typzuordnung; nur deskriptive Vergleiche, keine Übertragung der Hauptanalyse-p-Werte auf geänderte Zielgrößen.

Prüfungen: 21 Altersvergleiche je Typenpaar und Skala; Ausgangsraten reproduzieren Interaktionen; Wochenkontraste reproduzieren Gesamtdifferenzen; nach Wochenzahl gewichtete Monatswerte reproduzieren PostW5; die Zugehörigkeitsabschnitte enthalten jede Kreiswoche genau einmal. `EXTENDED_VALIDATION.txt` dokumentiert den Abschluss.

## 9 Referenzprüfung, Rechenbeispiel und vollständige Phasen

`alter_zeit_korrelation.R` prüft die Standardgewichte aus 400 gegenüber 383 Kreisen im Referenzjahr 2021. Die Hauptanalyse bleibt unverändert bei 383 vollständigen Kreisen und den ursprünglichen 400-Kreis-Gewichten. Für jede Kreiswoche werden beide standardisierten Raten berechnet, danach Wochen-Typmittel und alle sechs Gesamtdifferenzen. Dies ist eine deskriptive Referenzsensitivität ohne neue p-Werte.

Ein reales Rechenbeispiel für München (AGS 09162), Woche ab 07.03.2022, enthält sieben Altersraten, tatsächliche Anteile, Referenzanteile und gewichtete Beiträge. Deren Summe wird unabhängig mit der standardisierten Kreisrate verglichen. Die Bevölkerungsrekonstruktion bleibt eine Einschränkung.

Die neue Phasentabelle enthält sämtliche neun Phasen, deren Wochenzahl, mittlere Differenz, Verhältnis der Phasenmittel sowie den Anteil negativer, gleicher und positiver Wochenunterschiede. Ein Verhältnis der Mittel ist nicht das Mittel der wöchentlichen Verhältnisse. Ausgewählte Extremwochen begründen keine Schlussfolgerung.

## 10 Deskriptive Zeitreihenkorrelation

Untersucht werden (a) sechs Paare der vier standardisierten Kreistypmittel und (b) innerhalb jedes Typs alle 21 Paare der sieben Altersgruppen, somit weitere 84 Paare. Niveauanalyse: 209 aufeinanderfolgende Wochen; Änderungsanalyse: 208 erste Differenzen `Rate[t] − Rate[t−1]`. Es werden keine Pseudocounts und keine logarithmierte Nullrate benötigt.

Pearson beschreibt lineare zeitliche Synchronität; Spearman ergänzt eine rangbasierte Sensitivität. Beide werden insgesamt und je vorhandener Phase berechnet. Bei Phasenauswertungen dürfen beide Endpunkte einer Differenz nur derselben Phase angehören. Bei konstanter Reihe ist die Korrelation nicht definiert; sie wird als NA mit `constant_series` gekennzeichnet. Kurze Phasen sind entsprechend vorsichtig zu interpretieren.

Die Autokorrelationsfunktion wird für Niveau und Änderung bis Lag 12 berechnet. Es werden keine weißen-Rauschens-Bänder gezeigt, da Unabhängigkeit nicht vorausgesetzt werden kann. Erste Differenzen garantieren weder Stationarität noch das Entfernen gemeinsamer Epidemieschocks. Deshalb gibt es keine gewöhnlichen unabhängigen-Wochen-Korrelationstests und keine Kausalaussagen oder behauptete Übertragungsrichtung.

**Exploratives Block-Resampling:** Auf den bereits gebildeten Differenzreihen werden überlappende zusammenhängende Blöcke gemeinsam für alle Reihen eines Vergleichssatzes gezogen. Blockanfänge werden aus `1…n−L+1` mit Zurücklegen gezogen, Blöcke aneinandergehängt und auf n Beobachtungen gekürzt. Hauptlänge L = 8, Sensitivitäten 4/12 Wochen; 1.999 Wiederholungen, Seed 20261124. Dieselben Zeitindizes gelten innerhalb eines Satzes für alle vier Typen bzw. sieben Altersgruppen. Damit bleibt kurzfristige Abhängigkeit innerhalb eines Blocks erhalten, nicht über gezogene Blockgrenzen hinweg.

Die 2,5%- und 97,5%-Quantile sind explorative Resampling-Bereiche. Wegen nichtstationärer Epidemiedynamik, veränderlicher Varianz und weniger großer Wellen wird keine nominale 95%-Abdeckung behauptet. Sie sind keine kalibrierten Tests, keine simultanen Bänder und keine Grundlage für eine Rangliste signifikanter Korrelationen. Phasenwerte und vollständige Kurven bleiben für die Interpretation erforderlich. Ein Prognosemodell oder eine Regression mit ARIMA-Fehlern wird in dieser Auswertung nicht geschätzt.

Die frühere Raum- und Panelmodellsektion ist nicht Bestandteil des aktuellen Berichts. Bereits erzeugte Dateien bleiben im Projekt nachvollziehbar, werden aber nicht im aktuellen Berichtspaket angeboten.

### Methodische Quellen

- [R: Holm und andere Mehrfachkorrekturen](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html).
- [Forecasting: Principles and Practice – dynamische Regression](https://otexts.com/fpp3/dynamic-regression.html): Regression und korrelierte Fehler schließen sich nicht grundsätzlich aus.
- [R: Zeitreihen-Bootstrap](https://stat.ethz.ch/R-manual/R-devel/library/boot/html/tsboot.html): Prinzip zusammenhängender Blockziehungen; die vorliegende Implementierung zieht die gemeinsamen Indizes explizit.

Prüfungen stehen in `TIME_SERIES_VALIDATION.txt`: gültige Referenzgewichte, reproduziertes Standardisierungsbeispiel, vollständige 6 + 84 Paare, 180 Gesamtkorrelationen über zwei Skalen und 270 Blockintervall-Einträge über drei Blocklängen.
