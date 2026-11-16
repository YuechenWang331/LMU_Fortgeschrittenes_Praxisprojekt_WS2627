# Modellwahl

## 1. Basismodell: Poisson-Regression

**Warum Poisson?**

- COVID-19-Fallzahlen sind Zähldaten (*Count* ).
- Unterschiedliche Bevölkerungsgrößen können durch einen **Offset** berücksichtigt werden.
- Kovariaten und Interaktionseffekte können untersucht werden.
- Einfache Implementierung in R mit `glm()`.

### Modellgleichung (wöchentliche Daten)

$$
Y_{igt} \sim \operatorname{Poisson}(\mu_{igt})
$$

$$
\begin{aligned}
\log(\mu_{igt}) ={}&
\log(P_{igt}) + \beta_0 \\
&+ \beta_1 \mathrm{Altersgruppe}_g \\
&+ \beta_2 \mathrm{Urbanisierung}_i \\
&+ \beta_3(\mathrm{Altersgruppe}_g \times \mathrm{Urbanisierung}_i) \\
&+ \boldsymbol{\gamma}^{T}\mathbf{X}_{it}
+ \delta_t
\end{aligned}
$$

**Notation:**

- $i$: Landkreis
- $g$: Altersgruppe
- $t$: Kalenderwoche (Jahr und Woche)
- $Y_{igt}$: Gemeldete COVID-19-Fälle
- $\mu_{igt}$: Erwartete Fallzahl
- $P_{igt}$: Bevölkerung der jeweiligen Altersgruppe im Landkreis
- $\mathbf{X}_{it}$: Weitere regionale Kovariaten
- $\delta_t$: Gemeinsamer Wocheneffekt

**Warum ein Offset?**

Mit `log(Population)` als Offset modellieren wir die **Inzidenzrate statt der absoluten Fallzahl**:

$$
\log(\mu_i) = \log(P_i) + X_i\beta
$$

Dies entspricht:

$$
\log\left(\frac{\mu_i}{P_i}\right)=X_i\beta
$$

Damit modellieren wir die **Inzidenzrate statt der absoluten Fallzahl**. Der Koeffizient des Offsets ist fest auf 1 gesetzt.

**Mögliche Kovariaten (nach André):**

- Pendlerquote

- Arbeitslosenquote

- Einkommen

- Weitere regionale Strukturmerkmale

## 2. Limitationen und mögliche Erweiterungen

**2.1 Overdispersion**

Bei COVID-19-Fallzahlen kann die Varianz größer als der Erwartungswert sein.

- Poisson-Annahme: $\operatorname{Var}(Y)=E(Y)$

  → Mögliche Erweiterung: **Quasi-Poisson-Regression**

**2.2 Abhängigkeit innerhalb der Landkreise**

Wöchentliche Beobachtungen desselben Landkreises sind möglicherweise korreliert.

→ Mögliche Erweiterung: **Mixed-Effects-Modell mit Random Intercept für Landkreis**. Eine zeitliche Autokorrelation muss gegebenenfalls zusätzlich berücksichtigt werden.

**2.3 Zeitliche Dynamik**

Der Wocheneffekt $\delta_t$ berücksichtigt allgemeine zeitliche Schwankungen der Inzidenz, jedoch keine altersgruppen- oder regionsspezifischen Zeitverläufe.

→ Mögliche Erweiterung: **Interaktionen mit der Zeit**, um Veränderungen der Zusammenhänge zu untersuchen.

**3.4 Weitere Einschränkungen**

- Unterschiedliche Test- und Meldepraktiken zwischen Regionen und Jahren.
- Mögliche Multikollinearität zwischen regionalen Kovariaten.
- Keine direkten kausalen Schlussfolgerungen aus regionalen Zusammenhängen.

## 3. Vorgehensweise

1.  **Bisherige Beobachtungen (done):**
    - **Zeitverlauf:** Starke zeitliche Schwankungen der COVID-19-Inzidenz, insbesondere im Jahr 2022.

    - **Altersgruppen:** Unterschiedliche Inzidenzmuster je nach Alter. Altersgruppen bilden diese Unterschiede nicht immer vollständig ab.

    - **Kreistypen:** Kreistypen: Insgesamt ähnliche zeitliche Inzidenzverläufe, jedoch unterschiedlich starke und im Zeitverlauf schwankende Abweichungen zwischen den Kreistypen.

    - **Urbanisierungsgrad (BBSR-Location Type, sehr zentral bis sehr peripher):** Insgesamt ähnliche zeitliche Inzidenzverläufe zwischen den vier Location Types

    - **Urbanisierungsgrad × Altersgruppe:** Die aggregierten Inzidenzverläufe der vier Urbanisierungstypen unterscheiden sich innerhalb der Altersgruppen überwiegend nur geringfügig.
2.  **Poisson GLM:** Basismodell mit Altersgruppe, Urbanisierungsgrad, Interaktion und Wocheneffekt.
3.  **Kovariaten:** Weitere regionale Strukturmerkmale schrittweise ergänzen.
4.  **Modelldiagnostik:** Overdispersion, Residuen und Abhängigkeiten prüfen.
5.  **Modellerweiterung:** Ggf. Negative Binomial Regression, Mixed-Effects-Modell oder zeitliche Interaktionen.
6.  **Sensitivitätsanalyse:** Alternative Altersgruppierungen, Zeiträume und Kovariaten vergleichen.
