# Zeitlicher Verlauf: Wann erreicht eine Welle einen Kreis? Ueberlebenszeitanalyse je Welle
# (Statistik V und Biometrie: Kaplan-Meier, Cox-Modell; Lineare Modelle Kap. 10 fuer die diskrete Alternative).
# Ergaenzt die Modelle 12-18, die jede Welle auf die kumulative Inzidenz reduzieren: hier geht es um das Timing.
# Ereignis: Die Wocheninzidenz eines Kreises erreicht erstmals SCHWELLE x bundesweiten Gipfel der Welle
#   (je Altersgruppe bzw. alle Altersgruppen; Hauptanalyse 50 %, Sensitivitaet 25 %). Zeit = Woche der Welle
#   (1 = erste Woche). Kreise, die die Schwelle bis Wellenende nicht erreichen, sind zensiert.
# Modelle je Welle:
#   KM    : Anteil der Kreise ohne Ereignis nach Kreistyp (alle Altersgruppen)
#   cox   : Surv ~ Kreistyp + SGB-II + 65+ + Tourismus + strata(Bundesland)   (alle Altersgruppen)
#           strata: jedes Land hat eigene Basis-Hazardfunktion (Landespolitik, Ferien); Hazard Ratio (HR) < 1
#           heisst: der Kreistyp wird spaeter erreicht als Grossstaedte.
#   cox_age: alle 7 Altersgruppen gestapelt, Kreistyp je Altersgruppe, strata(Land, Altersgruppe),
#           cluster(Kreis) -> robuste Standardfehler; Wald-Test "gleicher Kreistyp-Effekt in allen Altersgruppen".
# Wochendaten sind diskret (viele Bindungen) -> Efron-Methode.
# Ausgabe: results/modellauswahl/tables/arrival_km.csv, arrival_cox.csv, arrival_cox_age.csv, arrival_summary.csv

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(survival))

wv <- readRDS(file.path(DIR_CLEAN, "waves.rds"))
WAVES <- wv$phases[type == "Welle", id]
cv <- merge(model_covariates()[, .(ags, kt, z_sgb2, z_p65, z_ltour)],
            readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))[, .(ags, state)], by = "ags")
KT_SHORT <- c(T1_Grossstadt = "T1", T2_staedtisch = "T2", T3_laendl_Verdichtung = "T3", T4_duenn_besiedelt = "T4")

a <- readRDS(file.path(DIR_CLEAN, "covid_agegrp.rds"))[scheme == "coarse", .(ags, week, grp = as.character(grp), cases, pop_rki)]
a <- merge(a, wv$week_phase, by = "week")[phase %in% WAVES]
alle <- a[, .(cases = sum(cases), pop_rki = sum(pop_rki)), by = .(ags, week, phase)][, grp := "alle"]
a <- rbind(a, alle)
a[, inc := cases / pop_rki * 1e5]
a[, t := match(week, sort(unique(week))), by = phase]          # Woche innerhalb der Welle
nat <- a[, .(inc_nat = sum(cases) / sum(pop_rki) * 1e5), by = .(phase, grp, week, t)][
  , .(gipfel = max(inc_nat), start_anteil = inc_nat[t == 1] / max(inc_nat)), by = .(phase, grp)]
# Wellen, die bundesweit schon in Woche 1 ueber der Schwelle liegen (z.B. W8: Beginn am Minimum nach W7, aber
# Inzidenz noch ueber 50 % des Dezember-Gipfels), sind fuer die Ankunftszeit nicht auswertbar (links zensiert).
a <- merge(a, nat, by = c("phase", "grp"))

arrival <- function(thr) {
  e <- a[, .(T = if (any(inc >= thr * gipfel)) min(t[inc >= thr * gipfel]) else max(t),
             event = as.integer(any(inc >= thr * gipfel))), by = .(phase, grp, ags)]
  merge(e, cv, by = "ags")
}
wald_equal <- function(m, V) {          # gleiche Kreistyp-Effekte in allen Altersgruppen (Differenzen zur ersten Gruppe)
  b <- coef(m); nm <- names(b); k <- grep(":T[234]$", nm)
  terms <- c("T2", "T3", "T4"); ref <- GR_COARSE[1]
  C <- do.call(rbind, lapply(terms, function(tt) {
    ii <- k[endsWith(nm[k], tt)]; i0 <- ii[grepl(paste0("grp", ref, ":"), nm[ii], fixed = TRUE)]
    t(vapply(setdiff(ii, i0), function(i) { r <- numeric(length(b)); r[i] <- 1; r[i0] <- -1; r }, numeric(length(b))))
  }))
  cb <- C %*% b; chi2 <- as.numeric(t(cb) %*% solve(C %*% V %*% t(C), cb))
  c(chi2 = chi2, df = nrow(C), p = pchisq(chi2, nrow(C), lower.tail = FALSE))
}
tidy_hr <- function(m, V = vcov(m)) {
  b <- coef(m); k <- grep("^kt|:T[234]$", names(b)); se <- sqrt(diag(V))[k]
  data.table(coef = names(b)[k], est = b[k], se = se, hr = exp(b[k]), lo = exp(b[k] - 1.96 * se), hi = exp(b[k] + 1.96 * se))
}

