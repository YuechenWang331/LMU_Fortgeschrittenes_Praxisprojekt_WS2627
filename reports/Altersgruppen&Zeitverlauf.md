# Wochenbericht KW 47 – Zeitentwicklung der COVID-19-Inzidenz nach Altersgruppen

**Fortgeschrittenes Praxisprojekt WS 2026/27 · LMU München**  
**Projekt:** Zusammenhang zwischen Strukturmerkmalen und Inzidenzverläufen in den Altersgruppen (COVID-19)  
**Aufgabe:** Exploration der Zeitentwicklung in verschiedenen Altersgruppen  
**Bearbeitung:** Thomas · **Stand:** 19.11.2026 · **Projektpartner:** André Klima

## 1. Fragestellung und Ziel

Wie unterscheiden sich die **zeitlichen Verläufe der gemeldeten COVID-19-Wocheninzidenz** zwischen Altersgruppen? Welche Unterschiede werden sichtbar, wenn statt **7 breiten Altersgruppen** eine feinere Einteilung in **13 Altersgruppen** verwendet wird?

Ziel dieser Woche war eine **explorative, deskriptive Analyse**, noch keine Erklärung von Ursachen oder die Modellierung von Zusammenhängen mit regionalen Strukturmerkmalen.

## 2. Daten und Vorgehen

- **Datenbasis:** Aufbereitete RKI-/SurvStat-Daten für die Jahre **2020–2023** mit **209 aufeinanderfolgenden Wochen**. Die Ausgangsdaten unterscheiden die Einzelalter **0–79** und die offene Gruppe **80+**; unbekanntes Alter wird separat kontrolliert.
- **Altersgruppierung:** Aufbau der beiden von André vorgeschlagenen Schemata aus den Einzelaltern: **7 Gruppen** (0–5, 6–17, 18–39, 40–59, 60–69, 70–79, 80+) und **13 feinere Gruppen** (0–2, 3–5, 6–9, 10–14, 15–17, 18–24, 25–29, 30–39, 40–49, 50–59, 60–69, 70–79, 80+).
- **Geografischer Umfang:** Die Primärdarstellung dieser EDA verwendet eine **konstante Stichprobe von 383 der 400 harmonisierten Kreise** (*Balanced Sample*). Bei 17 Kreisen fehlen insgesamt 29 Kombinationen aus Einzelalter, Jahr und Kreis im abgeleiteten Bevölkerungsnenner. Die 383 Kreise ermöglichen eine über alle Jahre und Altersgruppen konsistente Nennerabdeckung.
- **Kennzahl:** Gemeldete Fälle je **100.000 Einwohner und ISO-Meldewoche**, berechnet nach Aggregation von Fallzahlen und jahresspezifischen Bevölkerungsnennern. Es handelt sich **nicht** um eine gleitende 7-Tage-Inzidenz. Die Zeitreihen werden für die Auswertung der Maxima **nicht geglättet**.
- **Analysen:** Zeitreihen und Heatmap, deskriptive Kennzahlen, Zeitpunkte der beobachteten Maxima, Vergleich beider Gruppierungen und vertiefte Betrachtung von **2022-W01 bis 2022-W16**. Aggregation und Ausgaben wurden technisch validiert.

## 3. Zentrale Ergebnisse

### 3.1 Unterschiedliche Maximalwerte und Zeitpunkte

In **allen 20 Altersgruppen-Reihen** der beiden Schemata liegt das beobachtete **Gesamtmaximum im Jahr 2022**; die Maxima fallen auf die ISO-Wochen **W04, W05, W11 oder W12**. Beispiele aus dem 7er-Schema:

| Altersgruppe | Maximale Wocheninzidenz | ISO-Woche |
|---|---:|---|
| 0–5 | 1.510,79 | 2022-W04 |
| 6–17 | 3.484,07 | 2022-W05 |
| 18–39 | 2.517,79 | 2022-W11 |
| 40–59 | 2.034,65 | 2022-W12 |
| 60–69 | 1.168,02 | 2022-W12 |
| 70–79 | 790,76 | 2022-W12 |
| 80+ | 836,16 | 2022-W12 |

