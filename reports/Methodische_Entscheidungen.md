---
output:
  html_document: default
  pdf_document: default
---
# Methodische Entscheidungen

Ziel dieses Dokuments ist es, die methodischen Entscheidungen im Rahmen der statistischen Modellierung nachvollziehbar zu dokumentieren. Für jede Entscheidung werden der Hintergrund, mögliche Alternativen, deren methodische Auswirkungen sowie die Entscheidungsgrundlage festgehalten.

## Inhaltsverzeichnis {#inhaltsverzeichnis}

- [1. Datengrundlage und Untersuchungszeitraum](#e01)
- [2. Altersgruppenbildung](#e02)
- [3. Operationalisierung der regionalen Strukturmerkmale](#e03)
- [4. Zeitliche Auflösung und Periodisierung](#e04)
  - [4.1 Zeitliche Auflösung: Weekly Panel oder Phase Panel](#e4-1)
  - [4.2 Umgang mit P0](#e4-2)
  - [4.3 Umgang mit PostW5](#e4-3)
- [5. Zeitliche Zuordnung des Kreistyps](#e05)
- [6. Umgang mit fehlenden Werten](#e06)
- [7. Definition der Zielgröße](#e07)
- [8. Gewichtung der Beobachtungen](#e08)
- [9. Modellierung der Zielvariable und Wahl der Modellfamilie](#e09)
- [10. Statistischer Modellrahmen](#e10)
  - [10.1 Modellrahmen](#e10-1)
  - [10.2 Random-Effects-Struktur](#e10-2)
- [11. Referenzgruppen und Kontraste](#e11)
- [12. Aufbau der Modellhierarchie](#e12)
- [13. Sensitivitätsanalysen](#e13)

------------------------------------------------------------------------

## 1. Datengrundlage und Untersuchungszeitraum {#e01}

Die vorliegenden COVID-19-Daten enthalten wöchentlich gemeldete Fallzahlen, Inzidenzen und jährliche Bevölkerungszahlen auf Kreisebene. Die Altersjahre 0–79 liegen einzeln vor, während Personen ab 80 Jahren bereits zusammengefasst sind.

### Rahmenbedingungen

- Untersuchungszeitraum: ISO-Jahre 2020–2023
- Räumliche Untersuchungseinheiten: 400 Kreise
- Zeitliche Auflösung: 209 Kalenderwochen
- Beobachtungseinheit: Kreis × Altersgruppe × Woche

### Methodische Auswirkungen

Die Daten besitzen eine Panelstruktur. Beobachtungen desselben Kreises über verschiedene Altersgruppen und Zeitpunkte hinweg können voneinander abhängig sein. Diese Abhängigkeiten müssen bei der Modellierung und statistischen Inferenz berücksichtigt werden.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 2. Altersgruppenbildung {#e02}

**Bezug zu anderen Entscheidungen:** [1. Datengrundlage und Untersuchungszeitraum](#e01).

Die ursprünglichen Daten liegen überwiegend nach Einzelalter vor. Eine Zusammenfassung zu Altersgruppen reduziert die Anzahl der Beobachtungskategorien und kann die statistische Stabilität der Inzidenzen verbessern. Gleichzeitig gehen durch die Aggregation altersspezifische Informationen verloren.

### Alternativen

- 7 Altersgruppen
- 13 Altersgruppen
- Andere Altersgruppeneinteilungen
- Einzelalter: Maximaler Erhalt altersspezifischer Informationen; Hohe Datensparsität, komplexere Modellierung

### Entscheidung und Begründung

Noch festzulegen.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 3. Operationalisierung der regionalen Strukturmerkmale {#e03}

Der Urbanisierungsgrad ist ein zentraler Bestandteil der Forschungsfrage. Er lässt sich jedoch durch unterschiedliche regionale Strukturmerkmale operationalisieren, die verschiedene Aspekte räumlicher Strukturen erfassen.

### Alternativen und methodische Auswirkungen

| Strukturmerkmal | Erfasster Aspekt | Methodische Auswirkungen |
|------------------------|------------------------|------------------------|
| Kreistyp | Siedlungsstruktur | Einfach interpretierbare Gruppenvergleiche |
| Raumtyp (Lage) | Räumliche Zentralität bzw. Peripherie | Ergänzende Perspektive auf regionale Lage und Erreichbarkeit |
| Bevölkerungsdichte | Bevölkerungszahl pro Flächeneinheit | Kontinuierliche Abbildung regionaler Unterschiede; mögliche Nichtlinearität |
| Kombination mehrerer Merkmale | Mehrdimensionale regionale Struktur | Differenziertere Analyse, aber potenzielle Multikollinearität |

### Entscheidung und Begründung

Vorgesehen ist der Kreistyp als primäres Strukturmerkmal, da er für die Forschungsfrage am relevantesten ist. Raumtyp und Bevölkerungsdichte sollen als alternative bzw. ergänzende Operationalisierungen untersucht werden.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 4. Zeitliche Auflösung und Periodisierung {#e04}

Die COVID-19-Inzidenzen weisen starke zeitliche Schwankungen und unterschiedliche epidemiologische Phasen auf. Die zeitliche Auflösung beeinflusst sowohl den Informationsgehalt als auch die Komplexität der statistischen Modelle.

### 4.1 Zeitliche Auflösung: Weekly Panel oder Phase Panel {#e4-1}

| Alternative | Vorteile | Nachteile |
|------------------------|------------------------|------------------------|
| Weekly Panel | Erhalt kurzfristiger Veränderungen und vollständiger zeitlicher Verläufe | Hohe Modellkomplexität, zeitliche Abhängigkeit und kurzfristige Meldeschwankungen |
| Phase Panel | Übersichtliche Darstellung epidemiologischer Phasen, geringere Modellkomplexität | Informationsverlust innerhalb der Phasen und Abhängigkeit von den Phasengrenzen |

#### Epidemiologische Phasen

- P0, W1, G1, W2, W3, G2, W4, W5, PostW5

### 4.2 Umgang mit P0 {#e4-2}

P0 weist aufgrund der frühen Pandemiephase einen besonders hohen Anteil an Nullinzidenzen auf.

- Einschluss: vollständige Abbildung des Untersuchungszeitraums, jedoch möglicherweise starke Unterschiede in der Verteilung der Zielvariable gegenüber späteren Phasen.
- Ausschluss: Konzentration auf die eigentlichen epidemischen Phasen, jedoch Einschränkung des zeitlichen Geltungsbereichs der Hauptanalyse.

Nullinzidenzen stellen grundsätzlich keine fehlenden Werte dar.

### 4.3 Umgang mit PostW5 {#e4-3}

PostW5 umfasst einen vergleichsweise langen Zeitraum mit potenziell heterogenen epidemiologischen Bedingungen und unterschiedlichen Inzidenzniveaus. Veränderungen der Immunitätslage, der Virusvarianten sowie des Test- und Meldeverhaltens können die Vergleichbarkeit innerhalb dieser Phase beeinflussen.

- Gemeinsame Betrachtung: konsistente Verwendung der bisherigen Phasendefinition.
- Aufteilung in PostW5_2022 und PostW5_2023: differenziertere Abbildung zeitlicher Veränderungen, jedoch zusätzliche Modellparameter.

### Entscheidung und Begründung

Noch festzulegen.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 5. Zeitliche Zuordnung des Kreistyps {#e05}


Die Klassifikation einzelner Kreise kann sich zwischen 2020 und 2023 ändern. Daher muss entschieden werden, ob der Kreistyp während des gesamten Untersuchungszeitraums konstant gehalten oder jahresspezifisch berücksichtigt wird.

### Alternativen und methodische Auswirkungen

| Alternative | Vorteile | Nachteile |
|------------------------|------------------------|------------------------|
| Snapshot 2023 | Konstante Gruppenzugehörigkeit, einfachere zeitliche Vergleichbarkeit | Klassifikation früherer Jahre anhand eines späteren Gebietsmerkmals |
| Jahresspezifischer Kreistyp | Berücksichtigung tatsächlicher Klassifikationsänderungen | Veränderungen der Gruppenzusammensetzung erschweren zeitliche Vergleiche |
| Häufigster Kreistyp innerhalb einer Phase | Eindeutige Zuordnung bei phasenbasierter Analyse | Vereinfachung möglicher Klassifikationswechsel innerhalb einer Phase |

Bei einer zeitvariierenden Klassifikation können beobachtete Unterschiede zwischen Phasen teilweise auf Veränderungen der Gruppenzusammensetzung zurückzuführen sein.

### Entscheidung und Begründung

Noch festzulegen.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 6. Umgang mit fehlenden Werten {#e06}

Für einzelne Kombinationen aus Kreis, Altersgruppe und Jahr fehlen Bevölkerungsnenner. Dadurch können trotz vorhandener Fallzahlen keine gültigen Inzidenzen berechnet werden.

Bei der Aggregation zu epidemiologischen Phasen besteht zusätzlich das Problem, dass einzelne Wochen einer Phase fehlen können.

### Vergleich der Altersgruppierungen

*Zahlen gemäß bisherigem Arbeitsstand (9 Phasen einschließlich P0); bei einer Änderung der Altersgruppen oder Periodisierung erneut zu prüfen.*

| Kennzahl | 7 Altersgruppen | 13 Altersgruppen |
|----|---:|---:|
| Fehlende Kreis-Altersgruppen-Jahres-Kombinationen | 22 | 28 |
| Betroffene wöchentliche Beobachtungen | 1.148 | 1.461 |
| Erwartete Kreis-Altersgruppen-Phasen-Kombinationen | 25.200 | 46.800 |
| Teilweise unvollständige Phasen-Kombinationen | 22 | 28 |
| Vollständig fehlende Phasen-Kombinationen | 12 | 15 |
| Unvollständige Phasen-Kombinationen insgesamt | 34 | 43 |
| Anteil unvollständiger Phasen-Kombinationen | 0,135 % | 0,092 % |

### Alternativen und methodische Auswirkungen

| Alternative | Vorteile | Nachteile |
|------------------------|------------------------|------------------------|
| Balanced Panel | Vollständig vergleichbare Beobachtungsstruktur | Ausschluss gültiger Beobachtungen betroffener Kreise |
| Unbalanced Panel | Erhalt aller Kreise und möglichst vieler gültiger Beobachtungen | Unterschiedliche Anzahl verfügbarer Beobachtungen |
| Imputation fehlender Bevölkerungswerte | Vollständige Panelstruktur | Zusätzliche Annahmen und Unsicherheit durch geschätzte Bevölkerungsnenner |
| Aggregation verfügbarer Wochen | Maximale Nutzung vorhandener Inzidenzen | Möglicherweise verzerrte Phasenvergleiche durch unterschiedliche Beobachtungszeiträume |

Insbesondere bei Phasen mit starken zeitlichen Veränderungen kann der Mittelwert der verfügbaren Wochen erheblich vom Mittelwert der vollständigen Phase abweichen.

### Entscheidung und Begründung

Noch festzulegen.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 7. Definition der Zielgröße {#e07}

**Bezug zu anderen Entscheidungen:** [4. Zeitliche Auflösung und Periodisierung](#e04)

### Hintergrund

Die Definition der Inzidenz hängt von der gewählten zeitlichen Auflösung der Analysedaten ab.

Bei einer wochenbasierten Analyse wird die 7-Tage-Inzidenz direkt verwendet. Bei einer phasenbasierten Analyse müssen die wöchentlichen Inzidenzen zu einer vergleichbaren Zielgröße aggregiert werden.

### Alternativen

**Weekly Panel**

- Wöchentliche 7-Tage-Inzidenz

**Phase Panel**

- Arithmetischer Mittelwert der wöchentlichen Inzidenzen
- Expositionsgewichtete mittlere Wocheninzidenz

### Methodische Auswirkungen

Bei konstanten Bevölkerungsnennern innerhalb einer Phase führen beide Aggregationsmethoden zum gleichen Ergebnis. Unterschiede können insbesondere bei jahresübergreifenden Phasen mit veränderlichen Bevölkerungsnennern entstehen.

Aufgrund der unterschiedlichen Phasenlängen wird die kumulative Inzidenz nicht als primäre Zielgröße betrachtet.

### Entscheidung

Die Definition der Zielgröße erfolgt in Abhängigkeit von der gewählten zeitlichen Auflösung. Anschließend wird geprüft, inwieweit sich die beiden Aggregationsmethoden empirisch unterscheiden.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 8. Gewichtung der Beobachtungen {#e08}

Kreise unterscheiden sich hinsichtlich ihrer Bevölkerungsgröße. Zudem besitzen epidemiologische Phasen unterschiedliche Längen. Die Gewichtung beeinflusst, welche Beobachtungen stärker zur Modellschätzung beitragen und welche Zielgröße geschätzt wird.

### Alternativen und methodische Auswirkungen

| Gewichtung | Bedeutung | Methodische Auswirkungen |
|------------------------|------------------------|------------------------|
| Unweighted | Keine explizite Gewichtung | Keine direkte Bevorzugung bevölkerungsreicher Kreise oder längerer Phasen |
| Population-weighted | Gewichtung nach Bevölkerung | Stärkerer Einfluss bevölkerungsreicher Beobachtungseinheiten |
| Phase-duration weighted | Gewichtung nach Anzahl der Wochen | Stärkerer Einfluss längerer epidemiologischer Phasen |
| Precision-weighted | Gewichtung nach geschätzter Präzision | Stärkerer Einfluss von Beobachtungen mit geringerer statistischer Unsicherheit |
| Exposure-weighted | Gewichtung nach Person-Wochen | Gemeinsame Berücksichtigung von Bevölkerung und Phasendauer |

Die Gewichtung ist nicht ausschließlich eine technische Maßnahme, sondern beeinflusst auch die Interpretation der Ergebnisse. Insbesondere entspricht eine Populationsgewichtung einer anderen Untersuchungsperspektive als eine primär kreisbezogene Analyse.

### Entscheidungsgrundlage

- Forschungsziel: kreisbezogene oder bevölkerungsbezogene Betrachtung
- Verteilung der Bevölkerungsgrößen
- Unterschiede in der Phasendauer
- Statistische Unsicherheit der Inzidenzen
- Auswirkungen verschiedener Gewichtungen auf die geschätzten Effekte

### Entscheidung und Begründung

Noch festzulegen.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 9. Modellierung der Zielvariable und Wahl der Modellfamilie {#e09}

**Bezug zu anderen Entscheidungen:** [7. Definition der Zielgröße](#e07), [8. Gewichtung der Beobachtungen](#e08).

Nach Definition der epidemiologischen Zielgröße ist zu entscheiden, auf welcher Skala und mit welcher statistischen Modellfamilie die Zusammenhänge untersucht werden.

Die Wahl der Modellfamilie und die statistische Darstellung der Zielvariable stehen in engem Zusammenhang.

### Mögliche Ansätze

- Inzidenz auf der Originalskala mit LM oder LMM
- Transformierte Inzidenz, beispielsweise `log1p(incidence)`, mit LM oder LMM
- Fallzahlen mit Bevölkerungsexposition als Offset in einem GLM oder GLMM

### Methodische Auswirkungen

Modelle auf der Originalskala ermöglichen die Untersuchung absoluter Inzidenzunterschiede. Modelle auf einer logarithmischen Skala erfassen Unterschiede auf der transformierten Skala. Fallzahlmodelle mit logarithmischer Linkfunktion und Offset ermöglichen die Untersuchung relativer Inzidenzraten.

Die verschiedenen Ansätze unterscheiden sich hinsichtlich ihrer Verteilungsannahmen, Varianzstruktur, Interpretierbarkeit und Berücksichtigung wiederholter Beobachtungen.

### Entscheidungsgrundlage

- Verteilung der Zielvariable
- Anteil der Nullwerte
- Mittelwert-Varianz-Zusammenhang
- Overdispersion
- Abhängigkeiten innerhalb der Kreise
- Absolute oder relative Interpretation der Zusammenhänge
- Ergebnisse der Modellanpassung und Modelldiagnostik

### Entscheidung

Die Wahl der Modellfamilie und der Modellierungsskala erfolgt gemeinsam auf Grundlage der deskriptiven Analyse und der anschließenden Modellprüfung.

Die konkreten Modellfamilien und die Abhängigkeitsstruktur werden in [Entscheidung 10](#e10) näher betrachtet.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 10. Statistischer Modellrahmen {#e10}

**Bezug zu anderen Entscheidungen:** [9. Modellierung der Zielvariable und Wahl der Modellfamilie](#e09).

### Hintergrund

Die Daten weisen eine hierarchische Panelstruktur auf. Mehrere Beobachtungen stammen aus demselben Kreis und können daher statistisch voneinander abhängig sein. Darüber hinaus unterscheiden sich Inzidenzniveaus und Varianzen zwischen Altersgruppen und epidemiologischen Phasen.

### 10.1 Modellrahmen {#e10-1}

| Modell | Vorteile | Einschränkungen |
|------------------------|------------------------|------------------------|
| Linear Model (LM) | Einfache Interpretation und geringe Modellkomplexität | Abhängigkeiten und Heteroskedastizität müssen bei der Inferenz berücksichtigt werden |
| Linear Mixed-Effects Model (LMM) | Berücksichtigung kreisspezifischer Unterschiede durch Random Effects | Zusätzliche Annahmen über Random Effects und Residuen |
| Poisson GLM | Modellierung von Fallzahlen unter Berücksichtigung der Bevölkerungsexposition | Restriktive Varianzannahme |
| Quasi-Poisson GLM | Berücksichtigung von Overdispersion | Kein gewöhnlicher likelihoodbasierter AIC-Vergleich |
| Negative Binomial Model | Flexible Modellierung überdisperser Fallzahlen | Zusätzlicher Dispersionsparameter |
| Generalized Linear Mixed Model (GLMM) | Kombination von Zähldatenmodellierung und hierarchischer Datenstruktur | Höhere Modell- und Rechenkomplexität |

### 10.2 Random-Effects-Struktur {#e10-2}

Mögliche Spezifikationen:

- Random Intercept auf Kreisebene
- Zusätzlicher Random Intercept für Kreis-Altersgruppen-Kombinationen
- Random Slopes
- Alternative zeitliche und räumliche Kovarianzstrukturen

Eine komplexere Random-Effects-Struktur ist nur sinnvoll, wenn sie statistisch identifizierbar und inhaltlich begründbar ist.

### Entscheidungsgrundlage

- Datenstruktur
- Verteilung der Zielvariable
- Overdispersion
- Abhängigkeiten innerhalb der Kreise
- Konvergenz und Singularität
- Interpretierbarkeit
- Ergebnisse der Modelldiagnostik

### Entscheidung und Begründung

Ein LMM ist als Hauptmodell vorgesehen. Die endgültige Random-Effects- und Kovarianzstruktur wird anhand der Modellanpassung und Diagnostik beurteilt.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 11. Referenzgruppen und Kontraste {#e11}

Bei kategorialen erklärenden Variablen werden die Modellkoeffizienten in Abhängigkeit von der gewählten Kontrastkodierung interpretiert. Die Wahl der Referenzgruppen beeinflusst die direkte Interpretation der Koeffizienten, nicht jedoch die Modellvorhersagen bei ansonsten identischer Modellspezifikation.

### Vorgesehene Referenzgruppen

| Variable     | Referenzgruppe        |
|--------------|-----------------------|
| Kreistyp     | Kreisfreie Großstädte |
| Altersgruppe | 18–39 Jahre           |
| Phase        | W1                    |

### Methodische Auswirkungen

- Kreistyp: Vergleich anderer siedlungsstruktureller Kreistypen mit Großstädten.
- Altersgruppe: Vergleich anderer Altersgruppen mit der Gruppe der 18- bis 39-Jährigen.
- Phase: Vergleich späterer epidemiologischer Phasen mit der ersten Welle.

Bei Modellen mit Interaktionen beziehen sich einzelne Haupt- und Interaktionskoeffizienten auf spezifische Referenzkombinationen. Sie dürfen daher nicht ohne Weiteres als allgemeine durchschnittliche Effekte interpretiert werden.

### Entscheidung und Begründung

Die genannten Referenzgruppen sind vorgesehen. Die Kontrastkodierung und konkreten Effektvergleiche werden vor der abschließenden Inferenz festgelegt.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 12. Aufbau der Modellhierarchie {#e12}

**Bezug zu anderen Entscheidungen:** [9. Modellierung der Zielvariable und Wahl der Modellfamilie](#e09), [10. Statistischer Modellrahmen](#e10), [11. Referenzgruppen und Kontraste](#e11).

Die Forschungsfrage umfasst sowohl regionale und altersspezifische Unterschiede als auch deren Veränderungen über die Zeit. Eine schrittweise Erweiterung der Modellstruktur ermöglicht es, den zusätzlichen Beitrag einzelner Haupt- und Interaktionseffekte zu untersuchen.

### Vorgesehene Modellhierarchie

| Modell | Fixed Effects | Untersuchungsziel |
|------------------------|------------------------|------------------------|
| M0a | `age_group + period` | Additive Alters- und Phaseneffekte |
| M0b | `age_group * period` | Altersabhängige zeitliche Unterschiede |
| M1 | `age_group * period + kreistyp_phase` | Zusätzliche regionale Strukturunterschiede |
| M2a | `age_group * period + kreistyp_phase * period` | Zeitliche Veränderung regionaler Unterschiede |
| M2b | `(kreistyp_phase + age_group + period)^2` | Alle Zweifachinteraktionen |
| M3 | `kreistyp_phase * age_group * period` | Altersabhängige zeitliche Veränderung regionaler Unterschiede |

### Methodische Auswirkungen

Mit zunehmender Modellkomplexität können differenziertere Zusammenhänge untersucht werden. Gleichzeitig steigt die Anzahl der zu schätzenden Parameter, wodurch die Interpretation komplexer und die Schätzunsicherheit größer werden kann.

Die Dreifachinteraktion in M3 ermöglicht die direkte Untersuchung der zentralen Forschungsfrage. Eine bessere inhaltliche Übereinstimmung mit der Forschungsfrage bedeutet jedoch nicht zwangsläufig eine bessere statistische Modellgüte.

### Entscheidung und Begründung

Verwendung der sechs Modelle M0a bis M3 als hierarchischer Modellaufbau. M3 dient als hypothesenorientiertes Inferenzmodell; einfachere Modelle werden als Vergleichsmodelle berücksichtigt.

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)

------------------------------------------------------------------------

## 13. Sensitivitätsanalysen {#e13}

Die Ergebnisse können von Entscheidungen zur Datenaufbereitung, Variablendefinition, Gewichtung und Modellspezifikation abhängen. Sensitivitätsanalysen dienen dazu, diese Abhängigkeit systematisch zu untersuchen.

### Geplante Analysen

| Sensitivitätsanalyse | Überprüfte methodische Annahme | Entscheidung |
|------------------------|------------------------|------------------------|
| 7 vs. 13 Altersgruppen | Abhängigkeit von der Altersgruppenbildung | [2](#e02) |
| Balanced vs. Unbalanced Panel | Einfluss der Stichprobenauswahl | [6](#e06) |
| Imputation fehlender Bevölkerungswerte | Einfluss fehlender Bevölkerungsnenner | [6](#e06) |
| Weekly vs. Phase Panel | Einfluss zeitlicher Aggregation | [4](#e04) |
| Einschluss von P0 | Einfluss der frühen Pandemiephase | [4](#e04) |
| Aufteilung von PostW5 | Einfluss langer und heterogener Phasen | [4](#e04) |
| Kreistyp 2023 vs. jahresspezifischer Kreistyp | Einfluss veränderlicher Klassifikationen | [5](#e05) |
| Raumtyp und Bevölkerungsdichte | Abhängigkeit von der Operationalisierung regionaler Struktur | [3](#e03) |
| Kreistyp mit zusätzlicher Bevölkerungsdichte | Zusätzlicher Erklärungsbeitrag der Bevölkerungsdichte | [3](#e03) |
| Gewichtete vs. ungewichtete Modelle | Einfluss der Gewichtungsentscheidung | [8](#e08) |
| Alternative Zielvariablen | Abhängigkeit von der gewählten Inzidenzskala | [9](#e09) |
| Quasi-Poisson-Modell | Einfluss der Modellfamilie | [9](#e09) |
| Alternative Kovarianzschätzer | Robustheit der statistischen Inferenz | [10](#e10) |

### Bewertung der Robustheit

Die Ergebnisse werden hinsichtlich folgender Aspekte verglichen:

- Richtung der geschätzten Zusammenhänge
- Größenordnung der Effekte
- Konfidenzintervalle
- Alters- und phasenspezifische Muster
- Statistische Unsicherheit
- Inhaltliche Schlussfolgerungen

### Entscheidung und Begründung

...to be continue

[Zum Inhaltsverzeichnis](#inhaltsverzeichnis)
