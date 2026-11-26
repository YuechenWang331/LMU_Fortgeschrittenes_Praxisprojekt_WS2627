# Option D (Diskussion, 25.11.2026): EIN Modell ueber alle 8 Wellen statt 8 getrennter Modelle (glmmTMB).
#
# Frage: Veraendert sich der Stadt-Land-Unterschied ueber die Wellen ("Verlaeufe" im Thema)?
#   Im Hauptmodell A1 (22_main_model_tmb.R) gibt es dafuer 8 getrennte Tests + Holm. Hier wird das als
#   EIN Test im gemeinsamen Modell geprueft; ausserdem trennt das Modell dauerhafte Kreis-Abweichungen
#   (ueber alle Wellen) von welle-spezifischen.
#
# Modell (400 Kreise x 7 Altersgruppen x 8 Wellen = 22.400 Zeilen), gw = Altersgruppe x Welle (56 Zellen):
#   cases ~ 0 + gw + gw:kt + state + gw:(z_sgb2 + z_p65 + z_ltour)
#           + rr(0 + grp | ags, d = 1)        dauerhafter Kreis-Faktor u_k, Ladung je Altersgruppe
#           + rr(0 + grp:dW1 | ags, d = 1) + ... + rr(0 + grp:dW8 | ags, d = 1)
#                                             welle-spezifischer Kreis-Faktor v_kw mit eigenen Ladungen je Welle
#                                             (dW = Indikator der Welle; das ist genau die Kreis-Struktur von A1)
#           + (1 | state:wave) + (1 | state:grp) + (1 | state:grp:wave)   Bundesland: fest + zufaellig
#           + offset(log pop)
#   Familie nbinom2, dispformula = ~ 0 + gw (eigenes theta je Altersgruppe UND Welle), ML (Laplace),
#   profile = TRUE (die 407 festen Effekte werden im inneren Problem geschaetzt; sonst sehr langsam).
#   Randregel fuer theta wie in 22 (theta > 1e4 oder Hessematrix nicht positiv definit -> auf 1e4 festhalten).
# Unterschiede zu A1 (bewusst, sonst haette das Modell 840 Bundesland-Parameter):
#   Bundesland je Altersgruppe x Welle nicht fest, sondern als zufaellige Effekte (state:wave, state:grp,
#   state:grp:wave) um einen festen Bundesland-Effekt. Kreistyp- und Kovariablen-Effekte bleiben je
#   Altersgruppe x Welle frei (wie in A1), damit die Kreistyp-Koeffizienten direkt vergleichbar sind.
# Struktur-Wahl (getestet 25.11.2026, Gesamtmodell mit dauerhaftem Kreis-Faktor):
#   (1 | ags:wave)                         gleiche Kreis-Varianz in allen Wellen und Altersgruppen
#   rr(0 + grp | ags:wave, d = 1)          Ladungen je Altersgruppe, aber gleich in allen Wellen: AIC -55
#   8 x rr(0 + grp:dW | ags, d = 1)        Ladungen je Altersgruppe UND Welle (wie A1):              AIC -2149
#   Mit gleichen Ladungen ueber die Wellen waren die SE gegenueber A1 stark verzerrt (Verhaeltnis 0,73 in W1,
#   2,19 in W5), weil die Kreis-Streuung in W1 viel groesser ist als in W5 (A1: SD 0,34-0,63 vs. 0,07-0,11).
#   Mit eigenen Ladungen je Welle liegt das SE-Verhaeltnis bei 0,99-1,06.
# Tests (Wald, alle aus EINEM Modell):
#   Typ x Alter x Welle    aendert sich das Altersmuster des Kreistyp-Effekts ueber die Wellen?  (df 126)
#   Typ x Alter (gemittelt) gibt es im Mittel ueber die Wellen ein Altersmuster?                 (df 18)
#   Typ x Alter (in einer Welle) gibt es in mindestens einer Welle ein Altersmuster? (ersetzt 8 Tests + Holm; df 144)
#   Typ x Welle            aendert sich der mittlere (ueber Altersgruppen) Kreistyp-Effekt?       (df 21)
#   je Welle               wie in 22 (df 18), dazu Holm ueber die Wellen -> Vergleich mit A1
# Zusaetzlich: gleiches Modell ohne dauerhaften Kreis-Faktor -> LR/AIC (wie wichtig sind dauerhafte Kreis-Abweichungen?)
# Laufzeit: ca. 20-25 Minuten (2 Modelle, jeweils mit Neuanpassung nach der Randregel fuer theta).
# Braucht: glmmTMB; data_processed/modellauswahl/kreis_nb.rds (16); results/modellauswahl/tables/main_kt_coef.csv (22) fuer den Vergleich.
# Ausgabe: results/modellauswahl/tables/crosswave_kt_coef.csv, crosswave_tests.csv, crosswave_varcomp.csv; data_processed/modellauswahl/crosswave_model.rds

