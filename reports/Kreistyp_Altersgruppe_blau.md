# COVID-19-Meldeinzidenz nach Kreistyp und Altersgruppe

**Wochenbericht zum Praxisprojekt · Stand 20. November 2026**

In dieser Auswertung habe ich untersucht, wie sich die wöchentliche COVID-19-Meldeinzidenz zwischen den vier siedlungsstrukturellen Kreistypen unterscheidet und wie diese Unterschiede mit der Altersgruppe und dem Zeitpunkt variieren. Die größten absoluten Abstände zeigten sich Anfang 2022, besonders bei den 6- bis 17- und den 18- bis 39-Jährigen.

## 1. Datenaufbereitung für 2020–2023

1.  **Fallzahlen und Bevölkerung nach Alter zusammenfassen.** Die wöchentlichen RKI-Fallzahlen aus `rki_weekly_long.rds` und die jährlichen Bevölkerungszahlen aus `rki_population_annual.rds` wurden zu sieben Altersgruppen zusammengefasst (0–5, 6–17, 18–39, 40–59, 60–69, 70–79 und 80+ Jahre). Fälle mit unbekanntem Alter wurden separat gezählt und blieben bei der altersspezifischen Berechnung unberücksichtigt.
2.  **Jährlichen Kreistyp zuordnen.** Die Zuordnung stammt aus `population_Kreistyp_Raumtyp_2020_2024.rds`. Für jede Kreis-Woche wurden die Bevölkerung der jeweiligen Altersgruppe und der Kreistyp des zugehörigen ISO-Jahres verwendet.
3.  **Vollständigkeit prüfen.** Die Auswertungstabelle enthält **400 Kreise × 209 ISO-Kalenderwochen × 7 Altersgruppen = 585.200 Beobachtungen**. Bei 22 Kreis-Jahr-Altersgruppen-Kombinationen fehlen insgesamt 29 Einzelaltersangaben in der zugrunde liegenden Bevölkerungstabelle. Dadurch bleiben **1.148 Wocheninzidenzen (0,20 %)** ohne gültigen Wert. Die Fallzahlen bleiben erhalten. Für die Abbildungen wurden Beobachtungen ohne gültige Inzidenz ausgeschlossen.

Die aufbereitete Tabelle liegt unter `data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds`.

## 2. Definition der Meldeinzidenz

> **Wöchentliche Meldeinzidenz = (gemeldete Fälle eines Kreises in einer Altersgruppe und ISO-Kalenderwoche ÷ Bevölkerung desselben Kreises in dieser Altersgruppe im zugehörigen Jahr) × 100.000**

Bei 120 gemeldeten Fällen und 12.000 Einwohnerinnen und Einwohnern derselben Altersgruppe ergibt sich eine Wocheninzidenz von 1.000 Fällen je 100.000 Personen dieser Altersgruppe.

Für jede Kalenderwoche, Altersgruppe und jeden Kreistyp wurde der **Median der einzelnen Kreiswerte** berechnet. In die Mediane und den bundesweiten Mittelwert gehen die jeweils verfügbaren Kreise gleichgewichtet ein.

## 3. Deskriptive Analyse

### 3.1 Zeitlicher Verlauf der wöchentlichen Mediane

Innerhalb der Altersgruppen zeigen die vier Kreistypen weitgehend dieselben Anstiegs- und Rückgangsphasen. Die höchsten Wochenmediane traten Anfang 2022 bei den **6- bis 17-Jährigen** auf und erreichten in einzelnen Kreistypen rund **3.700** Fälle je 100.000 Personen. Bei den 18- bis 39-Jährigen lagen die höchsten Werte über 3.000, bei den 70- bis 79-Jährigen und den Personen ab 80 Jahren um 1.000 oder darunter. In mehreren Gruppen ab 40 Jahren sind im weiteren Verlauf des Jahres 2022 erneut Anstiege sichtbar. Die gemeinsame y-Achse erleichtert den Vergleich der absoluten Niveaus.

![Wöchentliche Kreistyp-Mediane nach Altersgruppe, 2020–2023](../results/Kreistyp%20x%20Altersgruppe/lineplot_age_and_kreistyp.png)

### 3.2 Kreisfreie Großstädte als Referenz

Für jede Altersgruppe und Kalenderwoche wurde vom Median des jeweiligen Kreistyps der Median der **kreisfreien Großstädte** abgezogen. Violett zeigt negative, Orange positive Differenzen.

