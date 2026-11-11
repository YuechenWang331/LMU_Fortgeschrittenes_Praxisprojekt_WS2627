# RKI weekly long – Variablendefinitionen

**Projekt:** Zusammenhang zwischen Strukturmerkmalen und Inzidenzverläufen in den Altersgruppen  
**Datensatz:** `data_processed/rki_weekly_long.rds`  
**Erzeugendes Skript:** `Scripts/04_Preprocess_RKI_Data.R`  
**Stand der Dokumentation:** 05.11.2026

## 1. Datensatz und Beobachtungseinheit

Der Datensatz enthält wöchentliche COVID-19-Meldedaten aus **SurvStat@RKI 2.0** im Long-Format. **Eine Zeile entspricht einem Kreis, einer Altersgruppe und einer ISO-Meldewoche.**

- **Gebiete:** 400 Kreiseinheiten; die zwölf Berliner Bezirke sind zu Berlin zusammengefasst.
- **Altersgruppen:** Einzelalter 0–79, `80+` und unbekanntes Alter (`"NA"`).
- **Zeitraum:** ISO-Meldejahre 2020–2024.
- **Variablen:** 7.

## 2. Variablenverzeichnis

### `geo_code`

- **Definition:** Fünfstelliger Gebietsschlüssel des Kreises bzw. der kreisfreien Stadt.
- **Datentyp:** `character`
- **Einheit / Werte:** Fünf Ziffern als Text, z. B. `"01001"`; gesamtes Berlin: `"11000"`.
- **Fehlwerte / Besonderheiten:** Führende Nullen müssen erhalten bleiben. Fehlende Werte wurden nicht separat ausgewertet.
- **Quelle:** `CountyKey71Map.csv`, aufbereitet im Projektskript.

### `age_group`

- **Definition:** Altersgruppe der gemeldeten Person zum Meldezeitpunkt.
- **Datentyp:** `character`
- **Einheit / Werte:** `"0"` bis `"79"` (Einzelalter in Jahren), `"80+"`, `"NA"`.
- **Fehlwerte / Besonderheiten:** `"NA"` ist die **Textkategorie für unbekanntes Alter**, kein R-Fehlwert `NA`.
- **Quelle:** SurvStat, `age_groups$single_year`.

### `week_start`

- **Definition:** Montag der betreffenden ISO-Meldewoche.
- **Datentyp:** `Date`
- **Einheit / Werte:** Datum, z. B. `2019-12-30` für ISO-KW 01/2020.
- **Fehlwerte / Besonderheiten:** Im Skript werden gültige Datumswerte und Montag als Wochenbeginn geprüft.
- **Quelle:** Aus der Wochenkennzeichnung der SurvStat-Daten abgeleitet.

### `iso_year`

- **Definition:** Jahr gemäß ISO-Wochenkalender.
- **Datentyp:** `integer`
- **Einheit / Werte:** 2020–2024.
- **Fehlwerte / Besonderheiten:** Kann vom Kalenderjahr von `week_start` abweichen.
- **Quelle:** Aus `week_start` berechnet (`format(..., "%G")`).

### `iso_week`

- **Definition:** Nummer der ISO-Kalenderwoche innerhalb von `iso_year`.
- **Datentyp:** `integer`
- **Einheit / Werte:** 1–52, gegebenenfalls 53.
- **Fehlwerte / Besonderheiten:** Aus einem gültigen `week_start` abgeleitet.
- **Quelle:** Aus `week_start` berechnet (`format(..., "%V")`).

### `count`

- **Definition:** Anzahl der gemeldeten COVID-19-Fälle je Kreis, Altersgruppe und Meldewoche.
- **Datentyp:** `numeric` (inhaltlich ganzzahlige Fallzahl)
- **Einheit / Werte:** Fälle; nichtnegative ganze Zahlen.
- **Fehlwerte / Besonderheiten:** `0` = keine gemeldeten Fälle; numerisches `NA` = fehlender Wert. Dieselbe fortdauernde Infektion wird nicht jede Woche erneut gezählt; eine als neuer Fall erfasste Reinfektion kann erneut eingehen.
- **Quelle:** SurvStat, `measure = "Count"`; für Berlin Summe der zwölf Bezirke.

### `incidence`

- **Definition:** Wöchentliche COVID-19-Meldeinzidenz je 100.000 Einwohner derselben Altersgruppe und desselben Gebiets.
- **Datentyp:** `numeric`
- **Einheit / Werte:** Gemeldete Fälle pro 100.000 Einwohner und Meldewoche; nichtnegative Werte.
- **Fehlwerte / Besonderheiten:** Numerisches `NA` = fehlende/nicht berechenbare Inzidenz. Bei `age_group == "NA"` wird `incidence` im Skript immer auf `NA` gesetzt.
- **Quelle:** SurvStat, `measure = "Incidence"`; für Berlin aus aggregierten Fallzahlen und geschätztem Bevölkerungsnenner neu berechnet.

## 3. Wichtige Hinweise

- **Meldedatum:** Die Meldewoche bezieht sich auf den Zeitpunkt der Meldung beim Gesundheitsamt, nicht auf den tatsächlichen Infektionsbeginn.
- **Fälle ≠ Personen:** Ein fortdauernder Fall wird nicht allein wegen seiner Dauer erneut gezählt. Eine getrennt erfasste Reinfektion kann als neuer Fall eingehen. Da keine Personenkennungen vorliegen, sind unterschiedliche infizierte Personen und Reinfektionsraten aus dieser Tabelle nicht bestimmbar.
- **Inzidenz ≠ Prävalenz:** `incidence` misst gemeldete Fälle je 100.000 Einwohner pro Woche, nicht alle in dieser Woche Erkrankten.
- **Datenprüfung:** Definitionen und Datentypen wurden aus den Projektskripten abgeleitet. Empirische Wertebereiche, Häufigkeiten fehlender Werte und der ursprüngliche RKI-Abrufstand sind noch nicht verifiziert.

## 4. Quellen

- Robert Koch-Institut (RKI): [SurvStat@RKI 2.0](https://survstat.rki.de/), [Inhaltliche Hinweise](https://survstat.rki.de/Content/Instruction/Content.aspx) und [Variablenübersicht](https://survstat.rki.de/Docs/Attributes.pdf).
- `rsurvstat`: [Paketdokumentation](https://cran.r-universe.dev/rsurvstat/doc/manual.html).
- Projektdateien: `data_raw/00_Download_Skript.R`, `Scripts/04_Preprocess_RKI_Data.R`, `data_raw/CountyKey71Map.csv`.

*Hinweis: Die Definitionen sollten vor der Abgabe anhand der Originaldaten geprüft und die KI-Unterstützung gemäß den LMU-Richtlinien dokumentiert werden.*