source("Scripts/modellauswahl/00_setup.R")
suppressPackageStartupMessages(library(glmmTMB))

WAVES <- readRDS(file.path(DIR_CLEAN, "waves.rds"))$phases[type == "Welle", id]
cv <- model_covariates()
kw <- merge(readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% WAVES],
            cv[, .(ags, kt, z_sgb2, z_p65, z_ltour)], by = "ags")
TERMS <- c(ktT2_staedtisch = "T2", ktT3_laendl_Verdichtung = "T3", ktT4_duenn_besiedelt = "T4")
d <- as.data.frame(kw)
d$grp <- factor(d$grp, GR_COARSE); d$wave <- factor(d$phase, WAVES)
d$gw <- factor(paste(d$grp, d$wave, sep = "_"), as.vector(outer(GR_COARSE, WAVES, paste, sep = "_")))
d$state <- factor(d$state); d$ags <- factor(d$ags); d$lpop <- log(d$pop_rki)
for (w in WAVES) d[[paste0("d", w)]] <- as.numeric(d$wave == w)   # Indikatoren fuer die welle-spezifischen Kreis-Faktoren

# Moran's I der Kreis-Residuen je Welle (wie in 22)
nbo <- readRDS(file.path(DIR_CLEAN, "kreis_nb.rds"))
W <- matrix(0, 400, 400); for (i in seq_along(nbo$nb)) W[i, nbo$nb[[i]]] <- 1 / length(nbo$nb[[i]])
set.seed(20261121); PERM <- replicate(999, sample.int(400))
moran <- function(x) {
  z <- x - mean(x); den <- sum(z^2); I <- sum(z * (W %*% z)) / den; P <- matrix(z[PERM], 400)
  c(I = I, p = (1 + sum(colSums(P * (W %*% P)) / den >= I)) / (ncol(PERM) + 1))
}

CTRL <- glmmTMBControl(optCtrl = list(iter.max = 5000, eval.max = 10000), profile = TRUE)
THETA_MAX <- 1e4
FIX <- "0 + gw + gw:kt + state + gw:(z_sgb2 + z_p65 + z_ltour)"
RE_STATE <- "(1 | state:wave) + (1 | state:grp) + (1 | state:grp:wave) + offset(lpop)"
RE_WAVE <- paste(sprintf("rr(0 + grp:d%s | ags, d = 1)", WAVES), collapse = " + ")
F_D  <- as.formula(paste("cases ~", FIX, "+ rr(0 + grp | ags, d = 1) +", RE_WAVE, "+", RE_STATE))
F_D0 <- as.formula(paste("cases ~", FIX, "+", RE_WAVE, "+", RE_STATE))   # ohne dauerhaften Kreis-Faktor
fit_tmb <- function(f, ...) withCallingHandlers(
  glmmTMB(f, dispformula = ~ 0 + gw, family = nbinom2, data = d, control = CTRL, ...),
  warning = function(w) {
    m <- conditionMessage(w)
    if (grepl("non-integer counts", m) || grepl("non-positive-definite Hessian", m)) invokeRestart("muffleWarning")
  })