km <- list(); cx <- list(); cxa <- list(); sm <- list()
for (thr in c(.5, .25)) {
  ev <- arrival(thr)
  for (w in WAVES) {
    if (nat[phase == w & grp == "alle", start_anteil] >= thr) {
      cat(sprintf("Schwelle %.0f %%: %s nicht auswertbar (bundesweit in Woche 1 bei %.0f %% des Gipfels)\n",
                  100 * thr, w, 100 * nat[phase == w & grp == "alle", start_anteil])); next
    }
    d <- ev[phase == w & grp == "alle"]
    m <- coxph(Surv(T, event) ~ kt + z_sgb2 + z_p65 + z_ltour + strata(state), data = d, ties = "efron")
    zp <- tryCatch(cox.zph(m)$table["GLOBAL", "p"], error = function(e) NA_real_)   # PH-Test (Schoenfeld); kann singulaer sein
    cx[[length(cx) + 1]] <- tidy_hr(m)[, `:=`(wave = w, schwelle = thr, term = KT_SHORT[sub("^kt", "", coef)], ph_global_p = zp)]
    med <- d[, .(median_woche = { s <- survfit(Surv(T, event) ~ 1, data = .SD); unname(summary(s)$table["median"]) },
                 anteil_erreicht = mean(event), anteil_woche1 = mean(event == 1 & T == 1)), by = kt]
    sm[[length(sm) + 1]] <- med[, `:=`(wave = w, schwelle = thr, n_wochen = max(a[phase == w, t]))]
    if (thr == .5) {
      f <- survfit(Surv(T, event) ~ kt, data = d)
      km[[length(km) + 1]] <- data.table(wave = w, time = f$time, surv = f$surv,
                                         kt = rep(sub("^kt=", "", names(f$strata)), f$strata))
      # Kreistyp als 0/1-Dummys (T2-T4 vs. Grossstadt), damit grp:Typ je Altersgruppe ohne aliasierte Spalten
      da <- ev[phase == w & grp != "alle"][, `:=`(grp = factor(grp, GR_COARSE), T2 = as.numeric(KT_SHORT[as.character(kt)] == "T2"),
                                                 T3 = as.numeric(KT_SHORT[as.character(kt)] == "T3"), T4 = as.numeric(KT_SHORT[as.character(kt)] == "T4"))]
      ma <- coxph(Surv(T, event) ~ grp:(T2 + T3 + T4) + grp:(z_sgb2 + z_p65 + z_ltour) + strata(state, grp) + cluster(ags),
                  data = da, ties = "efron")
      wt <- wald_equal(ma, vcov(ma))                     # vcov eines coxph mit cluster() = robuste Kovarianz
      cxa[[length(cxa) + 1]] <- tidy_hr(ma)[, `:=`(wave = w, grp = sub("^grp(.+):T[234]$", "\\1", coef),
                                                  term = sub("^grp.+:", "", coef), wald_p = wt[["p"]])]
    }
  }
}
km <- rbindlist(km); cx <- rbindlist(cx); cxa <- rbindlist(cxa); sm <- rbindlist(sm)
km[, kt := KT_SHORT[kt]]; sm[, kt := KT_SHORT[as.character(kt)]]
fwrite(km, file.path(DIR_TAB, "arrival_km.csv"))
fwrite(cx[, .(wave, schwelle, term, est, se, hr, lo, hi, ph_global_p)], file.path(DIR_TAB, "arrival_cox.csv"))
fwrite(cxa[, .(wave, grp, term, est, se, hr, lo, hi, wald_p)], file.path(DIR_TAB, "arrival_cox_age.csv"))
fwrite(sm, file.path(DIR_TAB, "arrival_summary.csv"))

lab <- function(x) x[, l := sprintf("%.2f%s", hr, fifelse(lo > 1 | hi < 1, "*", ""))]
cat("== Mediane Ankunftswoche je Kreistyp (Schwelle 50 % des bundesweiten Gipfels, alle Altersgruppen) ==\n")
print(dcast(sm[schwelle == .5], wave + n_wochen ~ kt, value.var = "median_woche"))
cat("Anteil Kreise mit Ereignis:", paste(sm[schwelle == .5, .(a = round(mean(anteil_erreicht), 2)), by = wave][, paste(wave, a)], collapse = ", "), "\n")
cat("\n== Cox: HR gegenueber Grossstadt (< 1 = spaeter erreicht; * = 95 %-KI ohne 1), Schwelle 50 % ==\n")
print(dcast(lab(cx[schwelle == .5]), wave ~ term, value.var = "l")[, ph_global_p := signif(unique(cx[schwelle == .5, .(wave, ph_global_p)])$ph_global_p, 2)])
cat("\nSchwelle 25 %:\n"); print(dcast(lab(cx[schwelle == .25]), wave ~ term, value.var = "l"))
cc <- merge(cx[schwelle == .5, .(wave, term, e50 = est)], cx[schwelle == .25, .(wave, term, e25 = est)], by = c("wave", "term"))
cat("Korrelation log-HR 50 % vs. 25 % (Wellen mit beiden Schwellen):", round(cor(cc$e50, cc$e25), 2), "\n")
cat("Anteil Kreise schon in Woche 1 ueber der 50-%-Schwelle:", paste(sm[schwelle == .5, .(x = round(mean(anteil_woche1), 2)), by = wave][, paste(wave, x)], collapse = ", "), "\n")
cat("\n== Altersspezifisch: HR Typ 4 vs. Grossstadt je Altersgruppe; Wald-Test gleicher Effekte (robust) ==\n")
x <- dcast(lab(cxa[term == "T4"]), wave ~ factor(grp, GR_COARSE), value.var = "l")
print(merge(x, unique(cxa[, .(wave, wald_p = signif(wald_p, 2))]), by = "wave"))
