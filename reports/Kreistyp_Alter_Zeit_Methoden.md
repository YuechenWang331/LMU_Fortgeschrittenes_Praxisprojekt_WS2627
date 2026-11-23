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

## 9 Ergänzung vom 24.11.2026: räumliche Unsicherheit

`modell_raum_zeit.R` ergänzt eine räumliche Sensitivität für sämtliche 21 Alterskontraste, alle sechs Typenpaare und beide Skalen, insgesamt und in den neun Phasen. Hinzu kommen die standardisierten Gesamtvergleiche. Es werden dieselben Punktschätzer wie in der deskriptiven Analyse verwendet.

Die Kreisgeometrien stammen aus `data_geo/landkreise_simplify200.geojson`. Alle 383 Kreise werden über AGS eindeutig zugeordnet. Aus den Flächenschwerpunkten in EPSG:3035 werden vor Betrachtung der Modellergebnisse drei Raster definiert:

| Schema | Besetzte Blöcke | Interpretation |
|---|---:|---|
| Einzelne Kreise | 383 | Keine Abhängigkeit zwischen verschiedenen Kreisen |
| 100 km, primäre Sensitivität | 45 | Beliebige Abhängigkeit innerhalb desselben Raumblocks, auch über die Zeit |
| 200 km | 16 | Größere räumliche Abhängigkeit, wenige unabhängige Blöcke |
| 100 km, je Achse um 50 km verschoben | 49 | Sensitivität gegenüber den Blockgrenzen |

Rasterursprung sind ganzzahlige Vielfache der Blockweite im genannten Koordinatensystem. Die geografische Blockzuordnung ist zeitlich konstant und von der jährlichen Kreistypzuordnung unabhängig. Zwischen verschiedenen Blöcken wird Unabhängigkeit angenommen. Nahe Kreise an einer Grenze können daher getrennt sein; dies ist keine vollständige Modellierung räumlicher Korrelation. Die 200-km-Ergebnisse mit nur 16 Blöcken sind besonders vorsichtig zu lesen.

Für einen Typmittelwert wird je Kreis und Woche der Beitrag `(Rate − Wochen-Typmittel) / Anzahl Kreise des Typs` berechnet und über die Wochen des Zielzeitraums gemittelt. Diese Beiträge werden für Differenzen linear kombiniert, für logarithmierte Ratenverhältnisse mittels Delta-Methode durch die jeweilige mittlere Rate dividiert. Für Altersinteraktionen werden die Beiträge beider Altersgruppen gemeinsam verrechnet. Damit bleiben deren Abhängigkeit und sämtliche Wochen eines Kreises erhalten.

Die Beiträge werden innerhalb jedes Raumblocks summiert. Die Varianz ist die Summe der quadrierten Blocksummen, multipliziert mit `G/(G−1)`. Intervalle und zweiseitige Tests verwenden die t-Verteilung mit `G−1` Freiheitsgraden. Dies ist eine linearisierte Block-Sandwich-Sensitivität, kein neuer räumlicher Bootstrap und kein Conley-Distanzkernel. Sie korrigiert Unsicherheit, nicht räumliche Confounder.

Holm-Korrektur **je räumlichem Schema** getrennt über:

- 252 Altersinteraktionen im Gesamtzeitraum;
- 2.268 Altersinteraktionen in den Phasen;
- 12 standardisierte Typenvergleiche im Gesamtzeitraum;
- 108 standardisierte Typenvergleiche in den Phasen.

Die Standardisierungsfamilie ist damit enger als die ursprüngliche Bootstrap-Familie mit neun Zielgrößen. Deren korrigierte p-Werte sind deshalb nicht allein aufgrund anderer Standardfehler verschieden. Die Testfamilien der Altersinteraktionen bleiben dagegen gleich. Raster werden als Sensitivitäten gemeinsam berichtet; es wird nicht das günstigste Raster ausgewählt.

## 10 Ergänzende Panelmodelle: Altersinteraktion über die Zeit

Die Modelle vertiefen den aus der vollständigen Rangliste ausgewählten Vergleich **18–39 vs. 70–79 Jahre**. Sie nutzen alle vier Typen und berechnen alle sechs Typenpaare. Die Auswahl ist datenabhängig: Die Modelle sind keine unabhängige Bestätigungsstudie und bilden kein vollständiges Modell aller sieben Altersgruppen.

Seien `i` der Kreis, `a` die Altersgruppe, `t` die Woche und `p(t)` die Phase. Die lineare Spezifikation lautet schematisch:

`Rate_iat = Kreis×Alter-Fixeffekt + Woche×Alter-Fixeffekt + Typ×Alter-Haupteffekt + Typ×Alter×Phase-Abweichung + Fehler`.

W4 ist die Referenzphase, Typ 1 die Referenz innerhalb einer Altersgruppe. Die Typzuordnung folgt dem ISO-Jahr. Nicht identifizierbare Typ-Haupteffekte werden wegen Kollinearität entfernt; sie werden nicht inhaltlich interpretiert. Für die beiden Altersgruppen entfallen jeweils die Basisindikatoren für Typ 2 und Typ 4. Die verbleibenden jährlichen Wechsel zwischen Typ 3 und Typ 4 werden als Störterme berücksichtigt.

