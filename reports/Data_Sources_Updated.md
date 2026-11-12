# Datenquellen

**Projekt:** Zusammenhang zwischen Strukturmerkmalen und Inzidenzverläufen in den Altersgruppen\
**Veranstaltung:** Fortgeschrittenes Praxisprojekt, LMU München, WS 2026/27\
**Stand der Recherche:** 11.11.2026\
**Zweck:** Dokumentation der Nicht-RKI-Datenquellen und ihrer Verknüpfung mit den RKI-Wochenfällen.\
**Analysezeitraum der Kreistyp-Auswertung:** ISO-Wochenjahre 2020–2023.

## 1. Kurzüberblick

| Nr. | Datensatz | Originalinstitution | Offizielle Referenz | Lokale Rohdatei |
|---------------|---------------|---------------|---------------|---------------|
| 1 | Bevölkerung nach Kreisen, Geschlecht und Altersgruppen | Statistisches Bundesamt (Destatis) | GENESIS-Online **12411-0018** | `data_raw/12411-0018 Bevölkerung nach Geschlecht, Altersgruppen und Kreisen.csv` |
| 1a | Gesamtbevölkerung der Kreise für 2020 | Statistisches Bundesamt (Destatis) | GENESIS-Online **12411-0016** | `data_raw/12411-0016_de 2020.xlsx` |
| 2a | Siedlungs- und raumstrukturelle Kreisgliederungen sowie Gemeindebevölkerung (Gebietsstände 2021–2023) | Bundesinstitut für Bau-, Stadt- und Raumforschung (BBSR) | *Referenzen Raumabgrenzungen* | `data_raw/raumgliederungen-referenzen-2021.xlsx` bis `data_raw/raumgliederungen-referenzen-2023.xlsx` |
| 2b | Siedlungsstrukturelle Kreistypen und Raumtypen nach Lage (Gebietsstand 2020) | BBSR | Laufende Raumbeobachtung | `data_raw/siedlungsstrukt-kreistypen-2020.csv`, `data_raw/raumtypen-lage-2020.csv` |
| 3 | Gebietsfläche nach Kreisen | Statistisches Bundesamt (Destatis) | GENESIS-Online **11111-0002** | `data_raw/11111-0002 Gebietsfläche nach Kreise.csv` |

------------------------------------------------------------------------

## 2. Bevölkerung: GENESIS-Tabelle 12411-0018

### 2.1 Originalquelle

- **Herausgeber:** Statistisches Bundesamt (Destatis), Deutschland.
- **Statistik:** Fortschreibung des Bevölkerungsstandes (Statistik-Code **12411**).
- **Tabellenkennung:** **12411-0018**.
- **Originaltitel:** *Bevölkerung: Kreise, Stichtag, Geschlecht, Altersgruppen*.
- **Offizielle Tabellenseite:** <https://genesis.destatis.de/datenbank/online/statistic/12411/table/12411-0018>
- **Offizielle Statistikübersicht:** <https://genesis.destatis.de/datenbank/online/statistic/12411/details>
- **Methodischer Hintergrund (Zensusumstellung):** <https://www.destatis.de/DE/Themen/Gesellschaft-Umwelt/Bevoelkerung/Bevoelkerungsstand/Methoden/Erlauterungen/umstellung-bevoelkerungszahlen-zensus-2022.html>

### 2.2 Inhalt und Verwendung im Projekt

Die amtliche Tabelle enthält Bevölkerungsbestände (**Anzahl Personen**) nach **Kreis**, **Stichtag**, **Geschlecht** und **Altersgruppe**. Die GENESIS-Tabelle weist Altersgruppen von „unter 3 Jahre“ bis „75 Jahre und mehr“ aus. Der dokumentierte Gesamtzeitraum der offiziellen Tabelle reicht über den Untersuchungszeitraum 2020–2023 hinaus; entscheidend ist die **konkrete Auswahl in der lokalen CSV**.

**Geplante Verwendung:** Beschreibung der regionalen Altersstruktur; Bevölkerungsanteile je Altersgruppe; potenzielle Kovariaten und – **nur bei identischer Alters-/Gebietsdefinition** – Bevölkerungsnenner für selbst berechnete Inzidenzkennzahlen.

------------------------------------------------------------------------

## 3. Raumgliederungen: BBSR-Referenztabellen, Gebietsstände 2021–2023

### 3.1 Originalquelle

- **Herausgeber:** Bundesinstitut für Bau-, Stadt- und Raumforschung (BBSR) im Bundesamt für Bauwesen und Raumordnung (BBR).

- **Datenbereich:** Laufende Raumbeobachtung / Raumabgrenzungen und Raumgliederungen.

