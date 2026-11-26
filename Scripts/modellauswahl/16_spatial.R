# Raeumliche Struktur: Kreisgeometrie, Nachbarschaft und Moran's I fuer Inzidenz und Modellresiduen.
# Geometrie: data_geo/landkreise_simplify200.geojson, uebernommen aus dem Gruppen-Repository
#   (github.com/YuechenWang331/LMU_Fortgeschrittenes_Praxisprojekt_WS2627, data_geo/). Abgeleitet von BKG VG250
#   ("© GeoBasis-DE / BKG, Daten veraendert"), vereinfacht. GF == 4 = Landflaechen; GF == 2 (Wasserflaechen) entfaellt.
#   400 Kreise wie in kreis_key.rds (Berlin = 11000, Eisenach im Wartburgkreis).
# Nachbarschaft: Die vereinfachten Grenzen beruehren sich nicht exakt (st_touches findet fuer 285 Kreise keinen
#   Nachbarn). Nachbarn sind deshalb Kreise, deren Flaechen sich nach einem Puffer von 100 m schneiden (Queen-
#   Kontiguitaet); Kontrolle mit 50 m und 500 m unten. Gewichte zeilenstandardisiert.
# Moran's I mit Permutationstest (999 Permutationen, fester Seed; einseitig auf positive Autokorrelation) je
#   Welle x Altersgruppe (grob):
#   a) log kumulative Inzidenz (RKI-Nenner) - wie stark sind benachbarte Kreise sich aehnlich?
#   b) Pearson-Residuen des Hauptmodells m1 (aus 12_models_wave_age.R) - bleibt nach Bundesland und Kovariaten
#      raeumliche Struktur uebrig? Wenn ja, sind die modellbasierten Standardfehler zu klein.
# Ausgabe: data_processed/modellauswahl/kreis_geo.rds (sf, EPSG:25832, fuer die Karten in 11_figures.R), data_processed/modellauswahl/kreis_nb.rds,
#          results/modellauswahl/tables/spatial_moran.csv

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(sf))

GEO_FILE <- file.path("data_geo", "landkreise_simplify200.geojson")
if (!file.exists(GEO_FILE)) stop("Kreisgrenzen fehlen: ", GEO_FILE, " (siehe Kopf dieses Skripts)")

key <- readRDS(file.path(DIR_CLEAN, "kreis_key.rds"))
g <- st_read(GEO_FILE, quiet = TRUE)
g <- g[as.character(g$GF) == "4", ]
g$ags <- sprintf("%05d", as.integer(g$AGS))
g$ags[g$ags == "16056"] <- "16063"                            # falls eine Fassung Eisenach noch getrennt fuehrt
g <- aggregate(g["ags"], by = list(ags = g$ags), FUN = function(x) x[1])[, "ags"]
stopifnot(nrow(g) == 400, setequal(g$ags, key$ags))
g <- st_transform(g[order(g$ags), ], 25832)                   # ETRS89 / UTM 32N
g$state <- substr(g$ags, 1, 2)
saveRDS(g, file.path(DIR_CLEAN, "kreis_geo.rds"))

# ---- Nachbarschaft ---------------------------------------------------------------------------
nb_buffer <- function(dist) lapply(st_intersects(st_buffer(g, dist)), function(i) i)
nb <- nb_buffer(100)
nb <- Map(setdiff, nb, seq_along(nb))
nn <- lengths(nb)
stopifnot(all(nn > 0), all(vapply(seq_along(nb), function(i) all(i %in% nb[[i]] == FALSE), TRUE)))
sym <- all(vapply(seq_along(nb), function(i) all(vapply(nb[[i]], function(j) i %in% nb[[j]], TRUE)), TRUE))
stopifnot(sym)
for (dd in c(50, 500)) {
  alt <- Map(setdiff, nb_buffer(dd), seq_along(nb))
  cat(sprintf("Kontrolle Puffer %3d m: %d von 400 Kreisen mit anderer Nachbarzahl\n", dd, sum(lengths(alt) != nn)))
}
cat("Nachbarn je Kreis: min", min(nn), "| Median", median(nn), "| max", max(nn), "\n")
saveRDS(list(ags = g$ags, nb = nb), file.path(DIR_CLEAN, "kreis_nb.rds"))

W <- matrix(0, 400, 400)
for (i in seq_along(nb)) W[i, nb[[i]]] <- 1 / length(nb[[i]])

# ---- Moran's I -------------------------------------------------------------------------------
set.seed(20261121)
N_PERM <- 999
PERM <- replicate(N_PERM, sample.int(400))                    # gleiche Permutationen fuer alle Variablen
moran <- function(x) {
  z <- x - mean(x); den <- sum(z^2)
  I <- sum(z * (W %*% z)) / den
  P <- matrix(z[PERM], 400)
  Ip <- colSums(P * (W %*% P)) / den
  c(I = I, p = (1 + sum(Ip >= I)) / (N_PERM + 1))
}

WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
kw <- readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES]
rs <- readRDS(file.path(DIR_CLEAN, "model_nb.rds"))$resid
res <- rbindlist(lapply(WAVES, function(w) rbindlist(lapply(GR_COARSE, function(gr) {
  k <- kw[phase == w & grp == gr][match(g$ags, ags)]
  r <- rs[wave == w & grp == gr][match(g$ags, ags)]
  stopifnot(!anyNA(k$cases), !anyNA(r$pearson))
  a <- moran(log((k$cases + 0.5) / k$pop_rki * 1e5)); b <- moran(r$pearson)
  data.table(wave = w, grp = gr, I_inzidenz = a[["I"]], p_inzidenz = a[["p"]], I_resid = b[["I"]], p_resid = b[["p"]])
}))))

