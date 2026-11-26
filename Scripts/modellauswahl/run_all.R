# Gesamte Pipeline in der richtigen Reihenfolge ausfuehren (aus dem Wurzelordner des Gruppen-Repos):
#   BOOT_B=0   Rscript Scripts/modellauswahl/run_all.R           # alles, GAM ohne Bootstrap (ca. 1 Stunde; 23 ca. 22 min, 25 ca. 25 min)
#   BOOT_B=100 Rscript Scripts/modellauswahl/run_all.R           # alles mit Kreis-Bootstrap wie in den Abbildungen (zusaetzlich ca. 20 min)
#   Rscript Scripts/modellauswahl/run_all.R 08                   # ab Skript 08 (z.B. nach geaenderten Wellengrenzen; BOOT_B noetig, da 13 dabei)
#   Rscript Scripts/modellauswahl/run_all.R 11                   # nur die Abbildungen
#   Rscript Scripts/modellauswahl/run_all.R --release            # Abgabelauf: alles, Bootstrap B = 100, INLA Pflicht (im Gruppen-Repo ohne Quarto-Rendering)
#
# Laeuft 13_gam_age.R mit, muss BOOT_B gesetzt sein: BOOT_B=0 ersetzt gespeicherte Bootstrap-Baender durch
# modellbasierte (deutlich zu schmal), BOOT_B=100 reproduziert die veroeffentlichten Baender (externe Pruefung 26.11.2026:
# ein Standardlauf hatte die Bootstrap-Intervalle stillschweigend ersetzt).
# --release (Abgabe): BOOT_B = 100, falls nicht gesetzt; bricht ab statt zu ueberspringen, wenn INLA fehlt;
#   im Arbeitsordner werden danach die Quarto-Dokumente in report/ gerendert (im Gruppen-Repo nicht vorhanden). Ohne --release wird 24 ohne INLA uebersprungen (steht im Protokoll).
# Jedes Skript laeuft in einem eigenen R-Prozess (wie beim Einzelaufruf); Abbruch beim ersten Fehler.
# Protokoll des Laufs (Modus, Schritte, Bootstrap, INLA-Threads, Startwerte, Git-Stand, Paketversionen):
#   results/modellauswahl/session_info.txt

STEPS <- c("01_kreis_key", "02_clean_covid", "03_audit_structural", "04_clean_structural",
           "05_check_population", "06_pop_sensitivity", "07_agegroups", "08_waves", "09_urban_rural",
           "10_plot_rki_phases", "12_models_wave_age", "13_gam_age", "14_sens_age_unknown",
           "15_compare_schemes", "16_spatial", "17_joint_age_models", "18_gam_age_density",
           "19_covariates_pca_cv", "20_wave_arrival", "21_cluster_typology",
           "22_main_model_tmb",   # Modellvorschlag A1 (glmmTMB, theta je Altersgruppe), braucht Tabellen aus 16 und 17
           "23_cross_wave_tmb",   # Option D: ein Modell ueber alle Wellen (glmmTMB), braucht Tabellen aus 22
           "24_spatial_theta_inla",   # Option III: A1 + BYM2 (INLA; ohne INLA nur ausserhalb von --release uebersprungen)
           "25_rank2_tmb",        # Kandidat: A1 mit zwei Kreis-Faktoren, mehrere Startwerte; braucht Tabellen aus 22
           "11_figures")   # Abbildungen immer zuletzt (braucht Tabellen aus 09 und 12-24)
QMD <- character()   # Quarto-Dokumente (report/) liegen nur im Arbeitsordner, nicht im Gruppen-Repo -> hier nichts zu rendern

if (!file.exists("Scripts/modellauswahl/00_setup.R")) stop("Bitte aus dem Wurzelordner des Gruppen-Repos ausfuehren.")
args <- commandArgs(trailingOnly = TRUE)
release <- "--release" %in% args
args <- args[!startsWith(args, "--")]
from <- if (length(args)) which(startsWith(STEPS, args[1]))[1] else 1L
if (is.na(from)) stop("Unbekannter Startschritt '", args[1], "'. Moeglich: ", paste(substr(STEPS, 1, 2), collapse = ", "))
run <- STEPS[from:length(STEPS)]

if (release) {
  if (from != 1L) stop("--release laeuft immer ab Schritt 01 (ohne Startschritt aufrufen).")
  if (!nzchar(Sys.getenv("BOOT_B"))) Sys.setenv(BOOT_B = "100")
  if (Sys.getenv("BOOT_B") == "0") stop("--release mit BOOT_B=0: die veroeffentlichten Abbildungen brauchen den Bootstrap.")
  if (!requireNamespace("INLA", quietly = TRUE)) stop("--release braucht INLA (Installation siehe README).")
  if (length(QMD) && !nzchar(Sys.which("quarto"))) stop("--release braucht Quarto (https://quarto.org) zum Rendern von report/.")
}
if ("13_gam_age" %in% run && !nzchar(Sys.getenv("BOOT_B")))
  stop("13_gam_age laeuft mit: bitte BOOT_B setzen, z.B. BOOT_B=100 (wie veroeffentlicht, ca. 20 min) oder ",
       "BOOT_B=0 (schnell, ersetzt die gespeicherten Bootstrap-Baender durch modellbasierte).")