fit_d <- function(f) {
  m <- fit_tmb(f)
  bd <- m$fit$par[names(m$fit$par) == "betadisp"]
  fix <- bd > log(THETA_MAX)
  if (!isTRUE(m$sdr$pdHess) && !any(fix)) fix <- bd == max(bd)
  if (any(fix)) {   # Neuanpassung wie in 22 (nur theta als Startwert; Startwerte fuer die Varianzparameter aus der
                    # ersten Anpassung fuehrten beim Modell ohne dauerhaften Faktor in ein schlechteres lokales Optimum)
    st <- pmin(bd, log(THETA_MAX)); st[fix] <- log(THETA_MAX)
    m <- fit_tmb(f, start = list(betadisp = unname(st)), map = list(betadisp = factor(ifelse(fix, NA, seq_along(bd)))))
  }
  attr(m, "theta_fix") <- paste(levels(d$gw)[fix], collapse = ", ")
  attr(m, "fix") <- fix
  m
}

t0 <- Sys.time()
m <- fit_d(F_D)
if (m$fit$convergence != 0 || !isTRUE(m$sdr$pdHess)) stop("Gesamtmodell nicht konvergiert (", m$fit$message, ")")
cat(sprintf("Gesamtmodell: %.1f min | AIC %.0f | theta festgehalten: %s\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins")), AIC(m), if (nzchar(attr(m, "theta_fix"))) attr(m, "theta_fix") else "keine"))
t0 <- Sys.time()
m0 <- fit_d(F_D0)
if (m0$fit$convergence != 0 || !isTRUE(m0$sdr$pdHess)) warning("Modell ohne dauerhaften Kreis-Faktor: nicht konvergiert oder Hessematrix nicht positiv definit")
# LR und AIC-Differenz direkt aus der Zielfunktion (logLik() von glmmTMB ist NA, wenn die Hessematrix nicht positiv definit ist)
lr <- 2 * (m0$fit$objective - m$fit$objective)
dk <- length(m$fit$par) - length(m0$fit$par)     # zusaetzliche Parameter (Ladungen des dauerhaften Faktors)
cat(sprintf("ohne dauerhaften Kreis-Faktor: %.1f min | LR = %.0f (df %d) | AIC-Gewinn durch den dauerhaften Faktor %.0f\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins")), lr, dk, lr - 2 * dk))

# ---- Kreistyp-Koeffizienten je Altersgruppe x Welle ------------------------------------------
b <- fixef(m)$cond; V <- vcov(m)$cond
IX <- array(NA_integer_, c(length(GR_COARSE), length(WAVES), length(TERMS)), list(GR_COARSE, WAVES, TERMS))
for (a in GR_COARSE) for (w in WAVES) for (t in names(TERMS)) IX[a, w, TERMS[[t]]] <- match(sprintf("gw%s_%s:%s", a, w, t), names(b))
stopifnot(!anyNA(IX))
coefs <- CJ(grp = GR_COARSE, wave = WAVES, term = unname(TERMS), sorted = FALSE)
coefs[, i := IX[cbind(match(grp, GR_COARSE), match(wave, WAVES), match(term, TERMS))]]
coefs[, `:=`(est = b[i], se = sqrt(diag(V))[i], i = NULL)]
coefs[, `:=`(irr = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se))]

# ---- Wald-Tests ------------------------------------------------------------------------------
row_of <- function(w8) { r <- numeric(length(b)); r[w8$i] <- w8$w; r }   # Kontrastzeile aus Indizes und Gewichten
wald <- function(C, label) {
  cb <- C %*% b; chi2 <- as.numeric(t(cb) %*% solve(C %*% V %*% t(C), cb))
  data.table(test = label, chi2 = chi2, df = nrow(C), p = pchisq(chi2, nrow(C), lower.tail = FALSE))
}
A <- GR_COARSE[-1]; Wv <- WAVES[-1]; a1 <- GR_COARSE[1]; w1 <- WAVES[1]; nA <- length(GR_COARSE); nW <- length(WAVES)
C_aw <- do.call(rbind, lapply(TERMS, function(t) do.call(rbind, lapply(A, function(a) do.call(rbind, lapply(Wv, function(w)
  row_of(list(i = IX[c(a, a1, a, a1), c(w, w, w1, w1), t][cbind(1:4, 1:4)], w = c(1, -1, -1, 1)))))))))