- **Offizielle Referenz:** *Referenzen Raumabgrenzungen*.

- **Offizielle Tabellenseite:** <https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/downloads/raumgliederungen-referenzen-2021.xlsx?__blob=publicationFile&v=2>

  <https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/downloads/raumgliederungen-referenzen-2022.xlsx?__blob=publicationFile&v=2>

  <https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/downloads/raumgliederungen-referenzen-2023.xlsx?__blob=publicationFile&v=3>

- **Administrative Grundlage:** Gemeindeverzeichnis-Informationssystem (GV-ISys) des Statistischen Bundesamtes (Destatis), laut den Nutzungshinweisen der Excel-Dateien.

- **Lizenz:** Datenlizenz Deutschland – Namensnennung – Version 2.0.

- **Empfohlene Quellenangabe:** *Bundesinstitut für Bau-, Stadt- und Raumforschung: Laufende Raumbeobachtung des BBSR.*

| Nr. | Lokale Rohdatei | Gebietsstand | Stand der Datei |
|------------------|------------------|------------------|------------------|
| 1 | `data_raw/raumgliederungen-referenzen-2021.xlsx` | 31.12.2021 | 17.11.2023 |
| 2 | `data_raw/raumgliederungen-referenzen-2022.xlsx` | 31.12.2022 | 30.04.2025 |
| 3 | `data_raw/raumgliederungen-referenzen-2023.xlsx` | 31.12.2023 | 03.12.2025 |

Der **Gebietsstand** bezeichnet den Stichtag der administrativen Gebietsgliederung. Der **Stand der Datei** bezeichnet die Fassung der Excel-Datei. Beide Angaben stammen aus dem jeweiligen Arbeitsblatt `Nutzungshinweise`.

### 3.2 Inhalt und Verwendung im Projekt

| Arbeitsblatt | Verwendete Angaben | Verwendung im Projekt |
|------------------------|------------------------|------------------------|
| `Administrativ` | Gemeindeschlüssel, Kreisschlüssel und Einwohnerzahl. Für 2022 sind dies `GEM2022`, `KRS2022` und `bev22`. | Die Einwohnerzahlen der Gemeinden werden je Kreis summiert. Die Kreisbevölkerung wird für 2021–2023 aus diesen Referenztabellen aufbereitet. In der aktuellen Kreistyp-Auswertung gehen die Jahrgänge 2021–2023 als Nenner der wöchentlichen COVID-19-Meldeinzidenz ein. |
| `Kreisreferenz` | Kreisschlüssel, siedlungsstruktureller Kreistyp (`KTU`) und Raumtyp nach Lage (`RLK`). Für 2022 sind dies `KRS2022`, `KTU2022` und `RLK2022`. | Beide Klassifikationen werden dem jeweiligen Kreis und Jahr zugeordnet und für Vergleiche der Inzidenzverläufe nach regionalen Strukturmerkmalen verwendet. Die Auswertung verwendet die Klassifikation des jeweiligen Analysejahres. |

**Hinweis zum Datenbestand:** Im lokalen Ordner `data_raw` liegt keine BBSR-Referenzdatei für 2024 vor. Dateinamen von Verarbeitungsskripten und RDS-Dateien mit dem Suffix `2020_2024` werden hier als bestehende Projektpfade dokumentiert; daraus folgt nicht, dass die BBSR-Referenztabelle für 2024 lokal vorhanden ist.

**Lokaler Verarbeitungspfad:**

- **Bevölkerungsaufbereitung:** `Scripts/Preprocess_population_kreis_2020_2024.R` → `data_processed/population_kreis_2020_2024.rds`
- **Aufbereitung der Kreistypen und Raumtypen:** `Scripts/Preprocess_population_Kreistyp_Raumtyp_2020_2024.R` → `data_processed/population_Kreistyp_Raumtyp_2020_2024.rds`
- **Verknüpfung:** Die jährlichen Bevölkerungs- und Klassifikationsangaben werden über den fünfstelligen Kreisschlüssel und das Jahr zusammengeführt. Die Skripte prüfen, ob die erwarteten 400 Kreise je Jahr vorliegen.
- **Separater Referenzdatensatz 2023:** `Scripts/02_Preprocess_Raumgliederungen_2023.R` erzeugt aus `Kreisreferenz` die Datei `data_processed/raumgliederungen_kreis_2023.rds`. Die Kreisschlüssel dienen der Prüfung der räumlichen Abdeckung der aufbereiteten RKI-Daten.

### 3.3 Ergänzende BBSR-Quellen für 2020