Anfang 2022 lagen die Mediane beider ländlicher Kreistypen bei den 6- bis 17-Jährigen zunächst unter und wenige Wochen später deutlich über dem Großstadtmedian. In der späteren Phase lagen auch die Mediane der 18- bis 39-Jährigen in beiden ländlichen Kreistypen deutlich darüber. Bei den 70- bis 79-Jährigen waren die absoluten Abstände in diesem Zeitraum kleiner. Im Jahr 2023 waren die Differenzen auf derselben absoluten Farbskala meist schwächer ausgeprägt.

![Differenz der Kreistyp-Mediane zum Median der kreisfreien Großstädte](../results/Kreistyp%20x%20Altersgruppe/weekly_incidence_difference_vs_grossstaedte.png)

### 3.3 Vergleich mit dem bundesweiten Mittelwert der Kreiswerte

Die zweite Heatmap zieht vom jeweiligen Kreistyp-Median das **arithmetische Mittel aller gültigen Kreiswerte derselben Altersgruppe und Woche** ab. Damit bezieht sich der Vergleich auf einen bundesweiten, ungewichteten Mittelwert auf Kreisebene. Im Bericht zur Gesamtbevölkerung wurde für den bundesweiten Vergleich der Median verwendet.

In der Phase mit großen positiven Abständen zu den Großstädten lagen die Mediane der beiden ländlichen Kreistypen bei den **6- bis 17- und 18- bis 39-Jährigen** zeitweise auch über diesem bundesweiten Mittelwert. Gleichzeitig lagen die Großstadtmediane in diesen Altersgruppen darunter. Das Muster hängt in diesen Wochen folglich nicht allein von der Wahl der Großstädte als Referenz ab.

![Differenz der Kreistyp-Mediane zum bundesweiten arithmetischen Mittel der Kreiswerte](../results/Kreistyp%20x%20Altersgruppe/weekly_incidence_difference_vs_mean.png)

### 3.4 Verteilungen in KW 11/2022

KW 11/2022 illustriert eine Phase mit großen Unterschieden. In allen drei ausgewählten Altersgruppen hatten die kreisfreien Großstädte den niedrigsten Median der vier Kreistypen. Der Abstand zu den dünn besiedelten ländlichen Kreisen war bei den jüngeren Gruppen deutlich größer.

| Altersgruppe | Kreisfreie Großstädte | Dünn besiedelte ländliche Kreise | Differenz |
|----|---:|---:|---:|
| 6–17 Jahre | ca. 2.300 | ca. 3.500 | ca. +1.200 |
| 18–39 Jahre | ca. 2.160 | ca. 3.100 | ca. +940 |
| 70–79 Jahre | ca. 700 | ca. 800 | ca. +100 |

Die Werte sind aus den Boxplots abgelesen und gerundet. Einheit sind gemeldete Fälle je 100.000 Personen der jeweiligen Altersgruppe. Pro Altersgruppe liegen Werte für alle **400 Kreise** vor (67 kreisfreie Großstädte, 133 städtische Kreise, 98 ländliche Kreise mit Verdichtungsansätzen und 102 dünn besiedelte ländliche Kreise).

Die Punkte zeigen, dass sich die Verteilungen trotz verschobener Mediane überlappen. So lagen einige ländliche Kreise bei den 18- bis 39-Jährigen unter einzelnen kreisfreien Großstädten. Die gemeinsame y-Achse über alle Teilgrafiken zeigt zudem, wie viel niedriger das absolute Niveau und die Streuung bei den 70- bis 79-Jährigen waren.

![KW 11/2022 mit Altersgruppen in den Spalten und Kreistypen in den Zeilen](../results/Kreistyp%20x%20Altersgruppe/boxplot_2022_KW11_by_kreistyp.png)

![KW 11/2022 mit Altersgruppen in den Zeilen und Kreistypen auf der x-Achse](../results/Kreistyp%20x%20Altersgruppe/boxplot_2022_KW11_by_age.png)

### 3.5 Vergleichswoche KW 01/2023

