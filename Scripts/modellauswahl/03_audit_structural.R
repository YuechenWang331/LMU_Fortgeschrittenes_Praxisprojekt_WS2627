# Audit der Strukturvariablen (GENESIS / Regionalstatistik, BBSR).
# Frage: Welche Dateien haben Kreisebene, fuer welche Jahre, und wie viele der
# 400 Kreise (AGS, Berlin zusammengefasst) lassen sich verknuepfen?
# Ausgabe: results/modellauswahl/tables/variable_audit.csv

source("Scripts/modellauswahl/00_setup.R")
kreis <- readRDS(file.path(DIR_CLEAN, "kreis_key.rds"))
AGS <- kreis$ags

rd <- function(f) fread(file.path(DIR_RAW, f), sep = ";", encoding = "UTF-8",
                        colClasses = "character", showProgress = FALSE)

# GENESIS-Sonderzeichen: "-" = genau Null, "." / "x" / "/" = unbekannt oder gesperrt
is_unk <- function(v) v %in% c(".", "x", "/", "...", "")

# Besonderheiten der Kodierung (im Audit festgestellt):
#  * Hamburg (02000) und Berlin (11000) stehen in den meisten Dateien NICHT als Kreis,
#    sondern nur als Bundesland (1_variable_code == "DLAND", Code "02" bzw. "11").
#    Berlin-Bezirke (11001-11012) kommen zusaetzlich vor und werden hier nicht verwendet.
#  * Pendler-Dateien: Gemeinde-Code "P" + 12-stelliger AGS; der Kreis-AGS sind die
#    Stellen 2-6 (z.B. "P081165004046" -> 08116).
audit_flat <- function(f, level_code = "KREISE", pendler = FALSE, indicator_col = "value_variable_code") {
  d <- rd(f)
  if (pendler) {
    d <- d[`1_variable_code` == "PGEMEIN"]
    d[, ags := substr(`1_variable_attribute_code`, 2, 6)]
  } else {
    d <- d[`1_variable_code` %in% c("KREISE", "DLAND")]
    d[, ags := fcase(`1_variable_code` == "KREISE", substr(`1_variable_attribute_code`, 1, 5),
                     `1_variable_code` == "DLAND" & `1_variable_attribute_code` == "02", "02000",
                     `1_variable_code` == "DLAND" & `1_variable_attribute_code` == "11", "11000",
                     default = NA_character_)]
    d <- d[!is.na(ags) & !(substr(ags, 1, 2) == "11" & ags != "11000")]
  }
  d[, matched := ags %in% AGS]
  yr <- if (grepl("^[0-9]{4}$", d$time[1])) d$time else substr(d$time, 1, 4)
  d[, year := as.integer(yr)]
  d[, unk := is_unk(value)]
  res <- d[, .(
    rows         = .N,
    kreise_total = uniqueN(ags),
    kreise_match = uniqueN(ags[matched]),
    share_unknown = round(mean(unk[matched]), 3)
  ), by = .(year, indicator = get(indicator_col))]
  res[, file := f]
  list(res = res, unmatched = sort(unique(d[matched == FALSE, ags])),
       missing = setdiff(AGS, unique(d$ags)))
}

jobs <- list(
  list(f = "abschlusse_flat.csv"),
  list(f = "arbeitslose_flat.csv"),
  list(f = "beschaeftigte_flat.csv"),
  list(f = "grundsicherung_flat.csv"),
  list(f = "pflegestat_flat.csv"),
  list(f = "schutzsuchende_flat.csv"),
  list(f = "tageseinrichtungen_flat.csv"),
  list(f = "tourismus_flat.csv"),
  list(f = "11111-0002 Gebietsfläche nach Kreise.csv"),
  list(f = "12411-0018 Bevölkerung nach Geschlecht, Altersgruppen und Kreisen.csv"),
  list(f = "einpendelnde21_flat.csv", pendler = TRUE),
  list(f = "einpendelnde22_flat.csv", pendler = TRUE),
  list(f = "einpendelnde23_flat.csv", pendler = TRUE),
  list(f = "auspendelnde21_flat.csv", pendler = TRUE),
  list(f = "auspendelnde22_flat.csv", pendler = TRUE),
  list(f = "auspendelnde23_flat.csv", pendler = TRUE)
)

out <- rbindlist(lapply(jobs, function(j) {
  r <- do.call(audit_flat, j)
  cat(sprintf("\n%s\n  nicht in 400 Kreisen: %d (z.B. %s)\n  fehlende Kreise: %d (z.B. %s)\n",
              j$f, length(r$unmatched), paste(head(r$unmatched, 5), collapse = ","),
              length(r$missing), paste(head(r$missing, 8), collapse = ",")))
  r$res
}))

# Pendler: Gemeindeebene -> Kreis-Zaehlung oben ist nur eine Anzahl eindeutiger Kreis-AGS
fwrite(out, file.path(DIR_TAB, "variable_audit.csv"))

cat("\n--- Zusammenfassung (Kreise verknuepfbar von 400, je Datei und Jahr) ---\n")
print(out[, .(indicators = uniqueN(indicator), kreise_match_min = min(kreise_match),
              kreise_match_max = max(kreise_match), share_unknown_max = max(share_unknown)),
          by = .(file, year)][order(file, year)], nrows = 100)

# --- BBSR-Raumgliederungen (CSV in Latin-1) ------------------------------------
bb <- function(f) {
  d <- fread(file.path(DIR_RAW, f), sep = ";", encoding = "Latin-1", colClasses = "character")
  setnames(d, c("kennz", "name", "typ", "typ_name"))
  d[, ags := substr(kennz, 1, 5)]
  d
}
for (f in c("siedlungsstrukt-kreistypen-2020.csv", "raumtypen-lage-2020.csv")) {
  d <- bb(f)
  cat(sprintf("\n%s: %d Zeilen, %d verknuepfbar, fehlen von 400: %s\n", f, nrow(d), sum(d$ags %in% AGS),
              paste(head(setdiff(AGS, d$ags), 12), collapse = ",")))
  cat("  nicht in 400:", paste(head(setdiff(d$ags, AGS), 12), collapse = ","), "\n")
  print(d[, .N, by = .(typ, typ_name)][order(typ)])
}
