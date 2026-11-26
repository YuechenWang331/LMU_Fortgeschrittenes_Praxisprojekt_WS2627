# Erste Modellierung

## 1. Ziel und Datengrundlage

Unterscheiden sich die gemeldeten COVID-19-Inzidenzen zwischen Kreistypen? Und ändern sich diese Unterschiede je nach Altersgruppe und Pandemiephase?

| Merkmal             | Einstellung der ersten Modellierung           |
|---------------------|-----------------------------------------------|
| Zeitraum            | 2020–2023                                     |
| Kreise              | 400                                           |
| Altersgruppen       | 0–5, 6–17, 18–39, 40–59, 60–69, 70–79, 80+    |
| Phasen              | W1, G1, W2, W3, G2, W4, W5, PostW5 (ohne P0)  |
| Kreistyp            | Dynamisch; häufigster Typ innerhalb der Phase |
| Beobachtungseinheit | Kreis × Altersgruppe × Phase                  |
| Stichprobe          | 22.370 von 22.400 Beobachtungen               |

30 Beobachtungen werden wegen unvollständiger Bevölkerungsnenner ausgeschlossen. Nullfälle bleiben erhalten. Alle Modelle verwenden dieselbe Stichprobe, ohne zusätzliche Beobachtungsgewichte.

## 2. Welche sechs Modelle werden verglichen?

Zunächst wird die Struktur der erklärenden Variablen konstant gehalten (`M0b`: Altersgruppe × Phase). Verglichen werden drei Zielgrößen bzw. Modellansätze.

| Modell | Zielgröße | Verteilung / Link | Kreiszufallseffekt |
|------------------|------------------|------------------|------------------|
| `raw_lm` | Mittlere Wocheninzidenz | Normal / Identität | Nein |
| `raw_lmm` | Mittlere Wocheninzidenz | Normal / Identität | Ja |
| `log_lm` | log(1 + mittlere Wocheninzidenz) | Normal / Identität | Nein |
| `log_lmm` | log(1 + mittlere Wocheninzidenz) | Normal / Identität | Ja |
| `poisson` | Fallzahl der Phase | Poisson / Log | Nein |
| `negbin` | Fallzahl der Phase | Negativ-Binomial / Log | Nein |

**Warum diese Modelle?** LM und LMM prüfen, ob ein kreisspezifisches Ausgangsniveau berücksichtigt werden sollte. Die Log-Transformation soll die ungleichmäßige Residuenstreuung reduzieren. Poisson und Negativ-Binomial modellieren direkt die Fallzahlen; letzteres erlaubt Überdispersion.

Sei $I$ das arithmetische Mittel der Wocheninzidenzen, $C$ die Phasenfallzahl, $E$ die Summe der wöchentlichen Bevölkerungsnenner (Personenwochen) und $\eta=X\beta$ der lineare Prädiktor.

- LM: $I=\eta+\varepsilon$; LMM: $I=\eta+b_k+\varepsilon$, mit Kreiszufallseffekt $b_k$. Für die Log-Modelle wird $I$ durch $\log(1+I)$ ersetzt.
- Zählmodelle: $\log(\mathbb{E}[C])=\eta+\log(E)$, mit festem Offset $\log(E)$. Die geschätzte Wochenrate je 100.000 beträgt $100000\exp(\eta)$.

Die mittlere Wocheninzidenz und die expositionsbezogene Rate haben dieselbe Einheit, sind bei wechselnden Bevölkerungsnennern aber nicht zwingend identisch.

## 3. Welche erklärenden Variablen enthalten M0a–M3?

Die **Modellspezifikation** (Abschnitt 2) bestimmt Zielgröße, Verteilung und Zufallseffekte. Die **Modellhierarchie** bestimmt dagegen die Fixed Effects. Für die Phasendaten gilt folgende Struktur (R-Formelsyntax; `*` umfasst Haupteffekte und Interaktionen):

| ID | Fixed Effects | Fragestellung |
|------------------------|------------------------|------------------------|
| M0a | `age_group + period` | Additive Alters- und Phasenunterschiede |
| M0b | `age_group * period` | Unterscheidet sich der Phasenverlauf nach Alter? |
| M1 | `age_group * period + kreistyp` | Gibt es einen zusätzlichen Kreistypunterschied? |
| M2a | `age_group * period + kreistyp * period` | Ändert sich der Kreistypunterschied nach Phase? |
| M2b | `(age_group + period + kreistyp)^2` | Unterscheidet er sich zusätzlich nach Alter? |
| M3 | `age_group * period * kreistyp` | Ändert sich der Kreistypunterschied über die Phasen je nach Alter unterschiedlich? |

Die Formeln beschreiben den Fixed-Effects-Teil. Beim LMM kommt `(1 | geo_code)` hinzu, bei den Zählmodellen `offset(log_exposure)`. Referenzen: 18–39 Jahre, W1 und kreisfreie Großstädte. Alle LMMs werden mit Maximum Likelihood (ML) geschätzt.

