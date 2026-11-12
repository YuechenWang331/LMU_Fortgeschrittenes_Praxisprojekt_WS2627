# COVID-19-Meldeinzidenz nach Kreistyp

**Wochenbericht zum Praxisprojekt · Stand 12. November 2026**

Ich habe die COVID-19-Meldedaten für 2020–2023 auf Kreisebene aufbereitet, zwei Shiny-Karten erstellt und untersucht, wie sich die wöchentliche Meldeinzidenz zwischen den vier siedlungsstrukturellen Kreistypen unterscheidet.

## 1. Datenaufbereitung für 2020–2023

1.  **Fallzahlen auswählen.** Als Ausgangspunkt habe ich die bereits über alle Altersgruppen zusammengefassten wöchentlichen RKI-Fallzahlen je Kreis verwendet. Die Auswahl erfolgte nach ISO-Wochenjahr. Der Wochenbeginn ist jeweils der Montag.
2.  **Regionale Merkmale vereinheitlichen.** Ich habe die Kreisschlüssel in beiden Datensätzen als fünfstellige Zeichenketten standardisiert. Aus den jährlichen Regionaldaten habe ich für 2020–2023 die Gesamtbevölkerung, den Kreistyp und den Raumtyp Lage übernommen.
3.  **Wochen- und Jahresdaten verbinden.** Über den Kreisschlüssel und das ISO-Wochenjahr habe ich jeder Kreis-Woche die Bevölkerung und die regionalen Merkmale des zugehörigen Jahres zugeordnet.
4.  **Vollständigkeit prüfen.** Die aufbereitete Tabelle umfasst **83.600 Kreis-Wochen** mit **400 Kreisen je Woche**. Das Jahr 2020 umfasst 53 ISO-Kalenderwochen, die übrigen Jahre jeweils 52. Die Prüfungen kontrollieren eindeutige Schlüssel, vollständige Zuordnungen, positive Bevölkerungszahlen und übereinstimmende jährliche Fallsummen vor und nach der Verknüpfung. Das Ergebnis ist in `regional_weekly_summary_2020_2023.rds` gespeichert.

## 2. Definition der Meldeinzidenz

Die **wöchentliche COVID-19-Meldeinzidenz** ist die Zahl der gemeldeten Fälle aller Altersgruppen in einem Kreis und einer ISO-Kalenderwoche, bezogen auf 100.000 Einwohner dieses Kreises.

> **Meldeinzidenz = (gemeldete Fälle in der ISO-Kalenderwoche ÷ Kreisbevölkerung im zugehörigen ISO-Jahr) × 100.000**

**Beispiel.** Bei 150 gemeldeten Fällen in einem Kreis mit 75.000 Einwohnern beträgt die Wocheninzidenz 200 Fälle je 100.000 Einwohner.

## 3. Zwei interaktive Shiny-Karten

| Anwendung | Was sich damit erkunden lässt |
|----|----|
| [Meldeinzidenz-Karte](../data_processed/Kreistyp/incidence_map_Shiny.R) | Vergleich der Meldeinzidenz zwischen Kreisen nach Woche, Monat oder Jahr. Die App bietet eine Kreissuche und zeigt für Deutschland auch die Gesamtrate aus der Summe der Fälle und der Gesamtbevölkerung. |
| [Kreistyp-Karte](../data_processed/Kreistyp/Kreistyp_geo.R) | Räumliche Verteilung der vier Kreistypen und jährliche Zuordnung der einzelnen Kreise von 2020 bis 2023. Die App bietet einen animierbaren Jahresregler, eine Kreissuche und die Anzahl der Kreise je Typ. |

In der Meldeinzidenz-Karte werden für Monat und Jahr die zugeordneten Wochenfälle summiert und auf die jeweilige Jahresbevölkerung bezogen. Die Monatswerte sind eine Näherung aus Wochendaten. Die App ordnet ganze Wochen anhand ihres Montags zu und verwendet am ISO-Jahreswechsel Sonderregeln für Januar und Dezember.

**Start in RStudio.** Im Projekt die verlinkte R-Datei öffnen und **Run App** wählen. Alternativ im Projektstamm einen der folgenden Befehle ausführen.

``` r
shiny::runApp("data_processed/Kreistyp/incidence_map_Shiny.R")
shiny::runApp("data_processed/Kreistyp/Kreistyp_geo.R")
```

Beide Apps verwenden die R-Pakete `shiny`, `leaflet`, `sf` und `dplyr` sowie die Kreisgrenzen in `data_geo/landkreise_simplify200.geojson`. Die Meldeinzidenz-Karte liest die Wochenübersicht im Skriptordner. Die Kreistyp-Karte benötigt im Unterordner `Kreistyp_prepare/` die Datei `population_Kreistyp_Raumtyp_2020_2024.rds` und verwendet daraus die Jahre 2020–2023. Für einen direkten Start im Browser braucht die App eine bereitgestellte Shiny-URL.