**Zielmaß:** Für jedes Typenpaar und jede Phase wird die Veränderung der Altersinteraktion gegenüber W4 berechnet. Die vier passenden Phase-Koeffizienten werden als `(jung, Typ A − Typ B) − (alt, Typ A − Typ B)` kombiniert. W4 ist dabei eine Parametrisierung, kein Gegenbeweis gegen Unterschiede in W4. Dauerhafte Unterschiede zwischen fast unveränderlichen Typen können mit Kreis-Fixeffekten nicht zusätzlich als eigenständige Haupteffekte interpretiert werden.

Das lineare Modell verwendet 160.094 Kreis-Alters-Wochen (383 × 209 × 2). Als unabhängige Kontrolle werden Ergebnisvariable und Designmatrix von beiden Fixeffekten bereinigt und die OLS-Koeffizienten per QR-Zerlegung neu berechnet. Sie stimmen bis auf numerische Toleranz überein. Das lineare Modell dient der Kontrastschätzung, nicht als Prognosemodell für zwingend nichtnegative Raten.

Für die relative Skala wird dieselbe Struktur mit Log-Link als **Poisson-Pseudolikelihood auf der Inzidenzrate** geschätzt. Die Rate darf nichtganzzahlig sein; eine Poisson-Verteilung der beobachteten Raten wird nicht behauptet. Es wird weder `log(Rate)` gebildet noch ein Pseudocount addiert. Das ist bei proportionalen Nennergewichten äquivalent zur Verwendung der Fallzahl mit Bevölkerungs-Offset und inverser Nennergewichtung. Es wird bewusst nicht das bevölkerungsgewichtete Zielmaß eines ungewichteten Fallzahlmodells verwendet. Robuste Blockvarianzen ersetzen die Poisson-Varianzannahme.

**Nullzellen:** Vor W1 sind mehrere Typ-Alters-Zellen vollständig ohne Fälle. Daraus kann eine numerisch extreme, nicht endliche relative Interaktion entstehen. Deshalb wird P0 für das relative Modell ausgeschlossen; die Entscheidung folgt fehlender Unterstützung durch positive Zellen, nicht einem p-Wert. Das relative Modell umfasst 153.200 Beobachtungen (383 × 200 × 2). Alle späteren Typ-Alters-Phasen-Zellen enthalten Fälle. Absolute Modelle und deskriptive Daten behalten P0 bei. Konvergenz und Übereinstimmung beobachteter und vorhergesagter Summen je Fixeffekt werden geprüft; die maximale relative Summenabweichung beträgt rund 1,34 × 10⁻⁸.

Die relativen Kontraste sind Verhältnisse modellbedingter Altersinteraktionen, nicht Verhältnisse der unbedingten arithmetischen Typmittel. Ein abweichender p-Wert gegenüber dem rein deskriptiven Dreifachvergleich ist deshalb kein Widerspruch.

**Unsicherheit:** `fixest::vcov` mit Kreis- bzw. Raumblock-Clustering, `K.adj=TRUE`, `G.adj=TRUE`, t-Referenz mit `G−1` Freiheitsgraden. Ein Block enthält alle Wochen und beide Altersgruppen seiner Kreise. Innerhalb eines Blocks ist beliebige Abhängigkeit erlaubt. Je Schema werden 48 absolute und 42 relative Kontraste gemeinsam mit Holm korrigiert (**90 Tests**). Die Grafiken zeigen punktweise, nicht simultane Intervalle. Die Korrektur berücksichtigt nicht die vorherige Auswahl des Alterspaars aus 21 Paaren; deshalb bleiben diese Ergebnisse explorativ.

R-Paket: `fixest` 0.14.2. Die Modelle werden mit zwei Threads geschätzt. Die großen RDS-Modellobjekte bleiben lokal; portable Koeffizienten, Kontraste, Nullzellen, Blockzuordnung und Prüfungen werden als Tabellen gespeichert.

### Quellen und Umsetzung

- [fixest: Fixed-effects OLS estimation](https://lrberge.github.io/fixest/reference/feols.html): Spezifikation von Fixeffekten und Kontrasten.
- [fixest: On Standard Errors](https://lrberge.github.io/fixest/articles/standard_errors.html): Cluster-Varianzen und kleine-Stichproben-Anpassungen.
- [fixest: Generalized linear models](https://lrberge.github.io/fixest/reference/feglm.html): Poisson-Pseudolikelihood mit Fixeffekten.
- Für die grafische Aufbereitung wurde zuvor die Arbeitsanleitung *scientific-visualization* verwendet: Kassis et al. (2026), [Scientific Agent Skills](https://doi.org/10.48550/arXiv.2609.00065). Sie ersetzt keine statistische Validierung.

Die Befunde bleiben beobachtete Zusammenhänge. Fixeffekte entfernen zeitlich stabile kreis- und altersspezifische Niveaus sowie gemeinsame altersspezifische Wochenverläufe, aber nicht alle zeitveränderlichen regionalen Störfaktoren. Tests, Impfungen und vorherige Infektionen sind nicht separat modelliert.
