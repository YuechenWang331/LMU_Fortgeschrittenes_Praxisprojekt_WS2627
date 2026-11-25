# Varianz- und Abhängigkeitsstruktur

## Stichprobe und Vergleichsfolge

Alle Fits verwenden die unveränderten M3-Fixed-Effects (Kreistyp × Altersgruppe × Phase) und dieselben 22370 Beobachtungen aus 400 Kreisen wie die erste Modellierungsrunde. Die gespeicherten M3-Referenzen für das Originalskalen-LMM und das negative Binomial-GLM wurden nach Prüfung der Stichprobe und Prüfsummen wiederverwendet.

Im Gauß-Zweig wurde zuerst der Kreis-Altersgruppen-Intercept geprüft. Darauf folgte eine phasenspezifische Residualvarianz, motiviert durch die ausgeprägte Heteroskedastizität im ersten Bericht und das wechselnde Inzidenzniveau zwischen Phasen. Für den nächsten Schritt wurde jeweils der konvergierte, nicht singuläre Kandidat mit niedrigerem BIC fortgeführt. Dies legt keine endgültige Baseline fest. CAR(1) wurde anschließend bei derselben Varianz- und Zufallseffektstruktur geprüft. Im Zählzweig wurde ein NB2-GLMM mit Kreis- und Kreis-Altersgruppen-Intercepts gegen das NB2-GLM verglichen.

| Kandidat | Vergleichsfit | ΔAIC | ΔBIC | Fit-Status |
|---|---|---:|---:|---|
| raw_kreis_age | raw_kreis | 2,0 | 10,0 | singular |
| raw_phase_variance | raw_kreis | -39967,2 | -39911,1 | fitted |
| raw_car1 | raw_phase_variance | 2,0 | 10,0 | fitted |
| nb_glmm | nb_glm | -3765,3 | -3749,3 | singular |

Negative Differenzen begünstigen den Kandidaten. Die Gauß-Vergleiche verwenden ML. Die Profiloptimierung schätzt die Varianzverhältnisse und gegebenenfalls ρ; nlme rekonstruiert den Fit. AIC und BIC zählen auch diese profilierten Parameter. Die NB2-Vergleiche verwenden dieselben Zählwerte und denselben Personenwochen-Offset sowie eine Laplace-Approximation der marginalen GLMM-Likelihood. Im GLMM werden dieselben gesättigten M3-Effekte numerisch als Zellmittel parametrisiert. Werte aus den beiden Antwortfamilien werden getrennt beurteilt. Die Vergleiche sind deskriptiv. Randparameter bei Zufallsvarianzen und bei CAR(1) machen reguläre χ²-Referenzen für Likelihood-Ratio-Tests ungeeignet.

Die phasenspezifische Residualvarianz verbessert beide Informationskriterien deutlich. Der zusätzliche Kreis-Altersgruppen-Intercept im Gauß-Modell liegt am Rand und verbessert die Likelihood praktisch nicht. Das NB2-GLMM verbessert den Fit deutlich gegenüber dem GLM, ist aber wegen der sehr kleinen Kreis-Altersgruppen-Varianz singulär. Der Gewinn stützt die gemeinsame Erweiterung gegenüber dem GLM und liefert keine getrennte Evidenz für den Kreis-Altersgruppen-Intercept.

## Varianz, Konvergenz und Zeit

Geschätzte Standardabweichungen für das konstante Gauß-Modell mit zwei Intercepts: kreis_age = 0,00, kreis = 21,66, residual_reference = 66,75. Beim NB2-GLMM auf Logratenskala: kreis = 0,22, kreis_age = 0,00.
Im heteroskedastischen Gauß-Fit reichen die geschätzten Residual-SD je Phase von 3,20 (G1) bis 151,18 (W5).

Für CAR(1) wurde die Mitte der vorgesehenen ISO-Wochen jeder Phase verwendet. Abstände und Lücken gehen in Kalenderwochen ein. Die Korrelation wirkt innerhalb desselben Kreises und derselben Altersgruppe. Die numerische Profiloptimierung verwendete Starts bei 0,20 und 0,95 je Woche. Geschätztes ρ je Woche: 0,200. Die maximale absolute gepoolte Korrelation über die betrachteten Abstände beträgt beim Vergleichsfit 0,53 und nach CAR(1) 0,53 für Pearson- bzw. 0,53 für normalisierte Residuen.

