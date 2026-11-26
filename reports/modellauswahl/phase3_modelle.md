# Phase 3: Erste Modelle je Welle × Altersgruppe (Stand 21.11.2026)

Skript: `Scripts/modellauswahl/12_models_wave_age.R` (Laufzeit ca. 7 s), Abbildungen `fig10`–`fig12` aus `Scripts/modellauswahl/11_figures.R`.
Ergebnisse: `results/modellauswahl/tables/model_nb_coef{,_fine}.csv` (Koeffizienten), `model_nb_fit{,_fine}.csv` (Anpassungsgüte, LR-Tests), `data_processed/modellauswahl/model_nb{,_fine}.rds`.

**Status: erster Entwurf, noch nicht mit Finn abgestimmt.** Alle Aussagen sind Zusammenhänge auf Kreisebene (ökologische Analyse). „Hauptmodell“ heißt in diesen Arbeitsnotizen: **Vorschlag**, in der Gruppe noch nicht entschieden (siehe [`Modellauswahl_Gesamtbericht.md`](Modellauswahl_Gesamtbericht.md)).

Übersicht: Teil 1 NB-Modelle je Welle × Altersgruppe (`12`); Teil 2 GAM mit Einzeljahren (`13`); Teil 3 grobes vs. feines Altersschema (`15`); Teil 4 räumliche Struktur (`16`); Teil 5 gemeinsames Modell aller Altersgruppen mit Kreis- und räumlichem Effekt (bis 24.11.2026 Hauptmodell, jetzt Sensitivität für den räumlichen Effekt), Test Kreistyp × Alter, Bundesland Fixed vs. Random, GEE (`17`); Teil 6 Dichte × Alter als Fläche, Kreistyp vs. Dichte (`18`); Teil 7 Kovariaten: PCA und Kreuzvalidierung (`19`); Teil 8 Ankunftszeit der Wellen: Kaplan-Meier und Cox (`20`); Teil 9 datengetriebene Kreistypologie: Clusteranalyse (`21`); Teil 10 **Hauptmodell** (seit 24.11.2026): gemeinsames Modell mit eigenem theta je Altersgruppe (`22`, glmmTMB). Zur Diskussion (25.11.2026): Teil 11 Option D, ein Modell über alle Wellen (`23`, glmmTMB); Teil 12 Option III, Hauptmodell mit räumlichem Kreis-Effekt (BYM2) und eigenem theta je Altersgruppe (`24`, INLA; seit 26.11.2026 seriell neu gerechnet); Teil 13 Kandidat A1 mit zwei Kreis-Faktoren (`25`, glmmTMB, 26.11.2026).

## Modell

Je Welle (W1–W8) und Altersgruppe (grob 7, fein 13) ein Negativbinomial-Modell auf die Fallzahlen der 400 Kreise, Offset = log(mittlere Bevölkerung der Phase). Referenz des Kreistyps: kreisfreie Großstadt. `exp(Koeffizient)` = Inzidenzverhältnis (IRR) gegenüber Großstädten bei gleichem Bundesland und gleichen Kovariaten.

| Modell | Formel (Prädiktoren) | Rolle |
|---|---|---|
| m0 | Kreistyp + Bundesland | nur Bundesland kontrolliert |
| **m1** | Kreistyp + Bundesland + SGB-II-Quote + Anteil 65+ + log(Übernachtungen je Einw.) | **Hauptmodell der getrennten Modelle** (Gesamt-Hauptmodell: Teil 5) |
| m1_nokt | m1 ohne Kreistyp | Likelihood-Ratio-Test des Raumtyps (3 Parameter) |
| m2 | log(Dichte) statt Kreistyp, sonst wie m1 | Robustheit (stetiges Raummaß) |
| m3 | m1 + BBSR-Lage | Zusatz |
| m1_gen | wie m1, Offset mit GENESIS-skalierter Bevölkerung | Sensitivität Nenner |

Kovariaten standardisiert (z-Werte über die 400 Kreise), Mittelwerte 2020–2023. Auswahl der Kovariaten: SGB-II-Quote und Arbeitslosenquote korrelieren mit ρ = 0,94, Anteil 65+ und Anteil 18–39 mit −0,83; je ein Vertreter. Tourismus als Merkmal mit geringer Korrelation zu den anderen. Das ist eine **vorläufige Auswahl**, keine begründete Modellselektion.
Standardfehler: modellbasiert; zusätzlich cluster-robust nach Bundesland (`se_cl`, nur 16 Cluster, daher mit Vorsicht).
Alle 56 (grob) bzw. 104 (fein) Zellen × 6 Spezifikationen konvergierten ohne Warnung. Ausgenommen ist die Warnung „non-integer x“, die seit der Verteilung der Fälle ohne Altersangabe (nicht ganzzahlige Fallzahlen) bei jeder Anpassung auftritt. Sie stammt nur aus der AIC-Berechnung des Poisson-Startfits von `glm.nb` und betrifft Koeffizienten, Theta und AIC des NB-Modells nicht (geprüft). Deshalb wird sie mit `quiet_nonint()` (`Scripts/modellauswahl/00_setup.R`) unterdrückt, damit die Spalte `warn` in `model_nb_fit*.csv` echte Probleme wieder anzeigt.

## Ergebnisse (Hauptmodell m1, grobes Schema, `fig10`)

IRR „dünn besiedelter ländlicher Kreis“ (Typ 4) gegenüber Großstadt, * = 95 %-KI ohne 1 (unkorrigiert):

- **W1:** niedriger, besonders 80+ (0,62*), 60–69 (0,72*), 18–39 (0,76*), 0–5 (0,70, nicht signifikant bei wenigen Fällen).
- **W2, W3:** bei Erwachsenen und Älteren höher (18–39: 1,13*; 80+: 1,32* in W2, 1,29* in W3).
- **W4:** 70–79 1,20*, 18–39 1,14*, übrige Gruppen ähnlich, aber teils nicht signifikant.
- **W5:** in allen Gruppen ab 6–17 höher (1,06*–1,15*); 0–5 niedriger (0,90*).
- **W6:** 0–5 deutlich niedriger (0,69*), 18–39 0,91*.
- **W7, W8:** meist um 1; 0–5 niedriger (0,82*, 0,80*).

Städtische Kreise (Typ 2) liegen meist näher bei den Großstädten (IRR 0,8–1,2).
Likelihood-Ratio-Test des Raumtyps insgesamt (p < 0,05 in x von 7 Altersgruppen): W3: 6, W5: 6, W1: 4, W6: 2, W2/W4/W7/W8: je 1. Bei 56 Tests wären rund 3 Treffer allein durch Zufall zu erwarten; W3 und W5 liegen deutlich darüber, die übrigen Wellen nicht.

**Dichte (m2, `fig12`):** je 1 SD log(Dichte) sinkt die Inzidenz in W2–W5 bei Erwachsenen und Älteren (IRR 0,83–0,97, z. B. W3 80+: 0,83*), und steigt bei 0–5 in W6 (1,12*) und W8 (1,08*). Das passt zum Muster beim Kreistyp.

**Kovariaten (m1, je 1 SD):** SGB-II-Quote: W1 < 1 (0,75–0,87 bei Erwachsenen), W2–W3 > 1 (1,04–1,16, am stärksten bei 6–17), in W4 nur noch bei Kindern (1,08–1,10), danach meist ≤ 1. Anteil 65+: meist um 1, leicht > 1 in W7/W8. Tourismus: W3 ≈ 0,91–0,93, sonst nahe 1.

## Robustheit (`fig11`)

- **Nenner:** GENESIS-skalierte Bevölkerung (m1_gen) ändert die log-IRR im Mittel um 0,002 (Maximum 0,016). Die Ergebnisse hängen praktisch nicht vom Nenner ab.
- **Standardfehler:** cluster-robust nach Bundesland im Median 2 % größer; der Anteil signifikanter Typ-4-Koeffizienten sinkt von 43 % auf 27 %.
- **Spezifikation (wichtig):** Die Schätzer reagieren auf die Adjustierung. Korrelation der Kreistyp-Koeffizienten m0 (nur Bundesland) vs. m1: 0,49, mittlere absolute Abweichung 0,094 (log-IRR). Mit zusätzlicher BBSR-Lage (m3) ändern sich einzelne Zellen stark (z. B. W3 80+: Typ 4 von 1,29 auf etwa 1,03), insgesamt Korrelation m1 vs. m3 0,93. Kreistyp, Lage und Dichte sind stark kollinear (|ρ| ≈ 0,8); Effekte des Kreistyps sind also **nicht scharf von Lage/Dichte trennbar**.
- **Modellvergleich (Summe der AIC über alle Zellen, nur grobe Orientierung):** m3 272.488 < m2 (Dichte) 272.523 < m1 272.624 < m1_nokt 272.707 < m0 273.454. Das stetige Raummaß (Dichte) passt besser als die vier Kreistypen; Kovariaten verbessern die Anpassung deutlich gegenüber m0.
- **Überdispersion:** θ klein in W1 (1,6–5,6), größer in W5 (29–157): die Streuung der Kreise ist in der ersten Welle am größten (auch wegen kleiner Fallzahlen: bei 0–5 in W1 haben 71 Kreise 0 Fälle).
- **Modelldiagnose** (`results/modellauswahl/tables/model_nb_diag{,_fine}.csv`, aus `12_models_wave_age.R`):
  - Die Pearson-Dispersion liegt in allen 56 Zellen bei 1,00–1,45 (Median 1,10, höchste Werte in W1); die NB-Varianz passt also im Wesentlichen.
  - Je Zelle haben im Median 4 Kreise ein |Pearson-Residuum| > 3.
  - Kein einzelner Kreis verschiebt beim Weglassen einen Kreistyp-Koeffizienten um mehr als 0,55 Standardfehler (feines Schema: 0,84). Am häufigsten am einflussreichsten sind Rostock, Greiz, Flensburg und Weimar.
  - Hamburg und Berlin bestimmen mit dem Bundesland-Effekt ihren eigenen Wert vollständig (Hebelwert 1) und tragen nichts zum Kreistyp-Effekt bei.
- **Räumliche Abhängigkeit:** siehe Teil 4. Die Residuen sind räumlich autokorreliert. Mit einem zusätzlichen räumlichen Effekt bleiben die Kreistyp-Effekte in Richtung und Größenordnung erhalten.

## Einschränkungen

- **Ökologisch:** Aussagen gelten für Kreise, nicht für Personen.
- **Räumliche Autokorrelation der Residuen** (Teil 4): Moran's I 0,07–0,45, in allen Zellen signifikant. Das Bundesland fängt nur den groben Teil ab, die modellbasierten Standardfehler sind daher eher zu klein. Ein Modell mit räumlichem MRF-Effekt beseitigt die Autokorrelation und bestätigt die Kreistyp-Effekte; im gemeinsamen Hauptmodell (Teil 5) ist dieser Effekt enthalten.
- **Multiples Testen:** Sterne sind nicht korrigiert; vorsichtig lesen, Muster über mehrere Wellen und Altersgruppen zählen mehr als einzelne Zellen.
- **Strukturmerkmale sind Mittelwerte 2020–2023**, nicht wellenspezifisch.
- **Gemeldete Inzidenz** hängt von Testumfang und Meldeverhalten ab (Teststrategie W1, Schultests W3–W5, Restphase 2023).
- **Stadtstaaten:** Hamburg, Berlin sind je ein Kreis, Bremen zwei; ihre Bundesland-Effekte sind nicht von Kreistyp 1 zu trennen.
- **Kleine Fallzahlen** in W1 bei den jüngeren Altersgruppen.
- Die Auswahl der Kovariaten ist vorläufig und nicht aus den Daten begründet.

## Nächste Schritte (Vorschlag)

1. Mit Finn klären: Kovariatensatz, ob Kreistyp, Dichte oder Lage das Hauptmaß ist (Dichte passt nach AIC besser), Umgang mit Kollinearität, Random Intercept statt Fixed Effect für das Bundesland.
2. Gemeinsames Modell mit Alter als glatter Funktion (GAM) je Welle, Wechselwirkung Raummaß × Alter. Dann Altersgruppen nicht vorab festlegen (Klimas Wunsch).
3. ~~Kreisgrenzen beschaffen, Residuen auf räumliche Autokorrelation prüfen, Karten~~ erledigt (21.11.2026, Teil 4). Offen: ob der räumliche Effekt ins Hauptmodell soll (mit Finn klären).
4. Wellenübergreifendes Modell (Wechselwirkung Welle × Raummaß) als Alternative zu getrennten Modellen.
5. Fehlende Kovariaten nachladen (73111 Einkommen, 33111 Bodennutzung, Zensus-Raster).

---

# Teil 2: GAM mit stetigem Alter (Einzeljahre 0–79)