**Interpretation:** Die Altersgruppen unterscheiden sich im beobachteten Niveau und in den Zeitpunkten ihrer höchsten Wocheninzidenz. Diese Maxima müssen aber **nicht derselben epidemiologischen Welle** angehören; ihre zeitliche Differenz ist **kein Nachweis einer Übertragungsverzögerung**.

### 3.2 Die feinere Einteilung zeigt verdeckte Heterogenität

Ein besonders anschauliches Beispiel ist die breite Gruppe **0–5 Jahre**:

| Altersgruppe | Beobachtetes Maximum | ISO-Woche |
|---|---:|---|
| 0–5 | 1.510,79 | 2022-W04 |
| 0–2 | 1.001,59 | 2022-W12 |
| 3–5 | 2.109,11 | 2022-W04 |

Zwischen **2022-W04 und W05** steigt die Wocheninzidenz bei den **0–2-Jährigen** von **883,80 auf 915,61**, während sie bei den **3–5-Jährigen** von **2.109,11 auf 2.068,17** sinkt. Die zusammengefasste Gruppe **0–5** zeigt dagegen nur eine geringe Veränderung von **1.510,79 auf 1.505,38**. **Gegenläufige Entwicklungen innerhalb einer breiten Altersgruppe können durch Aggregation verdeckt werden.**

Auch bei den **6–17-Jährigen** unterscheiden sich die Teilgruppen: **6–9** und **10–14 Jahre** erreichen ihr Gesamtmaximum in **2022-W05**, die **15–17-Jährigen** dagegen in **2022-W11**. Weitere Unterschiede zeigen sich innerhalb der 18–39-Jährigen.

### 3.3 Abgleich mit 400 Kreisen

Für **2021 und 2022** sind die Bevölkerungsnenner aller 400 Kreise vollständig. Dort wurde die 383-Kreis-Zeitreihe mit der 400-Kreis-Zeitreihe verglichen. Die **maximale absolute Abweichung** über die geprüften Altersgruppen und Wochen beträgt **9,20 Fälle je 100.000 Einwohner und Woche** (13er-Schema, 2022). Die beobachteten aggregierten Werte sind für diese beiden Jahre somit **wenig sensitiv gegenüber der Kreis-Auswahl**. Dies ist **keine** Gleichwertigkeitsprüfung für 2020/2023 oder für spätere Analysen regionaler Strukturmerkmale.

## 4. Abbildungen für die Besprechung

Die folgenden **bereits erzeugten** Abbildungen liegen im Git-Projekt unter `results/Altsgruppen_ZeitlicheEntwicklung/`. Die angegebenen Pfade sind **relativ zum Repository** und vermeiden nicht-portable lokale Benutzerpfade.

| Abbildung | Datei | Aussage für die Präsentation |
|---|---|---|
| **Abb. 01** | `01_timeseries_7_groups.png` | Überblick über die Entwicklung der sieben breiten Gruppen, 2020–2023 |
| **Abb. 04** | `04_heatmap_13_groups.png` | Zeitliches Muster und Niveau der 13 feineren Gruppen |
| **Abb. 06** | `06_grouping_comparison.png` | Direkter Vergleich von breiten und feineren Altersgruppen |
| **Abb. 08** | `08_focused_2022_age_patterns.png` | Konkretes Beispiel der verdeckten Unterschiede im Frühjahr 2022 |

Die übrigen fünf Abbildungen und detaillierten Statistiktabellen stehen als **technischer Anhang** zur Verfügung. Für die mündliche Vorstellung sind besonders **Abb. 01 → 06 → 08** geeignet; Abb. 04 kann die feinere Gesamtsicht ergänzen.

## 5. Datenqualität und Grenzen

