# Kovariaten: Dimensionsreduktion (PCA) und Vergleich von Kovariatensaetzen per Kreuzvalidierung
# (Statistik V "Hauptkomponentenanalyse", "Generalisierte Lineare Modelle: Kreuzvalidierung fuer Prognoseguete";
#  Lineare Modelle Kap. 11 "Variablenselektion"). Evidenz zur offenen Frage "welche Kovariaten?".
# 1. PCA auf 26 standardisierten Strukturmerkmalen (Mittelwerte 2020-2023, ohne die Raummasse Dichte, Kreistyp,
#    Lage). Fehlende Werte durch den Median des Bundeslands, wo das Land keinen Wert hat bundesweit: oeffentl.
#    Beschaeftigte fehlen fuer Hamburg, Bremen, Bremerhaven, Berlin (bundesweit); Schutzsuchende fuer das ganze
#    Saarland (bundesweit), Kassel und Spree-Neisse (Land).
#    Anzahl Komponenten: Eigenwert > 1 (Kaiser).
# 2. Hauptmodell m1 (NB, Kreistyp + Bundesland + Kovariaten, Offset) je Welle x Altersgruppe mit vier Saetzen:
#      S0 ohne Kovariaten | S1 bisherige Auswahl (SGB-II, 65+, Tourismus) | S2 Hauptkomponenten | S3 alle 26
#    10-fache Kreuzvalidierung ueber Kreise (Folds je Bundesland zugeteilt; Hamburg und Berlin - je einziger Kreis
#    ihres Landes - bleiben immer im Training). Guete: mittlere NB-Log-Likelihood der Testkreise (stetige Form,
#    da die Fallzahlen nach der Verteilung der Faelle ohne Alter nicht ganzzahlig sind), theta aus dem Training.
# 3. Wie stark haengen die Kreistyp-Effekte vom Kovariatensatz ab?
# Hinweis (Biometrie, Confounding): Welche Kovariaten als Confounder in ein Modell gehoeren, ist eine inhaltliche
# Frage (z.B. ueber einen DAG), keine reine Prognosefrage. Die Kreuzvalidierung zeigt nur, welche Saetze die
# Inzidenz besser vorhersagen.
# Ausgabe: results/modellauswahl/tables/pca_loadings.csv, pca_variance.csv, cv_covariate_sets.csv, cv_kt_sensitivity.csv

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(MASS))

const <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]

# ---- 1. PCA ----------------------------------------------------------------------------------
X <- struct_matrix()                                         # 26 Merkmale, imputiert (Scripts/modellauswahl/00_setup.R)
VARS <- setdiff(names(X), c("ags", "state"))
n_imp <- attr(X, "n_imputiert")
pc <- prcomp(X[, VARS, with = FALSE], center = TRUE, scale. = TRUE)
ev <- pc$sdev^2
K_PC <- sum(ev > 1)
var_tab <- data.table(pc = paste0("PC", seq_along(ev)), eigenwert = ev, anteil = ev / sum(ev), kumuliert = cumsum(ev) / sum(ev))
# Vorzeichen so, dass die betragsgroesste Ladung positiv ist (nur fuer die Lesbarkeit)
L <- pc$rotation; S <- pc$x
for (j in seq_len(ncol(L))) if (L[which.max(abs(L[, j])), j] < 0) { L[, j] <- -L[, j]; S[, j] <- -S[, j] }
load_tab <- data.table(variable = rownames(L), L[, seq_len(K_PC), drop = FALSE])
fwrite(var_tab, file.path(DIR_TAB, "pca_variance.csv")); fwrite(load_tab, file.path(DIR_TAB, "pca_loadings.csv"))

cat("Imputiert (Median des Landes, sonst bundesweit):", paste(names(n_imp)[unlist(n_imp) > 0], unlist(n_imp)[unlist(n_imp) > 0], collapse = ", "), "\n")
cat("PCA:", length(VARS), "Merkmale;", K_PC, "Komponenten mit Eigenwert > 1, erklaeren",
    round(100 * var_tab$kumuliert[K_PC]), "% der Varianz\n")
for (j in seq_len(K_PC)) {
  o <- order(-abs(L[, j]))[1:5]
  cat(sprintf("  PC%d (%.0f %%): %s\n", j, 100 * var_tab$anteil[j],
              paste(sprintf("%s %+.2f", rownames(L)[o], L[o, j]), collapse = ", ")))
}