Skript: `Scripts/modellauswahl/13_gam_age.R` (Laufzeit ca. 2 Minuten, mit Bootstrap `BOOT_B=100` ca. 20 Minuten, parallel über `BOOT_CORES`), Abbildungen `fig13` (Raumtyp × Alter) und `fig14` (Dichte × Alter).
Ergebnisse: `results/modellauswahl/tables/gam_age_curves.csv` (Kurven je Welle, Raumtyp und Alter), `gam_age_tests.csv`, `data_processed/modellauswahl/gam_age_curves.rds`, Basisdaten `data_processed/modellauswahl/covid_wave_age.rds` (Kreis × Einzelalter × Welle).

Klima wünscht ausdrücklich Ansätze ohne vorab festgelegte Altersgruppen; dieses Modell nutzt dazu die Einzeljahre.

## Modell

Je Welle ein Negativbinomial-GAM (`mgcv::bam`, fREML) auf 32.000 Zeilen (400 Kreise × 80 Einzeljahre):
`Fälle ~ Raumtyp + Alter (Faktor, 80 Stufen) + s(Alter, by = Raumtyp) + Bundesland + s(Alter, by = Bundesland) + s(Alter, by = SGB-II) + s(Alter, by = Anteil 65+) + s(Alter, by = Tourismus) + Kreis-Zufallsachsenabschnitt + Offset(log Bevölkerung)`.

- **Raumeffekt:** Referenz ist die Großstadt; die `by`-Glätter sind die Differenz zur Referenz. Damit ist der Raumeffekt eine **glatte Funktion des Alters**.
- **Dichte-Modell:** ersetzt den Kreistyp durch log(Dichte) (standardisiert, „je 1 SD“) mit `s(Alter, by = log(Dichte))`, ohne zusätzlichen linearen Dichte-Term (siehe Änderung 21.11. unten).
- **Nicht modelliert:** 80+ ist in den Daten eine Sammelgruppe (siehe Gruppenmodelle in Teil 1).
- **Alters-Haupteffekt:** beschreibt nur das bundesweite Altersprofil (Störparameter) und ist als Faktor ohne Glättung modelliert.
- **Basisdimensionen:** 15 für die Raumeffekt-Glätter, 8 für die Bundesland- und Kovariaten-Glätter (`GAM_COV` in `Scripts/modellauswahl/00_setup.R`, gemeinsam mit Teil 6).

**Änderung 24.11.2026 (Adjustierung wie im Hauptmodell, Teil 10):**
- **Vorher** wirkten Bundesland und Kovariaten in allen Altersjahren gleich. Im Hauptmodell und in den Gruppenmodellen (Teil 1, 5, 10) sind sie dagegen altersspezifisch. Altersspezifische Unterschiede zwischen den Ländern (z. B. Schultests) konnten so in die Raumtyp-Kurven geraten.
- **Jetzt:**
  - Bundesland als Fixed Effect plus eine glatte, je Land zentrierte Abweichung über das Alter;
  - jede Kovariate mit glatt altersabhängiger Steigung. Ein numerischer `by`-Glätter enthält den linearen Effekt schon, daher steht kein zusätzliches z_* im Modell.
- **Wirkung auf die Kurven:**
  - Die Raumtyp-Kurven ändern sich deutlich (Typ 4: mittlere |Änderung| 0,059, maximal 0,33 log-IRR; Korrelation alt/neu 0,77–0,82).
  - Sie stimmen jetzt viel besser mit den Gruppenmodellen und dem Hauptmodell überein (siehe Robustheit).

**Änderung 21.11.2026 (Modellspezifikation, technisch):**
- **Alters-Haupteffekt als Faktor statt `s(Alter, k = 25)`:**
  - Der Glätter war ausgeschöpft (edf 23–24 von 24; mit k = 40 bzw. 60 stieg die edf auf 35 bzw. 54), und das Altersprofil hat Sprünge (z. B. an Schulaltersgrenzen).
  - Als Faktor ist das AIC deutlich besser (z. B. W5 um ca. 2.600). Die Raumeffekt-Kurven ändern sich dabei um höchstens 0,003 (log-IRR, im Mittel 0,0005).
- **Dichte-Modell ohne separaten Term `z_ld`:**
  - Ein Glätter mit numerischer `by`-Variable wird in `mgcv` nicht zentriert und enthält den linearen Dichte-Effekt bereits. Der zusätzliche Term war doppelt (nicht identifizierbar), wodurch die edf im Wald-Test je nach Rechenweg um genau 1 sprang.
  - Ohne den Term sind Kurven und AIC identisch und die Testgrößen stabil.

Der Kreis-Zufallsachsenabschnitt fängt ab, dass die Einzeljahre eines Kreises nicht unabhängig sind. Vergleichsmodelle: konstanter Raumeffekt über das Alter, GENESIS-Nenner.

## Ergebnisse (Typ 4 „dünn besiedelt“ gegenüber Großstadt, `fig13`)

Werte aus `gam_age_curves.csv`, Stand 24.11.2026 (altersspezifische Adjustierung). „KI ohne 1“ = punktweises 95 %-KI, modellbasiert bzw. Bootstrap, unkorrigiert.

| Welle | Alter 0 | 10 | 20 | 30 | 40 | 60 | 79 | KI ohne 1 (modellbasiert) | KI ohne 1 (Bootstrap) |
|---|---|---|---|---|---|---|---|---|---|
| W1 | 0,74 | 0,77 | 0,79 | 0,79 | 0,80 | 0,82 | 0,90 | niedriger bei 54 Altersjahren (0–53) | niedriger bei 24 (0–40) |
| W2 | 0,99 | 0,89 | 1,06 | 1,13 | 1,14 | 1,14 | 1,21 | höher bei 47 (29–79) | höher bei 14 (33–79) |
| W3 | 0,94 | 0,95 | 1,15 | 1,18 | 1,13 | 1,14 | 1,30 | höher bei 41 (19–79) | höher bei 12 (28–79) |
| W4 | 0,94 | 1,00 | 1,15 | 1,19 | 1,13 | 1,07 | 1,15 | höher bei 25 (16–78) | höher bei 32 (15–79) |
| W5 | 0,81 | 1,03 | 1,14 | 1,07 | 1,06 | 1,13 | 1,15 | höher bei 64 (12–79), niedriger bei 5 (0–4) | höher bei 63 (12–79), niedriger bei 3 (0–2) |
| W6 | 0,60 | 0,84 | 1,00 | 0,88 | 0,92 | 1,00 | 0,97 | niedriger bei 32 (0–40) | niedriger bei 33 (0–42) |
| W7 | 0,73 | 0,98 | 1,11 | 0,95 | 1,00 | 1,04 | 1,02 | niedriger bei 6 (0–5), höher bei 5 (17–21) | niedriger bei 5 (0–4), höher bei 3 (19–21) |
| W8 | 0,74 | 0,91 | 1,08 | 0,92 | 0,95 | 0,93 | 0,94 | niedriger bei 15 (zwischen 0 und 67) | niedriger bei 15 (zwischen 0 und 69) |

**Beschreibung der Kurven:**
- **W1:** In ländlichen Kreisen über fast alle Altersjahre niedriger (0,74–0,90), ohne deutliche Altersabhängigkeit (siehe Tests unten).
- **W2–W4:** Bei Kindern um 10 Jahre etwa 0,89–1,00, bei Erwachsenen darüber (1,13–1,19 bei 30–40 Jahren) und bei den Ältesten 1,15–1,30.
- **W5:** Bei den Jüngsten niedriger (Alter 0: 0,81), ab etwa 12 Jahren leicht höher (1,03–1,15).
- **W6–W8:** Bei den Jüngsten deutlich niedriger (Alter 0: 0,60–0,74), Erwachsene nahe 1.
- **Gegenüber der früheren Fassung** sind vor allem die niedrigen Werte der kleinen Kinder ab W5 neu (vorher Alter 0 in W5/W7/W8 bei 1,00–1,03). Sie passen jetzt zu den Gruppenmodellen und zum Hauptmodell (0–5: 0,69–0,90).

**Dichte (`fig14`, IRR je 1 SD log(Dichte)):**
- W1: bei den Jüngsten 1,12, bei 79 Jahren 0,98;
- W2–W4: bei Kindern um 10 Jahre 1,01–1,05, bei 79 Jahren 0,87–0,93;
- W6–W8: bei den Jüngsten 1,14–1,21 (in dichten Kreisen höher), bei Älteren 1,00–1,05.

**Variiert der Effekt mit dem Alter?**
- **W2–W8: ja.** Wald-Test der `by`-Glätter p ≈ 0 (näherungsweise); das AIC des Modells mit altersabhängigem Raumeffekt ist um 260 (W8) bis 1.073 (W5) besser als das mit konstantem Effekt.
- **W1: kaum.** Typ 2 p = 0,10 (edf 1,0, also linear), Typ 3 p = 0,006, Typ 4 p = 0,098; ΔAIC nur 12. Das passt zum Hauptmodell (W1: Wald-Test p = 0,72).
- **Früher** lag der AIC-Vorteil bei 176–1.508. Ein Teil der scheinbaren Altersabhängigkeit kam also aus altersspezifischen Länderunterschieden.

## Robustheit und Plausibilität

- **Vergleich mit Gruppen- und Hauptmodell:** Man mittelt die GAM-Kurven über die Altersjahre einer Gruppe (0–79, 144 Zellen):
  - gegenüber den NB-Gruppenschätzern aus Teil 1 (m1): r = 0,90, mittlere absolute Abweichung 0,026, Maximum 0,24;
  - gegenüber dem Hauptmodell (Teil 10): r = 0,93, 0,021, 0,22;
  - vor der Änderung vom 24.11.: r = 0,70 bzw. 0,74.

  Die frühere mäßige Übereinstimmung lag also vor allem an der nicht altersspezifischen Adjustierung.
- **Bootstrap** (100 Wiederholungen, Kreise innerhalb der Bundesländer neu gezogen; Spalten `se_b`, `lo_b`, `hi_b`):
  - Die modellbasierten Standardfehler sind zu klein. Verhältnis Bootstrap/Modell: Typ 2 1,09, Typ 3 1,14, Typ 4 1,14, Dichte 1,10; je Welle bei Typ 4 0,93–1,26, am größten in W1–W3 (1,23–1,26).
  - Das Signifikanzurteil stimmt bei 91 % der Punkte überein (Typ 4: 82 %).
  - Bei Typ 4 sinkt die Zahl der Altersjahre mit KI ohne 1 nach Bootstrap deutlich in W1 (24 statt 54), W2 (14 statt 47) und W3 (12 statt 41).
  - Vermutung (nicht geprüft): Die Länder-Glätter machen die Schätzung bei Ländern mit wenigen Kreisen empfindlich für das Neuziehen.
  - **Für Aussagen über Altersbereiche die Bootstrap-Bänder verwenden;** die Bänder in `fig13`/`fig14` sind modellbasiert.
- **GENESIS-Nenner:** mittlere Abweichung ≤ 0,007 (Maximum 0,024) in W5–W8; W1–W4 sind identisch, weil RKI und GENESIS dort übereinstimmen.
- **Glättungsdimension** (geprüft am 21.11. mit der früheren Spezifikation): Mit kleinerer Basisdimension ändern sich die Kurven im Mittel um 0,007–0,014 (log-IRR).
- **Alters-Haupteffekt:** Faktor statt Glätter ändert die Kurven um höchstens 0,003 (log-IRR).

## Einschränkungen

- **Flexible Kurven:** Die Differenzglätter nutzen in W2–W8 einen großen Teil der Basisdimension (edf 9,5–13,5 von 14 beim Kreistyp; Dichte 10,4–14,7 von 15). An den Rändern (Alter 0 und 79) sind die Schätzer unsicher.
- **Daten:** 80+ fehlt (Sammelgruppe); Einzeljahre können Melde- oder Rundungsartefakte enthalten.
- **Interpretation:** Alles bleibt ökologisch (Kreisebene) und beschreibt Zusammenhänge, keine Ursachen. Sterne bzw. punktweise Bänder sind nicht für multiples Testen korrigiert.
- **Kovariaten:** dieselben vorläufigen wie in Teil 1, Mittelwerte 2020–2023. Die Kollinearität von Kreistyp, Lage und Dichte (Teil 1) gilt auch hier.
- **Dispersion:** ein gemeinsames θ über alle Altersjahre (vgl. Teil 10: Die Dispersion unterscheidet sich zwischen Altersgruppen) – ein weiterer Grund für die Bootstrap-Bänder.
- **Räumliche Struktur:** Der GAM enthält einen unabhängigen Kreis-Zufallseffekt, aber keinen räumlich strukturierten. Die Residuen der Gruppenmodelle sind räumlich autokorreliert (Teil 4); für den GAM ist das nicht eigens geprüft.

---

# Teil 3: Grobes vs. feines Altersschema (Stand 21.11.2026)

Skript: `Scripts/modellauswahl/15_compare_schemes.R` (liest nur die fertigen Tabellen aus 09 und 12, keine neue Schätzung), Abbildung `fig15_altersschema_grob_fein.png`.
Ergebnisse: `results/modellauswahl/tables/scheme_compare_model.csv` (je feiner Gruppe mit zugehöriger grober Gruppe), `scheme_compare_summary.csv` (je Welle × grober Gruppe × Kreistyp-Term), `scheme_compare_descr.csv` (deskriptive Verhältnisse aus 09).

