# Datengetriebene Kreistypologie per Clusteranalyse (Statistik V "Distanzmasse", "Clusteranalyse",
# "Clustervalidierung") als Alternative zum BBSR-Kreistyp. Evidenz zur offenen Frage "welches Raummass?".
# Eingabe: 26 Strukturmerkmale (struct_matrix(), 00_setup.R) + log(Bevoelkerungsdichte), standardisiert;
#   euklidische Distanz. Verfahren: k-Means (50 Starts) und hierarchisch nach Ward; Wahl von k ueber die mittlere
#   Silhouettenbreite (k = 2..8, interne Validierung). Zusaetzlich k = 4 fuer den direkten Vergleich mit den vier
#   BBSR-Typen (externe Validierung: Kreuztabelle, adjustierter Rand-Index).
# Danach Hauptmodell m1 je Welle x Altersgruppe mit dem Cluster statt des Kreistyps (gleiche Kovariaten und
#   Bundesland) -> Vergleich der AIC-Summen. Die Cluster enthalten auch die Kovariaten des Modells (SGB-II, 65+,
#   Tourismus); das Modell misst also "Regionstyp" in einem breiteren Sinn als nur Urbanisierung.
# Ausgabe: results/modellauswahl/tables/cluster_silhouette.csv, cluster_profile.csv, cluster_vs_bbsr.csv, cluster_model_aic.csv,
#          data_processed/modellauswahl/kreis_cluster.rds

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages({library(MASS); library(cluster)})

const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
X <- merge(struct_matrix(), const[, .(ags, log_dichte = log(dichte_mean), kreistyp_code)], by = "ags")
VARS <- c(setdiff(names(X), c("ags", "state", "kreistyp_code")))
Z <- scale(as.matrix(X[, VARS, with = FALSE]))
D <- dist(Z)

# ---- interne Validierung: Silhouette je k ------------------------------------------------------
set.seed(20261121)
hc <- hclust(D, method = "ward.D2")
sil <- rbindlist(lapply(2:8, function(k) {
  km <- kmeans(Z, centers = k, nstart = 50, iter.max = 100)
  data.table(k = k, kmeans = mean(silhouette(km$cluster, D)[, 3]), ward = mean(silhouette(cutree(hc, k), D)[, 3]))
}))
fwrite(sil, file.path(DIR_TAB, "cluster_silhouette.csv"))
K_SIL <- sil[which.max(kmeans), k]

ari <- function(a, b) {               # adjustierter Rand-Index (Hubert & Arabie)
  tab <- table(a, b); n <- sum(tab); c2 <- function(x) x * (x - 1) / 2
  s <- sum(c2(tab)); sa <- sum(c2(rowSums(tab))); sb <- sum(c2(colSums(tab))); e <- sa * sb / c2(n)
  (s - e) / ((sa + sb) / 2 - e)
}
# Clusternummern nach mittlerer Dichte sortieren (1 = dichtester Cluster), damit sie mit den BBSR-Typen vergleichbar sind
relabel <- function(cl) { o <- order(-tapply(X$log_dichte, cl, mean)); match(cl, o) }
set.seed(20261121)
cl_sil <- relabel(kmeans(Z, centers = K_SIL, nstart = 50, iter.max = 100)$cluster)
set.seed(20261121)
cl4 <- relabel(kmeans(Z, centers = 4, nstart = 50, iter.max = 100)$cluster)
X[, `:=`(cl_sil = cl_sil, cl4 = cl4)]
saveRDS(X[, .(ags, cl_sil, cl4)], file.path(DIR_CLEAN, "kreis_cluster.rds"))

prof <- X[, c(list(n = .N, dichte = round(exp(mean(log_dichte)))),
              lapply(.SD, function(v) round(mean(v), 2)),
              list(anteil_bbsr1 = round(mean(kreistyp_code == 1), 2), anteil_bbsr4 = round(mean(kreistyp_code == 4), 2),
                   anteil_ost = round(mean(as.integer(state) %in% 12:16), 2))),
          by = .(cl4), .SDcols = c("sgb2", "alo", "anteil_65p", "anteil_0_5", "log_tourismus", "einpendler", "hochschulreife")][order(cl4)]
fwrite(prof, file.path(DIR_TAB, "cluster_profile.csv"))
ct <- as.data.table(table(cluster = X$cl4, bbsr = X$kreistyp_code))
fwrite(ct, file.path(DIR_TAB, "cluster_vs_bbsr.csv"))

cat("== Silhouette (mittlere Breite; hoeher = klarer getrennte Cluster) ==\n"); print(sil[, lapply(.SD, round, 3)])
cat("k mit groesster Silhouette (k-Means):", K_SIL, "\n")
cat("\n== Profile der 4 Cluster (k-Means; Mittelwerte, Dichte geometrisch) ==\n"); print(prof)
cat("\n== Cluster (k = 4) vs. BBSR-Kreistyp ==\n"); print(table(cluster = X$cl4, bbsr = X$kreistyp_code))
cat(sprintf("Adjustierter Rand-Index: k = 4 vs. BBSR %.2f | k = %d vs. BBSR %.2f | k-Means vs. Ward (k = 4) %.2f\n",
            ari(X$cl4, X$kreistyp_code), K_SIL, ari(X$cl_sil, X$kreistyp_code), ari(X$cl4, cutree(hc, 4))))

# ---- Modellvergleich: Cluster statt Kreistyp ----------------------------------------------------
cv <- merge(model_covariates()[, .(ags, kt, z_sgb2, z_p65, z_ltour)], X[, .(ags, cl4 = factor(cl4), cl_sil = factor(cl_sil))], by = "ags")
kw <- merge(readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES], cv, by = "ags")
kw[, state := factor(state)]
SPECS <- list(kt = cases ~ kt + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki)),
              cl4 = cases ~ cl4 + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki)),
              ohne = cases ~ state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki)))
if (K_SIL != 4) SPECS$cl_sil <- cases ~ cl_sil + state + z_sgb2 + z_p65 + z_ltour + offset(log(pop_rki))
aic <- rbindlist(lapply(WAVES, function(w) rbindlist(lapply(GR_COARSE, function(g) {
  d <- kw[phase == w & grp == g]
  data.table(wave = w, grp = g, spec = names(SPECS),
             aic = vapply(SPECS, function(f) AIC(quiet_nonint(glm.nb(f, data = d, control = glm.control(maxit = 100)))), numeric(1)))
}))))
fwrite(aic, file.path(DIR_TAB, "cluster_model_aic.csv"))
cat("\n== AIC-Summe ueber 56 Zellen (kleiner = besser) ==\n"); print(aic[, .(aic_summe = round(sum(aic))), by = spec])
w <- dcast(aic, wave + grp ~ spec, value.var = "aic")
cat("Cluster (k = 4) besser als Kreistyp in", sum(w$cl4 < w$kt), "von", nrow(w), "Zellen\n")
print(w[, .(dAIC_kt_minus_cl4 = round(sum(kt - cl4), 1)), by = wave])