# Umlaute in Abbildungen brauchen eine UTF-8-Locale (Rscript startet auf macOS sonst teils mit "C")
if (.Platform$OS.type != "windows" && !l10n_info()$`UTF-8`) Sys.setenv(LC_ALL = "en_US.UTF-8")
rscript <- file.path(R.home("bin"), "Rscript")
git <- function(...) tryCatch(suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = FALSE)), error = function(e) character())
git_start <- c(head = paste(git("rev-parse", "--short", "HEAD"), collapse = ""),
               dirty = length(git("status", "--porcelain", "--untracked-files=no")))

t_all <- Sys.time(); done <- character(); skipped <- character()
for (s in run) {
  cat(sprintf("\n========== %s ==========\n", s))
  if (s == "24_spatial_theta_inla" && !requireNamespace("INLA", quietly = TRUE)) {
    message("INLA nicht installiert -> 24_spatial_theta_inla uebersprungen (Installation siehe README)")
    skipped <- c(skipped, s); next
  }
  t0 <- Sys.time()
  rc <- system2(rscript, file.path("Scripts/modellauswahl", paste0(s, ".R")))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (rc != 0) stop(sprintf("%s abgebrochen (Exit-Code %d) nach %.0f s", s, rc, secs))
  cat(sprintf("---------- %s fertig (%.0f s)\n", s, secs))
  done <- c(done, s)
}
if (release) for (q in QMD) {
  cat(sprintf("\n========== quarto render %s ==========\n", q))
  if (system2("quarto", c("render", q)) != 0) stop("quarto render ", q, " fehlgeschlagen")
  done <- c(done, paste("render", basename(q)))
}
cat(sprintf("\nPipeline fertig: %d Schritte in %.1f Minuten\n", length(done),
            as.numeric(difftime(Sys.time(), t_all, units = "mins"))))

# ---- Protokoll: was ist in diesem Lauf wirklich passiert? (Reproduzierbarkeit in der Gruppe; kein renv) ----------
boot_line <- if (!"13_gam_age" %in% done) "13 nicht gelaufen" else {
  bi <- tryCatch(readRDS("data_processed/modellauswahl/gam_age_curves.rds")$boot, error = function(e) NULL)
  if (is.null(bi)) sprintf("BOOT_B = %s (kein Bootstrap, Baender modellbasiert)", Sys.getenv("BOOT_B")) else
    sprintf("BOOT_B = %d, erfolgreich je Welle: %s", max(bi$B), paste(sprintf("%s %d", bi$wave, bi$n_ok), collapse = ", "))
}
pk <- c("data.table", "ggplot2", "scales", "ragg", "MASS", "sandwich", "mgcv", "sf", "survival", "cluster", "glmmTMB", "TMB", "INLA", "sn")
writeLines(c(paste("Lauf:", format(Sys.time(), "%Y-%m-%d %H:%M"), "| Modus:", if (release) "Abgabe (--release)" else "Entwicklung"),
             paste("Git-Stand bei Start:", git_start[["head"]],
                   if (git_start[["dirty"]] != "0") sprintf("(+ %s geaenderte versionierte Dateien, nicht committet)", git_start[["dirty"]]) else "(sauber)"),
             paste("Gelaufen:", paste(substr(done, 1, 2), collapse = " ")),
             paste("Uebersprungen:", if (length(skipped)) paste(skipped, collapse = ", ") else "-"),
             paste("Bootstrap (13):", boot_line),
             paste("INLA-Threads (24):", if ("24_spatial_theta_inla" %in% done) Sys.getenv("INLA_THREADS", "1:1") else "24 nicht gelaufen"),
             paste("Rang-2-Startwerte (25):", if ("25_rank2_tmb" %in% done) Sys.getenv("R2_STARTS", "5") else "25 nicht gelaufen"),
             R.version.string, paste("Plattform:", R.version$platform),
             paste("Quarto:", if (nzchar(Sys.which("quarto"))) paste(system2("quarto", "--version", stdout = TRUE), collapse = "") else "fehlt"),
             sprintf("%-11s %s", pk, vapply(pk, function(p) tryCatch(as.character(packageVersion(p)), error = function(e) "fehlt"), ""))),
           "results/modellauswahl/session_info.txt")