Klima wollte beide Schemata rechnen und am Ende vergleichen. Die feinen Gruppen sind Teilmengen der groben:
- 0–5 = 0–2 + 3–5;
- 6–17 = 6–9 + 10–14 + 15–17;
- 18–39 = 18–24 + 25–29 + 30–39;
- 40–59 = 40–49 + 50–59;
- 60–69, 70–79 und 80+ sind in beiden Schemata gleich. Als Kontrolle sind ihre 72 Koeffizienten identisch.

Verglichen werden die Kreistyp-Effekte (T2, T3, T4 gegenüber Großstadt) des Hauptmodells m1. Es gibt 96 Zellen: 8 Wellen × 4 geteilte Gruppen × 3 Terme.

## Ergebnisse

- **Keine Heterogenität zwischen den Untergruppen:** Der Cochran-Q-Test auf Unterschiede der feinen Schätzer innerhalb einer groben Gruppe ist in **0 von 96 Zellen** signifikant (p < 0,05). Bei reinem Zufall wären etwa 5 zu erwarten; der kleinste p-Wert ist 0,07 (W5). Der Test behandelt die Untergruppen als unabhängig. Da sie aus denselben 400 Kreisen stammen und positiv korreliert sind, ist er eher konservativ.
- **Gleiche Richtung:** In keiner Zelle ist eine Untergruppe signifikant in die Gegenrichtung des groben Schätzers. Das nach Präzision gewichtete Mittel der Untergruppen korreliert mit dem groben Schätzer mit r = 0,996.
- **Spanne innerhalb einer groben Gruppe:** Die Spanne der feinen log-IRR liegt im Median bei 0,057, maximal bei 0,42. Am größten ist sie bei 6–17 in W1 (Typ 4: 0,84–1,28), wo die Fallzahlen klein sind.
- **„Verdeckt“:** In 8 Zellen ist der grobe Schätzer nicht signifikant, aber eine Untergruppe knapp signifikant, z. B. W6 6–17 Typ 3: grob 0,93, fein 0,83–0,97. Das sind Grenzfälle mit gleicher Richtung, keine anderen Muster.
- **„Verdünnt“:** Dass der grobe Schätzer signifikant ist, aber keine Untergruppe, kommt nicht vor. Beim LR-Test des Raumtyps insgesamt ist das Bild ähnlich: grob signifikant und mindestens eine Untergruppe signifikant in 13 Zellen, beides nicht signifikant in 17. Nur in 2 Zellen ist grob nicht signifikant, aber eine Untergruppe signifikant.
- **Deskriptiv:** Das Verhältnis Kreistyp/Bundeswert wechselt in 20 von 128 Zellen innerhalb einer groben Gruppe die Seite von 1. Fast immer liegen die Werte dabei nahe 1. Die größten Abweichungen gibt es in W1, z. B. Typ 4 bei 18–39: grob 0,82, fein 0,76 (30–39) bis 0,91 (18–24).

## Folgerung

Das feine Schema ändert die Aussagen nicht. Die groben Gruppen fassen Untergruppen mit gleich gerichteten, statistisch nicht unterscheidbaren Raumeffekten zusammen. Für die Hauptdarstellung reicht deshalb das **grobe Schema**: Die Schätzer sind genauer, und es sind weniger Tests nötig. Das feine Schema bleibt eine Robustheitsprüfung im Anhang. Die feinere Altersauflösung zeigt ohnehin der GAM (Teil 2) mit Einzeljahren.

Einschränkungen: Der Q-Test ist konservativ, und in W1 ist die Teststärke wegen kleiner Fallzahlen gering. Auch ein nicht signifikanter Test beweist nicht, dass die Effekte gleich sind.

---

# Teil 4: Räumliche Struktur (Stand 21.11.2026)

Skript: `Scripts/modellauswahl/16_spatial.R` (ca. 50 s). Abbildungen:
- `fig16_karte_kreistyp.png`: BBSR-Kreistyp;
- `fig17_karte_inzidenz_welle.png`: kumulative Inzidenz relativ zum Bundeswert je Welle;
- `fig18_moran_autokorrelation.png`.

Ergebnisse:
- `results/modellauswahl/tables/spatial_moran.csv`: Moran's I je Welle × Altersgruppe;
- `results/modellauswahl/tables/spatial_model_coef.csv`: Kreistyp-Effekte m1 vs. m1 + MRF;
- Geometrie `data_processed/modellauswahl/kreis_geo.rds` und Nachbarschaft `data_processed/modellauswahl/kreis_nb.rds`.

## Daten und Methode

- **Kreisgrenzen:** `data_geo/landkreise_simplify200.geojson` aus dem Gruppen-Repository (`YuechenWang331/LMU_Fortgeschrittenes_Praxisprojekt_WS2627`, `data_geo/`).
  - Abgeleitet von BKG VG250 (© GeoBasis-DE / BKG, Daten verändert) und vereinfacht.
  - Verwendet werden nur Landflächen (`GF = 4`). Die 400 Kreise stimmen genau mit `kreis_key.rds` überein.
- **Nachbarschaft:** Kreise mit gemeinsamer Grenze. Weil sich die vereinfachten Grenzen nicht exakt berühren, gelten Flächen als benachbart, die sich nach 100 m Puffer schneiden.
  - Ergebnis: 1–12 Nachbarn, Median 5.
  - Kontrolle: Mit 50 m Puffer ändert sich die Nachbarzahl bei 2 Kreisen, mit 500 m bei 23.
  - Die Gewichte sind zeilenstandardisiert.
- **Moran's I:** Permutationstest mit 999 Permutationen. Geprüft werden (a) die log kumulative Inzidenz und (b) die Pearson-Residuen des Hauptmodells m1, je Welle × grobe Altersgruppe (56 Zellen).
- **Sensitivitätsmodell m1 + MRF:**
  - Hauptmodell plus ein Markov-Random-Field-Effekt über die Kreis-Nachbarschaft (`mgcv`, `bs = "mrf"`, Rang 100, NB, REML).
  - Der Effekt nimmt glatte Unterschiede zwischen Nachbarkreisen auf, die Bundesland und Kovariaten nicht erklären (edf 27–78).

## Ergebnisse

- **Die Inzidenz ist stark räumlich geclustert:** Moran's I 0,28–0,88 (Median 0,62), in allen 56 Zellen signifikant. Am stärksten ist das Clustering in W4 (Median 0,83; Ost-Süd-Muster in `fig17`), am schwächsten in W7 (0,41).
- **Auch die Residuen von m1 sind autokorreliert:** I = 0,07–0,45 (Median 0,20), alle 56 Zellen signifikant. Bundesland und Kovariaten erklären also nur einen Teil der räumlichen Struktur; am meisten bleibt in W4 übrig (bis 0,45 bei 40–59). Folge: Die modellbasierten Standardfehler und Sterne in Teil 1 sind eher zu optimistisch.
- **Mit MRF-Effekt verschwindet die Autokorrelation:** I = −0,07–0,06, 1 von 56 Zellen knapp signifikant.
- **Die Kreistyp-Effekte bleiben stabil:**
  - Die log-IRR von m1 und m1 + MRF korrelieren mit r = 0,954; die mittlere absolute Differenz ist 0,033, das Maximum 0,15 (W1 80+, Typ 3: 0,63 → 0,73).
  - Kein signifikanter Koeffizient wechselt das Vorzeichen; die Standardfehler sind im Median 3 % größer.
  - Signifikant (95 %, unkorrigiert) sind 54 von 168 Koeffizienten in m1 und 63 mit MRF (Typ 4: 24 → 32).
  - Mit MRF werden die Effekte „ländlich höher“ in W2–W4 eher etwas stärker, z. B. W3 70–79, Typ 4: 1,13 → 1,27. Das spricht dagegen, dass sie nur ein Artefakt räumlicher Cluster sind.

## Einordnung und Einschränkungen

- Der Kreistyp ist selbst räumlich strukturiert (`fig16`). Ein räumlicher Effekt kann deshalb einen Teil des Kreistyp-Effekts aufnehmen oder verschieben (räumliche Konfundierung). Für die getrennten Modelle ist die MRF-Version darum eine **Sensitivitätsanalyse**. Im gemeinsamen Hauptmodell (Teil 5) ist der räumliche Effekt seit 21.11.2026 enthalten; dort werden die Kreistyp-Effekte mit ihm eher größer.
- Entscheidung 21.11.2026: Der räumliche Effekt ist Teil des gemeinsamen Hauptmodells (Teil 5); mit Finn noch abzustimmen.
- Die Vereinfachung der Grenzen kann einzelne Nachbarschaften an Grenzpunkten falsch setzen. Die Kontrolle mit 50 m und 500 m Puffer zeigt nur geringe Unterschiede.
- Geprüft wurde nur das grobe Schema; für den GAM (Teil 2) ist die räumliche Autokorrelation nicht eigens geprüft.

---

# Teil 5: Gemeinsames Modell aller Altersgruppen mit räumlichem Effekt (Stand 21.11.2026; seit 24.11.2026 Sensitivitätsanalyse, Hauptmodell siehe Teil 10)

Skript: `Scripts/modellauswahl/17_joint_age_models.R` (ca. 55 s), Abbildung `fig19_gemeinsames_modell_kreistyp_alter.png`.
Ergebnisse: `results/modellauswahl/tables/joint_kt_coef.csv` (Kreistyp-Effekte je Altersgruppe für `int`, `int_re`, `int_nosp` und `gee`, mit den Schätzern der getrennten Modelle) und `joint_tests.csv`.
Methodisch:
- Statistik V „Gemischte Modelle“ (GLMM, cAIC), geoadditive Modelle (räumlicher Effekt) und marginale Modelle (GEE);
- Lineare Modelle Kap. 6 (Interaktionen) und Kap. 9 (gemischtes Modell).

**Änderung 21.11.2026:** Das Hauptmodell enthält jetzt einen räumlichen Effekt (Nachbarkreise). Das frühere Modell ohne diesen Effekt läuft als `int_nosp` weiter mit; seine Ergebnisse sind unverändert.

**Änderung 24.11.2026:** Dieses Modell hat ein gemeinsames θ für alle Altersgruppen, die Dispersion unterscheidet sich aber stark zwischen den Altersgruppen (Teil 10). Hauptmodell ist deshalb jetzt Teil 10 (`22_main_model_tmb.R`); dieses Modell bleibt die Sensitivitätsanalyse für den räumlichen Effekt. Die Aussage unten „W2–W8 auch nach Bonferroni signifikant“ gilt mit eigenem θ je Altersgruppe nicht mehr für W7 und W8 (Teil 10).

## Warum

In Teil 1 hat jede Welle × Altersgruppe ein eigenes Modell. Ob sich der Kreistyp-Effekt **zwischen Altersgruppen unterscheidet**, das Kernstück der Fragestellung, lässt sich dort nicht testen, weil dieselben 400 Kreise in allen Altersgruppen vorkommen und die Schätzer deshalb abhängig sind.

## Modell

Je Welle ein NB-Modell mit allen 7 Altersgruppen (2.800 Zeilen):
`cases ~ Altersgruppe + Altersgruppe:Kreistyp + Altersgruppe:Bundesland + Altersgruppe:(SGB-II + 65+ + Tourismus) + (1 | Kreis) + räumlicher Kreis-Effekt + offset(log Bevölkerung)`.

- **Kreistyp, Bundesland und Kovariaten** wirken altersspezifisch, wie in den getrennten Modellen.
- **Die Abhängigkeit wird auf drei Ebenen modelliert:**
  1. **Altersgruppen desselben Kreises:** unstrukturierter Kreis-Zufallseffekt (`s(ags, bs = "re")`), z. B. für Testen oder lokale Ausbrüche.
  2. **Kreise desselben Landes:** Bundesland.
  3. **Nachbarkreise:** Markov-Random-Field über die Kreis-Nachbarschaft aus Teil 4 (`s(ags_m, bs = "mrf")`, Rang 100).

  Der Kreis-Effekt wird damit in einen räumlich strukturierten und einen unstrukturierten Teil zerlegt (BYM-artig).
