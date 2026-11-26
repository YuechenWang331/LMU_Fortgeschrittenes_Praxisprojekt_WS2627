# COVID-19: Kreistyp, Altersgruppe und Zeit (Bericht v2.4)

**Deutschland · ISO-Jahre 2020–2023 · Stand: 2026-11-26**

::: {.takeaway}
**Kurzantwort**

**Vorgehen:** Zuerst entfernt die Altersstandardisierung den Einfluss der unterschiedlichen Altersstruktur der Kreise. Danach beantworten wir drei Fragen nacheinander: **Gibt es einen Unterschied → in welchen Altersgruppen → in welchen Phasen?** Zum Schluss prüfen wir, ob die Ergebnisse auch mit anderen Berechnungsweisen halten.

1. **Hintergrund:** Alle vier Kreistypen erlebten dieselben Wellen; die Wochenraten verlaufen fast synchron (Großstädte und dünn besiedelte ländliche Kreise: r = 0,972). Verglichen wird also, wer *innerhalb derselben Welle* höher oder niedriger liegt.
2. **Frage 1 (Unterschied):** Nach Altersstandardisierung liegen <span class="k k1"></span>Großstädte rund 9 % unter <span class="k k4"></span>dünn besiedelten ländlichen Kreisen (Verhältnis 0,906; 95 %-Intervall 0,879–0,933) und rund 10 % unter <span class="k k3"></span>ländlichen Kreisen mit Verdichtungsansätzen. Zwischen den beiden ländlichen Typen gibt es kaum einen Unterschied (1,005). Die Standardisierung *vergrößert* die Lücke: Großstädte haben mehr junge Erwachsene mit hohen Raten, was ihren Rohwert nach oben drückt.
3. **Wann:** Etwa 95 % der Gesamtlücke entstehen in <span class="w w4"></span>W4 (Delta, Großstädte rund 25 % niedriger) und <span class="w w5"></span>W5 (Omikron, rund 13 % niedriger, aber größte absolute Differenz). In W1–W3 und nach W5 ist kaum ein Unterschied erkennbar.
4. **Frage 2 (Alter):** Die Lücke ist bei 18–39 Jahren am größten (Verhältnis 0,879) und bei älteren Gruppen kleiner. Das ist eine **Altersinteraktion**: Innerhalb gleicher Altersgruppen ist der Stadt-Land-Unterschied verschieden groß – unabhängig von der Altersstruktur.
5. **Frage 3 (Zeit):** In W4 liegen Großstädte in allen Altersgruppen rund 15–35 % niedriger, ohne klares Altersmuster. In W5 konzentriert sich die Lücke auf Jüngere (18–39: −16 %, 70–79: nur −6 %).
6. **Belastbarkeit:** Die Richtung ist unter vier Berechnungsweisen stabil, aber einzelne Kreise überlappen stark. Es handelt sich um Zusammenhänge **gemeldeter Fälle**, die teilweise Test- und Meldeunterschiede widerspiegeln können – keine kausalen Effekte des Wohnorts.
:::

Der Bericht ist nach den drei Forschungsfragen gegliedert. Jede Frage folgt derselben Reihenfolge: **Daten ansehen → quantifizieren → Unsicherheit beurteilen → Robustheit prüfen → interpretieren**. Jeder Abschnitt nennt, wie die Zahlen berechnet wurden und aus welcher Ergebnisdatei sie stammen. Unter jeder Abbildung steht ein Kasten „So liest man …“.

## 1 Forschungsfragen und Lesehilfe

**Frage 1 – Stadt-Land-Unterschied:** Unterscheiden sich die vier Kreistypen nach Altersstandardisierung in der gemeldeten Inzidenz? In welchen Phasen?