| Datensatz | Lokale Rohdatei | Verwendung im Projekt |
|------------------------|------------------------|------------------------|
| Siedlungsstrukturelle Kreistypen 2020 | `data_raw/siedlungsstrukt-kreistypen-2020.csv` | Zuordnung des siedlungsstrukturellen Kreistyps je Kreis. |
| Raumtypen nach Lage 2020 | `data_raw/raumtypen-lage-2020.csv` | Zuordnung des Lagetyps je Kreis. |

Siedlungsstrukturelle Kreistypen 2020: <https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/deutschland/kreise/siedlungsstrukturelle-kreistypen/siedlungsstrukt-kreistypen-2020.csv?__blob=publicationFile&v=2>

Raumtypen nach Lage 2020:

<https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/deutschland/kreise/Raumtypen2010_krs/raumtypen-lage-2020.csv?__blob=publicationFile&v=2>

Die Kreisbevölkerung für 2020 stammt aus der Destatis-Tabelle **GENESIS 12411-0016**. Im Projekt wird dafür die Rohdatei `data_raw/12411-0016_de 2020.xlsx` verwendet. Die Einwohnerzahlen von Eisenach (`16056`) und dem damaligen Wartburgkreis (`16063`) werden für die harmonisierte Bevölkerung 2020 unter `16063` zusammengefasst.

------------------------------------------------------------------------

## 4. Gebietsfläche: GENESIS-Tabelle 11111-0002

### 4.1 Originalquelle

- **Herausgeber:** Statistisches Bundesamt (Destatis), Deutschland.
- **Statistik / Tabelle:** **11111-0002**.
- **Originaltitel:** *Gebietsfläche: Kreise, Stichtag*.
- **Offizielle Tabellenseite:** <https://genesis.destatis.de/datenbank/online/statistic/11111/table/11111-0002>
- **Einheit:** Quadratkilometer (**km²**, in GENESIS als `qkm` bezeichnet).
- **Zeitliche Verfügbarkeit laut offizieller Tabellenansicht:** 31.12.1995 bis 31.12.2023;

### 4.2 Inhalt und Verwendung im Projekt

Die Tabelle umfasst amtliche Flächenangaben für Kreise zu bestimmten Stichtagen. Im lokalen Aufbereitungsskript werden `geo_code`, `geo_name`, `year` und `area_km2` erstellt.

**Geplante Verwendung:** Berechnung der Bevölkerungsdichte als regionaler Strukturindikator.

------------------------------------------------------------------------

## 5. Verknüpfung mit den RKI-Wochenfällen und Kartenansicht

| Schritt | Eingabe bzw. Ergebnis |
|------------------------------------|------------------------------------|
| Wochenfälle aller Altersgruppen | `data_processed/rki_weekly_cases_all_ages.rds` |
| Jährliche Bevölkerung und Kreistypen | `data_processed/population_Kreistyp_Raumtyp_2020_2024.rds` |
| Verknüpfung und Inzidenzberechnung | `Preprocess_regional_weekly_summary_2020_2023.R` |
| Wöchentliche Analysetabelle | `data_processed/Kreistyp/regional_weekly_summary_2020_2023.rds` |
| Geometrie für die Kartenansicht | `data_geo/landkreise_simplify200.geojson` |

Das Aufbereitungsskript beschränkt beide Eingaben auf 2020–2023 und verknüpft sie über den fünfstelligen Kreisschlüssel und das ISO-Wochenjahr. Die Wocheninzidenz ergibt sich aus den gemeldeten Fällen aller Altersgruppen je Kreis und Woche, geteilt durch die Gesamtbevölkerung des Kreises im zugehörigen Jahr und multipliziert mit 100.000. Das Skript prüft die Eindeutigkeit der Schlüssel, die Fallzahlerhaltung und die Abdeckung von 400 Kreisen je Woche. Die Ausgabetabelle umfasst 83.600 Zeilen (400 Kreise × 209 ISO-Kalenderwochen).

`incidence_map_Shiny.R` liest diese Ausgabetabelle. Für die Jahresansicht werden die Fälle aller ISO-Kalenderwochen eines Jahres summiert. Für die Monatsansicht werden die Wochen dem Monat ihres Montags zugeordnet. Liegt der Montag vor dem zugehörigen ISO-Jahr, wird die Woche dessen Januar zugeordnet (z. B. KW 01/2020 mit Wochenbeginn am 30.12.2019). Die Monatswerte sind Näherungen aus Wochendaten. Beide Ansichten teilen die summierten Fälle durch die jeweilige Jahresbevölkerung und multiplizieren mit 100.000.

Für die Karte werden die Landgeometrien (`GF = 4`) verwendet und über den Kreisschlüssel (`AGS`) mit der Analysetabelle verknüpft. Die Kartenansicht verwendet einheitliche Kreisgrenzen für alle Analysejahre.

------------------------------------------------------------------------