- **Schätzung:** mit `mgcv` (`bam`, REML), ein gemeinsames θ. Kontrolle in W4 (ohne MRF): Eine ML-Schätzung mit `gam` ergibt die Kreistyp-Koeffizienten bis auf 0,002 gleich.
- **Rang des MRF:** Rang 100, 200 und 399 (voll) ändern die Kreistyp-Koeffizienten um höchstens 0,03, das AIC um weniger als 5 und den Wald-Test nicht (geprüft für W2, W6–W8). Der volle Rang überkorrigiert teilweise (W2: Moran's I = −0,11).
- **Vergleichsmodelle:**
  - `const`: ein Kreistyp-Effekt für alle Altersgruppen;
  - `int_re`: Bundesland als Zufallseffekt (Land + Land × Altersgruppe) statt Fixed Effect;
  - `int_nosp`: ohne räumlichen Effekt;
  - `gee`: GEE (siehe unten).
- **Tests:**
  - Wald-Test „Kreistyp-Effekt in allen Altersgruppen gleich“ mit 3 Typen × 6 Differenzen = 18 Kontrasten;
  - konditionales AIC von `mgcv` (entspricht dem cAIC aus der Vorlesung);
  - Moran's I der Kreis-Residuen (Pearson-Residuen je Kreis über die Altersgruppen gemittelt; Permutationstest).

## Ergebnisse

| Welle | Wald-Test (df 18) p | nur Typ 4 (df 6) p | ΔAIC const − int | ΔAIC Land RE − FE | ΔAIC ohne − mit MRF | Moran's I Kreis-Residuen mit / ohne MRF | θ | SD Kreis-Effekt |
|---|---|---|---|---|---|---|---|---|
| W1 | 0,27 | 0,23 | −15,1 | −43,6 | 6,0 | 0,02 / 0,14* | 18 | 0,38 |
| W2 | 5·10⁻⁷ | 1·10⁻⁹ | 26,4 | −16,1 | 6,4 | 0,01 / 0,22* | 55 | 0,19 |
| W3 | 3·10⁻¹³ | 6·10⁻⁷ | 60,7 | −17,0 | 2,7 | 0,04 / 0,15* | 84 | 0,21 |
| W4 | 2·10⁻⁵ | 3·10⁻⁴ | 17,5 | −15,3 | 8,7 | −0,02 / 0,17* | 106 | 0,16 |
| W5 | 1·10⁻¹⁶ | 5·10⁻²¹ | 79,0 | −11,0 | 4,2 | 0,02 / 0,21* | 193 | 0,08 |
| W6 | 2·10⁻³⁰ | 2·10⁻³³ | 146,6 | −6,2 | 2,3 | 0,10* / 0,22* | 183 | 0,14 |
| W7 | 2·10⁻⁷ | 1·10⁻⁹ | 29,3 | −6,6 | 0,9 | 0,09* / 0,14* | 199 | 0,14 |
| W8 | 0,002 | 0,003 | 3,7 | −5,1 | 3,6 | 0,09* / 0,20* | 112 | 0,16 |

Lesart:
- ΔAIC const − int > 0: Das Modell mit altersspezifischem Kreistyp-Effekt passt besser.
- ΔAIC Land RE − FE < 0: Bundesland als Zufallseffekt passt besser.
- ΔAIC ohne − mit MRF > 0: Der räumliche Effekt verbessert das Modell.
- \*: Permutationstest p < 0,05.

**Räumliche Abhängigkeit (Unabhängigkeitsannahme):**
- Ohne räumlichen Effekt sind die Kreis-Residuen in allen Wellen autokorreliert (I = 0,14–0,22).
- Mit MRF verschwindet das in W1–W5 (I = −0,02 bis 0,04, nicht signifikant); in W6–W8 bleibt ein kleiner Rest (I ≈ 0,1).
- Das konditionale AIC bevorzugt in allen Wellen das Modell mit MRF.
- Die Annahme „Beobachtungen bedingt auf das Modell unabhängig“ ist damit weitgehend erfüllt.

**Ergebnisse zur Fragestellung:**
- **Der Kreistyp-Effekt unterscheidet sich in W2–W8 deutlich zwischen den Altersgruppen.**
  - Das gilt auch nach Bonferroni über 8 Wellen (0,05/8 = 0,006), und das AIC bevorzugt das Interaktionsmodell.
  - Nur in W1 gibt es keinen Hinweis darauf (p = 0,27, AIC für den konstanten Effekt). Dort sind die Fallzahlen klein und die Kreis-Streuung groß (SD 0,38).
  - Mit und ohne räumlichen Effekt sind die p-Werte praktisch gleich.
- **Muster** (`fig19`, Typ 4 gegenüber Großstadt):
  - Bei 0–5 liegen ländliche Kreise in W1 (0,59) und ab W5 (0,68–0,89) niedriger.
  - Bei Erwachsenen und Älteren liegen sie in W2–W5 höher, z. B. 80+ in W2 1,41 und in W3 1,47; 70–79 in W4 1,27.
  - In W6–W8 liegen die Erwachsenen nahe 1.
  - Der Unterschied zwischen den Altersgruppen kommt also vor allem von **kleinen Kindern gegenüber Erwachsenen** und von den **Älteren in W2–W4**.
- **Robustheit der Kreistyp-Effekte** (log-IRR, 168 Koeffizienten; Vergleich mit dem Hauptmodell):

  | Vergleich | Korrelation | mittlere \|Differenz\| | SE-Verhältnis |
  |---|---|---|---|
  | getrennte Modelle (Teil 1) | 0,93 | 0,042 | 1,01 |
  | ohne räumlichen Effekt | 0,97 | 0,033 | 1,01 |
  | Bundesland als Random Effect | 0,99 | 0,015 | 1,00 |
  | GEE | 0,83 | 0,058 | 1,09 |

  - Mit räumlichem Effekt werden die Effekte „ländlich höher“ in W2–W4 eher größer.
  - Signifikant (95 %, unkorrigiert) sind 75 von 168 Koeffizienten mit MRF und 55 ohne.
  - Der räumliche Effekt nimmt dem Kreistyp also keinen Effekt weg; Anzeichen für räumliche Konfundierung gibt es nicht.
- **Bundesland Fixed vs. Random Effect (offene Frage an Finn):** Die Kreistyp-Effekte sind praktisch gleich. Das konditionale AIC bevorzugt in allen Wellen den Random Effect (−5 bis −44). **Für die Kreistyp-Effekte ist die Wahl also unkritisch**; der Random Effect ist sparsamer (105 Parameter weniger).
- **GEE als marginale Alternative** (Statistik V, marginale Modelle/GEE):
  - **Umsetzung:**
    - gleicher Prädiktor ohne Zufallseffekte, Quasi-Poisson;
    - Arbeitskorrelation „unabhängig“ mit robuster Sandwich-Kovarianz, geclustert nach Kreis (`sandwich::vcovCL`);
    - eine austauschbare Arbeitskorrelation bräuchte `geepack` (nicht installiert).
  - **Ergebnis:** Der Wald-Test ergibt in W2–W8 p ≤ 0,006, in W1 p = 0,30. Die Aussage hängt also weder an der Annahme normalverteilter Zufallseffekte noch an der NB-Verteilung. Quasi-Poisson gewichtet große Kreise stärker, daher weichen die Schätzer etwas ab.

## Wie die Abhängigkeit insgesamt abgesichert ist

Fünf verschiedene Arten, abhängige Beobachtungen zu behandeln, führen zum gleichen Ergebnis: Kreistyp × Altersgruppe ist in W2–W8 signifikant, in W1 nicht; die Richtung der Effekte ist gleich.

1. GLMM mit Kreis-Effekt und MRF (Hauptmodell);
2. GLMM ohne MRF;
3. GEE mit robusten Standardfehlern (Cluster Kreis);
4. getrennte Modelle mit cluster-robusten Standardfehlern nach Bundesland (Teil 1);
5. Kreis-Bootstrap im GAM (Teil 2).

## Einschränkungen

- **Ein gemeinsames θ für alle Altersgruppen:** In den getrennten Modellen ist die Überdispersion je Altersgruppe verschieden (Teil 1). Der Kreis-Effekt fängt einen Teil davon auf.
- **Restliche Autokorrelation in W6–W8 (I ≈ 0,1):** Der räumliche Effekt ist für alle Altersgruppen gleich. Altersspezifische räumliche Muster nimmt er nicht auf; auch ein größerer Rang beseitigt den Rest nicht.
- **Räumliche Konfundierung:** Der Kreistyp ist selbst räumlich geklumpt (`fig16`). Ein räumlicher Effekt kann grundsätzlich einen Teil seines Effekts aufnehmen; hier werden die Effekte mit MRF aber eher größer.
- **Ökologische Analyse:** Alle Aussagen gelten für Kreise.

---

# Teil 6: Bevölkerungsdichte × Alter als glatte Fläche (Stand 24.11.2026)

Skript: `Scripts/modellauswahl/18_gam_age_density.R` (ca. 2 Minuten). Abbildungen:
- `fig20_gam_dichte_alter_flaeche.png`: Fläche;
- `fig21_gam_dichte_kontrast.png`: dichter vs. dünner Kreis je Altersjahr.

Ergebnisse: `results/modellauswahl/tables/gam_surface_grid.csv`, `gam_surface_contrast.csv` und `gam_surface_tests.csv`.
Methodisch: Statistik V Tensorprodukt-Glätter („Glättung in z1- und z2-Richtung“).

**Änderung 24.11.2026:** Die Adjustierung ist jetzt altersspezifisch wie in Teil 2 (`GAM_COV`): Bundesland und Kovariaten mit glatten Altersverläufen. Die Ergebnisse unten sind neu berechnet; einige Aussagen der Fassung vom 21.11. gelten nicht mehr (siehe „Kreistyp vs. lineare Dichte“).

## Modell

Gleiche Daten und Kovariaten wie Teil 2 (Kreis × Einzelalter 0–79, NB, Kreis-Zufallseffekt). Verglichen werden drei Modelle:

| Modell | Raumterm | Annahme |
|---|---|---|
| `kt` (wie fig13) | `ktO + s(Alter, by = ktO)` | vier Kreistypen, Effekt glatt im Alter |
| `dens` (wie fig14) | `s(Alter, by = log-Dichte)` | linear in log-Dichte, Steigung glatt im Alter |
| `surf` | `s(log-Dichte) + ti(Alter, log-Dichte)` | beliebige glatte Fläche über Alter und Dichte |

Die Basisdimension des Tensors ist 15 × 8. Die edf steigen mit k weiter (wie beim früheren Alters-Haupteffekt). Die Kontrastkurve änderte sich von 15 × 8 auf 20 × 10 aber nur um bis zu 0,026 (log-IRR; geprüft am 21.11. mit der früheren Adjustierung).

## Ergebnisse

- **Das konditionale AIC bevorzugt in allen Wellen die Fläche:**
  - gegenüber dem linearen Dichtemodell um 18 (W1) bis 593 (W5);
  - gegenüber dem Kreistyp-Modell um 48 (W1) bis 487 (W5).

  Vorher waren es 98–1.406 bzw. 40–1.242; ein Teil des früheren Vorteils kam aus nicht altersspezifisch adjustierten Länderunterschieden.
- **Kreistyp vs. lineare Dichte – uneinheitlich:**
  - Die lineare Dichte passt besser in W1, W3, W6, W7 und W8 (ΔAIC 26–82).
  - Der Kreistyp passt besser in W2, W4 und W5 (46–106).
  - In der Fassung vom 21.11. passte der Kreistyp in W1–W6 besser. Diese Aussage gilt nicht mehr.
- **Woher der Vorteil der Fläche kommt:**
  - Der Dichte-Haupteffekt ist nahezu linear (edf 1,0–2,7). Die Wechselwirkung mit dem Alter ist flexibel (edf 27–72 von 98) und klar signifikant.
  - Bei festem Alter weicht die Fläche nur wenig von einer Geraden in log-Dichte ab: Median der absoluten Abweichung über das Dichte-Raster 0,008–0,018 log-IRR, maximal 0,12.
- **Die zentrale Aussage hängt nicht an der Form:** Verglichen wird ein dichter Kreis (90. Perzentil, 1.518 Einw./km²) mit einem dünnen (10. Perzentil, 85 Einw./km²). Fläche und lineares Modell unterscheiden sich dabei im Mittel nur um 0,008–0,021 (log-IRR; maximal 0,06 in W1, `fig21`).
- **Muster laut Fläche** (dicht vs. dünn, IRR):
  - **Jüngste Kinder:** in dichten Kreisen höher, vor allem in W6–W8 (Alter 0: 1,39–1,66; Alter 5: 1,04–1,27) und in W1 (1,36).
  - **W2–W4:** Erwachsene und Ältere in dichten Kreisen niedriger (W3: 55 Jahre 0,83, 79 Jahre 0,72), Schulkinder leicht höher (W3: 10 Jahre 1,12).
  - **W5:** ab dem Jugendalter niedriger (0,83–0,90).
  - **W8:** Ältere höher (70 Jahre 1,15).

## Folgerung für „Kreistyp oder Dichte“

- **Am besten passt eine stetige, flexibel modellierte Dichte.** Zwischen den vier Kreistypen und einer linearen Dichte gibt es keinen klaren Sieger (je nach Welle).
- **Für die Kernaussage** (dicht vs. dünn je Alter) liefern lineares Dichtemodell und Fläche praktisch dieselben Kurven.
- **Vorschlag für die Diskussion mit Finn** (unverändert):
  - Kreistyp als interpretierbares Hauptmaß behalten;
  - die Dichte-Fläche als Robustheitsprüfung zeigen, die bestätigt, dass die Muster nicht an der Kategorisierung hängen.

## Einschränkungen

- **AIC-Vorteil vorsichtig lesen:** Die Dichte ist ein Kreismerkmal. Eine sehr flexible Fläche kann deshalb auch kreisspezifische Altersprofile aufnehmen, die mit der Dichte nur zufällig zusammenhängen; die edf steigen mit k weiter.
- **Räumliche Autokorrelation** ist in diesen GAM nicht modelliert (siehe Teil 4). Die Konfidenzbänder sind eher zu schmal, vgl. den Bootstrap in Teil 2.

---

# Teil 7: Kovariaten – Hauptkomponenten und Kreuzvalidierung (Stand 21.11.2026)

Skript: `Scripts/modellauswahl/19_covariates_pca_cv.R` (ca. 25 s). Abbildungen:
- `fig22_pca_ladungen.png`;
- `fig23_kv_kovariatensaetze.png`.

Ergebnisse: `results/modellauswahl/tables/pca_loadings.csv`, `pca_variance.csv`, `cv_covariate_sets.csv` und `cv_kt_sensitivity.csv`.
Methodisch: Statistik V Hauptkomponentenanalyse und Kreuzvalidierung; Lineare Modelle Kap. 11 Variablenselektion. Evidenz zur offenen Frage „welche Kovariaten?“.

## Hauptkomponenten

Grundlage sind 26 Strukturmerkmale (Mittelwerte 2020–2023, ohne die Raummaße Dichte, Kreistyp und Lage), standardisiert. 12 fehlende Werte wurden durch den Median des Landes ersetzt bzw. durch den bundesweiten Median, wenn das ganze Land fehlt: öffentlich Beschäftigte in den Stadtstaaten, Schutzsuchende im Saarland.

6 Komponenten haben einen Eigenwert > 1 und erklären zusammen 75 % der Varianz:

| PC | Varianz | höchste Ladungen | Deutung |
|---|---|---|---|
| PC1 | 27 % | SGB-II +0,34, Arbeitslose +0,32, Grundsicherung im Alter +0,30, Schutzsuchende +0,29, Auspendler −0,33 | soziale Lage / Benachteiligung |
| PC2 | 19 % | Anteil 65+ +0,41, Anteil 0–5 −0,35, Anteil 18–39 −0,34, ausländische Arbeitslose −0,37 | Altersstruktur (alt vs. jung) |
| PC3 | 11 % | Kita-Personal +0,36, Anteil 6–17 −0,34, Tourismus +0,34, Einpendler +0,32, Pendlersaldo +0,31 | Zentralität / Einpendler |
| PC4 | 8 % | Pflegeheim-Personal +0,55, Pflegeheimplätze +0,50 | stationäre Pflege |
| PC5 | 6 % | Betriebe +0,60, Tourismus +0,50 | Gewerbe / Tourismus |
| PC6 | 4 % | Asylbewerberleistungen +0,88 | Einzelmerkmal |

## Kreuzvalidierung der Kovariatensätze (Hauptmodell m1, 56 Zellen)

**Vorgehen:**
- 10-fache Kreuzvalidierung über Kreise. Die Folds werden je Bundesland zugeteilt; Hamburg und Berlin bleiben immer im Training.
- Güte: mittlere NB-Log-Likelihood der Testkreise, als Differenz zur bisherigen Auswahl (S1: SGB-II, 65+, Tourismus).

| Satz | Δ Test-Log-Lik je Kreis (Mittel) | besser als S1 | AIC-Summe |
|---|---|---|---|
| S0 ohne Kovariaten | −0,015 | 9 von 56 | 273.454 |
| S1 bisherige Auswahl | 0 | – | 272.624 |
| S2 6 Hauptkomponenten | +0,005 | 29 von 56 | 272.198 |
| S3 alle 26 Merkmale | +0,007 | 30 von 56 | 271.078 |

**Ergebnisse:**
- Mit Kovariaten werden die Vorhersagen besser als ohne. Zwischen S1, S2 und S3 sind die Unterschiede in der Vorhersage aber klein.
- S3 gewinnt in W2–W4 (+0,03 bis +0,055) und verliert in W1, W7 und W8 (Überanpassung). Das AIC bevorzugt S3, die Kreuzvalidierung kaum.

## Wie stark hängen die Kreistyp-Effekte von der Auswahl ab?

| Satz | Korrelation der log-IRR mit S1 | mittlere / maximale Abweichung | signifikant (von 168) |
|---|---|---|---|
| S0 ohne | 0,49 | 0,094 / 0,39 | 60 |
| S1 bisherige Auswahl | 1 | – | 54 |
| S2 Hauptkomponenten | 0,89 | 0,045 / 0,22 | 36 |
| S3 alle 26 | 0,68 | 0,075 / 0,35 | 24 |

- **Die Kreistyp-Effekte reagieren stark auf die Adjustierung.** Je mehr Merkmale im Modell stehen, desto kleiner und seltener signifikant werden sie.
- Das liegt auch daran, dass einige Merkmale selbst Urbanisierung messen, z. B. Einpendler, Pendlersaldo und Kita-Personal in PC3. Wer für sie adjustiert, nimmt dem Kreistyp einen Teil seines Effekts; das kann **Überadjustierung** sein, wenn diese Merkmale auf dem Weg von Urbanisierung zu Inzidenz liegen (Mediatoren).
- **Folgerung (Biometrie, Confounding):** Welche Merkmale als Confounder ins Modell gehören, ist eine inhaltliche Entscheidung, am besten über einen DAG, und nicht über Vorhersagegüte. Kreuzvalidierung und AIC helfen hier nur begrenzt.
- **Vorschlag für Finn:**
  - Confounder inhaltlich festlegen: soziale Lage und Altersstruktur, also etwa PC1 und PC2 oder deren stärkste Einzelmerkmale;
  - Mobilitäts- und Zentralitätsmerkmale nicht als Confounder des Urbanisierungseffekts behandeln;
  - S2 bzw. S3 als Sensitivitätsanalysen zeigen.
- Eine Lasso-Selektion (Statistik V Regularisierung) wurde nicht gerechnet, weil `glmnet` nicht installiert ist.

---

# Teil 8: Ankunftszeit der Wellen – Kaplan-Meier und Cox (Stand 21.11.2026)

Skript: `Scripts/modellauswahl/20_wave_arrival.R` (ca. 2 s). Abbildungen:
- `fig24_ankunft_kaplan_meier.png`;
- `fig25_ankunft_cox_alter.png`.

Ergebnisse: `results/modellauswahl/tables/arrival_km.csv`, `arrival_cox.csv`, `arrival_cox_age.csv` und `arrival_summary.csv`.
Methodisch: Überlebenszeitanalyse aus Statistik V und Biometrie.

## Warum

Die Modelle in Teil 1–7 reduzieren jede Welle auf die kumulative Inzidenz. Die Fragestellung spricht aber von Inzidenz**verläufen**. Hier geht es deshalb um das Timing: Erreicht eine Welle ländliche Kreise später?

## Definition und Modell

- **Ereignis:** Die Wocheninzidenz eines Kreises erreicht erstmals 50 % des bundesweiten Wellengipfels; Sensitivität 25 %. Gemessen wird für alle Altersgruppen zusammen bzw. je Altersgruppe mit deren eigenem Gipfel.
- **Zeit:** Woche innerhalb der Welle. Wer die Schwelle bis zum Wellenende nicht erreicht, ist zensiert.
- **Nicht auswertbare Wellen:**
  - W8: liegt bundesweit schon in Woche 1 bei 74 % des Gipfels;
  - bei 25 % auch W3, W6 und W7.
  - In W3 liegen 27 % der Kreise schon in Woche 1 über der 50-%-Schwelle, in W6 15 %.
- **Modelle:**
  - Kaplan-Meier nach Kreistyp;
  - Cox-Modell mit Kreistyp, SGB-II, 65+, Tourismus und `strata(Bundesland)` (eigene Basis-Hazardfunktion je Land), Bindungen nach Efron;
  - altersspezifisch: alle Altersgruppen gestapelt, Kreistyp je Altersgruppe, `strata(Land × Altersgruppe)`, robuste Standardfehler mit Cluster Kreis.
- **Lesart:** Hazard Ratio (HR) < 1 heißt: später als Großstädte erreicht.

## Ergebnisse

| Welle | Median-Woche Großstadt / Typ 4 | HR Typ 4 (50 %) [95 %-KI] | HR Typ 4 (25 %) | PH-Test global p | Altersgruppen gleich? p |
|---|---|---|---|---|---|
| W1 | 4 / 4 | 0,59 [0,34; 1,02] | 0,48* | 0,36 | 0,021 |
| W2 | 5 / 7 | 0,81 [0,49; 1,32] | 0,80 | 0,021 | 0,004 |
| W3 | 3 / 2 | 1,85* [1,11; 3,08] | – | 0,36 | 0,77 |
| W4 | 16 / 15 | 1,33 [0,79; 2,25] | 0,73 | 0,20 | 0,006 |
| W5 | 4 / 5 | 1,35 [0,83; 2,21] | 0,60* | 0,0001 | 0,056 |
| W6 | 3 / 4 | 0,80 [0,49; 1,31] | – | 0,017 | 0,006 |
| W7 | 5 / 5 | 1,12 [0,68; 1,85] | – | 0,27 | 0,011 |

- **Die Unterschiede im Timing zwischen den Kreistypen sind klein.** Die Median-Ankunft unterscheidet sich um höchstens 2 Wochen; das deutlichste Beispiel ist W2 (Großstädte Woche 5, dünn besiedelte Kreise Woche 7, `fig24`).
- **Signifikant ist nur W3** (HR 1,85, ländlich früher). Dort liegen aber viele Kreise schon in Woche 1 über der Schwelle; das ist mit Vorsicht zu lesen.
- **Die Ergebnisse hängen stark von der Schwelle ab:** Die log-HR bei 50 % und 25 % korrelieren nur mit r = 0,49. Bei 25 % werden ländliche Kreise in W1 und W5 signifikant später erreicht. Die Wellen „kommen“ dort also später an, der Gipfel aber nicht unbedingt.
- **Proportionale Hazards** sind in W2, W5 und W6 verletzt (Schoenfeld-Test). Die HR sind dort als Mittelwert über die Zeit zu lesen.
- **Altersspezifisch** (`fig25`):
  - Die Kreistyp-Effekte unterscheiden sich zwischen den Altersgruppen in W1, W2, W4, W6 und W7 (p ≤ 0,021).
  - Am deutlichsten: Jüngere (0–5, 6–17, 18–39) werden in ländlichen Kreisen in W1, W2 und W6 später erreicht (HR 0,45–0,58). Ältere werden in W5 früher erreicht (60+: HR 1,95–2,23).
- **Folgerung:** Ein durchgängiges Muster „ländliche Kreise später“ gibt es nicht. Die Raumunterschiede liegen vor allem im **Niveau** (Teil 1–6), weniger im Timing. Die altersspezifischen Unterschiede im Timing passen zum Niveau-Muster bei Kindern (Teil 5).

## Einschränkungen

- Die Schwelle ist eine Setzung. Wochendaten sind grob (viele Bindungen).
- Kreise mit niedrigem Niveau erreichen eine bundesweite Schwelle eventuell nie; dann vermischen sich Niveau und Timing.
- Räumliche Abhängigkeit ist nicht modelliert (Teil 4).

---

# Teil 9: Datengetriebene Kreistypologie – Clusteranalyse (Stand 21.11.2026)

Skript: `Scripts/modellauswahl/21_cluster_typology.R` (ca. 2 s), Abbildung `fig26_karte_cluster.png`.
Ergebnisse: `results/modellauswahl/tables/cluster_silhouette.csv`, `cluster_profile.csv`, `cluster_vs_bbsr.csv`, `cluster_model_aic.csv` und `data_processed/modellauswahl/kreis_cluster.rds`.
Methodisch: Statistik V Distanzmaße, Clusteranalyse und Clustervalidierung. Evidenz zur offenen Frage „welches Raummaß?“.

## Vorgehen

- **Eingabe:** die 26 Strukturmerkmale aus Teil 7 plus log-Dichte, standardisiert; euklidische Distanz.
- **Verfahren:** k-Means mit 50 Starts und hierarchisch nach Ward.
- **Validierung:**
  - intern über die mittlere Silhouettenbreite (k = 2–8);
  - extern über den Vergleich mit dem BBSR-Kreistyp (Kreuztabelle, adjustierter Rand-Index).
- **Modellvergleich:** Hauptmodell m1 mit dem Cluster statt des Kreistyps.

## Ergebnisse

- **Kaum Clusterstruktur:**
  - Die Silhouette liegt für k-Means bei 0,26 (k = 2), 0,21 (k = 3) und 0,22 (k = 4), für größere k bei höchstens 0,16; Ward mit k = 4 erreicht nur 0,12.
  - Werte um 0,25 und darunter zeigen höchstens eine schwache Struktur. Die Kreise bilden ein Kontinuum, keine klar getrennten Gruppen.
  - k-Means und Ward stimmen bei k = 4 nur mäßig überein (adjustierter Rand-Index 0,46).
- **Profile der 4 Cluster** (k-Means, nach Dichte sortiert; `fig26`):
  1. dicht und wohlhabend (n = 53, 1.342 Einw./km², SGB-II 66 je 1.000, viele Einpendler, Hochschulreife 40 %); 64 % BBSR-Typ 1.
  2. dicht und benachteiligt (n = 65, 837 Einw./km², SGB-II 99, Arbeitslose 6,8 %; u. a. Ruhrgebiet, Bremen, Berlin); 48 % BBSR-Typ 1.
  3. ländlich bis suburban, West und Süd, wenig Benachteiligung (n = 196, 195 Einw./km², SGB-II 36).
  4. ländlich, alt, überwiegend Ost (n = 86, 105 Einw./km², 65+ 27 %, 72 % in den östlichen Ländern).
- **Geringe Übereinstimmung mit BBSR:** Der adjustierte Rand-Index liegt bei 0,20. Die Cluster trennen eher **soziale Lage und Ost/West** als den Grad der Urbanisierung.
- **Im Modell** (AIC-Summe über 56 Zellen):

  | Modell | AIC-Summe |
  |---|---|
  | Kreistyp | 272.624 |
  | 4 Cluster | 272.780 |
  | ohne Raummaß | 272.707 |
  | 2 Cluster | 272.616 |

  - Die 4 Cluster passen schlechter als der Kreistyp und sogar schlechter als gar kein Raummaß. Neben Bundesland und Kovariaten bringen sie keine zusätzliche Information.
- **Folgerung:** Die datengetriebene Typologie ist kein besseres Urbanisierungsmaß. Der BBSR-Kreistyp bleibt das interpretierbare Hauptmaß; die Dichte dient als stetige Robustheitsprüfung (Teil 6).

---

# Teil 10: Hauptmodell mit eigenem θ je Altersgruppe (Stand 24.11.2026)

Skript: `Scripts/modellauswahl/22_main_model_tmb.R` (ca. 3–4 Minuten; Paket `glmmTMB` 1.1.15), Abbildung `fig27_hauptmodell_kreistyp_alter.png`.
Ergebnisse:
- `results/modellauswahl/tables/main_kt_coef.csv`: Kreistyp-Effekte je Welle × Altersgruppe, daneben die Schätzer aus Teil 5 mit MRF (`est_mrf`, `se_mrf`) und GEE (`est_gee`, `se_gee`);
- `main_tests.csv`: Wald-Tests, Holm/Bonferroni über die Wellen, LR-Test für θ, Moran's I;
- `main_dispersion.csv`: θ, Pearson-Dispersion und SD des Kreis-Effekts je Altersgruppe;
- `data_processed/modellauswahl/main_models.rds`.

Entscheidung der Gruppe am 24.11.2026, nach Prüfung der Anpassung von Teil 5.

## Warum

- **Problem in Teil 5:** Das Modell `int` hat ein gemeinsames θ für alle 7 Altersgruppen. Die Pearson-Dispersion je Altersgruppe lag damit bei:
  - 0–5: 1,46–3,41;
  - 80+: 1,61–2,59;
  - 40–59: 0,26–0,51.

  Die Konfidenzintervalle sind also bei 0–5 und 80+ zu schmal und bei Erwachsenen zu breit. Das betrifft genau die Kernaussage (kleine Kinder, Ältere).
- **Eigenes θ je Altersgruppe:** Der LR-Test (df 6) ergibt je Welle 403–1584, das AIC ist um 391–1574 besser.
- **Abwägung gegen den räumlichen Effekt:** Beides zusammen geht mit den installierten Paketen nicht:
  - `mgcv` kennt nur ein θ;
  - `glmmTMB` hat keinen MRF; eine exponentielle räumliche Kovarianz über die Kreisschwerpunkte konvergierte nicht (Hessematrix nicht positiv definit, ca. 3,5 Minuten je Welle, Moran's I unverändert);
  - `mgcv` mit Poisson und altersgruppenspezifischem Beobachtungs-Zufallseffekt war nach 11 Minuten noch mit keiner Welle fertig.

  Wirkung auf die Standardfehler: eigenes θ je Altersgruppe 15–30 %, räumlicher Effekt 1–3 % (Teil 4 und 5). Deshalb ist das Hauptmodell ohne MRF; Teil 5 bleibt die Sensitivitätsanalyse für den räumlichen Effekt.
- **Ausblick:** Beides in einem Modell ist mit INLA möglich; umgesetzt am 25.11.2026 als Option III (Teil 12).

## Modell

Je Welle, alle 7 Altersgruppen (2.800 Zeilen), NB2 mit ML (TMB, Laplace):
`cases ~ Altersgruppe + Altersgruppe:Kreistyp + Altersgruppe:Bundesland + Altersgruppe:(SGB-II + 65+ + Tourismus) + rr(0 + Altersgruppe | Kreis, d = 1) + offset(log Bevölkerung)`, Dispersion `~ 0 + Altersgruppe`.

- **Kreis-Effekt:** ein gemeinsamer Kreis-Faktor mit eigener Ladung je Altersgruppe (reduzierter Rang 1). Gegenüber einem einfachen `(1 | Kreis)` ist das AIC besser (W2 −27, W5 −167); die Kreistyp-Koeffizienten ändern sich um höchstens 0,002.
- **Randregel für θ:**
  - Bei 40–59 läuft θ in W4–W6 gegen sehr große Werte (kaum Überdispersion über den Kreis-Effekt hinaus); die Hessematrix ist dann nicht positiv definit.
  - Regel: Liegt ein θ über 10⁴, wird es auf 10⁴ festgehalten und das Modell neu angepasst.
  - 10⁴ ist eine **numerische Obergrenze, nicht „gleich Poisson“**: Varianz / Poisson-Varianz = 1 + μ/θ liegt bei den großen Fallzahlen noch deutlich über 1 (W5, 40–59: Median 2,07; externe Prüfung 26.11.2026).
  - Betroffen: 40–59 in W4, W5 und W6. Die Kreistyp-Koeffizienten ändern sich dadurch um höchstens 0,001 (extern mit Grenze 10⁶ geprüft: höchstens 0,00024, kein KI-Wechsel).
  - Der LR-Test „θ in allen Altersgruppen gleich“ (df 6) ist in diesen Wellen nur eine grobe Näherung (ein Parameter auf dem Rand); ein formaler Test bräuchte einen parametrischen Bootstrap mit derselben Randregel.
- **Optimierer:** `iter.max = 5000`. Mit dem Standard (300) bricht `glmmTMB` ohne Konvergenz ab.
- **Kontrolle:** Dasselbe Modell mit gemeinsamem θ und `(1 | Kreis)` reproduziert `int_nosp` aus Teil 5 (Kreistyp-Koeffizienten r = 0,9999, SE-Verhältnis 1,00).
- **Nicht ganzzahlige Fallzahlen** (verteilte Fälle ohne Altersangabe): Die NB-Loglikelihood nutzt `lgamma` und ist stetig; die Warnung von `glmmTMB` wird unterdrückt.

## Ergebnisse

| Welle | Wald-Test Kreistyp × Alter (df 18) p | Holm (8 Wellen) | LR θ je Altersgruppe | Moran's I Kreis-Residuen (p) | θ festgehalten |
|---|---|---|---|---|---|
| W1 | 0,72 | 0,72 | 403 | 0,04 (0,084) | – |
| W2 | 0,0020 | 0,0081 | 1.150 | 0,08 (0,013) | – |
| W3 | 3,5·10⁻⁸ | 2,5·10⁻⁷ | 792 | 0,12 (0,001) | – |
| W4 | 7,1·10⁻⁶ | 4,3·10⁻⁵ | 919 | 0,09 (0,005) | 40–59 |
| W5 | 4,1·10⁻⁴ | 0,0021 | 1.584 | 0,24 (0,001) | 40–59 |
| W6 | 4,6·10⁻¹² | 3,7·10⁻¹¹ | 809 | 0,21 (0,001) | 40–59 |
| W7 | 0,053 | 0,11 | 682 | 0,16 (0,001) | – |
| W8 | 0,013 | 0,040 | 732 | 0,11 (0,002) | – |

**Anpassung:**
- θ je Altersgruppe: 0–5 4,4–37; 80+ 4,0–82; 18–39 26–876; 40–59 308–4.480 bzw. festgehalten.
- Pearson-Dispersion jetzt 0,85–1,08 in allen Altersgruppen außer 40–59 (0,31–0,56). Erklärung: Der Kreis-Effekt wird vor allem aus den großen Fallzahlen der 40- bis 59-Jährigen geschätzt, deren bedingte Residuen werden dadurch klein. Ein Zeichen schlechter Anpassung ist das nicht.

**Standardfehler im Vergleich (Median der Verhältnisse):**
- Teil 5 (MRF, gemeinsames θ) / Hauptmodell: 0–5 0,79, 80+ 0,80, 18–59 1,15–1,18.
- GEE (robust nach Kreis) / Hauptmodell: 0–5 1,00, 80+ 1,00, übrige 1,09–1,13. Die Unsicherheit bei den kleinen Kindern und den Ältesten entspricht damit jetzt der robusten Schätzung.

**Schätzer:**
- gegenüber Teil 5 mit MRF: r = 0,972, mittlere |Differenz| 0,034 (log-IRR);
- gegenüber GEE: r = 0,846;
- signifikant (95 %, unkorrigiert) sind 54 von 168 Kreistyp-Koeffizienten (Teil 5: 75).

**Typ 4 („dünn besiedelt“) gegenüber Großstadt, IRR (\* = 95 %-KI ohne 1, unkorrigiert):**

| Altersgruppe | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 |
|---|---|---|---|---|---|---|---|---|
| 0–5 | 0,63\* | 0,96 | 1,01 | 1,00 | 0,90\* | 0,69\* | 0,82\* | 0,79\* |
| 6–17 | 0,97 | 0,96 | 1,03 | 1,05 | 1,06\* | 0,90\* | 1,01 | 0,95 |
| 18–39 | 0,78\* | 1,12\* | 1,15\* | 1,15\* | 1,08\* | 0,91\* | 1,01 | 0,96 |
| 40–59 | 0,82 | 1,13\* | 1,12 | 1,08 | 1,08\* | 0,97 | 1,03 | 0,96 |
| 60–69 | 0,78\* | 1,15\* | 1,14 | 1,06 | 1,11\* | 0,99 | 1,01 | 0,92 |
| 70–79 | 0,82 | 1,14 | 1,15 | 1,18\* | 1,10\* | 0,97 | 1,00 | 0,92 |
| 80+ | 0,68 | 1,30\* | 1,31\* | 1,13 | 1,15\* | 0,96 | 1,00 | 0,95 |

**Gegenüber Teil 5:**
- **Wald-Test:** Kreistyp × Alter ist nach Holm über die 8 Wellen signifikant in W2–W6 und W8, nicht in W1 und W7 (Bonferroni: nur W2–W6). In Teil 5 waren es W2–W8.
- **0–5:** In ländlichen Kreisen niedriger in W1 und ab W5 (0,69–0,90). In W2–W4 liegt der Effekt jetzt nahe 1 (0,96–1,01; Teil 5: 1,02–1,10).
- **Ältere:** Bei 80+ in W2/W3 höher (1,30/1,31), aber kleiner als in Teil 5 (1,41/1,47). Bei 80+ in W4 nicht mehr signifikant (1,13).

## Einschränkungen

- **Kein räumlicher Effekt:** Die Kreis-Residuen sind räumlich autokorreliert (Moran's I 0,04–0,24, signifikant in W2–W8). Die Standardfehler sind deshalb eher etwas zu klein. In Teil 4 und 5 änderte der MRF die Standardfehler aber nur um 1–3 % und die Effekte kaum (r = 0,97). Auch mit eigenem θ je Altersgruppe ändert ein räumlicher Kreis-Faktor (BYM2, Teil 12) die Schlüsse kaum (außer W8).
- **Randregel:** Das Festhalten von θ(40–59) auf 10⁴ in W4–W6 ist eine Setzung (numerische Obergrenze, nicht Poisson).
- **Kreis-Effekt:** Ein gemeinsamer Faktor mit Ladungen (Rang 1) erlaubt keine eigenen Kreis-Muster je Altersgruppe; Rang 2 siehe Teil 13.
- **Übrige Einschränkungen wie in Teil 1 und 5:** ökologisch, vorläufige Kovariaten (Teil 7), Strukturmerkmale als Mittelwerte 2020–2023 (Rangkorrelation 2020 vs. 2023 für SGB-II 0,986, 65+ 0,988, Tourismus 0,967).

---

# Teil 11: Option D – ein Modell über alle Wellen (Stand 25.11.2026, zur Diskussion)

Skript: `Scripts/modellauswahl/23_cross_wave_tmb.R` (ca. 7–8 Minuten, `glmmTMB`), Abbildung `fig28_gesamtmodell_verlauf_kreistyp.png`.
Ergebnisse:
- `results/modellauswahl/tables/crosswave_kt_coef.csv`: Kreistyp-Effekte je Welle × Altersgruppe, daneben A1 (`est_a1`, `se_a1`);
- `crosswave_tests.csv`: globale Wald-Tests und Tests je Welle (mit Holm), Moran's I, LR für den dauerhaften Kreis-Faktor;
- `crosswave_varcomp.csv`: Varianzkomponenten und θ je Altersgruppe × Welle;
- `data_processed/modellauswahl/crosswave_model.rds`.

**Status: Diskussionsoption, nicht Hauptmodell.** Es ersetzt A1 (Teil 10) nicht, sondern zeigt, was ein gemeinsames Modell zusätzlich beantworten kann.

## Warum

- Das Thema fragt nach **Verläufen**. In A1 gibt es dafür 8 getrennte Modelle und 8 Tests (mit Holm). Ob sich der Stadt-Land-Unterschied *zwischen* den Wellen ändert, wird dort nicht getestet, sondern nur durch Vergleich der Abbildungen beurteilt.
- Ein Modell über alle Wellen kann das als **einen** Test prüfen und trennt dauerhafte Kreis-Abweichungen (ein Kreis liegt in allen Wellen über dem Erwarteten) von welle-spezifischen.

## Modell

Alle 8 Wellen × 7 Altersgruppen × 400 Kreise (22.400 Zeilen), NB2 mit ML (TMB, Laplace; `profile = TRUE`):
`cases ~ 0 + Zelle + Zelle:Kreistyp + Bundesland + Zelle:(SGB-II + 65+ + Tourismus) + rr(0 + Altersgruppe | Kreis, d = 1) + Σ_w rr(0 + Altersgruppe:[Welle = w] | Kreis, d = 1) + (1 | Bundesland:Welle) + (1 | Bundesland:Altersgruppe) + (1 | Bundesland:Altersgruppe:Welle) + offset(log Bevölkerung)`, Dispersion `~ 0 + Zelle`; Zelle = Altersgruppe × Welle (56).

- **Kreistyp und Kovariaten** sind je Zelle frei (wie in A1), damit die Koeffizienten direkt vergleichbar sind.
- **Kreis:**
  - dauerhafter Faktor u_k (gleich in allen Wellen), Ladung je Altersgruppe;
  - welle-spezifischer Faktor v_kw mit eigenen Ladungen je Altersgruppe **und Welle**. Das ist genau die Kreis-Struktur von A1; u_k kommt hinzu.
- **Struktur-Wahl (geprüft 25.11.2026):** AIC gegenüber `(1 | Kreis:Welle)`:
  - Ladungen je Altersgruppe, gleich in allen Wellen: −55;
  - Ladungen je Altersgruppe und Welle: −2.149.

  Mit gleichen Ladungen über die Wellen waren die SE gegenüber A1 stark verzerrt (Verhältnis 0,73 in W1, 2,19 in W5). Grund: Die Kreis-Streuung ist in W1 viel größer als in W5 (A1: SD 0,34–0,63 bzw. 0,07–0,11).
- **Bundesland:** fester Effekt plus zufällige Effekte je Welle, je Altersgruppe und je Altersgruppe × Welle. Das ist der wichtigste Unterschied zu A1, wo Bundesland je Altersgruppe fest ist (fest je Zelle wären 840 Parameter).
- **θ** je Zelle (56), Randregel wie in Teil 10.

**Tests im selben Modell (Wald):**

| Test | Frage | df |
|---|---|---|
| Typ × Alter × Welle | Ändert sich das Altersmuster des Kreistyp-Effekts über die Wellen? | 126 |
| Typ × Alter (gemittelt) | Gibt es im Mittel über die Wellen ein Altersmuster? | 18 |
| Typ × Alter (in mindestens einer Welle) | ersetzt die 8 Tests + Holm aus A1 | 144 |
| Typ × Welle (gemittelt über Altersgruppen) | Ändert sich der mittlere Kreistyp-Effekt über die Wellen? | 21 |

## Ergebnisse

Anpassung: konvergiert, Hessematrix positiv definit; θ(40–59) in W4–W6 auf 10⁴ festgehalten (wie A1). θ je Zelle: 0–5 3,7–36, 80+ 4,0–93, 18–39 24–1.100.

**Globale Tests (ein Modell):**

| Test | χ² | df | p |
|---|---|---|---|
| Typ × Alter × Welle | 304 | 126 | 1,0·10⁻¹⁶ |
| Typ × Alter (gemittelt über Wellen) | 49,3 | 18 | 9,6·10⁻⁵ |
| Typ × Alter (in mindestens einer Welle) | 410 | 144 | 2,5·10⁻²⁷ |
| Typ × Welle (gemittelt über Altersgruppen) | 48,0 | 21 | 6,9·10⁻⁴ |

- Das Altersmuster des Stadt-Land-Unterschieds **ändert sich deutlich über die Wellen** (Typ × Alter × Welle). Das ist der direkte Test für „Verläufe“, den A1 nicht hat.
- Auch der über die Altersgruppen gemittelte Kreistyp-Effekt ändert sich über die Wellen (Typ × Welle).

**Je Welle (df 18, Holm über 8 Wellen) im Vergleich zu A1:**

| Welle | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 |
|---|---|---|---|---|---|---|---|---|
| Holm (D) | 0,39 | 0,023 | 1,4·10⁻⁸ | 3,9·10⁻⁴ | 0,0013 | 6,3·10⁻¹¹ | 0,10 | 0,018 |
| Holm (A1) | 0,72 | 0,0081 | 2,5·10⁻⁷ | 4,3·10⁻⁵ | 0,0021 | 3,7·10⁻¹¹ | 0,11 | 0,040 |

Gleiches Bild wie A1: signifikant in W2–W6 und W8, nicht in W1 und W7.

**Kreis-Effekte:**
- **Dauerhafter Faktor u_k:** Er verbessert das Modell klar (LR 1.250, AIC −1.240 gegenüber dem Modell ohne u_k), ist aber klein. SD 0,03–0,09; am größten bei 70–79/80+ (0,09) und 0–5 (0,08).
- **Welle-spezifische Abweichungen v_kw** sind viel größer und schwanken stark:
  - W1: SD 0,35–0,65;
  - W2–W4: 0,17–0,31;
  - W5: 0,07–0,09;
  - W6–W8: 0,07–0,27.
- **Folgerung:** Ein Kreis, der in einer Welle über dem Erwarteten liegt, tut das in der nächsten nur wenig. Die Kreis-Abweichungen sind überwiegend welle-spezifisch.
- **Bundesland** (SD auf log-Skala):
  - × Welle: 0,27;
  - × Altersgruppe: 0,06;
  - × Altersgruppe × Welle: 0,07.

  Die Bundesländer unterscheiden sich vor allem je Welle.

**Kreistyp-Koeffizienten gegenüber A1:**
- Übereinstimmung: r = 0,93–1,00, mittlere |Differenz| 0,002–0,043; SE-Verhältnis 0,99–1,06.
- Signifikant (95 %, unkorrigiert) sind nur 33 von 168 (A1: 54).
- **Grund:** Die Effekte der Erwachsenen in W2–W4 liegen näher an 1 (z. B. Typ 4, 18–39 in W2/W3: 1,09/1,12; A1 1,12/1,15). In D ist das Bundesland je Altersgruppe × Welle nur teilweise gepoolt (zufällig). Damit gehen auch Vergleiche *zwischen* Bundesländern in den Kreistyp-Effekt ein, in A1 nur Vergleiche *innerhalb*. Die Wahl „Bundesland fest oder zufällig“ wirkt also in D stärker als in Teil 5 (dort r = 0,99).

**Typ 4 gegenüber Großstadt:**
- 0–5: W1 0,60, W5–W8 0,72–0,90 (alle signifikant, wie A1).
- 80+: W2/W3 1,23/1,25 (A1 1,30/1,31).

**Moran's I der Kreis-Residuen:** 0,04–0,25, praktisch wie A1.

## Einschränkungen

- **Rechenzeit:** etwa 12 Minuten je Anpassung (A1: Sekunden je Welle).
- **Optimierung empfindlich:** Startwerte aus einer früheren Anpassung führten beim Modell ohne u_k in ein schlechteres lokales Optimum (Zielfunktion um 687 schlechter); deshalb Neuanpassung wie in 22.
- **Bundesland anders als in A1** (zufällig statt fest je Zelle). Das ist eine inhaltliche Entscheidung (Finn-Frage „Bundesland FE oder RE“) und keine reine Technik.
- **Strukturvariablen** zeitlich konstant; Kovariaten-Effekte je Zelle frei (168 Parameter). Ein sparsameres D (z. B. Kovariaten nur je Altersgruppe) wäre möglich, ist aber nicht gerechnet.
- **Kein räumlicher Effekt** (wie A1).

---

# Teil 12: Option III – Hauptmodell mit räumlichem Kreis-Effekt in einem Modell (INLA, Stand 25.11.2026, seriell neu gerechnet am 26.11.2026, zur Diskussion)

Skript: `Scripts/modellauswahl/24_spatial_theta_inla.R` (Paket INLA 25.10.19, nicht auf CRAN, Installation im README), Abbildung `fig29_inla_bym2_kreistyp_alter.png`.
Ergebnisse:
- `results/modellauswahl/tables/inla_kt_coef.csv`: Kreistyp-Effekte (Posterior-Mittel, -SD, 95 %-Kredibilitätsintervall) für `iid` und `bym2`, daneben A1;
- `inla_tests.csv`: Wald-artige Tests mit Holm, DIC/WAIC, φ, Moran's I;
- `inla_hyper.csv`: θ je Altersgruppe, Kreis-Präzision, φ, Ladungen;
- `data_processed/modellauswahl/inla_models.rds`.

**Status: Diskussionsoption.** Sie löst den Zielkonflikt aus Teil 10 („eigenes θ je Altersgruppe“ oder „räumlicher Effekt“).

## Warum

Mit `mgcv`/`glmmTMB` ging nur eines von beiden (Teil 10, „Abwägung“). INLA kann beides in einem Modell:
- eine eigene NB-Likelihood je Altersgruppe, also ein eigenes θ;
- einen räumlich strukturierten Kreis-Effekt (BYM2).

## Modell

Je Welle, feste Effekte wie A1: `Altersgruppe + Altersgruppe:Kreistyp + Altersgruppe:Bundesland + Altersgruppe:(SGB-II + 65+ + Tourismus) + offset(log Bevölkerung)`.

- **Kreis-Effekt** wie in A1 als gemeinsamer Faktor mit Ladung je Altersgruppe (0–5 Ladung 1, übrige als `copy` mit frei geschätzter Ladung).
  - `iid`: der Faktor ist unabhängig je Kreis. Das ist A1 in INLA und dient als Kontrolle.
  - `bym2`: der Faktor ist eine Mischung aus räumlich strukturiertem Teil (Nachbarkreise, ICAR) und unstrukturiertem Teil. φ ist der räumliche Anteil (Riebler et al. 2016).
- **Bayesianisch** (INLA, Laplace-Näherung). Priors:
  - feste Effekte N(0, 1000) (INLA-Standard);
  - Kreis-SD: PC-Prior mit P(SD > 1) = 0,01;
  - φ: PC-Prior mit P(φ < 0,5) = 2/3;
  - Ladungen N(1, 10);
  - θ: INLA-Standard.
  
  Eine Randregel für θ ist nicht nötig, weil der Prior θ(40–59) endlich hält.
- **Gerundete Fallzahlen:** INLA verlangt ganzzahlige Fallzahlen. Die verteilten Fälle ohne Altersangabe machen sie nicht ganzzahlig, deshalb wird gerundet (Fehler höchstens 0,5 je Zelle).
- **Test** „Kreistyp-Effekt in allen Altersgruppen gleich“ (18 Kontraste wie in A1): Wald-artig aus 2.000 Posterior-Ziehungen (Mittelwert und Kovarianz der Kontraste), Holm über die 8 Wellen. Das ist eine Näherung an den frequentistischen Test, kein Bayes-Faktor.
- **Modellvergleich `iid` vs. `bym2`:** DIC und WAIC (kleiner = besser), Moran's I der Kreis-Residuen.

## Ergebnisse

**Neu gerechnet am 26.11.2026 (seriell):** Mit mehreren Rechenfäden war INLA nicht reproduzierbar. Zwei Läufe mit identischen Daten ergaben für W5/BYM2 ein DIC von 37.634 bzw. 37.787, und der Vergleich BYM2 vs. `iid` hatte in mehreren Wellen ein anderes Vorzeichen. Seitdem gilt:
- Skript 24 rechnet seriell (`INLA_THREADS=1:1`, Standard).
- Vor den Posterior-Ziehungen wird je Welle × Modell ein R-Seed gesetzt, weil `inla.posterior.sample` die Hyperparameter-Konfigurationen mit dem R-Zufallsgenerator wählt.
- Im Arbeitsordner waren zwei serielle Läufe identisch. Ein weiterer serieller Lauf im Gruppen-Repo war in 5 von 8 Wellen identisch; in W1, W3 und W8 wich das DIC um bis zu 50 ab (W8-`iid` Holm 0,075 → 0,082). Testschlüsse, φ und das Vorzeichen des DIC/WAIC-Vergleichs blieben gleich. Seriell ist INLA also weitgehend, aber nicht vollständig reproduzierbar (Ursache offen).
- Alle Zahlen unten stammen aus dem seriellen Lauf. Gegenüber der früheren Fassung sind die Koeffizienten praktisch gleich (BYM2 r = 0,9999, max. Abweichung 0,009) und Holm ähnlich, aber der DIC/WAIC-Vergleich hat sich gedreht.

**Kontrolle (`iid` gegen A1):** Kreistyp-Koeffizienten r = 1,000, mittlere |Differenz| 0,001, Posterior-SD/ML-SE 1,02–1,04. Die INLA-Umsetzung (inklusive Rundung und Priors) reproduziert also A1.

| Welle | Kreistyp × Alter p (BYM2) | Holm (BYM2) | Holm (A1) | ΔDIC BYM2 − iid | ΔWAIC | φ (95 %-KrI) | Moran's I Kreis-Residuen iid → BYM2 |
|---|---|---|---|---|---|---|---|
| W1 | 0,72 | 0,72 | 0,72 | −11 | −18 | 0,75 (0,57–0,89) | 0,04 → 0,00 |
| W2 | 0,0021 | 0,011 | 0,0081 | −31 | −32 | 0,96 (0,88–1,00) | 0,08 → 0,06 |
| W3 | 1,3·10⁻⁷ | 9,4·10⁻⁷ | 2,5·10⁻⁷ | +10 | +4 | 0,94 (0,84–0,99) | 0,13 → 0,10 |
| W4 | 5,9·10⁻⁵ | 3,5·10⁻⁴ | 4,3·10⁻⁵ | −41 | −32 | 0,94 (0,86–0,99) | 0,09 → 0,07 |
| W5 | 0,0026 | 0,011 | 0,0021 | +88 | +51 | 0,53 (0,32–0,75) | 0,24 → 0,26 |
| W6 | 1,8·10⁻¹¹ | 1,4·10⁻¹⁰ | 3,7·10⁻¹¹ | +36 | −49 | 0,48 (0,02–0,97) | 0,21 → 0,21 |
| W7 | 0,060 | 0,13 | 0,11 | −9 | −7 | 0,52 (0,29–0,80) | 0,16 → 0,15 |
| W8 | 0,042 | 0,13 | 0,040 | +93 | +19 | 0,62 (0,43–0,85) | 0,11 → 0,12 |

**Ergebnisse im Einzelnen:**
- **DIC/WAIC geben kein klares Bild:**
  - BYM2 ist nach DIC besser in W1, W2, W4 und W7, schlechter in W3, W5, W6 und W8.
  - Nach WAIC ist BYM2 besser in W1, W2, W4, W6 und W7.
  - Die frühere Aussage „BYM2 nach DIC und WAIC besser in W2–W6 und W8“ beruhte auf dem nicht reproduzierbaren, mehrfädigen Lauf und **gilt nicht mehr**.
  - Für die Entscheidung über Option III braucht es andere Gründe.
- **φ:** In W2–W4 ist der Kreis-Faktor fast ganz räumlich strukturiert (φ 0,94–0,96), ab W5 etwa zur Hälfte (0,48–0,62). In W6 ist φ kaum bestimmt (KrI 0,02–0,97).
- **Kreistyp-Effekte:**
  - Gegenüber A1: r = 0,93–1,00, mittlere |Differenz| 0,008–0,034 (log-IRR).
  - Unsicherheit: Posterior-SD/SE(A1) im Median 0,88–1,06 je Welle.
  - Der Raumeffekt ändert die Schlüsse also kaum, die Standardfehler bleiben fast gleich.
- **Signifikanz:**
  - Kreistyp × Alter ist nach Holm in W2–W6 signifikant, W8 nicht (0,13; A1 0,040, INLA-`iid` 0,075). W8 ist damit spezifikationsabhängig.
  - Signifikante Kreistyp-Koeffizienten (95 %, unkorrigiert): 58 von 168 (A1 54), 18 Intervalle wechseln gegenüber A1.
- **Typ 4 gegenüber Großstadt:**
  - 0–5: W1 0,60, W5–W8 0,69–0,88, alle mit KrI ohne 1 (A1: 0,63; 0,69–0,90).
  - 80+: W2/W3 1,35/1,40 (A1: 1,30/1,31).
  - W1: Bei Erwachsenen und 80+ liegt der Effekt niedriger (0,63–0,78; A1 0,68–0,82).
- **Restliche Autokorrelation:** Moran's I der Kreis-Residuen sinkt kaum (außer in W1). Die Prüfung je Altersgruppe zeigt den Grund. Sie stammt aus einer Skizze außerhalb des Projekts mit dem früheren, mehrfädigen Lauf (W3, W5) und ist seriell nicht wiederholt:
  - Der Kreis-Faktor selbst ist räumlich stark strukturiert (Moran's I W3 0,27 iid bzw. 0,65 BYM2).
  - Die restliche Autokorrelation steckt in den altersspezifischen Abweichungen, in W5 vor allem bei 0–5 (0,32) und 6–17 (0,27).
  - Ein gemeinsamer Kreis-Faktor (räumlich oder nicht) kann das nicht auffangen. Dazu bräuchte es einen eigenen räumlichen Effekt für Kinder (z. B. einen zweiten BYM2-Faktor; vgl. Teil 13).

## Einschränkungen

- **Bayesianisch und genähert:**
  - Der Test ist eine Wald-Näherung aus Posterior-Ziehungen, nicht derselbe Test wie in A1.
  - DIC/WAIC sind für dieses Modell wenig verlässlich: θ(40–59) ist kaum identifiziert, die Fallzahlen sind gerundet, und DIC und WAIC widersprechen sich teils (W6).
- **Reproduzierbarkeit:** nur seriell (`INLA_THREADS=1:1`). Mit mehreren Rechenfäden ist es schneller, aber DIC/WAIC sind nicht stabil.
- **Rundung** der Fallzahlen (siehe Modell).
- **Prior-Abhängigkeit:** θ(40–59) wird durch den Prior begrenzt (Posterior-Median bis über 100.000). Die Kreistyp-Effekte hängen davon kaum ab (Kontrolle `iid` = A1).
- **Weiterhin ein Rang-1-Kreis-Faktor:** Die altersspezifische räumliche Struktur (Kinder in W5) bleibt im Residuum.
- **Software:** INLA ist nicht auf CRAN; die Gruppe müsste es installieren (README). Seriell dauert Skript 24 ca. 5–15 Minuten.

---

# Teil 13: Kandidat – A1 mit zwei Kreis-Faktoren (Rang 2, Stand 26.11.2026, zur Diskussion)

Skript: `Scripts/modellauswahl/25_rank2_tmb.R` (ca. 25 min, `glmmTMB`).
Ergebnisse:
- `results/modellauswahl/tables/rank2_tests.csv`: AIC, Wald-Tests und Holm für A1 und Rang 2;
- `rank2_starts.csv`: alle Startwerte je Welle (Konvergenz, Hessematrix, Loglikelihood, p, θ am Rand);
- `rank2_kt_coef.csv`: Kreistyp-Koeffizienten A1 vs. Rang 2;
- `rank2_alt_jung.csv`: Verhältnis der IRR 80+ zu 0–5;
- `rank2_resid_cor.csv`: Korrelation der Pearson-Residuen zwischen den Altersgruppen derselben Kreise;
- `data_processed/modellauswahl/rank2_models.rds`.

**Status: Kandidat für das Hauptmodell, zur Diskussion in der Gruppe.** A1 bleibt bis zur Entscheidung der Vorschlag.

## Warum

A1 erklärt die gemeinsame Abweichung eines Kreises über alle 7 Altersgruppen mit einem Faktor u_k (Rang 1, je Altersgruppe eine Ladung). Nach A1 korrelieren die Pearson-Residuen derselben Kreise aber noch zwischen benachbarten Altersgruppen:
- 0–5 mit 6–17: 0,24–0,71 je Welle;
- 70–79 mit 80+: 0,41–0,63 je Welle.

Laut externer Prüfung liegt der Wert für A1 in W2 (0–5 mit 6–17: 0,711) weit außerhalb dessen, was A1 selbst in Simulationen erzeugt (95 %-Bereich −0,11 bis 0,08). Ein einzelner Faktor kann zwei verschiedene Muster nicht gleichzeitig abbilden.

## Modell

- Wie A1 (feste Effekte, Offset, θ je Altersgruppe, Randregel θ ≤ 10⁴), nur `rr(0 + grp | ags, d = 2)` statt `d = 1`.
- **Startwerte:** Das Modell hat lokale Optima. Je Welle laufen 5 Startwerte (`R2_STARTS`): der Standardstart und 4 Zufallsladungen mit festen Seeds.
- **Wahl der Lösung:** die mit der höchsten Loglikelihood unter den Lösungen mit Konvergenz und positiv definiter Hessematrix, **nicht nach p-Wert**.
- **Kontrolle:** A1 wird im selben Skript mitgerechnet und muss `main_kt_coef.csv` reproduzieren.

## Ergebnisse

| Welle | ΔAIC (A1 − Rang 2) | Holm A1 | Holm Rang 2 | Holm Rang 2, nur Standardstart | θ am Rand (Rang 2) |
|---|---:|---:|---:|---:|---|
| W1 | 228 | 0,72 | 0,56 | 0,56 | 70–79 |
| W2 | 421 | 0,0081 | 0,12 | 0,017 | – |
| W3 | 276 | 2,5·10⁻⁷ | 7,1·10⁻⁶ | 7,1·10⁻⁶ | 6–17 |
| W4 | 260 | 4,3·10⁻⁵ | 4,1·10⁻⁵ | 4,1·10⁻⁵ | 40–59, 70–79 |
| W5 | 314 | 0,0021 | 0,0015 | 0,0015 | 60–69 |
| W6 | 409 | 3,7·10⁻¹¹ | 1,3·10⁻¹¹ | 1,3·10⁻¹¹ | 70–79 |
| W7 | 334 | 0,11 | 0,12 | 0,097 | 70–79 |
| W8 | 327 | 0,040 | 0,024 | 0,018 | 40–59, 70–79 |

- **Anpassung:**
  - Rang 2 ist nach AIC in allen Wellen deutlich besser (228–421).
  - Mit zwei Faktoren erreichen aber mehr Altersgruppen die θ-Grenze 10⁴ (der zweite Faktor übernimmt einen Teil der Überdispersion).
  - Zusammen mit den nicht ganzzahligen Fallzahlen macht das den AIC-Vergleich zu einer Näherung.
- **Kreistyp-Koeffizienten praktisch gleich:**
  - r = 0,998, mittlere |Differenz| 0,003, max. 0,055 (log-IRR);
  - SE-Verhältnis im Median 1,00 in allen Altersgruppen;
  - signifikant 54 → 55 (1 von 168 wechselt);
  - Verhältnis der Typ-4-IRR 80+ zu 0–5 bis auf W1 (1,08 → 1,15) identisch.
- **Tests:**
  - Holm < 5 % in W3–W6 und W8; W1, W7 nicht.
  - W2 hängt vom lokalen Optimum ab: Zwei Lösungen konvergieren mit positiv definiter Hessematrix (Abstand der Loglikelihood 14,7). Die bessere ergibt Wald-p 0,039 (Holm 0,12), die des Standardstarts 0,004 (Holm 0,017).
  - In allen anderen Wellen kommen die 5 Starts zur selben Lösung.
- **Residualkorrelation:**
  - Der zweite Faktor nimmt nicht gezielt die Kinder-Korrelation auf: 0–5 mit 6–17 wird in W2/W3 negativ (−0,59/−0,52) und bleibt in W5 bei 0,52.
  - 70–79 mit 80+ sinkt in allen Wellen, in 5 von 8 unter 0.
  - Bedingte Residuen sind auch bei richtigem Modell nicht unkorreliert. Ein Urteil bräuchte eine Simulationsreferenz für Rang 2.

## Einschränkungen

- **Lokale Optima:** Mehrere Startwerte sind Pflicht. Der W2-Test hängt von der gewählten Lösung ab.
- **θ am Rand:** Mehr Gruppen sind festgehalten als in A1. Das ist eine Setzung, die AIC und LR-Vergleiche nur näherungsweise gültig macht.
- **Keine Simulationsreferenz** für die Residualkorrelationen von Rang 2.
- **Laufzeit** ca. 25 Minuten (8 Wellen × 6 Anpassungen).

---

# Nicht umgesetzt

- **Bayesianisches Modell für Untererfassung** (Statistik V, Beispiel Khazaei et al. 2023 / Rehms et al. 2024): Es braucht Test-, Hospitalisierungs- oder Sterbedaten je Kreis × Alter, die im Projekt nicht vorliegen. Es bleibt als Ausblick für die Einschränkung „gemeldete Inzidenz ≠ Infektionen“.
- **Lasso** (`glmnet`) und **GEE mit austauschbarer Korrelation** (`geepack`): Diese Pakete sind nicht installiert. Ersatzweise wurden Kreuzvalidierung und PCA (Teil 7) sowie GEE mit Unabhängigkeits-Arbeitskorrelation (Teil 5) gerechnet.