# ---- Sensitivitaet: Hauptmodell m1 + raeumlicher Effekt (MRF) -----------------------------------
# Markov-Random-Field-Glaetter ueber die Kreis-Nachbarschaft (mgcv, bs = "mrf", reduzierter Rang K_MRF = 100),
# NB-Familie, REML. Er nimmt glatte raeumliche Abweichungen zwischen Nachbarkreisen auf, die Bundesland und
# Kovariaten nicht erklaeren. Achtung: Der Kreistyp ist selbst raeumlich strukturiert; ein Teil seines Effekts
# kann in den MRF-Term wandern (raeumliche Konfundierung). Deshalb Sensitivitaet, nicht Hauptmodell.
# (Voller Rang 400: ca. 20 s je Zelle, edf ~ 360 von 400, d.h. fast saturiert.)
suppressPackageStartupMessages(library(mgcv))
K_MRF <- 100
nbl <- setNames(lapply(nb, as.integer), g$ags)
cv <- model_covariates()
m1 <- fread(file.path(DIR_TAB, "model_nb_coef.csv"))[spec == "m1" & grepl("^kt", term), .(wave, grp, term, est_m1 = estimate, se_m1 = se)]
f_sp <- update(F_M1, . ~ . + s(ags_f, bs = "mrf", k = K_MRF, xt = list(nb = nbl)))
sp <- rbindlist(lapply(WAVES, function(w) rbindlist(lapply(GR_COARSE, function(gr) {
  d <- merge(kw[phase == w & grp == gr], cv, by = "ags")
  d[, `:=`(state = factor(state), ags_f = factor(ags, levels = g$ags))]
  m <- gam(f_sp, data = d, family = nb(), method = "REML")
  pt <- summary(m)$p.table; pt <- pt[grepl("^kt", rownames(pt)), , drop = FALSE]
  mi <- moran(residuals(m, "pearson")[match(g$ags, d$ags)])
  data.table(wave = w, grp = gr, term = rownames(pt), est_sp = pt[, 1], se_sp = pt[, 2],
             edf_mrf = sum(m$edf[grepl("ags_f", names(m$edf))]), I_resid_sp = mi[["I"]], p_resid_sp = mi[["p"]])
}))))
sp <- merge(m1, sp, by = c("wave", "grp", "term"))
sp[, `:=`(irr_m1 = exp(est_m1), irr_sp = exp(est_sp),
          sig_m1 = abs(est_m1 / se_m1) > 1.96, sig_sp = abs(est_sp / se_sp) > 1.96)]
fwrite(sp, file.path(DIR_TAB, "spatial_model_coef.csv"))
res <- merge(res, unique(sp[, .(wave, grp, edf_mrf, I_resid_sp, p_resid_sp)]), by = c("wave", "grp"))
fwrite(res, file.path(DIR_TAB, "spatial_moran.csv"))

cat("\n== Moran's I (Erwartung ohne Autokorrelation: ", round(-1 / 399, 4), ") ==\n", sep = "")
smry <- function(I, p) c(median = round(median(I), 2), spanne = sprintf("%.2f–%.2f", min(I), max(I)), sig = sum(p < .05))
print(rbind(inzidenz = smry(res$I_inzidenz, res$p_inzidenz), resid_m1 = smry(res$I_resid, res$p_resid),
            resid_m1_mrf = smry(res$I_resid_sp, res$p_resid_sp)))
cat("\nje Welle (Median ueber Altersgruppen):\n")
print(res[, .(I_inzidenz = round(median(I_inzidenz), 2), I_resid = round(median(I_resid), 2),
              I_resid_mrf = round(median(I_resid_sp), 2), edf_mrf = round(median(edf_mrf))), by = wave])
cat("\n== Kreistyp-Effekte m1 vs. m1 + MRF (", nrow(sp), " Koeffizienten) ==\n", sep = "")
cat("Korrelation der log-IRR:", round(cor(sp$est_m1, sp$est_sp), 3),
    "| mittlere |Differenz|:", round(mean(abs(sp$est_sp - sp$est_m1)), 3),
    "| max:", round(max(abs(sp$est_sp - sp$est_m1)), 3), "\n")
cat("SE-Verhaeltnis (MRF / m1): Median", round(median(sp$se_sp / sp$se_m1), 2), "\n")
cat("signifikant (95 %): m1", sum(sp$sig_m1), "| m1 + MRF", sum(sp$sig_sp),
    "| Vorzeichenwechsel bei signifikanten:", sum(sign(sp$est_m1) != sign(sp$est_sp) & (sp$sig_m1 | sp$sig_sp)), "\n")
print(sp[term == "ktT4_duenn_besiedelt", .(wave, grp, irr_m1 = round(irr_m1, 2), irr_sp = round(irr_sp, 2), sig_m1, sig_sp)][
  , .(m1 = paste(sprintf("%.2f%s", irr_m1, fifelse(sig_m1, "*", "")), collapse = " "),
      mrf = paste(sprintf("%.2f%s", irr_sp, fifelse(sig_sp, "*", "")), collapse = " ")), by = wave])