In KW 01/2023 lagen die Meldeinzidenzen in allen drei betrachteten Altersgruppen niedriger als in KW 11/2022. Bei den **70- bis 79-Jährigen** war die Reihenfolge zwischen den kreisfreien Großstädten und den dünn besiedelten ländlichen Kreisen umgekehrt. Die Mediane lagen bei rund **140** bzw. **94** Fällen je 100.000 Personen. Bei den 6- bis 17-Jährigen lagen die vier Mediane eng beieinander. In dieser Altersgruppe gingen **386 von 400 Kreisen** ein, bei den 18- bis 39-Jährigen **399 von 400** und bei den 70- bis 79-Jährigen **400 von 400**.

#### Einzelansichten · KW 01/2023

![Meldeinzidenz nach Kreistyp bei den 6-17-Jährigen, KW 01/2023](../results/Kreistyp%20x%20Altersgruppe/incidence_boxplot_2023_KW01_age_6-17.png)

![Meldeinzidenz nach Kreistyp bei den 18-39-Jährigen, KW 01/2023](../results/Kreistyp%20x%20Altersgruppe/incidence_boxplot_2023_KW01_age_18-39.png)

![Meldeinzidenz nach Kreistyp bei den 70-79-Jährigen, KW 01/2023](../results/Kreistyp%20x%20Altersgruppe/incidence_boxplot_2023_KW01_age_70-79.png)

#### Einzelansichten · KW 11/2022

![Meldeinzidenz nach Kreistyp bei den 6-17-Jährigen, KW 11/2022](../results/Kreistyp%20x%20Altersgruppe/incidence_boxplot_2022_KW11_age_6-17.png)

![Meldeinzidenz nach Kreistyp bei den 18-39-Jährigen, KW 11/2022](../results/Kreistyp%20x%20Altersgruppe/incidence_boxplot_2022_KW11_age_18-39.png)

![Meldeinzidenz nach Kreistyp bei den 70-79-Jährigen, KW 11/2022](../results/Kreistyp%20x%20Altersgruppe/incidence_boxplot_2022_KW11_age_70-79.png)

Die Einzelplots verwenden unterschiedliche y-Achsenbereiche. Für Vergleiche zwischen Wochen und Altersgruppen sind die jeweiligen Skalen zu beachten.

## 4. Grenzen der Auswertung

- Die Ergebnisse beschreiben **gemeldete Fälle**. Unterschiede im Test- und Meldeverhalten können Vergleiche zwischen Altersgruppen, Regionen und Phasen beeinflussen.
- Fehlende Bevölkerungswerte betreffen vor allem die **6- bis 17-Jährigen im Jahr 2023**. Bei den ländlichen Kreisen mit Verdichtungsansätzen waren 91 von 98 Kreisen auswertbar, bei den dünn besiedelten ländlichen Kreisen 97 von 102.
- Die beiden Kalenderwochen illustrieren unterschiedliche Muster. Aussagen über den gesamten Zeitraum stützen sich auf die Zeitreihen und Heatmaps. Die Auswertung ist deskriptiv.

## 5. Fazit

Die Kreistypen hatten innerhalb der Altersgruppen häufig ähnliche zeitliche Verläufe. Besonders Anfang 2022 änderten sich jedoch Größe und Richtung der Abstände. In KW 11/2022 lag der Median der dünn besiedelten ländlichen Kreise bei den 6- bis 17-Jährigen ungefähr 1.200 Fälle je 100.000 über dem Großstadtmedian, bei den 70- bis 79-Jährigen ungefähr 100. Die Boxplots zeigen zugleich eine deutliche Streuung innerhalb der Kreistypen und überlappende Kreiswerte.

## 6. R-Skripte

| Skript | Aufgabe |
|----|----|
| `Preprocess_Kreis_Weekly_Age_Kreistyp_2020_2023.R` | Analysetabelle aus Wochenfällen, jährlicher Altersbevölkerung und Kreistyp erstellen |
| `lineplot.R` | Wochenmediane nach Altersgruppe und Kreistyp darstellen |
| `heatmap.R` | Differenzen zum Großstadtmedian und zum bundesweiten Mittelwert darstellen |
| `boxplot_2022_KW11_by_age.R` | Boxplots für KW 11/2022 mit Altersgruppen in den Zeilen erstellen |
| `boxplot_2022_KW11_by_kreistyp.R` | Boxplots für KW 11/2022 mit Kreistypen in den Zeilen erstellen |

Die Skripte werden aus dem Projektstamm ausgeführt. Die relativen Bildpfade setzen voraus, dass diese Markdown-Datei in `reports/` liegt und die Abbildungen unter `results/Kreistyp x Altersgruppe/` gespeichert sind.
