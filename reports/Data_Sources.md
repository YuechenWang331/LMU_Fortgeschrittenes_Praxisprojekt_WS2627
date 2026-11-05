# Datenquellen und Quellenprüfung (ohne RKI)

**Projekt:** Zusammenhang zwischen Strukturmerkmalen und Inzidenzverläufen in den Altersgruppen  
**Veranstaltung:** Fortgeschrittenes Praxisprojekt, LMU München, WS 2026/27  
**Stand der Recherche:** 05.11.2026  
**Zweck:** Dokumentation der drei im Projektverzeichnis identifizierten Nicht-RKI-Datenquellen zur unabhängigen Prüfung durch die Gruppe.


## 1. Kurzüberblick

| Nr. | Datensatz                                                             | Originalinstitution                                      | Offizielle Referenz           | Lokale Rohdatei                                                                  |
| --- | --------------------------------------------------------------------- | -------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------------------------- |
| 1   | Bevölkerung nach Kreisen, Geschlecht und Altersgruppen                | Statistisches Bundesamt (Destatis)                       | GENESIS-Online **12411-0018** | `data_raw/12411-0018 Bevölkerung nach Geschlecht, Altersgruppen und Kreisen.csv` |
| 2   | Siedlungs- und raumstrukturelle Kreisgliederungen (Gebietsstand 2023) | Bundesinstitut für Bau-, Stadt- und Raumforschung (BBSR) | *Referenzen Raumabgrenzungen* | `data_raw/raumgliederungen-referenzen-2023.xlsx`                                 |
| 3   | Gebietsfläche nach Kreisen                                            | Statistisches Bundesamt (Destatis)                       | GENESIS-Online **11111-0002** | `data_raw/11111-0002 Gebietsfläche nach Kreise.csv`                              |



---

## 2. Bevölkerung: GENESIS-Tabelle 12411-0018

### 2.1 Originalquelle

- **Herausgeber:** Statistisches Bundesamt (Destatis), Deutschland.
- **Statistik:** Fortschreibung des Bevölkerungsstandes (Statistik-Code **12411**).
- **Tabellenkennung:** **12411-0018**.
- **Originaltitel:** *Bevölkerung: Kreise, Stichtag, Geschlecht, Altersgruppen*.
- **Offizielle Tabellenseite:** https://genesis.destatis.de/datenbank/online/statistic/12411/table/12411-0018
- **Offizielle Statistikübersicht:** https://genesis.destatis.de/datenbank/online/statistic/12411/details
- **Methodischer Hintergrund (Zensusumstellung):** https://www.destatis.de/DE/Themen/Gesellschaft-Umwelt/Bevoelkerung/Bevoelkerungsstand/Methoden/Erlauterungen/umstellung-bevoelkerungszahlen-zensus-2022.html

### 2.2 Inhalt und Verwendung im Projekt

Die amtliche Tabelle enthält Bevölkerungsbestände (**Anzahl Personen**) nach **Kreis**, **Stichtag**, **Geschlecht** und **Altersgruppe**. Die GENESIS-Tabelle weist Altersgruppen von „unter 3 Jahre“ bis „75 Jahre und mehr“ aus. Der dokumentierte Gesamtzeitraum der offiziellen Tabelle reicht über den Untersuchungszeitraum 2020–2023 hinaus; entscheidend ist die **konkrete Auswahl in der lokalen CSV**.

**Geplante Verwendung:** Beschreibung der regionalen Altersstruktur; Bevölkerungsanteile je Altersgruppe; potenzielle Kovariaten und – **nur bei identischer Alters-/Gebietsdefinition** – Bevölkerungsnenner für selbst berechnete Inzidenzkennzahlen.


---

## 3. Raumgliederungen: BBSR-Referenztabellen, Gebietsstand 31.12.2023

### 3.1 Originalquelle

- **Herausgeber:** Bundesinstitut für Bau-, Stadt- und Raumforschung (BBSR) im Bundesamt für Bauwesen und Raumordnung (BBR).
- **Datenbereich:** Laufende Raumbeobachtung / Raumabgrenzungen und Raumgliederungen.
- **Dateibezeichnung im Projekt:** `raumgliederungen-referenzen-2023.xlsx`.
- **Raumstand:** 31.12.2023 (laut lokaler Skriptdokumentation und BBSR-Kontext).
- **Offizieller Einstieg:** https://www.inkar.de/ → *Dokumentation und Hilfe* → *Referenzen Raumabgrenzungen*.
- **BBSR-Referenzseite:** https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/downloads/download-referenzen.html
- **Historisch referenzierter Direktlink zur XLSX (erneut prüfen):** https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/downloads/raumgliederungen-referenzen-2023.xlsx?__blob=publicationFile&v=5



### 3.2 Inhalt und Verwendung im Projekt

Aus dem Arbeitsblatt `Kreisreferenz` liest das Projektskript regionale Codes und Klassifikationen aus. 

**Geplante Verwendung:** Analyse, ob sich altersbezogene COVID-19-Inzidenzverläufe je nach siedlungsstrukturellem Kreistyp, Zentralität/Lage oder Stadt-Land-Klassifikation unterscheiden.

**Lokaler Verarbeitungspfad:**

- Rohdatei: `data_raw/raumgliederungen-referenzen-2023.xlsx`
- R-Skript: `Scripts/02_Preprocess_Raumgliederungen_2023.R`
- Ergebnis: `data_processed/raumgliederungen_kreis_2023.rds`
- Das Skript erwartet **400 eindeutige Kreise**, prüft eindeutige `geo_code` und nicht fehlende `kreistyp_code`.



---

## 4. Gebietsfläche: GENESIS-Tabelle 11111-0002

### 4.1 Originalquelle

- **Herausgeber:** Statistisches Bundesamt (Destatis), Deutschland.
- **Statistik / Tabelle:** **11111-0002**.
- **Originaltitel:** *Gebietsfläche: Kreise, Stichtag*.
- **Offizielle Tabellenseite:** https://genesis.destatis.de/datenbank/online/statistic/11111/table/11111-0002
- **Einheit:** Quadratkilometer (**km²**, in GENESIS als `qkm` bezeichnet).
- **Zeitliche Verfügbarkeit laut offizieller Tabellenansicht:** 31.12.1995 bis 31.12.2023; 

### 4.2 Inhalt und Verwendung im Projekt

Die Tabelle umfasst amtliche Flächenangaben für Kreise zu bestimmten Stichtagen. Im lokalen Aufbereitungsskript werden `geo_code`, `geo_name`, `year` und `area_km2` erstellt.

**Geplante Verwendung:** Berechnung der Bevölkerungsdichte als regionaler Strukturindikator.

---