C_age_w <- function(ws) do.call(rbind, lapply(TERMS, function(t) do.call(rbind, lapply(A, function(a) do.call(rbind, lapply(ws, function(w)
  row_of(list(i = IX[c(a, a1), w, t], w = c(1, -1)))))))))
C_age_avg <- do.call(rbind, lapply(TERMS, function(t) do.call(rbind, lapply(A, function(a)
  row_of(list(i = c(IX[a, , t], IX[a1, , t]), w = c(rep(1 / nW, nW), rep(-1 / nW, nW))))))))
C_wave <- do.call(rbind, lapply(TERMS, function(t) do.call(rbind, lapply(Wv, function(w)
  row_of(list(i = c(IX[, w, t], IX[, w1, t]), w = c(rep(1 / nA, nA), rep(-1 / nA, nA))))))))
tests <- rbind(wald(C_aw, "Typ x Alter x Welle"),
               wald(C_age_avg, "Typ x Alter (gemittelt ueber Wellen)"),
               wald(C_age_w(WAVES), "Typ x Alter (in mindestens einer Welle)"),
               wald(C_wave, "Typ x Welle (gemittelt ueber Altersgruppen)"))
tests[, wave := "alle"]
tw <- rbindlist(lapply(WAVES, function(w) wald(C_age_w(w), "Typ x Alter (je Welle)")[, wave := w]))
tw[, p_holm := p.adjust(p, "holm")]
# Moran's I der Kreis-Residuen je Welle
res <- data.table(ags = as.character(d$ags), wave = as.character(d$wave), r = residuals(m, type = "pearson"))[
  , .(r = mean(r)), by = .(wave, ags)]
for (w in WAVES) {
  mi <- moran(res[wave == w][match(nbo$ags, ags), r])
  tw[wave == w, `:=`(I_resid = mi[["I"]], p_I_resid = mi[["p"]])]
}
tests <- rbind(tests, tw, fill = TRUE)
tests[, `:=`(AIC = AIC(m), dAIC_ohne_dauerhaft = lr - 2 * dk, LR_dauerhaft = lr, df_LR = dk,
             theta_fix = attr(m, "theta_fix"))]

# ---- Varianzkomponenten ----------------------------------------------------------------------
vc <- VarCorr(m)$cond   # Reihenfolge wie in der Formel: ags (dauerhaft), ags.1 ... ags.8 (je Welle), Bundesland
vk <- vc[names(vc) == "ags" | startsWith(names(vc), "ags.")]
stopifnot(length(vk) == 1 + length(WAVES))
vcomp <- rbind(
  data.table(komponente = "Kreis dauerhaft (u_k)", grp = GR_COARSE, sd = unname(sqrt(diag(vk[[1]])))),
  rbindlist(lapply(seq_along(WAVES), function(j)
    data.table(komponente = paste("Kreis je Welle (v_kw)", WAVES[j]), grp = GR_COARSE, sd = unname(sqrt(diag(vk[[j + 1]])))))),
  data.table(komponente = c("Bundesland x Welle", "Bundesland x Altersgruppe", "Bundesland x Altersgruppe x Welle"), grp = "alle",
             sd = vapply(c("state_wave", "state_grp", "state_grp_wave"), function(nm) {
               k <- which(gsub("[.:]", "_", names(vc)) == nm)   # Namen: "state:wave" oder (bei mehreren rr-Termen) "state.wave"
               stopifnot(length(k) == 1); sqrt(vc[[k]][1])
             }, 0)))
