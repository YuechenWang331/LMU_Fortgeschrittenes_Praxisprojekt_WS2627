# Kurzbericht: Eisenach und Wartburgkreis in den RKI-Daten (2020)

**Projekt:** Zusammenhang zwischen Strukturmerkmalen und Inzidenzverläufen in den Altersgruppen (COVID-19)  
**LMU München · Fortgeschrittenes Praxisprojekt · Stand: 06.11.2026**

## 1. Fragestellung

Eisenach (`16056`) war 2020 noch eine eigenständige kreisfreie Stadt und wurde am **01.07.2021** in den Wartburgkreis (`16063`) eingegliedert. Für unsere Analysen werden alle Datensätze auf **400 Kreise** vereinheitlicht. Unklar war, ob die RKI-Daten für den Wartburgkreis im Jahr 2020 Eisenach bereits enthalten.

## 2. Daten und Aufbereitung

| Datenquelle | Gebietsgliederung | Vorgehen |
|---|---|---|
| Destatis-Bevölkerung 2020 | 401 Kreise, Eisenach separat | `16056` und `16063` werden für 2020 addiert. |
| RKI/SurvStat-Fälle und -Inzidenzen | 411 regionale Positionen; kein eigener Eintrag `16056` | Die zwölf Berliner Bezirke werden zu Berlin (`11000`) zusammengefasst: 411 → 400. |
| RKI/SurvStat-Bevölkerungsnenner | Aus SurvStat mit `infer_population()` abgeleitet | Für den Wartburgkreis 2020 wird die Summe über alle Altersgruppen geprüft. |

**Relevante Skripte:** `data_raw/00_Download_Skript.R`, `Scripts/01_Preprocess_Population_Data.R`, `Scripts/04_Preprocess_RKI_Data.R`.

## 3. Prüfung des Bevölkerungsnenners

Die folgende Kontrolle wurde lokal in RStudio mit `data_processed/rki_population_annual.rds` ausgeführt:

```r
rki <- readRDS("data_processed/rki_population_annual.rds")
x <- subset(rki, geo_code == "16063" & year == 2020 &
              age_group %in% c(as.character(0:79), "80+"))

nrow(x)
sum(is.na(x$population))
sum(x$population, na.rm = TRUE)
```

**Beobachtetes Ergebnis:** 81 Altersgruppen, 0 fehlende Werte, **159.937 Einwohner**.

Die amtlichen Einwohnerzahlen zum **31.12.2020** ergeben genau denselben Wert:

**Wartburgkreis ohne Eisenach: 117.967 + Eisenach: 41.970 = 159.937 Einwohner.**

Diese exakte Übereinstimmung ist ein **starker Beleg**, dass der in unserem RKI/SurvStat-Datensatz verwendete Bevölkerungsnenner für den Wartburgkreis 2020 **Eisenach einschließt**. Der Wert stammt aus den verarbeiteten SurvStat-Daten; `infer_population()` leitet Bevölkerungsnenner aus den SurvStat-Abfragen ab und ist keine eigenständige Volkszählung.

## 4. Bewertung und offene Frage

**Gesichert:** Die Destatis-Bevölkerung wurde auf 400 Kreise harmonisiert; der RKI/SurvStat-Bevölkerungsnenner für Wartburgkreis 2020 entspricht dem Gesamtgebiet einschließlich Eisenach.

**Noch nicht direkt nachgewiesen:** Ob die **COVID-19-Fallzahlen des Jahres 2020** in der heutigen RKI/SurvStat-Abfrage rückwirkend ebenfalls vollständig dem Wartburgkreis zugeordnet wurden. Der passende Bevölkerungsnenner allein beweist das nicht.

**Empfehlung:** Vorläufig **keine Fälle oder Einwohner löschen**. Die historische Zuordnung der Fälle bei RKI/SurvStat prüfen und das Ergebnis dokumentieren. Falls Eisenacher Fälle fehlen, sollte die Kreis-Jahr-Beobachtung 2020 nicht ohne weitere Korrektur als geografisch vergleichbar interpretiert werden.

## Quellen

- [Landkreis Wartburgkreis, Haushaltsplan 2022](https://www.wartburgkreis.de/fileadmin/Formulare_Merkblaetter_Regelungen/14/42-3-2022_Entwurf_HH_2022_Beschlussfassung.pdf) – Einwohnerzahl 2020 einschließlich Eisenach: 159.937.
- [Stadt Eisenach, Beteiligungsbericht 2021](https://www.eisenach.de/fileadmin/user_upload/buergerservice/StaedtischeFirmen/BBericht2021/BBericht2021.pdf) – getrennte Einwohnerzahlen für 2020.
- [Dokumentation des R-Pakets `rsurvstat`](https://cran.r-universe.dev/rsurvstat/rsurvstat.pdf) – SurvStat-Daten und `infer_population()`.
- Projektskripte und lokal ausgeführte RStudio-Kontrolle (siehe Abschnitte 2–3).
