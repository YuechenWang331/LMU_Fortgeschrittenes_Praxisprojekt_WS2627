# Schluesseltabelle der Kreise.
# Die 411 "Kreise" der RKI-Daten (SurvStat, CountyKey71) enthalten Berlin mit
# 12 Bezirken (AGS 11001-11012). GENESIS kennt Berlin nur als einen Kreis (11000).
# Entscheidung: Berlin wird zu einem Kreis zusammengefasst -> 400 Kreise.
#
# Verknuepfung immer ueber den 5-stelligen AGS, nie ueber den Namen
# (44 Namen kommen doppelt vor, z.B. "Ansbach" als Stadt und als Landkreis).

source("Scripts/modellauswahl/00_setup.R")

m <- fread(file.path(DIR_RAW, "CountyKey71Map.csv"), encoding = "UTF-8")
key <- data.table(
  pos      = m$region_position,                      # Position in den RKI-Arrays
  ags_orig = sub("^\\[", "", sub("\\]$", "", m$ComponentId)),
  name_rki = m$Name
)
key[, state := substr(ags_orig, 1, 2)]
key[, ags   := fifelse(state == BERLIN_PREFIX, BERLIN_AGS, ags_orig)]

stopifnot(nrow(key) == 411, !anyDuplicated(key$ags_orig),
          key[state == BERLIN_PREFIX, .N] == 12)

# Kreisebene nach Zusammenlegung: ein Eintrag pro AGS
kreis <- key[, .(n_orig = .N, state = state[1],
                 name_rki = if (.N > 1) "Berlin" else name_rki[1]), by = ags]
setorder(kreis, ags)

stopifnot(nrow(kreis) == 400, !anyDuplicated(kreis$ags))

saveRDS(key,   file.path(DIR_CLEAN, "key_rki_to_ags.rds"))
saveRDS(kreis, file.path(DIR_CLEAN, "kreis_key.rds"))
fwrite(kreis,  file.path(DIR_TAB, "kreis_key.csv"))
cat("OK: 411 RKI-Einheiten -> 400 Kreise (Berlin zusammengefasst)\n")