1. **Stichprobe:** Die Kurven beziehen sich auf **383 Kreise**, nicht auf die vollständige Bundesrepublik. Die 17 ausgeschlossenen Kreise wurden wegen fehlender Einzelalter-Bevölkerungsnenner ausgeschlossen, nicht wegen vollständig fehlender COVID-19-Falltabellen. Die Selektionswirkung kann für regionale Analysen relevanter sein als für die hier betrachteten aggregierten Kurven.
2. **Quell-Leerwerte:** Historische SurvStat-Antworten enthalten leere Zellen, die `rsurvstat::get_timeseries()` lokal in **0** umgewandelt hat. Die genaue Bedeutung dieser leeren Quellwerte (z. B. kein Fall oder fehlender Wert) ist **nicht abschließend bestätigt**. Die technische Validierung beseitigt diese fachliche Unsicherheit nicht.
3. **Bevölkerungsstand:** Die abgeleiteten RKI-Nenner sind mit einer älteren, auf **Zensus 2011** beruhenden Bevölkerungsfortschreibung konsistent; die neueren Destatis-Zahlen für 2022/2023 beruhen teilweise auf der **Zensus-2022-Basis** und dürfen nicht ohne Prüfung gemischt werden. Von 29 fehlenden Nennern wurden 8 aus historisch passenden amtlichen Quellen validiert; diese Werte wurden **nicht** in die Produktionsdaten übernommen.
4. **Deskriptive Aussagegrenze:** Melde- und Testpraxis können sich im Zeitverlauf verändert haben. Unterschiedliche beobachtete Spitzen belegen weder Übertragungsrichtungen noch kausale Zusammenhänge.

## 6. Fazit und Vorschlag für die nächsten Schritte

Die **explorative Analyse der altersgruppenspezifischen Zeitentwicklung ist abgeschlossen**. Die **7er-Einteilung** bietet einen gut lesbaren Überblick; die **13er-Einteilung** zeigt zusätzliche **innerhalb breiter Gruppen verdeckte zeitliche Heterogenität**. Sie ist daher besonders für gezielte Detailanalysen wertvoll, aber nicht grundsätzlich in jeder Darstellung überlegen.

**Vorschlag für die Projektgruppe:** Das **7er-Schema für die Übersicht** und das **13er-Schema für ausgewählte Detailfragen** beibehalten. Vor dem nächsten Arbeitsschritt gemeinsam entscheiden, welche Gruppierung für regionale Vergleiche und die Untersuchung der **Strukturmerkmale** verwendet werden soll. Die 383-Kreis-Ergebnisse können für diese Woche als explorative Grundlage dienen; bei Analysen von Kreismerkmalen müssen fehlende Nenner und mögliche **Selektionsverzerrungen** gesondert behandelt werden.

**Offene Abstimmungspunkte:** (a) Verwendungszweck der beiden Altersgruppierungen; (b) 383 versus bis zu 400 Kreise in regionalen Analysen; (c) Klärung der SurvStat-Leerwerte mit dem Datenpartner.

---

**Nachvollziehbarkeit:** Detaillierte Methoden, Zahlen und Prüfprotokolle sind in Obsidian unter `F_Praktikum/KW_47/` dokumentiert: [[02_Altersgruppen_Aggregation_Validierung]], [[03_Zeitentwicklung_Altersgruppen_EDA]], [[04_Vertiefende_Zeitentwicklung_2022]], [[05_Fehlende_Bevoelkerungsnenner_Ursachenanalyse]], [[06_Bevoelkerungsdefinitionen_und_SurvStat_Leerwerte]], [[07_Einzelalter_Bevoelkerung_Quellenpruefung]]. Die zugehörigen R-Skripte liegen unter `Scripts/Altsgruppen_ZeitlicheEntwicklung/`.

*Hinweis zur KI-Nutzung: KI-Assistenz wurde für Strukturierung und sprachliche Ausarbeitung dieses Wochenberichts verwendet. Datenauswertung und technische Prüfungen erfolgten über lokal ausgeführte R-Skripte; die inhaltliche Verantwortung und abschließende Freigabe liegen bei der Projektgruppe.*
