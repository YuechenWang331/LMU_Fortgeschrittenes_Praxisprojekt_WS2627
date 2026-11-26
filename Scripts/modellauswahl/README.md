# Skripte Modellauswahl

Pipeline von den Rohdaten bis zum **Modellvorschlag A1** und den Alternativen (Option D, Option III, A1 mit zwei Kreis-Faktoren). Das Modell ist in der Gruppe noch nicht entschieden.
**Arbeitsstand mit Abbildungen, gelösten und offenen Problemen und allen verworfenen Wegen:** [`reports/modellauswahl/Modellauswahl_Gesamtbericht.md`](../../reports/modellauswahl/Modellauswahl_Gesamtbericht.md).

Alle Skripte werden aus dem **Wurzelordner des Gruppen-Repos** ausgeführt:

```bash
BOOT_B=0   Rscript Scripts/modellauswahl/run_all.R      # gesamte Pipeline, GAM ohne Bootstrap (ca. 1–1,5 Stunden)
BOOT_B=100 Rscript Scripts/modellauswahl/run_all.R      # gesamte Pipeline mit Kreis-Bootstrap wie in den Abbildungen (+ ca. 20 min)
Rscript Scripts/modellauswahl/run_all.R 22              # A1, Option D, Option III, Rang 2, danach alle Abbildungen
Rscript Scripts/modellauswahl/run_all.R 11              # nur die Abbildungen
Rscript Scripts/modellauswahl/22_main_model_tmb.R       # nur A1 (Abbildungen danach mit run_all.R 11)
Rscript Scripts/modellauswahl/run_all.R --release       # Abgabelauf: alles ab 01, BOOT_B = 100, INLA Pflicht
```

- `BOOT_B` ist Pflicht, sobald `13_gam_age.R` mitläuft (sonst bricht `run_all.R` ab): `BOOT_B=0` ersetzt die gespeicherten Bootstrap-Bänder durch modellbasierte, `BOOT_B=100` reproduziert die veröffentlichten.
- `24_spatial_theta_inla.R` rechnet seriell (`INLA_THREADS=1:1`, Standard) und ist so weitgehend reproduzierbar; mit mehreren Rechenfäden ändern sich DIC/WAIC stark zwischen identischen Läufen.
- `25_rank2_tmb.R`: Zahl der Startwerte über `R2_STARTS` (Standard 5).
- Protokoll des letzten Laufs (Modus, Git-Stand, Skripte, Bootstrap, INLA-Fäden, Startwerte, Paketversionen): `results/modellauswahl/session_info.txt`.

| Ordner | Rolle |
|---|---|
| `data_raw/`, `data_geo/` | Eingabe (Rohdaten, Kreisgrenzen) – gemeinsam mit den anderen Teilprojekten |
| `data_processed/modellauswahl/` | bereinigte Daten und gespeicherte Modelle |
| `results/modellauswahl/figures/`, `results/modellauswahl/tables/` | Abbildungen und Tabellen |

| Skript | Rolle |
|---|---|
| `22_main_model_tmb.R` | **Modellvorschlag A1** (glmmTMB, θ je Altersgruppe, ein Kreis-Faktor) |
| `17_joint_age_models.R` | Vorgängermodell (gemeinsames θ + MRF), jetzt Sensitivität für den räumlichen Effekt |
| `23_cross_wave_tmb.R` | Option D: ein Modell über alle Wellen |
| `24_spatial_theta_inla.R` | Option III: A1 mit räumlichem Kreis-Faktor (BYM2, INLA) |
| `25_rank2_tmb.R` | Kandidat: A1 mit zwei Kreis-Faktoren, 5 Startwerte je Welle |

Pfade, Altersgruppen, Kovariaten und Formeln stehen zentral in `00_setup.R`, der Abbildungsstil in `00_theme.R`; Abbildungen entstehen nur in `11_figures.R` (läuft zuletzt). Pakete: data.table, ggplot2, scales, ragg, MASS, sandwich, mgcv, sf, survival, cluster, glmmTMB; für `24_spatial_theta_inla.R` zusätzlich INLA und sn (ohne INLA wird 24 übersprungen, mit `--release` Abbruch). `run_all.R --release` rendert hier keine Quarto-Folien; die liegen nur im Arbeitsordner.