- **Was wird verglichen:** Alle Kreistypen paarweise (sechs Paare); zuerst über alle 209 Wochen, dann getrennt nach Phasen (W1–W5, Zwischenphasen, nach W5).
- **Wie:** Für jedes Paar Verhältnis und Differenz; 95 %-Intervalle aus dem Kreis-Cluster-Bootstrap; Holm-Korrektur für multiples Testen.
- **Wo:** Abschnitt 5, [Abb. 8](#fig8)–[Abb. 11](#fig11).

**Frage 2 – Alter:** Ist der Stadt-Land-Unterschied innerhalb aller Altersgruppen gleich groß?

- **Was wird verglichen:** z. B. ob „Großstadt 18–39 vs. Land 18–39“ genauso weit auseinanderliegt wie „Großstadt 70–79 vs. Land 70–79“.
- **Wie:** Altersinteraktion – Verhältnis zweier Verhältnisse (relativ) bzw. Differenz zweier Differenzen (absolut).
- **Wo:** Abschnitt 6, [Abb. 12](#fig12), [Abb. 13](#fig13).

**Frage 3 – Zeit:** Verändern sich der Unterschied und sein Altersmuster zwischen den Wellen?

- **Was wird verglichen:** Altersprofile je Welle; Altersinteraktionen je Phase; Monatsverlauf nach W5.
- **Wie:** Dieselben Maße wie in Frage 2, getrennt nach Phasen.
- **Wo:** Abschnitt 7, [Abb. 14](#fig14)–[Abb. 16](#fig16).

**Zusätzlich:** Abschnitt 4 zeigt, ob die Wellen in allen Kreistypen gleichzeitig verlaufen (Hintergrund); Abschnitt 8 prüft, ob die Ergebnisse mit anderen Berechnungsweisen und auf Ebene einzelner Kreise halten (Robustheit).

**Drei Grundgrößen:**

- **Differenz A − B:** gemeldete Fälle je 100.000 Einwohner und Woche, voneinander abgezogen. Unter 0 heißt: A ist niedriger.
- **Verhältnis A / B** (Inzidenzverhältnis): Unter 1 heißt: A ist niedriger; 0,90 bedeutet 10 % niedriger. Der Bericht stellt Verhältnisse in den Vordergrund, weil sich das Inzidenzniveau zwischen Phasen und Altersgruppen um mehr als das Hundertfache unterscheidet; Differenzen ergänzen.
- **95 %-Intervall:** plausibler Bereich der Schätzung (Herleitung in [Anhang A](#app-a)).

**Farbzuordnung** (in allen Abbildungen und Tabellen gleich):

| <span class="nw">Kreistyp</span> | | <span class="nw">Welle</span> | |
|---|---|---|---|
| <span class="nw"><span class="k k1"></span>Großstadt</span> | <span class="nw">Orangerot</span> | <span class="nw"><span class="w w1"></span>W1</span> | <span class="nw">Dunkelrosa</span> |
| <span class="nw"><span class="k k2"></span>Städtisch</span> | <span class="nw">Gelborange</span> | <span class="nw"><span class="w w2"></span>W2</span> | <span class="nw">Hellrosa</span> |
| <span class="nw"><span class="k k3"></span>Ländlich verdichtet</span> | <span class="nw">Türkisgrün</span> | <span class="nw"><span class="w w3"></span>W3</span> | <span class="nw">Hellblau</span> |
| <span class="nw"><span class="k k4"></span>Ländlich dünn</span> | <span class="nw">Dunkelgrün</span> | <span class="nw"><span class="w w4"></span>W4</span> | <span class="nw">Dunkelblau</span> |
| | | <span class="nw"><span class="w w5"></span>W5</span> | <span class="nw">Violett</span> |
| | | <span class="nw"><span class="w wg"></span>Zwischenphase / <span class="w wp"></span>nach W5</span> | <span class="nw">Hellgrau / Grau</span> |

**Kurznamen:** Großstadt = kreisfreie Großstädte; Städtisch = städtische Kreise; Ländlich verdichtet = ländliche Kreise mit Verdichtungsansätzen; Ländlich dünn = dünn besiedelte ländliche Kreise (BBSR).

Beide Paletten wurden mit dem Palettenprüfskript des dataviz-Skills getestet; benachbarte Farben sind auch bei Farbsehschwäche unterscheidbar. In Tabellen: 🔻 erster Typ niedriger, 🔺 erster Typ höher; ✅ klare Evidenz, ⚠️ Unterschied, aber nach Korrektur nicht belegt, ➖ kein erkennbarer Unterschied.

## 2 Daten und Definitionen

- **Einheit:** gemeldete Fälle je 100.000 Einwohner und Woche. Alle Tabellenwerte sind mittlere *Wochen*inzidenzen, keine Jahresinzidenzen.
- **Stichprobe:** 383 der 400 Kreise mit vollständigen altersspezifischen Nennern in allen Jahren; 209 ISO-Wochen; sieben Altersgruppen (0–5, 6–17, 18–39, 40–59, 60–69, 70–79, 80+).
- **Kreistyp:** BBSR-Typ des jeweiligen ISO-Jahres, nicht fest auf 2023; vier Kreise wechseln den Typ.
- **Gewichtung:** Innerhalb einer Woche zählt jeder Kreis gleich, danach jede Woche gleich. Die Ergebnisse beschreiben also den *typischen Kreis*, nicht die Gesamtbevölkerung (Einwohnersicht in [Abschnitt 8.2](#sec-robust)).

### 2.1 Fehlend ist nicht null – und die Sensitivitätsanalyse „verfügbare Daten“

**Zwei Fälle trennen:** 0 Fälle bei bekannter Bevölkerung → Rate = 0, eine echte Null. Fehlt dagegen der Bevölkerungsnenner, ist die Rate nicht berechenbar (NA) und darf nicht als 0 gelten.

**Hauptanalyse:** Fehlt einem Kreis in irgendeinem Jahr der Nenner einer Altersgruppe, wird er in **allen Jahren** ausgeschlossen. So vergleichen 2020–2023 stets dieselben 383 Kreise, und zeitliche Veränderungen entstehen nicht durch eine wechselnde Stichprobe. Beispiel: Flensburg fehlt 2023 der Nenner für 6–17 Jahre, daher wird der Kreis vollständig ausgeschlossen.

**Sensitivitätsanalyse „verfügbare Daten“:** Statt Kreise ganz auszuschließen, wird **wochenweise** entschieden. Ein Kreis geht in eine Woche ein, wenn alle sieben Nenner gültig sind; in Jahren mit Lücken wird er nicht verwendet. Die Zahl der Kreise je Woche schwankt daher:

| <span class="nw">Jahr</span> | <span class="nw">Kreise je Woche</span> |
|---|---:|
| <span class="nw">2020</span> | <span class="nw">396</span> |
| <span class="nw">2021</span> | <span class="nw">400</span> |
| <span class="nw">2022</span> | <span class="nw">400</span> |
| <span class="nw">2023</span> | <span class="nw">385</span> |

Die 17 in der Hauptanalyse ausgeschlossenen Kreise sind 2021 und 2022 also wieder vollständig dabei.

**Warum 383 in der Hauptanalyse, hier aber 385 für 2023?** Die beiden Zahlen zählen Verschiedenes:

| <span class="nw">Jahr</span> | <span class="nw">Kreise ohne Nenner</span> | Hauptanalyse (durchgehend vollständig) | Verfügbare Daten (wochenweise) |
|---|---:|---|---:|
| <span class="nw">2020</span> | <span class="nw">4</span> | <span class="nw">alle 4 ausgeschlossen</span> | <span class="nw">400 − 4 = 396</span> |
| <span class="nw">2021</span> | <span class="nw">0</span> | <span class="nw">—</span> | <span class="nw">400</span> |
| <span class="nw">2022</span> | <span class="nw">0</span> | <span class="nw">—</span> | <span class="nw">400</span> |
| <span class="nw">2023</span> | <span class="nw">15</span> | <span class="nw">alle 15 ausgeschlossen</span> | <span class="nw">400 − 15 = 385</span> |
| <span class="nw">**2020–2023**</span> | <span class="nw">**17 verschiedene Kreise**</span> | <span class="nw">**400 − 17 = 383**</span> | |

2020 fehlen 4, 2023 fehlen 15 Kreise; Holzminden und Emden fehlen in beiden Jahren. Verschiedene Kreise also 4 + 15 − 2 = 17. Die Hauptanalyse verlangt Vollständigkeit in allen vier Jahren und schließt alle 17 aus (383); die Variante „verfügbare Daten“ betrachtet nur das jeweilige Jahr, 2023 fehlen also nur 15 (385). Meist fehlt die Gruppe 6–17, vor allem in kleineren kreisfreien Städten (z. B. Flensburg, Neumünster, Ansbach).

**Warum das keine Imputation ist:** Imputation würde fehlende Bevölkerungswerte schätzen. Hier wird nichts geschätzt; die Kreise werden nur in Wochen verwendet, in denen sie berechenbar sind.

**Ergebnis:** Großstadt − Ländlich dünn beträgt in der Hauptanalyse −22,07, mit verfügbaren Daten −21,14 – nur 0,93 Unterschied. Der Ausschluss der 17 Kreise beeinflusst das Ergebnis also kaum. Eine Selektionsverzerrung ist damit aber nicht ausgeschlossen: Wie diese Kreise in den fehlenden Jahren tatsächlich lagen, sehen wir nicht.

### 2.2 Phaseneinteilung und Quelle

W1–W5 stammen aus der dritten Aktualisierung der „Retrospektiven Phaseneinteilung der COVID-19-Pandemie“ des RKI (Tolksdorf, Loenenbach, Buda, Epid. Bull. 38/2022, [Original](https://edoc.rki.de/bitstream/handle/176904/10260/EB-38-2022-Phaseneinteilung.pdf?sequence=1)). Das RKI stützt die Einteilung nicht nur auf Fallzahlen, sondern auf Testzahlen und Positivenanteil, 7-Tage-Inzidenz, ambulante akute Atemwegserkrankungen, Hospitalisierungen und Intensivbelegung, Sentinel-Surveillance und Variantenanteile. Das Projekt behält die Zwischenphasen bei; die Grenzen stehen vorab fest und werden nicht nach Signifikanz gewählt.

| <span class="nw">Bericht</span> | <span class="nw">RKI-Phase</span> | <span class="nw">Zeitraum</span> | <span class="nw">Wochen</span> |
|---|---|---|---:|
| <span class="nw"><span class="w wg"></span>Vor W1</span> | um Phase 0 (sporadische Fälle) | <span class="nw">30.12.2019–01.03.2020</span> | <span class="nw">9</span> |
| <span class="nw"><span class="w w1"></span>W1</span> | <span class="nw">Phase 1: erste Welle</span> | <span class="nw">02.03.–17.05.2020</span> | <span class="nw">11</span> |
| <span class="nw"><span class="w wg"></span>Zw. W1/W2</span> | Phase 2: Sommerplateau 2020 | <span class="nw">18.05.–27.09.2020</span> | <span class="nw">19</span> |
| <span class="nw"><span class="w w2"></span>W2</span> | <span class="nw">Phase 3: zweite Welle</span> | <span class="nw">28.09.2020–28.02.2021</span> | <span class="nw">22</span> |
| <span class="nw"><span class="w w3"></span>W3</span> | Phase 4: dritte Welle (Alpha) | <span class="nw">01.03.–13.06.2021</span> | <span class="nw">15</span> |
| <span class="nw"><span class="w wg"></span>Zw. W3/W4</span> | Phase 5: Sommerplateau 2021 | <span class="nw">14.06.–01.08.2021</span> | <span class="nw">7</span> |
| <span class="nw"><span class="w w4"></span>W4</span> | Phase 6: vierte Welle (Delta) | <span class="nw">02.08.–26.12.2021</span> | <span class="nw">21</span> |
| <span class="nw"><span class="w w5"></span>W5</span> | Phase 7: fünfte Welle (Omikron BA.1/BA.2) | <span class="nw">27.12.2021–29.05.2022</span> | <span class="nw">22</span> |
| <span class="nw"><span class="w wp"></span>Nach W5</span> | ab Phase 8: BA.5-Welle und danach | <span class="nw">30.05.2022–31.12.2023</span> | <span class="nw">83</span> |

W steht für Welle, nicht für Woche. „Nach W5“ beginnt mit der sechsten RKI-Welle (BA.5, Sommer 2022); deren Ende war bei Veröffentlichung noch offen, daher fasst das Projekt die restliche Zeit zusammen. [Abschnitt 7.3](#sec-postw5) zerlegt sie in Monate.

## 3 Altersstandardisierung: warum und wie

### 3.1 Welcher Einfluss entfernt wird

<a id="fig1"></a>

![Abb. 1: Mittlere Wocheninzidenz nach Altersgruppe](../results/Kreistyp_Alter_Zeit/bericht_v2/A01_altersraten.png)

::: {.howto}
**So liest man Abb. 1:** Jeder Balken ist die mittlere Wocheninzidenz einer Altersgruppe 2020–2023 (alle 383 Kreise). 18–39 Jahre: 292,1; 70–79 Jahre: nur 112,3 – etwa das 2,6-Fache. **Ein Kreis mit vielen jungen Erwachsenen hat also eine höhere Gesamtrate, selbst wenn jede Altersgruppe dieselbe Rate wie anderswo hätte.**
:::

<a id="fig2"></a>

![Abb. 2: Altersanteile 2021 nach Kreistyp](../results/Kreistyp_Alter_Zeit/bericht_v2/F0a_altersanteile_2021.png)

::: {.howto}
**So liest man Abb. 2:** Je Altersgruppe vier Balken – der Bevölkerungsanteil dieser Gruppe in den vier Kreistypen. In Großstädten sind 30,7 % zwischen 18 und 39, in dünn besiedelten ländlichen Kreisen nur 23,0 %; ab 60 Jahren ist es umgekehrt.
:::

**Zusammen ergibt das ein Problem:** Großstädte haben mehr junge Erwachsene ([Abb. 2](#fig2)), und junge Erwachsene haben höhere Raten ([Abb. 1](#fig1)). Beim direkten Vergleich der Gesamtraten wird die Großstadtrate durch die junge Bevölkerung **nach oben** und die Landrate durch die ältere Bevölkerung **nach unten** gezogen. Ein Teil des sichtbaren Stadt-Land-Unterschieds entstünde dann nur aus der Altersstruktur.

**Genau diesen Einfluss entfernt die Standardisierung: die unterschiedliche Altersstruktur der Kreise.** Man rechnet so, als hätten alle Kreise dieselbe Altersstruktur. Was danach bleibt, ist der Unterschied „bei gleicher Altersstruktur“.

### 3.2 Berechnung

**Rohrate** = Σ (altersspezifische Rate des Kreises × **eigener** Altersanteil des Kreises)

**Standardisierte Rate** = Σ (altersspezifische Rate des Kreises × **gemeinsamer** Altersanteil)

Der einzige Unterschied sind die Gewichte: Die altersspezifischen Raten bleiben gleich, nur die eigene Altersstruktur wird durch eine gemeinsame ersetzt.

**Schritt 1: Woher die gemeinsamen Anteile kommen.** Die Bevölkerung aller 400 Kreise 2021 wird je Altersgruppe summiert und durch die Gesamtbevölkerung geteilt:

| <span class="nw">Altersgruppe</span> | Bevölkerung 400 Kreise (2021) | <span class="nw">Gemeinsamer Anteil</span> |
|---|---:|---:|
| <span class="nw">0–5</span> | <span class="nw">4.791.475</span> | <span class="nw">5,756 %</span> |
| <span class="nw">6–17</span> | <span class="nw">9.071.784</span> | <span class="nw">10,899 %</span> |
| <span class="nw">18–39</span> | <span class="nw">21.874.710</span> | <span class="nw">26,280 %</span> |
| <span class="nw">40–59</span> | <span class="nw">23.068.610</span> | <span class="nw">27,714 %</span> |
| <span class="nw">60–69</span> | <span class="nw">10.961.970</span> | <span class="nw">13,170 %</span> |
| <span class="nw">70–79</span> | <span class="nw">7.356.914</span> | <span class="nw">8,839 %</span> |
| <span class="nw">80+</span> | <span class="nw">6.111.655</span> | <span class="nw">7,342 %</span> |
| <span class="nw">**Summe**</span> | <span class="nw">**83.237.124**</span> | <span class="nw">**100 %**</span> |

Beispiel 18–39: 21.874.710 ÷ 83.237.124 = 0,2628, also 26,28 %. 2021 wurde gewählt, weil in diesem Jahr alle 400 Kreise vollständige Nenner haben.

**Schritt 2: Standardisierung je Kreis und Woche.** Beispiel München, Woche ab 07.03.2022:

| <span class="nw">Altersgruppe</span> | <span class="nw">Rate München</span> | <span class="nw">× gemeinsamer Anteil</span> | <span class="nw">= Beitrag</span> |
|---|---:|---:|---:|
| <span class="nw">0–5</span> | <span class="nw">903,00</span> | <span class="nw">5,756 %</span> | <span class="nw">51,98</span> |
| <span class="nw">6–17</span> | <span class="nw">2.316,69</span> | <span class="nw">10,899 %</span> | <span class="nw">252,49</span> |
| <span class="nw">18–39</span> | <span class="nw">2.341,60</span> | <span class="nw">26,280 %</span> | <span class="nw">615,37</span> |
| <span class="nw">40–59</span> | <span class="nw">1.673,17</span> | <span class="nw">27,714 %</span> | <span class="nw">463,71</span> |
| <span class="nw">60–69</span> | <span class="nw">846,28</span> | <span class="nw">13,170 %</span> | <span class="nw">111,45</span> |
| <span class="nw">70–79</span> | <span class="nw">607,91</span> | <span class="nw">8,839 %</span> | <span class="nw">53,73</span> |
| <span class="nw">80+</span> | <span class="nw">524,67</span> | <span class="nw">7,342 %</span> | <span class="nw">38,52</span> |
| <span class="nw">**Standardisierte Rate**</span> | | | <span class="nw">**1.587,26**</span> |

Mit Münchens eigener Altersstruktur ergibt sich eine Rohrate von 1.702,69. Die standardisierte Rate ist niedriger, weil München mehr junge Erwachsene hat als die gemeinsame Struktur – dieser „Aufschlag“ fällt weg.

**Schritt 3: Mittelung im Kreistyp.** Je Woche wird das ungewichtete Mittel der standardisierten Raten aller Kreise eines Typs gebildet; anschließend wird über die Wochen einer Phase gemittelt.

**Warum Gewichte aus 400, Analyse mit 383 Kreisen:** Die gemeinsamen Anteile sind nur ein „gemeinsamer Maßstab“ und müssen nicht mit der Analysestichprobe übereinstimmen. Mit Anteilen aus den 383 Kreisen ändert sich Großstadt − Ländlich dünn von −22,0670 auf −22,0701; die größte Änderung unter den sechs Paaren beträgt 0,0034.

### 3.3 Vorher und nachher

<a id="fig3"></a>

![Abb. 3: Mittlere Wocheninzidenz roh und standardisiert](../results/Kreistyp_Alter_Zeit/bericht_v2/F0b_roh_vs_standardisiert.png)

::: {.howto}
**So liest man Abb. 3:** Jeder Kreistyp hat seine Farbe; hell = Rohrate, dunkel = standardisierte Rate. Die y-Achse beginnt bei 200, damit die Unterschiede sichtbar sind. Großstädte sinken durch die Standardisierung, die drei anderen Typen steigen.
:::

**Was „2021“ in der Legende bedeutet:** Alle Balken sind **Mittelwerte über alle 209 Wochen 2020–2023**, keine Werte von 2021. „2021“ gibt nur an, aus welchem Jahr die gemeinsamen Altersanteile stammen (Schritt 1 in 3.2). Alle vier Jahre werden mit demselben Maßstab gewichtet, damit Kreise und Jahre vergleichbar sind.

| Mittlere Wocheninzidenz 2020–2023 | <span class="nw">Roh</span> | <span class="nw">Standardisiert</span> | <span class="nw">Änderung</span> |
|---|---:|---:|---:|
| <span class="nw"><span class="k k1"></span>Großstadt</span> | <span class="nw">215,24</span> | <span class="nw">211,65</span> | <span class="nw">−3,59</span> |
| <span class="nw"><span class="k k2"></span>Städtisch</span> | <span class="nw">223,52</span> | <span class="nw">225,12</span> | <span class="nw">+1,60</span> |
| <span class="nw"><span class="k k3"></span>Ländlich verdichtet</span> | <span class="nw">231,03</span> | <span class="nw">234,91</span> | <span class="nw">+3,88</span> |
| <span class="nw"><span class="k k4"></span>Ländlich dünn</span> | <span class="nw">228,01</span> | <span class="nw">233,71</span> | <span class="nw">+5,70</span> |

**Sechs Paare, roh und standardisiert:**

| <span class="nw">Vergleich</span> | <span class="nw">Differenz roh</span> | <span class="nw">Verhältnis roh</span> | <span class="nw">Differenz std.</span> | <span class="nw">Verhältnis std.</span> | <span class="nw">Bedeutung</span> |
|---|---:|---:|---:|---:|---|
| <span class="nw"><span class="k k1"></span>Großstadt − <span class="k k2"></span>Städtisch</span> | <span class="nw">−8,28</span> | <span class="nw">0,963</span> | <span class="nw">−13,47</span> | <span class="nw">0,940</span> | <span class="nw">🔻 Lücke größer</span> |
| <span class="k k1"></span>Großstadt − <span class="k k3"></span>Ländlich verdichtet | <span class="nw">−15,79</span> | <span class="nw">0,932</span> | <span class="nw">−23,27</span> | <span class="nw">0,901</span> | <span class="nw">🔻 Lücke größer</span> |
| <span class="k k1"></span>Großstadt − <span class="k k4"></span>Ländlich dünn | <span class="nw">−12,77</span> | <span class="nw">0,944</span> | <span class="nw">−22,07</span> | <span class="nw">0,906</span> | <span class="nw">🔻 Lücke größer</span> |
| <span class="k k2"></span>Städtisch − <span class="k k3"></span>Ländlich verdichtet | <span class="nw">−7,51</span> | <span class="nw">0,967</span> | <span class="nw">−9,79</span> | <span class="nw">0,958</span> | <span class="nw">🔻 etwas größer</span> |
| <span class="k k2"></span>Städtisch − <span class="k k4"></span>Ländlich dünn | <span class="nw">−4,49</span> | <span class="nw">0,980</span> | <span class="nw">−8,59</span> | <span class="nw">0,963</span> | <span class="nw">🔻 Lücke größer</span> |
| <span class="k k3"></span>Ländlich verdichtet − <span class="k k4"></span>Ländlich dünn | <span class="nw">+3,02</span> | <span class="nw">1,013</span> | <span class="nw">+1,20</span> | <span class="nw">1,005</span> | <span class="nw">➖ Lücke kleiner</span> |

::: {.takeaway}
**Interpretation:** Bei jedem Vergleich „stärker urban vs. weniger urban“ wird die Lücke durch die Standardisierung größer. Beispiel Großstadt vs. Ländlich dünn: roh 0,944 (5,6 % niedriger), standardisiert 0,906 (9,4 % niedriger). **Die Altersstruktur hat einen Teil des Stadt-Land-Unterschieds verdeckt:** Die junge Bevölkerung hob die Großstadtrate an. Die beiden ländlichen Typen haben ähnliche Altersstrukturen; ihr Unterschied wird kleiner.
:::

**Zwei Dinge auseinanderhalten:** Dieser Abschnitt entfernt die **Altersstruktur** (wie viele Menschen in jeder Altersgruppe leben). Abschnitt 6 untersucht die **Altersinteraktion**: ob der Stadt-Land-Unterschied *innerhalb* gleicher Altersgruppen verschieden groß ist. Das eine ist eine Frage der Gewichte, das andere eine Frage der Unterschiede innerhalb der Altersgruppen.

## 4 Hintergrund: dieselben Wellen

<a id="fig4"></a>

![Abb. 4: Standardisierte Wocheninzidenz (Wurzelskala)](../results/Kreistyp_Alter_Zeit/bericht_v2/F1_wochenverlauf.png)

::: {.howto}
**So liest man Abb. 4:** Jede Linie ist die standardisierte Wocheninzidenz eines Kreistyps. Die farbigen Flächen sind die fünf RKI-Wellen, in denselben Farben wie in allen späteren Abbildungen.
:::

**Warum eine Wurzelskala:** Die Raten reichen von fast 0 bis über 2.000. Auf normaler Skala füllt der W5-Gipfel die ganze Abbildung, und W1–W3 (meist unter 100) liegen flach am Boden. Die Wurzelskala staucht große und spreizt kleine Werte, sodass ruhige Phasen und Gipfel gleichzeitig lesbar sind. Der Preis: Gleiche Abstände auf der y-Achse bedeuten nicht mehr gleiche Fallzahlen – 0 bis 100 ist etwa so hoch wie 1.500 bis 2.000.

<a id="fig5"></a>

![Abb. 5: Dieselben Daten auf linearer Skala](../results/Kreistyp_Alter_Zeit/bericht_v2/F1_wochenverlauf_linear.png)

::: {.howto}
**So liest man Abb. 5:** Dieselben Daten wie Abb. 4, aber mit normaler y-Achse: gleiche Abstände = gleiche Fallzahlen. Hier sieht man sofort, wie groß die Lücke in W4 und W5 in Fällen ist; W1–W3 liegen dagegen am Boden. Beide Abbildungen ergänzen sich: Abb. 4 für die Form jeder Phase, Abb. 5 für die tatsächliche Größenordnung.
:::

### 4.1 Wie die Korrelation berechnet wird

<a id="fig6"></a>

![Abb. 6: Streudiagramm der Wochenwerte](../results/Kreistyp_Alter_Zeit/bericht_v2/F1b_korrelation_streudiagramm.png)

**Rechenschritte:**

1. Je Woche das Mittel der standardisierten Raten der 67 Großstädte und der rund 97 dünn besiedelten ländlichen Kreise – zwei Reihen mit je 209 Wochen.
2. **Niveaukorrelation (links):** Jede Woche ist ein Punkt (x = Land, y = Großstadt); Pearson-r über diese 209 Punkte.
3. **Veränderungskorrelation (rechts):** Zuerst **innerhalb jedes Typs** „diese Woche − Vorwoche“ (208 Werte), dann r zwischen den beiden Veränderungsreihen.

**Beide r sind weder Verhältnis noch Differenz zwischen Stadt und Land:**

- Die Niveau-r misst, ob die beiden Kurven gemeinsam steigen und fallen – auf Basis der Raten selbst.
- Die Veränderungs-r misst, ob die wöchentlichen Anstiege und Rückgänge gleichzeitig auftreten – auf Basis der Differenz zweier Wochen *im selben Typ*, nicht der Stadt-Land-Differenz.

::: {.howto}
**So liest man Abb. 6:** Punktfarbe = Welle. Gestrichelt: y = x (beide gleich), durchgezogen: lineare Anpassung. Je enger die Punkte an einer Geraden liegen, desto näher ist r an 1. Punkte unterhalb der gestrichelten Linie: In dieser Woche lag die Großstadt niedriger (links) bzw. stieg weniger (rechts). Links liegen die W5-Punkte (violett) deutlich darunter.
:::

| <span class="nw">Vergleich</span> | <span class="nw">Niveau-r</span> | <span class="nw">Veränderungs-r</span> |
|---|---:|---:|
| <span class="nw"><span class="k k1"></span>Großstadt / <span class="k k2"></span>Städtisch</span> | <span class="nw">0,993</span> | <span class="nw">0,961</span> |
| <span class="k k1"></span>Großstadt / <span class="k k3"></span>Ländlich verdichtet | <span class="nw">0,977</span> | <span class="nw">0,885</span> |
| <span class="k k1"></span>Großstadt / <span class="k k4"></span>Ländlich dünn | <span class="nw">0,972</span> | <span class="nw">0,874</span> |
| <span class="k k2"></span>Städtisch / <span class="k k3"></span>Ländlich verdichtet | <span class="nw">0,992</span> | <span class="nw">0,956</span> |
| <span class="k k2"></span>Städtisch / <span class="k k4"></span>Ländlich dünn | <span class="nw">0,988</span> | <span class="nw">0,944</span> |
| <span class="k k3"></span>Ländlich verdichtet / <span class="k k4"></span>Ländlich dünn | <span class="nw">0,999</span> | <span class="nw">0,985</span> |

**Warum zusätzlich die Veränderungs-r:** Die Niveau-r wird von wenigen großen Wellen bestimmt (die Punkte oben rechts); laufen die großen Wellen gleichzeitig, ist r automatisch hoch. Die Veränderungs-r ist strenger: Sie fragt, ob Anstiege und Rückgänge Woche für Woche zusammenfallen. Zwischen Großstadt und Land liegt sie niedriger (0,874) als zwischen den beiden ländlichen Typen (0,985) – der Rhythmus der Großstädte weicht also etwas ab.

### 4.2 Drei häufige Missverständnisse

**① Hohe Korrelation heißt nicht gleiches Niveau.** Zwei erfundene Beispiele:

<a id="fig7"></a>

![Abb. 7: Was die Korrelation misst (fiktives Beispiel)](../results/Kreistyp_Alter_Zeit/bericht_v2/A02_korrelation_beispiel.png)

::: {.howto}
**So liest man Abb. 7:** Oben Beispiel 1, unten Beispiel 2; links der Verlauf über 12 Wochen, rechts dieselben 12 Wochen als Streudiagramm (x = A, y = B).

- **Beispiel 1 (r = 1):** B liegt immer 100 über A, steigt und fällt aber exakt mit A. Die Punkte liegen auf einer Geraden, also r = 1 – obwohl die Kurven stets 100 auseinanderliegen. **Hohe Korrelation, verschiedenes Niveau.**
- **Beispiel 2 (r = 0,44):** Beide Kurven sind gleich hoch (mittlere Differenz 0), aber die Gipfel liegen in verschiedenen Wochen. Die Punkte streuen, r = 0,44. **Gleiches Niveau, niedrige Korrelation.**
:::

**Übertragen auf das Projekt:** Großstadt und Land verhalten sich wie Beispiel 1: fast gleicher Verlauf (r = 0,97), aber in W4 und W5 liegt die Großstadtkurve durchgehend darunter. Ein hohes r sagt also nur, dass alle dieselben Wellen erlebten; *wie viel* niedriger die Großstädte liegen, zeigen erst Differenzen und Verhältnisse in Abschnitt 5.

**② Warum keine p-Werte für die Korrelation.** Der übliche Test nimmt 209 unabhängige Beobachtungen an. In Pandemiedaten bestimmt aber die Vorwoche die aktuelle Woche fast vollständig: Die Autokorrelation erster Ordnung der Großstadtraten beträgt 0,973, die der Veränderungen noch 0,699. Die 209 Wochen enthalten also viel weniger unabhängige Information, und Standard-p-Werte wären zu optimistisch.

**③ Was der Block-Bootstrap macht.** Um grob einzuschätzen, wie stabil die Veränderungs-r ist, wird die Reihe in Blöcke von 8 aufeinanderfolgenden Wochen geteilt (Abhängigkeiten innerhalb eines Blocks bleiben erhalten), die Blöcke werden zufällig neu zusammengesetzt und r neu berechnet – 1.999-mal. Für Großstadt / Ländlich dünn liegen die mittleren 95 % bei 0,784–0,963. Auch bei vertauschten Zeitabschnitten bleibt r hoch; „gemeinsames Steigen und Fallen“ ist stabil. Da sich der Pandemierhythmus über die Zeit ändert, ist dieser Bereich kein strenges Konfidenzintervall, sondern nur ein Anhaltspunkt.

## 5 Frage 1: Wann und wo unterscheiden sich die Kreistypen?

### 5.1 Gesamtzeitraum und Phasen: sechs Paare

<a id="fig8"></a>

![Abb. 8: Inzidenzverhältnisse der sechs Paare je Phase](../results/Kreistyp_Alter_Zeit/bericht_v2/F2_verhaeltnis_phasen.png)

**Berechnung:** Für eine Phase wird zuerst je Woche der Typmittelwert berechnet, dann über alle Wochen der Phase gemittelt („mittlere Wocheninzidenz der Phase“); das Verhältnis zweier Typen ist der Quotient. Die 95 %-Intervalle stammen aus dem [Kreis-Cluster-Bootstrap](#app-a).

::: {.howto}
**So liest man Abb. 8:** Sechs Felder für sechs Paare (erster / zweiter Typ). Jede Zeile ist eine Phase in ihrer Wellenfarbe. Punkt = Verhältnis; Linie = 95 %-Intervall, also der Bereich, in dem das wahre Verhältnis unter Berücksichtigung des Stichprobenfehlers plausibel liegt; senkrechte gestrichelte Linie = 1 (gleich hoch).

- **Linie ganz links der 1:** Der gesamte plausible Bereich liegt unter 1; der erste Typ ist eindeutig niedriger.
- **Linie kreuzt die 1:** Es ist nicht klar, welcher Typ höher liegt.
:::

**Was Holm-p bedeutet:** Ein p-Wert misst, wie wahrscheinlich eine so große Lücke wäre, wenn es in Wahrheit keinen Unterschied gäbe; je kleiner, desto weniger zufällig. Wir testen sehr viel auf einmal (z. B. 108 Tests im Gesamtzeitraum) – je mehr Tests, desto eher findet sich zufällig ein kleiner p-Wert. Die Holm-Korrektur vergrößert jeden p-Wert entsprechend der Testzahl; erst wenn er danach unter 0,05 liegt, gilt das Ergebnis als belegt. Details in [Anhang B](#app-b).

**Gesamtzeitraum (2020–2023):**

| <span class="nw">Vergleich</span> | <span class="nw">Differenz std.</span> | <span class="nw">Verhältnis</span> | <span class="nw">95 %-Intervall</span> | <span class="nw">Holm-p</span> | <span class="nw">Bedeutung</span> |
|---|---:|---:|---|---:|---|
| <span class="nw"><span class="k k1"></span>Großstadt / <span class="k k2"></span>Städtisch</span> | <span class="nw">−13,47</span> | <span class="nw">0,940</span> | <span class="nw">0,916–0,965</span> | <span class="nw"><0,001</span> | <span class="nw">🔻✅ rund 6 % niedriger</span> |
| <span class="k k1"></span>Großstadt / <span class="k k3"></span>Ländlich verdichtet | <span class="nw">−23,27</span> | <span class="nw">0,901</span> | <span class="nw">0,874–0,929</span> | <span class="nw"><0,001</span> | <span class="nw">🔻✅ rund 10 % niedriger</span> |
| <span class="k k1"></span>Großstadt / <span class="k k4"></span>Ländlich dünn | <span class="nw">−22,07</span> | <span class="nw">0,906</span> | <span class="nw">0,879–0,933</span> | <span class="nw"><0,001</span> | <span class="nw">🔻✅ rund 9 % niedriger</span> |
| <span class="k k2"></span>Städtisch / <span class="k k3"></span>Ländlich verdichtet | <span class="nw">−9,79</span> | <span class="nw">0,958</span> | <span class="nw">0,934–0,984</span> | <span class="nw">0,096</span> | 🔻⚠️ rund 4 % niedriger; Intervall ohne 1, nach Korrektur nicht belegt |
| <span class="k k2"></span>Städtisch / <span class="k k4"></span>Ländlich dünn | <span class="nw">−8,59</span> | <span class="nw">0,963</span> | <span class="nw">0,938–0,989</span> | <span class="nw">0,326</span> | 🔻⚠️ rund 4 % niedriger; nicht belegt |
| <span class="k k3"></span>Ländlich verdichtet / <span class="k k4"></span>Ländlich dünn | <span class="nw">+1,20</span> | <span class="nw">1,005</span> | <span class="nw">0,975–1,036</span> | <span class="nw">1,000</span> | <span class="nw">➖ fast gleich</span> |

„Nicht belegt“ heißt nicht „gleich“, sondern: Nach so vielen Vergleichen ist die Lücke nicht groß genug, um Zufall auszuschließen.

### 5.2 Warum der Fokus auf Großstadt vs. Ländlich dünn

- **Es ist der Vergleich der Extreme.** Die vier BBSR-Typen sind nach Urbanisierungsgrad geordnet; Großstädte und dünn besiedelte ländliche Kreise liegen an beiden Enden, der Unterschied ist dort am klarsten.
- **Warum nicht gegen den Bundesdurchschnitt:** Der Durchschnitt enthält die Großstädte selbst („Vergleich mit sich selbst“), und er hängt von der Zahl der Kreise je Typ ab (129 städtische Kreise, nur 67 Großstädte). Paarvergleiche sind klarer.
- **Die anderen Paare gehen nicht verloren:** Alle sechs stehen in [Abb. 8](#fig8) und der Tabelle oben. Der Vergleich mit ländlich verdichteten Kreisen ergibt fast dasselbe (0,901); die Wahl des ländlichen Typs ändert das Ergebnis nicht.

### 5.3 Nach Phasen: Großstadt vs. Ländlich dünn

<a id="fig9"></a>

![Abb. 9: Großstadt vs. Ländlich dünn – Verhältnis und Differenz je Phase](../results/Kreistyp_Alter_Zeit/bericht_v2/F2a_phasen_grossstadt_land.png)

::: {.howto}
**So liest man Abb. 9:** Oben Verhältnis und 95 %-Intervall je Phase (1 = gleich), unten die mittlere Differenz (0 = gleich), in Wellenfarben. Auf einen Blick: Nur in W4 und W5 liegt der Punkt klar unter 1 und der Balken klar unter 0.
:::

| <span class="nw">Phase</span> | <span class="nw">Verhältnis</span> | <span class="nw">95 %-Intervall</span> | <span class="nw">mittl. Differenz</span> | Wochen mit <span class="k k1"></span>Großstadt niedriger | <span class="nw">Bedeutung</span> |
|---|---:|---|---:|---:|---|
| <span class="nw"><span class="w w1"></span>W1</span> | <span class="nw">0,942</span> | <span class="nw">0,733–1,209</span> | <span class="nw">−1,05</span> | <span class="nw">54,5 %</span> | <span class="nw">➖ sehr breites Intervall</span> |
| <span class="nw"><span class="w wg"></span>Zw. W1/W2</span> | <span class="nw">2,099</span> | <span class="nw">1,661–2,652</span> | <span class="nw">+4,61</span> | <span class="nw">0 %</span> | 🔺 etwa doppelt, aber nur ~5 Fälle mehr |
| <span class="nw"><span class="w w2"></span>W2</span> | <span class="nw">0,978</span> | <span class="nw">0,876–1,092</span> | <span class="nw">−2,67</span> | <span class="nw">54,5 %</span> | <span class="nw">➖ fast gleich</span> |
| <span class="nw"><span class="w w3"></span>W3</span> | <span class="nw">0,996</span> | <span class="nw">0,893–1,112</span> | <span class="nw">−0,41</span> | <span class="nw">40,0 %</span> | <span class="nw">➖ fast gleich</span> |
| <span class="nw"><span class="w wg"></span>Zw. W3/W4</span> | <span class="nw">1,878</span> | <span class="nw">1,586–2,224</span> | <span class="nw">+5,67</span> | <span class="nw">0 %</span> | 🔺 höher, absolut sehr klein |
| <span class="nw">**<span class="w w4"></span>W4**</span> | <span class="nw">**0,746**</span> | <span class="nw">**0,648–0,859**</span> | <span class="nw">**−58,47**</span> | <span class="nw">**57,1 %**</span> | <span class="nw">🔻✅ **rund 25 % niedriger**</span> |
| <span class="nw">**<span class="w w5"></span>W5**</span> | <span class="nw">**0,873**</span> | <span class="nw">**0,841–0,906**</span> | <span class="nw">**−142,69**</span> | <span class="nw">**68,2 %**</span> | 🔻✅ **rund 13 % niedriger, größte Differenz** |
| <span class="nw"><span class="w wp"></span>Nach W5</span> | <span class="nw">0,980</span> | <span class="nw">0,921–1,043</span> | <span class="nw">−3,56</span> | <span class="nw">37,3 %</span> | ➖ insgesamt nah, monatlich schwankend (7.3) |

::: {.takeaway}
**Drei Ergebnisse:**

1. **Die Gesamtlücke ist im Kern eine W4/W5-Lücke.** Summiert man „mittlere Differenz × Wochen“ über alle Phasen und teilt durch 209, erhält man die Gesamtdifferenz −22,07; rund 95 % davon stammen aus W4 und W5.
2. **Die Zwischenphasen zeigen das Gegenteil, sind aber unwichtig:** Das Verhältnis ist etwa doppelt so hoch, die Raten waren aber so niedrig, dass es absolut nur rund 5 Fälle mehr sind. Bei kleinen Nennern werden Verhältnisse aufgebläht.
3. **Phasenmittel ist nicht jede Woche:** W5 hat die größte mittlere Lücke, aber nur in 68,2 % der Wochen liegt die Großstadt niedriger (Grund im nächsten Abschnitt).
:::

### 5.4 W4 und W5 Woche für Woche

<a id="fig10"></a>

![Abb. 10: W4 und W5 im Wochenverlauf](../results/Kreistyp_Alter_Zeit/bericht_v2/F2b_w4_w5_wochen.png)

::: {.howto}
**So liest man Abb. 10:** Oben die Wocheninzidenz der vier Typen von August 2021 bis Mai 2022; unten jeder Wochenwert geteilt durch den Wert der dünn besiedelten ländlichen Kreise derselben Woche (unter 1 = niedriger als Land). Dunkelblaue Fläche = W4, violette Fläche = W5.

- **W4:** Zu Beginn (Aug.–Sep. 2021, noch niedrige Raten) liegen Großstädte sogar höher, in einzelnen Wochen beim 2,5-Fachen. Von Oktober bis Dezember steigt das Land rasch, die Großstädte fallen auf etwa das 0,6-Fache. Die städtischen Kreise (gelborange) verlaufen fast wie die Großstädte – **W4 ist ein Stadt-Land-Unterschied**, nicht nur ein Großstadteffekt.
- **W5:** In den ersten Wochen (Januar 2022) steigen die Großstädte zuerst und liegen kurz höher (etwa 1,5-fach); ab Februar holt das Land auf und überholt, im Gipfel (Feb.–März) liegen die Großstädte bei etwa dem 0,7-Fachen. Deshalb nur 68,2 % der Wochen niedriger.
:::

Beide Wellen folgen dem Muster „Stadt steigt zuerst, Land später höher“. Das passt zur Deutung „Ausbreitung von der Stadt aufs Land“, kann hier aber nicht belegt werden.

### 5.5 W4 und W5 nach Alter: Verhältnis und Differenz

<a id="fig11"></a>

![Abb. 11: W4 und W5 – Verhältnis und Differenz je Altersgruppe](../results/Kreistyp_Alter_Zeit/bericht_v2/F2c_w4_w5_alter.png)

::: {.howto}
**So liest man Abb. 11:** Je Altersgruppe zwei Punkte, dunkelblau W4, violett W5, mit 95 %-Intervall. Oben (A) das Verhältnis (1 = gleich), unten (B) die Differenz (0 = gleich). Ganz rechts der standardisierte Gesamtwert.
:::

| <span class="k k1"></span>Großstadt vs <span class="k k4"></span>Ländlich dünn | <span class="nw">0–5</span> | <span class="nw">6–17</span> | <span class="nw">18–39</span> | <span class="nw">40–59</span> | <span class="nw">60–69</span> | <span class="nw">70–79</span> | <span class="nw">80+</span> |
|---|---:|---:|---:|---:|---:|---:|---:|
| <span class="nw">W4 Verhältnis</span> | <span class="nw">0,83</span> | <span class="nw">0,86</span> | <span class="nw">0,69</span> | <span class="nw">0,74</span> | <span class="nw">0,72</span> | <span class="nw">0,69</span> | <span class="nw">0,66</span> |
| <span class="nw">W5 Verhältnis</span> | <span class="nw">0,88</span> | <span class="nw">0,89</span> | <span class="nw">**0,84**</span> | <span class="nw">0,89</span> | <span class="nw">0,91</span> | <span class="nw">**0,94**</span> | <span class="nw">0,88</span> |
| <span class="nw">W4 Differenz</span> | <span class="nw">−30</span> | <span class="nw">−63</span> | <span class="nw">−90</span> | <span class="nw">−59</span> | <span class="nw">−35</span> | <span class="nw">−30</span> | <span class="nw">−38</span> |
| <span class="nw">W5 Differenz</span> | <span class="nw">−111</span> | <span class="nw">−211</span> | <span class="nw">**−243**</span> | <span class="nw">−130</span> | <span class="nw">−56</span> | <span class="nw">**−24**</span> | <span class="nw">−53</span> |

::: {.takeaway}
**Interpretation:**

- **W4:** Verhältnisse in allen Altersgruppen 0,66–0,86 – die Großstädte liegen **in jeder Altersgruppe rund 15–35 % niedriger**, ohne klares Altersmuster.
- **W5:** 18–39 Jahre 0,84 (16 % niedriger), 70–79 Jahre 0,94 (nur 6 %). **Die Lücke konzentriert sich auf Jüngere.**
:::

**Warum Verhältnis vor Differenz:** Differenzen wachsen mit dem Inzidenzniveau. In W5 wirkt die Differenz bei 6–17 Jahren (−211) viel größer als bei 0–5 (−111), die Verhältnisse sind aber fast gleich (0,89 und 0,88): In beiden Gruppen liegen Großstädte rund 11 % niedriger; 6–17-Jährige haben nur höhere Raten, sodass derselbe Prozentsatz mehr Fällen entspricht. Das Verhältnis beantwortet „relativ wie viel niedriger“, die Differenz „wie viele Fälle weniger“ – beide sind nützlich und werden gezeigt.

## 6 Frage 2: Ist die Lücke in allen Altersgruppen gleich groß?

Abschnitt 3 hat den Einfluss der **Altersstruktur** entfernt. Hier geht es um etwas anderes: Ist der Stadt-Land-Unterschied **innerhalb derselben Altersgruppe** überall gleich groß? Wenn junge Großstädter 12 % unter jungen Landbewohnern liegen, ältere Großstädter aber nur 3 % unter älteren Landbewohnern, dann „hängt die Lücke vom Alter ab“ – eine **Altersinteraktion**. Sie hat nichts damit zu tun, wie viele Menschen in jeder Altersgruppe leben.

### 6.1 Berechnung der Altersinteraktion

<a id="fig12"></a>

![Abb. 12: Rechenweg der Altersinteraktion](../results/Kreistyp_Alter_Zeit/bericht_v2/F3e_altersinteraktion_rechenweg.png)

::: {.howto}
**So liest man Abb. 12:**

- **A:** Mittlere Wocheninzidenz je Altersgruppe, orangerot = Großstädte, dunkelgrün = dünn besiedelte ländliche Kreise.
- **B:** Quotient (Verhältnis), 1 = gleich.
- **C:** Differenz, 0 = gleich.
:::

Die senkrechten Linien in B und C sind 95 %-Intervalle; rote Zahlen markieren die zwei entscheidenden Altersgruppen.

| <span class="nw">Altersgruppe</span> | <span class="nw"><span class="k k1"></span>Großstadt</span> | <span class="nw"><span class="k k4"></span>Ländlich dünn</span> | <span class="nw">Differenz</span> | <span class="nw">Verhältnis</span> |
|---|---:|---:|---:|---:|
| <span class="nw">0–5</span> | <span class="nw">135,69</span> | <span class="nw">148,53</span> | <span class="nw">−12,84</span> | <span class="nw">0,914</span> |
| <span class="nw">6–17</span> | <span class="nw">276,76</span> | <span class="nw">304,54</span> | <span class="nw">−27,78</span> | <span class="nw">0,909</span> |
| <span class="nw">**18–39**</span> | <span class="nw">**266,14**</span> | <span class="nw">**302,85**</span> | <span class="nw">**−36,71**</span> | <span class="nw">**0,879**</span> |
| <span class="nw">40–59</span> | <span class="nw">234,84</span> | <span class="nw">258,02</span> | <span class="nw">−23,18</span> | <span class="nw">0,910</span> |
| <span class="nw">60–69</span> | <span class="nw">144,66</span> | <span class="nw">153,32</span> | <span class="nw">−8,66</span> | <span class="nw">0,944</span> |
| <span class="nw">**70–79**</span> | <span class="nw">**108,40**</span> | <span class="nw">**112,27**</span> | <span class="nw">**−3,86**</span> | <span class="nw">**0,966**</span> |
| <span class="nw">80+</span> | <span class="nw">136,40</span> | <span class="nw">146,57</span> | <span class="nw">−10,17</span> | <span class="nw">0,931</span> |

**Die Interaktion in drei Schritten:**

1. **Lücke je Altersgruppe:** 18–39: Differenz −36,71, Verhältnis 0,879; 70–79: Differenz −3,86, Verhältnis 0,966.
2. **Absolute Interaktion = Differenz der Differenzen:** −36,71 − (−3,86) = **−32,84**. Sie beantwortet: Um wie viele Fälle je 100.000 und Woche ist der Vorsprung der Großstädte bei Jüngeren größer als bei Älteren? Rund 33 Fälle. 0 hieße: gleich viele Fälle weniger in beiden Gruppen.
3. **Relative Interaktion = Verhältnis der Verhältnisse:** 0,879 ÷ 0,966 = **0,910** (95 %-Intervall 0,884–0,937). 1 hieße: gleicher prozentualer Abstand in beiden Gruppen.

**Wie 0,910 zu lesen ist:** Nicht „Junge infizieren sich 9 % seltener als Alte“, sondern: Der relative Vorsprung der Großstädte ist bei Jüngeren rund 9 % größer als bei Älteren – bei 18–39 rund 12,1 % niedriger, bei 70–79 nur rund 3,4 %.

**Warum auch ein Quotient ein Intervall hat:** Das Verhältnis ist kein feststehender Wert, sondern aus genau diesen 383 Kreisen berechnet. Mit einer anderen, gleichartigen Auswahl von Kreisen ergäbe sich ein etwas anderer Wert. Der [Kreis-Cluster-Bootstrap](#app-a) simuliert genau das: 1.999-mal werden 383 Kreise mit Zurücklegen gezogen und das Verhältnis neu berechnet; die mittleren 95 % bilden das Intervall. Für 18–39 liegt es bei 0,853–0,905 – vollständig unter 1, also kein Zufall. Für 70–79 liegt es bei 0,924–1,010 und berührt die 1; bei Älteren kann die Lücke nahe null sein.

### 6.2 Alle Paare im Überblick

<a id="fig13"></a>

![Abb. 13: Verhältnisse aller Paare je Altersgruppe](../results/Kreistyp_Alter_Zeit/bericht_v2/F3_verhaeltnis_alter.png)

::: {.howto}
**So liest man Abb. 13:** Jedes Feld ist ein Paar; x = Altersgruppe, y = Verhältnis (1 = gleich). Rot = 18–39 Jahre mit Zahlenwert.
:::

::: {.takeaway}
**Interpretation:** In allen drei Großstadtvergleichen (obere Reihe) hat 18–39 das niedrigste Verhältnis (0,917; 0,880; 0,879). Gleich gegen welchen Typ: Der „Jüngeren-Vorsprung“ der Großstädte ist am größten. Ohne Großstadt fehlt dieses Muster; zwischen den beiden ländlichen Typen (unten rechts) liegen alle Altersgruppen nahe 1.
:::

### 6.3 Konsistentes Muster – aber explorativ

Sechs Paare × 21 Altersgruppenpaare = 126 Interaktionen je Skala. Die fünf größten absoluten Interaktionen:

| <span class="nw">Rang</span> | <span class="nw">Paar</span> | <span class="nw">Altersvergleich</span> | <span class="nw">Absolute Interaktion</span> |
|---:|---|---|---:|
| <span class="nw">1</span> | <span class="k k1"></span>Großstadt / <span class="k k4"></span>Ländlich dünn | <span class="nw">18–39 vs. 70–79</span> | <span class="nw">−32,84</span> |
| <span class="nw">2</span> | <span class="k k1"></span>Großstadt / <span class="k k3"></span>Ländlich verdichtet | <span class="nw">18–39 vs. 70–79</span> | <span class="nw">−30,73</span> |
| <span class="nw">3</span> | <span class="k k1"></span>Großstadt / <span class="k k4"></span>Ländlich dünn | <span class="nw">18–39 vs. 60–69</span> | <span class="nw">−28,06</span> |
| <span class="nw">4</span> | <span class="k k1"></span>Großstadt / <span class="k k3"></span>Ländlich verdichtet | <span class="nw">18–39 vs. 80+</span> | <span class="nw">−27,76</span> |
| <span class="nw">5</span> | <span class="k k1"></span>Großstadt / <span class="k k4"></span>Ländlich dünn | <span class="nw">18–39 vs. 80+</span> | <span class="nw">−26,54</span> |

**Warum ein konsistentes Muster:** Alle fünf sind „Großstadt vs. Land“ und alle „18–39 vs. ältere Gruppe“. Wäre es Zufall, stünden oben beliebige Kombinationen von Typen und Altersgruppen; hier zeigen alle auf dasselbe: „junge Erwachsene in Großstädten relativ niedriger“. Auf relativer Skala ist Platz 1 ebenfalls Großstadt / Ländlich dünn, 18–39 vs. 70–79 (0,910).

**Warum trotzdem explorativ:** Wir haben 126 Interaktionen berechnet und dann die größten herausgegriffen. Das Maximum vieler Werte ist durch Zufall oft überhöht (wie der höchste Wurf, wenn 126 Personen je einmal würfeln). Platz 1 ist daher nicht automatisch der sicherste Befund; das Muster sollte in anderen Daten oder Zeiträumen bestätigt werden.

## 7 Frage 3: Ändert sich das Altersmuster über die Zeit?

### 7.1 Altersprofile je Welle

<a id="fig14"></a>

![Abb. 14: Altersprofile je Phase](../results/Kreistyp_Alter_Zeit/bericht_v2/F4a_altersprofil_wellen.png)

::: {.howto}
**So liest man Abb. 14:** Ein Feld je Phase in Wellenfarbe. x = Altersgruppe, y = Verhältnis Großstadt / Ländlich dünn (log. Skala), gestrichelt = 1. Jeder Punkt mit 95 %-Intervall; 18–39 und 70–79 sind hervorgehoben und beschriftet. Zwei Dinge ansehen:

- **Höhe der Linie:** unter der gestrichelten Linie = Großstädte insgesamt niedriger.
- **Neigung der Linie:** flach = gleiche Lücke in allen Altersgruppen; geneigt = Lücke ändert sich mit dem Alter (Altersinteraktion).
:::

**Je Phase:**

- **Gesamtzeitraum:** 18–39 am niedrigsten (0,88), zu den Älteren hin steigend (0,97); leicht geneigt.
- **W2, W3:** umgekehrte Richtung – bei 6–17 liegen Großstädte sogar höher (1,20; 1,27), ältere Gruppen niedriger (W3, 80+: 0,69).
- **W4:** Die ganze Linie liegt tief (0,66–0,86) und eher flach: Alle Altersgruppen niedriger, Lücke ähnlich groß.
- **W5:** 18–39 am niedrigsten (0,84), zu den Älteren steigend (0,94), deutlich geneigt: Lücke konzentriert sich auf Jüngere.
- **Nach W5:** nahe 1, ältere Gruppen leicht darüber.

### 7.2 Altersinteraktionen der Phasen in einer Abbildung

<a id="fig15"></a>

![Abb. 15: Jüngere vs. Ältere je Phase](../results/Kreistyp_Alter_Zeit/bericht_v2/F4b_altersinteraktion_phasen.png)

::: {.howto}
**So liest man Abb. 15:** Je Phase ein senkrechter Balken; gefüllter Punkt = Verhältnis bei 18–39, offener Punkt = bei 70–79 (jeweils Großstadt / Ländlich dünn). Die Zahl „÷ = …“ ist der Quotient beider, also die relative Interaktion.

- **Gefüllt unten, offen oben, langer Balken:** Die Lücke ist bei Jüngeren größer, ÷ < 1.
- **Kurzer Balken:** ähnliche Lücke in beiden Gruppen, ÷ ≈ 1.
- **Gefüllt oben:** umgekehrt, die Lücke ist bei Jüngeren kleiner, ÷ > 1.
:::

::: {.takeaway}
**Ergebnis:** W5 hat den längsten Balken mit gefülltem Punkt unten (÷ = 0,90); in W4 fallen beide Punkte fast zusammen (÷ = 1,01), obwohl beide tief liegen; in W1–W3 liegt der gefüllte Punkt oben (÷ > 1).
:::

**Relative und absolute Interaktion noch einmal:**

- **Relativ** (÷) vergleicht prozentuale Abstände: um wie viel Prozent die Großstadt bei Jüngeren bzw. Älteren niedriger liegt.
- **Absolut** vergleicht Fallzahlen: wie viele Fälle weniger bei Jüngeren bzw. Älteren.

Beide können auseinanderfallen. In W4 ist die absolute Interaktion −60 (bei Jüngeren mehr Fälle weniger), die relative aber ≈ 1 (gleicher Prozentsatz): Alle Altersgruppen liegen rund 30 % niedriger, nur entsprechen 30 % bei den höheren Raten der Jüngeren mehr Fällen (siehe [Abb. 11](#fig11)).

| <span class="nw">Phase</span> | <span class="nw">Absolute Interaktion</span> | <span class="nw">Holm-p</span> | <span class="nw">Relative Interaktion</span> | <span class="nw">95 %-Intervall</span> | <span class="nw">Holm-p</span> |
|---|---:|---:|---:|---|---:|
| <span class="nw"><span class="w w1"></span>W1</span> | <span class="nw">3,43</span> | <span class="nw">1,000</span> | <span class="nw">1,228</span> | <span class="nw">1,020–1,478</span> | <span class="nw">1,000</span> |
| <span class="nw"><span class="w wg"></span>Zw. W1/W2</span> | <span class="nw">5,16</span> | <span class="nw"><0,001</span> | <span class="nw">0,969</span> | <span class="nw">0,733–1,280</span> | <span class="nw">1,000</span> |
| <span class="nw"><span class="w w2"></span>W2</span> | <span class="nw">6,15</span> | <span class="nw">1,000</span> | <span class="nw">1,075</span> | <span class="nw">1,013–1,141</span> | <span class="nw">1,000</span> |
| <span class="nw"><span class="w w3"></span>W3</span> | <span class="nw">1,95</span> | <span class="nw">1,000</span> | <span class="nw">1,088</span> | <span class="nw">1,003–1,180</span> | <span class="nw">1,000</span> |
| <span class="nw"><span class="w wg"></span>Zw. W3/W4</span> | <span class="nw">8,04</span> | <span class="nw"><0,001</span> | <span class="nw">0,788</span> | <span class="nw">0,563–1,101</span> | <span class="nw">1,000</span> |
| <span class="nw"><span class="w w4"></span>W4</span> | <span class="nw">−59,77</span> | <span class="nw">0,009</span> | <span class="nw">1,008</span> | <span class="nw">0,948–1,072</span> | <span class="nw">1,000</span> |
| <span class="nw"><span class="w w5"></span>W5</span> | <span class="nw">−219,16</span> | <span class="nw"><0,001</span> | <span class="nw">0,899</span> | <span class="nw">0,865–0,935</span> | <span class="nw"><0,001</span> |
| <span class="nw"><span class="w wp"></span>Nach W5</span> | <span class="nw">−13,79</span> | <span class="nw">1,000</span> | <span class="nw">0,918</span> | <span class="nw">0,884–0,954</span> | <span class="nw">0,022</span> |

**Warum auch hier Holm-Korrektur:** Die phasenspezifischen Altersinteraktionen umfassen 2.268 Tests (6 Paare × 21 Altersgruppenpaare × 9 Phasen × 2 Skalen). Selbst wenn nirgends ein Unterschied bestünde, wären bei 5 % rund 113 zufällig „signifikant“. Die Holm-Korrektur filtert diese Zufallstreffer. In W2 und W3 schließen die Intervalle die 1 zwar aus, nach Korrektur ist p aber 1 – bei so vielen Tests ist ein Unterschied dieser Größe gut mit Zufall vereinbar.

::: {.takeaway}
**Ergebnis:**

- **W5** zeigt auf beiden Skalen Evidenz: Die Stadt-Land-Lücke ist bei Jüngeren klar größer als bei Älteren.
- **W4** nur auf der absoluten Skala; prozentual sind die Altersgruppen ähnlich.
- **Nach W5** nur auf der relativen Skala (p = 0,022).
- **Direkter Vergleich W4 vs. W5:** Änderung der absoluten Interaktion +159,39 (Holm-p < 0,001), der relativen 1,121 (Holm-p = 1). Aus „W5 signifikant, W4 nicht“ folgt noch kein Unterschied – dafür braucht es diesen direkten Vergleich.
:::

### 7.3 Die 83 Wochen nach W5 {#sec-postw5}

<a id="fig16"></a>

![Abb. 16: Monatliche mittlere Wocheninzidenz nach W5](../results/Kreistyp_Alter_Zeit/bericht_v2/F4c_monate_nach_w5.png)

::: {.howto}
**So liest man Abb. 16:** Eine Linie je Kreistyp, ein Punkt je Monat (offene Punkte = unvollständige Monate). Der Gipfel Juni–Juli 2022 ist die sechste RKI-Welle (BA.5); im Oktober folgt ein Herbstgipfel.
:::

| <span class="nw">Monat</span> | <span class="nw"><span class="k k1"></span>Großstadt</span> | <span class="nw"><span class="k k4"></span>Ländlich dünn</span> | <span class="nw">Differenz</span> | <span class="nw">Bedeutung</span> |
|---|---:|---:|---:|---|
| <span class="nw">Juni 2022</span> | <span class="nw">572,79</span> | <span class="nw">510,62</span> | <span class="nw">+62,18</span> | BA.5-Beginn, Großstadt steigt zuerst |
| <span class="nw">Juli 2022</span> | <span class="nw">681,74</span> | <span class="nw">733,07</span> | <span class="nw">−51,33</span> | <span class="nw">Gipfel, Land höher</span> |
| <span class="nw">Sep. 2022</span> | <span class="nw">311,28</span> | <span class="nw">379,87</span> | <span class="nw">−68,59</span> | <span class="nw">Großstadt niedriger</span> |
| <span class="nw">Okt. 2022</span> | <span class="nw">528,12</span> | <span class="nw">597,99</span> | <span class="nw">−69,87</span> | Herbstgipfel, Großstadt niedriger |
| <span class="nw">Dez. 2022</span> | <span class="nw">252,20</span> | <span class="nw">219,42</span> | <span class="nw">+32,78</span> | <span class="nw">Großstadt höher</span> |
| <span class="nw">Feb. 2023</span> | <span class="nw">120,45</span> | <span class="nw">106,10</span> | <span class="nw">+14,35</span> | <span class="nw">Großstadt höher</span> |
| <span class="nw">Nov. 2023</span> | <span class="nw">36,10</span> | <span class="nw">46,64</span> | <span class="nw">−10,54</span> | <span class="nw">Großstadt niedriger</span> |

::: {.takeaway}
**Ergebnis:** „Nach W5“ hat insgesamt ein Verhältnis von 0,980 und wirkt fast ohne Lücke; tatsächlich wechselt die Richtung mehrfach, und Plus und Minus heben sich auf. Auch die BA.5-Welle folgt dem Muster „Stadt zuerst, Land später höher“. Monate werden nach dem Montag der Woche zugeordnet; Mai 2022 enthält nur die Woche ab 30. Mai.
:::

## 8 Wie robust und wie einheitlich sind die Ergebnisse?

### 8.1 Unterschiede zwischen Kreisen desselben Typs

<a id="fig17"></a>

![Abb. 17: Verteilung über die Kreise](../results/Kreistyp_Alter_Zeit/bericht_v2/F5_kreisverteilung.png)

**Berechnung:** Je Kreis das Mittel seiner standardisierten Wochenraten in der Phase – ein Punkt je Kreis.

::: {.howto}
**So liest man Abb. 17:** Box = mittlere 50 % der Kreise, Strich = Median, weiße Raute = Typmittel der Hauptanalyse, grün gepunktet = Median der dünn besiedelten ländlichen Kreise. Jede Phase hat ihre eigene y-Skala.
:::

| <span class="nw">Phase</span> | <span class="nw">Typ</span> | <span class="nw">Kreise</span> | <span class="nw">Median</span> | <span class="nw">mittlere 50 %</span> | <span class="nw">Min.–Max.</span> |
|---|---|---:|---:|---|---|
| <span class="nw"><span class="w w4"></span>W4</span> | <span class="nw"><span class="k k1"></span>Großstadt</span> | <span class="nw">67</span> | <span class="nw">158,4</span> | <span class="nw">129,9–204,4</span> | <span class="nw">82,7–424,6</span> |
| <span class="nw"><span class="w w4"></span>W4</span> | <span class="nw"><span class="k k4"></span>Ländlich dünn</span> | <span class="nw">97</span> | <span class="nw">208,4</span> | <span class="nw">130,6–300,5</span> | <span class="nw">53,4–554,6</span> |
| <span class="nw"><span class="w w5"></span>W5</span> | <span class="nw"><span class="k k1"></span>Großstadt</span> | <span class="nw">67</span> | <span class="nw">975,9</span> | <span class="nw">911,4–1.037,6</span> | <span class="nw">637,6–1.347,8</span> |
| <span class="nw"><span class="w w5"></span>W5</span> | <span class="nw"><span class="k k4"></span>Ländlich dünn</span> | <span class="nw">97</span> | <span class="nw">1.114,9</span> | <span class="nw">1.013,2–1.209,8</span> | <span class="nw">252,6–1.410,5</span> |
| <span class="nw"><span class="w wp"></span>Nach W5</span> | <span class="nw"><span class="k k1"></span>Großstadt</span> | <span class="nw">67</span> | <span class="nw">175,0</span> | <span class="nw">158,4–196,6</span> | <span class="nw">101,6–229,2</span> |
| <span class="nw"><span class="w wp"></span>Nach W5</span> | <span class="nw"><span class="k k4"></span>Ländlich dünn</span> | <span class="nw">96</span> | <span class="nw">178,1</span> | <span class="nw">147,5–212,3</span> | <span class="nw">83,6–273,8</span> |

**Zwei anschaulichere Kennzahlen:**

| <span class="nw">Phase</span> | Anteil der <span class="k k1"></span>Großstadt-Kreise über dem Landmedian | P(zufällige Großstadt < zufälliger Landkreis) |
|---|---:|---:|
| <span class="nw"><span class="w w4"></span>W4</span> | <span class="nw">22,4 %</span> | <span class="nw">62,3 %</span> |
| <span class="nw"><span class="w w5"></span>W5</span> | <span class="nw">7,5 %</span> | <span class="nw">77,5 %</span> |
| <span class="nw"><span class="w wp"></span>Nach W5</span> | <span class="nw">47,8 %</span> | <span class="nw">52,0 %</span> |

Ohne Unterschied lägen beide Werte bei etwa 50 %. Die 77,5 % in W5 heißen: Zieht man zufällig eine Großstadt und einen dünn besiedelten Landkreis, liegt die Großstadt in rund drei von vier Fällen niedriger.

::: {.takeaway}
**Ergebnis:** W5 trennt am klarsten; nur 5 der 67 Großstädte liegen über dem Landmedian. In W4 ist der Medianabstand groß, die Landkreise streuen aber stark, sodass eine zufällige Großstadt nur mit 62 % niedriger liegt. Nach W5 kaum Unterschied. „Großstädte niedriger“ gilt also im Mittel; ein einzelner Landkreis liegt nicht zwingend über einer bestimmten Großstadt.
:::

### 8.2 Hält das Ergebnis mit anderer Berechnung? {#sec-robust}

<a id="fig18"></a>

![Abb. 18: Verhältnisse unter vier Berechnungsweisen](../results/Kreistyp_Alter_Zeit/bericht_v2/F6_robustheit.png)

**Die vier Varianten unterscheiden sich nur darin, wie der wöchentliche Typwert gebildet wird:**

| <span class="nw">Variante</span> | <span class="nw">Wöchentlicher Typwert</span> | <span class="nw">Datenquelle</span> | <span class="nw">Beantwortete Frage</span> |
|---|---|---|---|
| <span class="nw">Hauptanalyse</span> | arithm. Mittel der standardisierten Raten der 383 Kreise | `weekly_district_rates.csv` (mean) | <span class="nw">typischer Kreis</span> |
| <span class="nw">Median</span> | <span class="nw">Median der 383 Kreise</span> | <span class="nw">dieselbe (median)</span> | getrieben von wenigen Extremkreisen? |
| Alle verfügbaren Kreis-Wochen | Mittel aller Kreise mit gültigem Nenner in der Woche (s. 2.1) | `sensitivity_available_annual_types.csv` | Verzerrung durch Ausschluss der 17 Kreise? |
| <span class="nw">Bevölkerungsgewichtet</span> | Σ (Einwohner × Rate) ÷ Σ Einwohner | Rohdaten `kreis_weekly_age_kreistyp_2020_2023.rds` | Lage der durchschnittlichen Einwohnerin |

**Gemeinsame Folgeschritte:** Mittel über alle Wochen der Phase (jede Woche gleich) → Quotient zweier Typen. Die Einwohnerzahl ist die Summe der sieben Altersgruppen des Kreises; die Kreisraten sind weiterhin mit den gemeinsamen Anteilen standardisiert.

**Kontrolle:** Mit demselben Code und Gleichgewichtung neu berechnet, weicht das Ergebnis um weniger als 10⁻¹⁴ von der Hauptanalyse ab. Standardisierung und Gruppierung stimmen also überein; Unterschiede entstehen nur durch die Gewichte.

::: {.howto}
**So liest man Abb. 18:** Jede Zeile ist ein Paar, vier Symbole für vier Varianten; drei Felder für Gesamtzeitraum, W4 und W5. Liegen alle vier Punkte links der gestrichelten Linie, ändert die Berechnungsweise die Richtung nicht.
:::

| <span class="k k1"></span>Großstadt / <span class="k k4"></span>Ländlich dünn | <span class="nw">Gesamt</span> | <span class="nw">W4</span> | <span class="nw">W5</span> |
|---|---:|---:|---:|
| <span class="nw">Hauptanalyse</span> | <span class="nw">0,906</span> | <span class="nw">0,746</span> | <span class="nw">0,873</span> |
| <span class="nw">Median</span> | <span class="nw">0,932</span> | <span class="nw">0,798</span> | <span class="nw">0,871</span> |
| Alle verfügbaren Kreis-Wochen | <span class="nw">0,909</span> | <span class="nw">0,759</span> | <span class="nw">0,878</span> |
| <span class="nw">Bevölkerungsgewichtet</span> | <span class="nw">0,886</span> | <span class="nw">0,771</span> | <span class="nw">0,856</span> |

::: {.takeaway}
**Interpretation:**

- **Stabile Richtung:** Großstädte gegenüber beiden ländlichen Typen liegen im Gesamtzeitraum, in W4 und W5 unter allen vier Varianten unter 1.
- **Median näher an 1 (0,932):** Mit dem Median liegen Großstädte nur rund 7 % niedriger statt 9 %. Vermutlich vergrößern einige Landkreise mit sehr hohen Raten den Mittelwert – passend zum langen oberen Rand der Landverteilung in [Abb. 17](#fig17).
- **Bevölkerungsgewichtet etwas größer (0,886):** Aus Sicht der Einwohner liegt die Rate in Großstädten rund 11 % unter der auf dem Land.
- **Einziger nicht robuster Wert:** W4, Großstadt / Städtisch, wechselt bevölkerungsgewichtet von 0,981 auf 1,042 – keine belastbare Aussage.
:::

## 9 Interpretation und Grenzen

**Mögliche Erklärungen** (hier nicht trennbar):

- unterschiedliches Test- und Meldeverhalten, besonders in der Omikronphase (W5) und nach den Änderungen der Teststrategie 2022;
- zeitlich versetzte Epidemieverläufe: In W4, W5 und der BA.5-Welle steigen Städte zuerst, das Land liegt später höher ([Abb. 10](#fig10), [Abb. 16](#fig16));
- Unterschiede in Verhalten oder Exposition junger Erwachsener in Stadt und Land.

**Grenzen:**

- Gemeldete Fälle sind nicht alle Infektionen; Änderungen der Teststrategie betreffen gerade die Phasen mit der größten Lücke.
- Altersnenner aus RKI-Daten rekonstruiert, noch nicht mit amtlicher Bevölkerungsstatistik abgeglichen; 17 Kreise fehlen; Fälle unbekannten Alters nicht berücksichtigt.
- Jährliche Typzuordnung: Die Zusammensetzung der Gruppen ändert sich.
- Der Kreis-Bootstrap berücksichtigt Abhängigkeiten innerhalb eines Kreises, nicht aber räumliche Korrelation benachbarter Kreise.
- Die 383 Kreise sind keine Zufallsstichprobe; Inferenz ist explorativ. Aussagen gelten auf Kreisebene, nicht für Individuen.

## 10 Fazit

| <span class="nw">Frage</span> | <span class="nw">Antwort</span> | <span class="nw">Beleg</span> |
|---|---|---|
| <span class="nw">Frage 1</span> | Nach Altersstandardisierung liegen Großstädte rund 9–10 % unter ländlichen Kreisen – fast nur in W4 und W5. | [Abb. 8](#fig8), [Abb. 9](#fig9), [Abb. 10](#fig10); rund 95 % der Gesamtlücke aus diesen Wellen |
| <span class="nw">Frage 2</span> | Die Lücke ist bei 18–39 am größten, bei 70–79 am kleinsten; das ist eine Altersinteraktion, kein Effekt der Altersstruktur. | [Abb. 12](#fig12), [Abb. 13](#fig13); relative Interaktion 0,910 |
| <span class="nw">Frage 3</span> | W4: alle Altersgruppen niedriger; W5: vor allem Jüngere. Für „wann und für wen“ müssen Phase und Skala immer mit angegeben werden. | [Abb. 11](#fig11), [Abb. 14](#fig14), [Abb. 15](#fig15) |
| <span class="nw">Robustheit</span> | Die Richtung Großstadt vs. Land ist unter vier Varianten stabil, einzelne Kreise überlappen aber stark. | <span class="nw">[Abb. 17](#fig17), [Abb. 18](#fig18)</span> |

## Anhang

### Anhang A: Kreis-Cluster-Bootstrap {#app-a}

**Welches Problem er löst:** Wir beobachten nur diese 383 Kreise. Mit einer anderen, gleichartigen Auswahl wären Verhältnisse und Differenzen etwas anders. Der Bootstrap simuliert „eine andere Auswahl von Kreisen“ und zeigt, wie stark die Ergebnisse schwanken.

**Vorgehen:**

1. Aus den 383 Kreisen werden 383 **mit Zurücklegen** gezogen (manche doppelt, manche gar nicht), 1.999-mal (Seed 20261123).
2. Jeder gezogene Kreis bringt seine **gesamte** Historie mit: alle Wochen, alle Altersgruppen, die jährliche Typzuordnung. Abhängigkeiten zwischen Wochen desselben Kreises bleiben so erhalten.
3. Für jede Ziehung werden wöchentliche Typmittel und alle Vergleiche neu berechnet.
4. Die Standardabweichung der 1.999 Ergebnisse ist der Standardfehler; 95 %-Intervall = Schätzwert ± 1,96 × Standardfehler. Verhältnisse werden auf der Log-Skala berechnet und zurücktransformiert.

**Wo er verwendet wird:** alle 95 %-Intervalle in [Abb. 8](#fig8), 9, 10, 11, 12 sowie alle Intervalle und p-Werte in den Tabellen.

**Grenze:** Abhängigkeiten innerhalb eines Kreises bleiben erhalten, Kreise gelten aber als unabhängig voneinander. Benachbarte Kreise verlaufen oft ähnlich; die Intervalle können daher zu schmal sein, die Inferenz ist explorativ.

### Anhang B: Holm-Korrektur für multiples Testen {#app-b}

**Das Problem:** p < 0,05 gilt üblicherweise als „statistisch belegt“. Auch ohne jeden echten Unterschied tritt das aber in 5 % der Fälle zufällig auf. Bei einem Test ist das akzeptabel; bei 100 Tests entstehen im Mittel rund 5 rein zufällige „signifikante“ Ergebnisse.

**Holm-Verfahren:**

1. Die p-Werte einer Testfamilie aufsteigend sortieren;
2. der kleinste muss unter 0,05 ÷ Testzahl liegen, der zweitkleinste unter 0,05 ÷ (Testzahl − 1) usw.;
3. sobald einer die Schwelle verfehlt, gelten er und alle folgenden als „nicht belegt“.

„Holm-p“ im Bericht ist der umgerechnete p-Wert, direkt mit 0,05 vergleichbar.

**Kleines Beispiel (keine Projektergebnisse):** drei Tests mit p = 0,01; 0,03; 0,04.

- 0,01 × 3 = 0,03 < 0,05 → belegt;
- 0,03 × 2 = 0,06 > 0,05 → nicht belegt;
- 0,04 damit ebenfalls nicht belegt (umgerechnet 0,06).

**Testfamilien im Projekt:**

| <span class="nw">Familie</span> | <span class="nw">Tests</span> | <span class="nw">kleinstes p muss unter</span> |
|---|---:|---:|
| Paarvergleiche Gesamtzeitraum | 108 (6 Paare × 9 Maße × 2 Skalen) | <span class="nw">0,00046</span> |
| Altersinteraktionen Gesamtzeitraum | <span class="nw">252</span> | <span class="nw">0,00020</span> |
| Altersinteraktionen nach Phase | <span class="nw">2.268</span> | <span class="nw">0,000022</span> |

Die 95 %-Intervalle in den Abbildungen sind punktweise, nicht Holm-korrigiert. Daher kann ein Intervall die 1 ausschließen, ohne dass Holm-p signifikant ist (z. B. Städtisch / Ländlich verdichtet in 5.1).

### Anhang C: Dateien und Reproduktion

- **Alle Vergleiche:** `results/Kreistyp_Alter_Zeit/pairwise_contrasts.csv`, `age_interactions.csv`, `age_period_interactions.csv`.
- **Neu für diesen Bericht:** `results/Kreistyp_Alter_Zeit/bericht_v2/` (Abbildungen, bevölkerungsgewichtete Sensitivität, Kreisverteilungen).
- **Reihenfolge:** `run_analysis.R` → `erweiterte_analyse.R` → `alter_zeit_korrelation.R` → `bericht_v2.R` → `bericht_v2_details.R` (alle in `Scripts/Kreistyp_Alter_Zeit/`).
- **Offen:** Regressionsmodell als Vergleichsschätzung; Abgleich mit amtlichen Bevölkerungsdaten; Anteil der Fälle unbekannten Alters je Typ.