## 4. Modellvergleich unter M0b

| Modell  |       AIC |       BIC | Max. abs. Residuenkorrelation |
|---------|----------:|----------:|------------------------------:|
| raw_lm  |  255663,9 |  256120,7 |                          0,55 |
| raw_lmm |  254148,4 |  254613,3 |                          0,66 |
| log_lm  |   34787,9 |   35244,8 |                          0,64 |
| log_lmm |   31591,7 |   32056,6 |                          0,71 |
| poisson | 2400677,4 | 2401126,2 |                          0,67 |
| negbin  |  266270,4 |  266727,2 |                          0,60 |

AIC und BIC sind hier nur innerhalb derselben Zielgröße vergleichbar. Beide Kriterien bevorzugen die LMMs gegenüber den jeweiligen LMs. Bei den Zählmodellen spricht der Vergleich deutlich für Negativ-Binomial.

### Residuen und Verteilung

![Abbildung 1: Residuen gegen angepasste Werte](results/Modellierung/Initial/plots/m0b_residual_fitted.png)

**Abb. 1:** Beim Raw-LMM nimmt die Residuenstreuung mit dem angepassten Wert zu. Das Verhältnis der Residuen-RMS im oberen zum unteren Fünftel beträgt 7,04. Beim Log-LMM beträgt es 0,48; auch dort bleibt die Streuung ungleichmäßig. Die Transformation löst das Problem also nicht vollständig.

| Zählmodell       | Pearson-Quotient (Referenz: 1) | Erwartete Nullfälle |
|------------------|-------------------------------:|--------------------:|
| Poisson          |                         108,77 |              0,98 % |
| Negativ-Binomial |                           1,26 |              1,54 % |

Beobachtet werden 2,56 % Nullfälle. Das Negativ-Binomialmodell bildet die Überdispersion deutlich besser ab ($\theta=4{,}63$), unterschätzt aber weiterhin den Nullanteil.

![Abbildung 2: QQ-Plots](plots/m0b_qq.png)

**Abb. 2:** Die QQ-Plots zeigen insbesondere bei Poisson und den Raw-Modellen deutliche Abweichungen von der Referenzgeraden. Auch die Log- und Negativ-Binomialmodelle weisen Abweichungen in den Randbereichen auf. Bei Zählmodellen werden randomisierte Quantilresiduen verwendet.

### Zeitliche Abhängigkeit

![Abbildung 3: Residuenkorrelation](results/Modellierung/Initial/plots/m0b_temporal_residuals.png)

**Abb. 3:** Innerhalb derselben Kreis-Altersgruppen-Kombination bleiben Residuen über Phasen hinweg korreliert (maximal betragsmäßig 0,66 beim Raw-LMM und 0,60 bei Negativ-Binomial). Ein Kreiszufallseffekt allein löst dieses Problem nicht. Bei nur acht unterschiedlich langen Phasen ist die Wahl einer zeitlichen Korrelationsstruktur noch offen.

### Vorläufige Auswahl

Weitergeführt werden `raw_lmm` (direkt interpretierbare absolute Inzidenzunterschiede) und `negbin` (expositionsbezogene Raten mit Überdispersion). Dies ist keine endgültige Modellwahl. Die Log-Modelle bleiben vorerst diagnostisch, da `expm1()` allein keine erwartete arithmetische Inzidenz liefert.

## 5. Vergleich der Modellhierarchie

Für beide Kandidaten werden M0a–M3 geschätzt. Von M0a zu M3 sinkt der AIC beim Raw-LMM um 42612,8 und bei Negativ-Binomial um 12369,8.

| Spezifikation    | Niedrigster AIC | Niedrigster BIC |
|------------------|-----------------|-----------------|
| Raw-LMM          | M3              | M2a             |
| Negativ-Binomial | M2b             | M2a             |

Die Kriterien liefern keine einheitliche Modellwahl. M3 wird dennoch explorativ verwendet, weil es die alters- und phasenspezifischen Kreistypunterschiede direkt untersuchen lässt. Die Konvergenzprüfungen waren unauffällig. Residuenkorrelationen bleiben auch unter M3 bestehen (max. absolut 0,63 bzw. 0,59).

## 6. Inhaltliche Ergebnisse unter M3

### Geschätzte Inzidenzen

![Abbildung 4: Geschätzte Wocheninzidenzen](results/Modellierung/Initial/plots/m3_predicted_incidence.png)

**Abb. 4:** Die geschätzten Inzidenzen variieren deutlich zwischen Altersgruppen und Phasen. Besonders W5 zeigt hohe Werte, vor allem bei 6–17 und 18–39 Jahren. Beide Modelle liefern ähnliche Verläufe. Da die Kreistypkurven häufig nahe beieinanderliegen, werden ihre Differenzen separat dargestellt.