## 4. Deskriptive Analyse nach Kreistyp

Ich habe die Verteilungen über alle Kreis-Wochen, die Verteilungen in einer einzelnen Woche und den Verlauf der wöchentlichen Kreistyp-Mediane verglichen. Für die Differenzkurven habe ich vom jeweiligen Kreistyp-Median entweder den bundesweiten Median aller Kreiswerte oder den Median der kreisfreien Großstädte derselben Woche abgezogen. Jeder Kreis geht mit demselben Gewicht in den jeweiligen Median ein.

### 4.1 Vergleich innerhalb einer Woche · KW 11/2022

In KW 11/2022 lag der Median aller 400 Kreise bei ungefähr **2.000** Fällen je 100.000 Einwohner. Die Mediane der kreisfreien Großstädte und der städtischen Kreise lagen bei etwa **1.630** bzw. **1.900**, die der beiden ländlichen Kreistypen jeweils bei rund **2.200**. Die Verteilungen überlappen sich deutlich. Auch innerhalb der Kreistypen streuen die Werte stark.

![Abb. 1 – Boxplots und Kreiswerte für KW 11/2022](images/03_boxplot_2022_KW11.png)

### 4.2 Verteilung über alle Wochen

Die gepoolten Verteilungen sind bei allen vier Kreistypen rechtsschief. Einzelne Kreis-Wochen liegen über 4.000 gemeldeten Fällen je 100.000 Einwohner. Die vergrößerte Ansicht zeigt, dass die vier Mediane ungefähr zwischen **55 und 65** Fällen je 100.000 Einwohner liegen. Der Median ist bei den kreisfreien Großstädten etwas höher als bei den beiden ländlichen Kreistypen. Beide Abbildungen basieren auf denselben Beobachtungen.

![Abb. 2 – Boxplots aller Kreis-Wochen, vollständige Skala](images/01_boxplot_alle_wochen.png)

![Abb. 3 – Dieselben Boxplots, vergrößerter Ausschnitt](images/02_boxplot_alle_wochen_zoom.png)

### 4.3 Zeitlicher Verlauf der wöchentlichen Mediane

Die Kurven zeigen weitgehend dieselben Anstiegs- und Rückgangsphasen. Ende 2021 lagen die ländlichen Kreistypen zeitweise höher. Anfang 2022 erreichten zunächst die kreisfreien Großstädte einen höheren ersten Gipfel. Beim darauffolgenden Gipfel lagen beide ländlichen Kreistypen mit rund **2.200** Fällen je 100.000 Einwohner vorne. Im Jahr 2023 waren die Meldeinzidenzen und die absoluten Unterschiede zwischen den Kurven insgesamt geringer.

![Abb. 4 – Wöchentliche Mediane nach Kreistyp](images/04_woechentliche_mediane.png)

### 4.4 Abweichungen vom bundesweiten Median der Kreiswerte

Die größten Abweichungen lagen Anfang 2022. Der Median der kreisfreien Großstädte wechselte innerhalb weniger Wochen von rund **+350** auf rund **−410** Fälle je 100.000 Einwohner relativ zum bundesweiten Kreismedian. Beide ländlichen Kreistypen lagen zeitweise rund **200** Fälle je 100.000 Einwohner darüber. Die städtischen Kreise blieben näher an der Referenz. Die Einzelpanels verwenden dieselbe Skala und machen den Unterschied in der Schwankungsbreite sichtbar.

![Abb. 5 – Wöchentliche Differenzen zum bundesweiten Kreismedian](images/05_differenz_bundesmedian.png)

![Abb. 6 – Dieselben Differenzen in Einzelpanels mit gemeinsamer Skala](images/06_differenz_bundesmedian_facetten.png)

### 4.5 Kreisfreie Großstädte als Referenz

Gegenüber dem jeweiligen Großstadtmedian wechselten die beiden ländlichen Kreistypen Anfang 2022 von ungefähr **−500** auf zeitweise **+600** Fälle je 100.000 Einwohner. Der Vergleich mit derselben Referenz pro Woche zeigt damit einen deutlichen Wechsel der relativen Position. Die Ergebnisse beschreiben gemeldete Fälle auf Kreisebene.

![Abb. 7 – Wöchentliche Differenzen zum Median der kreisfreien Großstädte](images/07_differenz_grossstaedte.png)

## 5. Fazit

Über den gesamten Zeitraum liegen die vier Mediane nah beieinander. Im Wochenvergleich ändert sich die Rangfolge, besonders deutlich Anfang 2022. Die Ergebnisse beziehen sich auf alle Altersgruppen zusammen. Die von der Projektgruppe untersuchten Altersmuster bieten einen Ansatzpunkt, um im nächsten Schritt zu prüfen, ob die zeitlichen Unterschiede zwischen den Kreistypen je nach Altersgruppe unterschiedlich ausfallen.