Am kürzesten beobachteten Abstand von 11 Wochen entspricht das einem Korrelationswert von 2e-08. Der CAR(1)-Parameter ist in diesem Bereich schwach identifiziert. Die Residuenkorrelation bleibt bestehen, während sich AIC und BIC verschlechtern.

Die NB2-Dispersion θ beträgt 5,05 im GLM und 6,52 im GLMM. Für die Residuen sind phasenspezifische RMS, der Anteil großer standardisierter Residuen und Abstandsdiagnosen exportiert. Der GLMM-Pearson-Quotient wird anhand der Zahl der Fixed Effects skaliert und dient als deskriptive Diagnose. Konvergenzwarnungen, Hessian-Diagnosen und randnahe Zufallsvarianzen stehen im Register. Bei nlme wird eine sehr kleine Zufalls-SD als Randindikator verwendet.

## Kreistyp-Kontraste

Das Beispiel vergleicht 80+ in W5 zwischen dünn besiedelten ländlichen Kreisen und Großstädten. Der Dreifachkontrast vergleicht die Änderung dieses Abstands gegenüber W1 mit der entsprechenden Änderung bei 18–39. Die Einheit ist wöchentliche Fälle je 100.000.

| Spezifikation | Kreistypabstand | Dreifachkontrast | Änderung gegenüber der Familienreferenz |
|---|---:|---:|---:|
| nb_glm | 50,4 | -187,1 | 0,0 |
| nb_glmm | 61,5 | -211,8 | -24,7 |
| raw_kreis | 50,3 | -187,8 | 0,0 |
| raw_kreis_age | 50,3 | -187,8 | -0,0 |
| raw_phase_variance | 50,5 | -187,8 | 0,0 |
| raw_car1 | 50,5 | -187,8 | 0,0 |

In diesem Beispiel bleibt der Dreifachkontrast in allen Spezifikationen negativ. Die Änderung der Gauß-Kovarianz verschiebt ihn kaum. Beim NB2-GLMM steigt der Kreistypabstand und der negative Dreifachkontrast verstärkt sich. Wegen der randnahen Varianz ist dieser Vergleich vorläufig.

Für den NB2-Vergleich werden die GLMM-Raten über die beiden normalverteilten Intercepts gemittelt. Die bedingten Werte bei Zufallseffekten null stehen zusätzlich in der CSV. Die Änderungen der Kontraste sind Punktschätzungen. Die erste Runde verwendete kreisgeclusterte Sandwich-Inferenz. Für die neuen Modelle wurden keine modellübergreifenden robusten Intervalle konstruiert.

## Räumliche Residualabhängigkeit

Die vereinfachten Kreispolygone decken alle 400 Kreise ab. Der Intersektionsgraph hat 1044 ungerichtete Nachbarschaften und 0 isolierte Kreise. Moran-I wurde je Phase für über Altersgruppen gemittelte Kreisresiduen berechnet. Die Werte liegen zwischen 0,14 und 0,82. Bei 48 von 48 Modell-Phasen-Kombinationen liegt der innerhalb des Modells Holm-adjustierte Permutations-p-Wert unter 0,05.

Die räumliche Diagnose ist explorativ. Sie verwendet polygonbasierte Nachbarschaft und setzt für die Permutation Austauschbarkeit voraus. Küsteninseln, Geometrievereinfachung und ungleiche Residualpräzision können das Ergebnis beeinflussen. Die räumliche Struktur bleibt eine offene Einschränkung für kreisgeclusterte Inferenz. Ein räumliches Kovarianzmodell wurde in dieser Runde nicht geschätzt.

## Grenzen

Acht ungleich lange Phasen begrenzen die zeitliche Identifikation. Phasenmitten sind Kalenderanker für aggregierte Beobachtungen. Die CAR(1)-Struktur ist positiv und stationär und kann gegenläufige oder phasenspezifische Korrelationen nur begrenzt abbilden. Das NB2-GLMM enthält keine zusätzliche serielle Residualkorrelation. Die Rücktransformation eines Log-Inzidenzmodells bleibt offen. Modelle, Diagnosen, Stichprobenschlüssel und Cache-Signaturen sind im Ergebnisordner abgelegt. Die Ausführung verwendete lme4, nlme, glmmTMB und sf. Für die Wiederverwendung des GLMM-Caches muss glmmTMB im R-Bibliothekspfad verfügbar sein.