### Kreistypunterschiede

![Abbildung 5: Differenzen zu Großstädten](results/Modellierung/Initial/plots/m3_district_contrasts.png)

**Abb. 5:** Positive Werte bedeuten eine höhere geschätzte Wocheninzidenz als in kreisfreien Großstädten, negative Werte eine niedrigere. In W5 sind die Unterschiede für 6–17 und 18–39 Jahre besonders ausgeprägt. Nach W5 fallen sie deutlich kleiner aus. Die Abbildung zeigt ausgewählte Altersgruppen und Phasen mit punktweisen 95-%-Konfidenzintervallen.

### Dreifachinteraktion: Kreistyp × Alter × Phase

Sei $D_{a,p}$ die geschätzte Inzidenzdifferenz eines Kreistyps zu Großstädten für Altersgruppe $a$ und Phase $p$. Der Dreifachkontrast auf der Inzidenzskala lautet:

$$
(D_{a,p}-D_{a,W1})-(D_{18–39,p}-D_{18–39,W1}).
$$

Er vergleicht die Veränderung des Kreistypabstands seit W1 mit der entsprechenden Veränderung bei 18–39-Jährigen.

![Abbildung 6: Dreifachkontraste](results/Modellierung/Initial/plots/m3_three_way_contrasts.png)

**Abb. 6:** Besonders für 60–69 und 80+ zeigen sich in W5 negative Dreifachkontraste. Der Kreistypabstand hat sich gegenüber W1 weniger stark nach oben verschoben als bei 18–39-Jährigen. Das bedeutet nicht automatisch, dass die Inzidenz auf dem Land niedriger ist.

**Beispiel: Dünn besiedelte ländliche Kreise, 80+, W5** (wöchentliche Fälle je 100.000):

| Größe            |                 Raw-LMM |        Negativ-Binomial |
|------------------|------------------------:|------------------------:|
| Großstädte       |                   390,2 |                   390,1 |
| Ländliche Kreise |                   440,5 |                   440,5 |
| Differenz in W5  |       50,3 [27,2; 73,4] |       50,4 [27,3; 73,5] |
| Dreifachkontrast | −187,8 [−228,7; −146,9] | −187,1 [−227,7; −146,5] |

Die Differenz ist positiv, der Dreifachkontrast negativ: Beides ist vereinbar, da unterschiedliche Fragen beantwortet werden. Für den Dreifachkontrast gilt in beiden Modellen ein Holm-adjustierter p-Wert \< 2e-16. Die Intervalle sind punktweise 95-%-Intervalle.

Bei allen 27 ausgewählten Dreifachkontrasten stimmen die Vorzeichen zwischen den Modellen überein. Bei 15 sind zudem beide Holm-adjustierten p-Werte kleiner als 0,05. Das spricht für eine gewisse Robustheit gegenüber diesen beiden Spezifikationen, nicht für eine abschließende Bestätigung.

## 7. Fazit und offene Punkte

Die erste Modellierung liefert Hinweise darauf, dass Kreistypunterschiede sowohl von der Altersgruppe als auch von der Pandemiephase abhängen. Raw-LMM und Negativ-Binomial liefern dabei ähnliche ausgewählte Kontraste.

- Die Intervalle und Tests verwenden kreisgeclusterte HC1-Sandwich-Standardfehler, eine t-Approximation und für nichtlineare Ratendifferenzen die Delta-Methode. Holm wird je Modell und Kontrastfamilie angewandt; die Intervalle selbst sind nicht multiplikitätsadjustiert.
- Zeitliche Residuenabhängigkeit bleibt im Kovarianzmodell offen. Räumliche Abhängigkeit kann auch die Annahme unabhängiger Kreiscluster verletzen.
- Raw-LMM kann negative Inzidenzen vorhersagen; Negativ-Binomial enthält in dieser Runde keinen Kreiszufallseffekt. Die beiden Zielgrößen sind nicht vollständig identisch.
- Dynamische Kreistypen können ihre Zusammensetzung ändern. Die Ergebnisse sind explorative Assoziationen, keine kausalen Effekte.

Als nächste Schritte bieten sich Sensitivitätsanalysen zur Altersgruppierung, Kreistypdefinition und Abhängigkeitsstruktur an.

## Reproduzierbarkeit

Die Einstellungen und Formeln stehen in `config.R` und `model_formulas.R`, die Modellschätzung in `fit_models.R`. `run_initial_models.R` erzeugt die Ergebnisse, Diagnostiken und Kontraste. Modellregister, Stichprobenschlüssel, ausgeschlossene Beobachtungen und RDS-Dateien dokumentieren die Fits. Diese Zusammenfassung basiert auf den vorliegenden Ergebnissen; es wurden keine Modelle neu geschätzt.