fix <- attr(m, "fix"); bdf <- rep(log(THETA_MAX), length(fix))   # festgehaltene theta = THETA_MAX
bdf[!fix] <- m$fit$par[names(m$fit$par) == "betadisp"]
stopifnot(length(bdf) == nlevels(d$gw), sum(!fix) == sum(names(m$fit$par) == "betadisp"))
theta <- data.table(gw = levels(d$gw), theta = exp(unname(bdf)))
theta[, c("grp", "wave") := tstrsplit(gw, "_")]

# ---- Vergleich mit A1 ------------------------------------------------------------------------
a1t <- fread(file.path(DIR_TAB, "main_kt_coef.csv"))[, .(wave, grp, term, est_a1 = est, se_a1 = se)]
coefs <- merge(coefs, a1t, by = c("wave", "grp", "term"), all.x = TRUE)
setcolorder(coefs, c("wave", "grp", "term", "est", "se", "irr", "lo", "hi"))
setorder(coefs, wave, term, grp)
setcolorder(tests, c("wave", "test", "chi2", "df", "p", "p_holm"))
fwrite(coefs, file.path(DIR_TAB, "crosswave_kt_coef.csv"))
fwrite(tests, file.path(DIR_TAB, "crosswave_tests.csv"))
fwrite(rbind(vcomp, theta[, .(komponente = paste("theta", wave), grp, sd = theta)]), file.path(DIR_TAB, "crosswave_varcomp.csv"))
saveRDS(list(coefs = coefs, tests = tests, vcomp = vcomp, theta = theta), file.path(DIR_CLEAN, "crosswave_model.rds"))

# ---- Zusammenfassung -------------------------------------------------------------------------
sig <- function(x) x[, lapply(.SD, function(v) if (is.numeric(v)) signif(v, 3) else v)]
cat("\n== Globale Tests im Gesamtmodell ==\n")
print(sig(tests[wave == "alle", .(test, chi2, df, p)]))
cat("\n== je Welle (df 18): Gesamtmodell vs. A1 (Holm ueber 8 Wellen) ==\n")
a1p <- fread(file.path(DIR_TAB, "main_tests.csv"))[test == "alle Typen", .(wave, p_holm_A1 = p_holm)]
print(sig(merge(tests[test == "Typ x Alter (je Welle)", .(wave, chi2, p, p_holm, I_resid, p_I_resid)], a1p, by = "wave")))
cat(sprintf("\nDauerhafter Kreis-Faktor: LR = %.0f (df %d), AIC-Gewinn %.0f\n", lr, dk, lr - 2 * dk))
cat("\n== Varianzkomponenten (SD auf log-Skala) ==\n")
print(dcast(vcomp[grp != "alle"], grp ~ komponente, value.var = "sd", fun.aggregate = function(x) round(x, 3))[match(GR_COARSE, grp)])
print(vcomp[grp == "alle", .(komponente, sd = round(sd, 3))])
cat("\n== Kreistyp-Koeffizienten: Gesamtmodell vs. A1 ==\n")
print(coefs[, .(r = round(cor(est, est_a1), 3), mittl_abs_diff = round(mean(abs(est - est_a1)), 3),
                se_zu_A1 = round(median(se / se_a1), 2)), by = wave])
cat("signifikante Kreistyp-Koeffizienten (von 168, unkorrigiert): A1",
    fread(file.path(DIR_TAB, "main_kt_coef.csv"))[, sum(lo > 1 | hi < 1)], "| Gesamtmodell", coefs[, sum(lo > 1 | hi < 1)], "\n")
cat("\nIRR Typ 4 vs. Grossstadt je Altersgruppe, Gesamtmodell (* = 95 %-KI ohne 1, unkorrigiert):\n")
x <- coefs[term == "T4"][, lab := sprintf("%.2f%s", irr, fifelse(lo > 1 | hi < 1, "*", ""))]
print(dcast(x, grp ~ wave, value.var = "lab")[match(GR_COARSE, grp)])