# ---- 2. Kreuzvalidierung der Kovariatensaetze ---------------------------------------------------
Z <- data.table(ags = X$ags, scale(X[, VARS, with = FALSE]))
setnames(Z, VARS, paste0("x_", VARS))
PCS <- data.table(ags = X$ags, S[, seq_len(K_PC), drop = FALSE]); setnames(PCS, paste0("PC", seq_len(K_PC)), paste0("pc", seq_len(K_PC)))
cv <- merge(merge(model_covariates()[, .(ags, kt, z_sgb2, z_p65, z_ltour)], Z, by = "ags"), PCS, by = "ags")
SETS <- list(S0_ohne = character(0), S1_bisher = c("z_sgb2", "z_p65", "z_ltour"),
             S2_pca = paste0("pc", seq_len(K_PC)), S3_alle = paste0("x_", VARS))
form <- function(s) as.formula(paste("cases ~ kt + state", if (length(s)) paste("+", paste(s, collapse = " + ")), "+ offset(log(pop_rki))"))

ll_nb <- function(y, mu, th) lgamma(th + y) - lgamma(th) - lgamma(y + 1) + th * log(th) + y * log(mu) - (th + y) * log(th + mu)
fit <- function(f, d) quiet_nonint(glm.nb(f, data = d, control = glm.control(maxit = 100)))

# Folds je Bundesland (feste Zuordnung fuer alle Zellen und Saetze); Laender mit nur einem Kreis nie im Test
set.seed(20261121)
fk <- const[, .(ags, state)][, n := .N, by = state][, fold := if (n[1] > 1) sample(rep_len(1:10, .N)) else NA_integer_, by = state]
kw <- merge(readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES], cv, by = "ags")
kw <- merge(kw, fk[, .(ags, fold)], by = "ags")
kw[, state := factor(state)]

res <- list(); ktc <- list()
for (w in WAVES) for (g in GR_COARSE) {
  d <- kw[phase == w & grp == g]
  for (sn in names(SETS)) {
    f <- form(SETS[[sn]])
    ll <- unlist(lapply(1:10, function(k) {
      tr <- d[is.na(fold) | fold != k]; te <- d[fold %in% k]
      m <- fit(f, tr)
      ll_nb(te$cases, predict(m, newdata = te, type = "response"), m$theta)
    }))
    m <- fit(f, d)
    res[[length(res) + 1]] <- data.table(wave = w, grp = g, set = sn, cv_ll = mean(ll), aic = AIC(m))
    b <- coef(m); se <- sqrt(diag(vcov(m))); i <- grep("^kt", names(b))
    ktc[[length(ktc) + 1]] <- data.table(wave = w, grp = g, set = sn, term = names(b)[i], est = b[i], se = se[i])
  }
}
res <- rbindlist(res); ktc <- rbindlist(ktc)
res[, d_cv_ll := cv_ll - cv_ll[set == "S1_bisher"], by = .(wave, grp)]
fwrite(res, file.path(DIR_TAB, "cv_covariate_sets.csv"))
k1 <- ktc[set == "S1_bisher", .(wave, grp, term, est1 = est, se1 = se)]
sens <- merge(ktc[set != "S1_bisher"], k1, by = c("wave", "grp", "term"))
fwrite(ktc, file.path(DIR_TAB, "cv_kt_sensitivity.csv"))

cat("\n== Kreuzvalidierung: mittlere Test-Log-Likelihood je Kreis, Differenz zu S1 (positiv = besser als S1) ==\n")
print(res[, .(d_cv_ll_mittel = round(mean(d_cv_ll), 3), besser_als_S1 = sum(d_cv_ll > 0), zellen = .N,
              aic_summe = round(sum(aic))), by = set])
cat("\nje Welle (Mittel ueber Altersgruppen, Differenz zu S1):\n")
print(dcast(res[set != "S1_bisher"], wave ~ set, value.var = "d_cv_ll", fun.aggregate = function(x) round(mean(x), 3)))
cat("\n== Kreistyp-log-IRR je Kovariatensatz im Vergleich zu S1 ==\n")
print(sens[, .(korrelation = round(cor(est, est1), 3), mittlere_abw = round(mean(abs(est - est1)), 3),
               max_abw = round(max(abs(est - est1)), 3), se_verh = round(median(se / se1), 2),
               sig = sum(abs(est / se) > 1.96), sig_S1 = sum(abs(est1 / se1) > 1.96)), by = set])
