# Alle Abbildungen im einheitlichen Stil (einzige Stelle, an der Abbildungen entstehen; Ausnahme:
# pop_check_rel_diff.png aus 05_check_population.R).
# Reihenfolge: zuletzt ausfuehren (braucht Tabellen aus 09 und 12-24); Scripts/modellauswahl/run_all.R erledigt das.
# Ausgabe: results/modellauswahl/figures/fig01 ... fig29; Altersgruppen-Abbildungen fuer beide Klima-Schemata
#          (grob: fig02, fig04-fig07, fig09-fig12; fein: Suffix _fine). fig13/14 GAM, fig15 grob vs. fein,
#          fig16-18 Karten und Moran's I (nur wenn 16_spatial.R gelaufen ist), fig19 gemeinsames Altersmodell (17),
#          fig20/21 Dichte x Alter als Flaeche (18), fig22/23 PCA und Kreuzvalidierung (19),
#          fig24/25 Ankunftszeit der Wellen (20), fig26 Cluster-Karte (21), fig27 Modellvorschlag A1 (22),
#          fig28 Gesamtmodell ueber alle Wellen (23, Option D), fig29 A1 + BYM2 mit INLA (24, Option III).

# Umlaute und Sonderzeichen (–, ρ) brauchen eine UTF-8-Locale; Rscript startet hier sonst mit "C".
# In diesem Fall startet sich das Skript selbst mit LC_ALL=en_US.UTF-8 neu.
if (!l10n_info()$`UTF-8`) {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  quit(status = system2("Rscript", shQuote(f), env = "LC_ALL=en_US.UTF-8"))
}

source("Scripts/modellauswahl/00_setup.R")
source("Scripts/modellauswahl/00_theme.R")

ag_all <- readRDS(file.path(DIR_CLEAN, "covid_agegrp.rds"))
cov    <- readRDS(file.path(DIR_CLEAN, "covid_long.rds"))
wv     <- readRDS(file.path(DIR_CLEAN, "waves.rds"))
const  <- readRDS(file.path(DIR_CLEAN, "struct_kreis_const.rds"))
ph     <- wv$phases

# Wellen (Ende exklusiv) und Phasenzuordnung je Woche
W <- ph[type == "Welle", .(id, name, start, end = end + 7)]
W[, mid := start + as.numeric(end - start) / 2]
phase_of <- function(wk) ph$id[findInterval(as.numeric(wk), as.numeric(ph$start))]
X_MIN <- min(ag_all$week); X_MAX <- max(ag_all$week) + 7
x_date <- scale_x_date(date_breaks = "3 months", date_labels = "%m/%Y", expand = expansion(mult = c(.005, .005)),
                       limits = c(X_MIN, X_MAX))
x_angle <- theme(axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1))

# ============================================================================================
# A. Nationale Abbildungen (unabhaengig vom Altersschema): fig01, fig03, fig08
# ============================================================================================
ag_c <- ag_all[scheme == "coarse"]
nat <- ag_c[, .(cases = sum(cases), pop = sum(pop_rki)), by = week][, inc := cases / pop * 1e5]
nat[, phase := phase_of(week)]

plot_national <- function(ids, title, subtitle, legend_title, caption = NULL) {
  Wx   <- W[id %in% ids]
  ymax <- 2100
  ggplot() +
    geom_rect(data = Wx, aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf, fill = id), alpha = .13, show.legend = FALSE) +
    geom_line(data = nat, aes(week, inc), colour = GREY_LINE, linewidth = .75) +
    geom_line(data = nat[phase %in% ids], aes(week, inc, colour = phase, group = phase), linewidth = 1.2, lineend = "round") +
    wave_label(Wx, ymax * .955) +
    scale_fill_manual(values = WAVE_COL) +
    scale_colour_manual(values = WAVE_COL, breaks = ids, name = legend_title) +
    scale_y_continuous(labels = lab_de, expand = expansion(mult = c(0, .01)), limits = c(0, ymax)) +
    x_date + labs(x = NULL, y = "Gemeldete Fälle je 100.000 Einwohner / Woche", title = title, subtitle = subtitle, caption = caption) +
    guides(colour = guide_legend(nrow = 1, override.aes = list(linewidth = 1.6))) +
    theme_proj() + x_angle
}

# fig08 und fig01: Projekt-Wellen W1-W8 im Stil der Vorlage (farbige Wellen, grauer Rest, weisse Labels)
p8 <- plot_national(paste0("W", 1:8), "Gemeldete COVID-19-Fälle und Welleneinteilung W1–W8",
                    "W1–W5 und Beginn W6 nach RKI-Phaseneinteilung; Ende W6 sowie W7 und W8 eigene Abgrenzung; Pausen und Restphase grau",
                    "Welle",
                    caption = "Quelle: RKI SurvStat (gemeldete Fälle je 100.000, RKI-Bevölkerung); Phasen: RKI, Epidemiologisches Bulletin 38/2022, eigene Ergänzung")
save_fig(p8, "fig08_rki_phasen.png", 11, 5.4)
save_fig(p8, "fig01_national_gesamt.png", 11, 5.4)      # identische Abbildung unter dem frueheren Namen

# fig03: Heatmap Alter x Woche (Einzeljahre)
ha <- cov[, .(cases = sum(cases), pop = sum(pop)), by = .(age_num, week)][, inc := cases / pop * 1e5]
strip <- copy(W)[, col := WAVE_COL[id]]
p3 <- ggplot(ha, aes(week, age_num, fill = pmax(inc, 1))) + geom_raster() +
  geom_rect(data = strip, aes(xmin = start, xmax = end, ymin = 81.5, ymax = 85), inherit.aes = FALSE, fill = strip$col) +
  geom_text(data = strip, aes(x = mid, y = 83.25, label = id), inherit.aes = FALSE, colour = "white", fontface = "bold", size = 3.2) +
  scale_fill_viridis_c(trans = "log10", option = "magma", name = "Inzidenz\nje 100.000",
                       breaks = c(1, 10, 100, 1000), labels = lab_de) +
  scale_y_continuous(breaks = seq(0, 80, 20), labels = c("0", "20", "40", "60", "80+"), expand = c(0, 0)) +
  scale_x_date(date_breaks = "3 months", date_labels = "%m/%Y", expand = c(0, 0)) +
  labs(x = NULL, y = "Alter (Jahre)", title = "Wocheninzidenz nach Einzelalter",
       subtitle = "Bundesweit; Farbskala logarithmisch, Balken oben: Wellen") +
  theme_proj() + theme(legend.position = "right", panel.grid = element_blank()) + x_angle
save_fig(p3, "fig03_alter_zeit_heatmap.png", 11, 5.6)

# ============================================================================================
# B. Abbildungen je Altersschema (grob / fein): fig02, fig04, fig05, fig06, fig07, fig09
# ============================================================================================
cov_lab <- c(dichte = "Bevölkerungsdichte", kreistyp = "BBSR-Kreistyp (1 Stadt … 4 ländlich)",
             lage = "BBSR-Lage (1 zentral … 4 peripher)", anteil_65p = "Anteil 65+", anteil_0_5 = "Anteil 0–5",
             anteil_18_39 = "Anteil 18–39", sgb2 = "SGB-II-Quote", alo = "Arbeitslose je 100 (15–64)",
             schutzsuchende = "Schutzsuchende je 1.000", pendler_saldo = "Pendlersaldo",
             tourismus = "Übernachtungen je Einw.", hochschulreife = "Hochschulreife-Anteil",
             kita_plaetze = "Kita-Plätze je 1.000")

age_figures <- function(sch, sfx, fine) {
  ag  <- ag_all[scheme == sch]
  # Reihenfolge explizit (die Faktorstufen in covid_agegrp.rds enthalten beide Schemata hintereinander)
  GR  <- if (fine) GR_FINE else GR_COARSE
  stopifnot(setequal(GR, unique(as.character(ag$grp))))
  GRL <- sub("-", "–", GR); names(GRL) <- GR
  grl <- function(g) paste0(GRL[as.character(g)])           # Beschriftung je Gruppe
  cat("\nAbbildungen Altersschema:", sch, "(", length(GR), "Gruppen )\n")

  # ---- fig02: Wocheninzidenz je Altersgruppe ---------------------------------------------------------------
  gw <- rbind(copy(nat)[, grp := "Gesamt"][, .(grp, week, cases, pop, inc, phase)],
              ag[, .(cases = sum(cases), pop = sum(pop_rki)), by = .(grp, week)][
                , `:=`(grp = as.character(grp), inc = cases / pop * 1e5, phase = phase_of(week))])
  gw[, grp_lab := factor(fifelse(grp == "Gesamt", "Alle Altersgruppen", paste0(grl(grp), " Jahre")),
                         levels = c("Alle Altersgruppen", paste0(GRL, " Jahre")))]
  p2 <- ggplot() +
    geom_rect(data = W, aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf, fill = id), alpha = .10, show.legend = FALSE) +
    geom_line(data = gw, aes(week, inc), colour = GREY_LINE, linewidth = .5) +
    geom_line(data = gw[phase %in% W$id], aes(week, inc, colour = phase, group = phase), linewidth = .8, lineend = "round") +
    facet_wrap(~grp_lab, ncol = if (fine) 3 else 2, scales = "free_y") +
    scale_fill_manual(values = WAVE_COL) + scale_colour_manual(values = WAVE_COL, name = "Welle") +
    scale_y_continuous(labels = lab_de, expand = expansion(mult = c(0, .05)), limits = c(0, NA)) +
    scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y", expand = expansion(mult = c(.005, .005)), limits = c(X_MIN, X_MAX)) +
    labs(x = NULL, y = "Gemeldete Fälle je 100.000 / Woche", title = "Wocheninzidenz nach Altersgruppe",
         subtitle = "Eigene y-Achse je Panel; Wellen farbig, Pausen grau") +
    guides(colour = guide_legend(nrow = 1, override.aes = list(linewidth = 1.6))) + theme_proj() + x_angle +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1, size = if (fine) 7 else 9))
  save_fig(p2, paste0("fig02_national_altersgruppen", sfx, ".png"), if (fine) 13 else 10, if (fine) 14 else 11)

  # ---- fig04: Altersprofil je Welle ----------------------------------------------------------------------------
  kw <- readRDS(file.path(DIR_CLEAN, paste0("covid_wave_kreis", sfx, ".rds")))
  a  <- kw[phase %in% W$id, .(cases = sum(cases), pop = sum(pop_rki)), by = .(phase, grp)]
  a  <- merge(a, a[, .(tc = sum(cases), tp = sum(pop)), by = phase], by = "phase")
  a[, ratio := (cases / pop) / (tc / tp)]
  a[, `:=`(grp = factor(grp, levels = GR),
           lab = factor(phase, levels = W$id,
                        labels = sprintf("%s  %s–%s", W$id, format(W$start, "%m/%Y"), format(W$end - 7, "%m/%Y"))))]
  p4 <- ggplot(a, aes(grp, ratio, fill = phase)) + geom_col(width = .75) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey35", linewidth = .4) +
    geom_text(aes(label = sprintf("%.1f", ratio)), vjust = -.35, size = if (fine) 2.2 else 2.7, colour = "grey25") +
    facet_wrap(~lab, ncol = 4) + scale_fill_manual(values = WAVE_COL, guide = "none") +
    scale_x_discrete(labels = GRL) + scale_y_continuous(expand = expansion(mult = c(0, .12))) +
    labs(x = "Altersgruppe", y = "Inzidenz der Gruppe / Gesamtinzidenz",
         title = "Altersprofil je Welle", subtitle = "Verhältnis der kumulativen Inzidenz einer Altersgruppe zur Gesamtinzidenz der Welle (gestrichelt: 1)") +
    theme_proj() + theme(axis.text.x = element_text(size = if (fine) 6.5 else 8, angle = if (fine) 45 else 0, hjust = if (fine) 1 else .5))
  save_fig(p4, paste0("fig04_altersprofil_je_welle", sfx, ".png"), if (fine) 14 else 12, if (fine) 7 else 6)

  # ---- fig05: Wochenverlauf nach Raumtyp --------------------------------------------------------------------------
  dd <- merge(ag, const[, .(ags, kreistyp_code)], by = "ags")
  wk_t <- dd[, .(cases = sum(cases), pop = sum(pop_rki)), by = .(kreistyp_code, grp, week)]
  # Pseudo-log-Achse (ab etwa 2 logarithmisch, darunter linear): Wochen ohne Faelle (0) und Werte unter 1 bleiben
  # sichtbar; mit scale_y_log10(limits = c(1, NA)) fielen sie still aus der Abbildung (externe Pruefung 26.11.2026)
  wk_t[, `:=`(inc = cases / pop * 1e5, kt = factor(kreistyp_code, 1:4, KT_LAB),
              grp_lab = factor(paste0(grl(grp), " Jahre"), levels = paste0(GRL, " Jahre")))]
  p5 <- ggplot(wk_t, aes(week, inc, colour = kt)) +
    geom_rect(data = W, aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf), inherit.aes = FALSE, fill = "grey70", alpha = .16) +
    geom_line(linewidth = .5) + facet_wrap(~grp_lab, ncol = if (fine) 3 else 2) +
    scale_y_continuous(trans = scales::pseudo_log_trans(sigma = 1, base = 10), breaks = c(0, 1, 10, 100, 1000, 10000),
                       labels = lab_de) + scale_colour_manual(values = KT_COL, name = NULL) +
    scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y", expand = expansion(mult = c(.005, .005)), limits = c(X_MIN, X_MAX)) +
    labs(x = NULL, y = "Gemeldete Fälle je 100.000 / Woche (log, 0 sichtbar)", title = "Wocheninzidenz nach Altersgruppe und BBSR-Kreistyp",
         subtitle = "Graue Flächen: Wellen; y-Achse logarithmisch, unterhalb von etwa 2 linear, damit Wochen ohne Fälle (0) sichtbar bleiben") +
    guides(colour = guide_legend(nrow = 2, override.aes = list(linewidth = 1.6))) + theme_proj() + x_angle +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1, size = if (fine) 7 else 9))
  suppressWarnings(save_fig(p5, paste0("fig05_woche_kreistyp_alter", sfx, ".png"), if (fine) 13 else 10, if (fine) 14 else 11))

  # ---- fig06: Raumtyp relativ zum Bundeswert ------------------------------------------------------------------------
  rt <- fread(file.path(DIR_TAB, paste0("urban_kreistyp_wave_age", sfx, ".csv")))
  rt[, `:=`(kt = factor(as.integer(substr(kreistyp, 1, 1)), 1:4, KT_LAB), grp = factor(grp, levels = GR),
            phase = factor(phase, levels = W$id))]
  p6 <- ggplot(rt, aes(phase, grp, fill = ratio)) + geom_tile(colour = "white", linewidth = .8) +
    geom_text(aes(label = sprintf("%.2f", ratio)), size = if (fine) 2.4 else 2.9, colour = "grey15") +
    facet_wrap(~kt, ncol = 2) +
    scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", midpoint = 0, trans = "log2",
                         limits = c(0.5, 2), oob = squish, breaks = c(.5, .7, 1, 1.4, 2), labels = c("0,5", "0,7", "1", "1,4", "2"),
                         name = "Verhältnis zum\nBundeswert") +
    scale_y_discrete(labels = GRL) +
    labs(x = "Welle", y = "Altersgruppe", title = "Kumulative Inzidenz nach Raumtyp relativ zum Bundeswert",
         subtitle = "Je Welle und Altersgruppe; rot = höher als bundesweit, blau = niedriger") +
    theme_proj() + theme(legend.position = "right", panel.grid = element_blank())
  suppressWarnings(save_fig(p6, paste0("fig06_verhaeltnis_kreistyp_welle_alter", sfx, ".png"), 11.5, if (fine) 11 else 7.8))

  # ---- fig07: Rangkorrelationen mit Strukturmerkmalen -----------------------------------------------------------------
  co <- fread(file.path(DIR_TAB, paste0("corr_wave_age_struct", sfx, ".csv")))
  co <- co[covariate %in% names(cov_lab)]
  co[, `:=`(cv = factor(covariate, levels = rev(names(cov_lab)), labels = rev(cov_lab)), grp = factor(grp, levels = GR),
            phase = factor(phase, levels = W$id))]
  p7 <- ggplot(co, aes(grp, cv, fill = rho)) + geom_tile(colour = "white", linewidth = .6) +
    geom_text(aes(label = sprintf("%.1f", rho)), size = if (fine) 2 else 2.4, colour = "grey15") +
    facet_wrap(~phase, ncol = 4) +
    scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", limits = c(-.8, .8), oob = squish, name = "Spearman ρ") +
    scale_x_discrete(labels = GRL) +
    labs(x = "Altersgruppe", y = NULL, title = "Rangkorrelation: Kreisinzidenz je Welle und Strukturmerkmal",
         subtitle = "Explorativ, nicht adjustiert, Kreisebene (n ≈ 400); Merkmale als Mittelwert 2020–2023; Bundesland-Kontrolle siehe fig09") +
    theme_proj() + theme(panel.grid = element_blank(), axis.text.x = element_text(size = if (fine) 6 else 7.5),
                         legend.key.width = unit(1.6, "cm"))
  save_fig(p7, paste0("fig07_korrelation_welle_alter", sfx, ".png"), if (fine) 17 else 14, if (fine) 8.4 else 7.6)

  # ---- fig09: Raummasse gesamt vs. innerhalb der Bundeslaender -------------------------------------------------------------
  wc <- fread(file.path(DIR_TAB, paste0("corr_within_state", sfx, ".csv")))
  wc <- wc[covariate %in% c("kreistyp", "dichte")]
  wl <- melt(wc, id.vars = c("phase", "grp", "covariate"), measure.vars = c("rho", "rho_im_land"),
             variable.name = "messung", value.name = "rho")
  wl[, `:=`(messung = factor(messung, c("rho", "rho_im_land"), c("Alle Kreise (Bundesland nicht kontrolliert)", "Innerhalb der Bundesländer")),
            cov = factor(covariate, c("kreistyp", "dichte"), c("BBSR-Kreistyp (positiv: ländlicher = höher)",
                                                                  "Bevölkerungsdichte (positiv: dichter = höher)")),
            grp = factor(grp, levels = GR), phase = factor(phase, levels = W$id))]
  p9 <- ggplot(wl, aes(phase, grp, fill = rho)) + geom_tile(colour = "white", linewidth = .6) +
    geom_text(aes(label = sprintf("%.2f", rho)), size = if (fine) 2.1 else 2.6, colour = "grey15") +
    facet_grid(cov ~ messung) +
    scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", limits = c(-.6, .6), oob = squish, name = "Spearman ρ") +
    scale_y_discrete(labels = GRL) +
    labs(x = "Welle", y = "Altersgruppe", title = "Raummaße und Kreisinzidenz: mit und ohne Kontrolle des Bundeslands",
         subtitle = "Rangkorrelation je Welle und Altersgruppe; rechts: Ränge je Bundesland zentriert (Stadtstaaten entfallen)") +
    theme_proj() + theme(legend.position = "right", panel.grid = element_blank(), strip.text.y = element_text(angle = 0))
  save_fig(p9, paste0("fig09_raummass_im_bundesland", sfx, ".png"), 12.5, if (fine) 12 else 8.5)
}

# ============================================================================================
# C. Modellabbildungen (aus 12_models_wave_age.R): fig10 Raumtyp-IRR, fig11 Robustheit, fig12 Dichte
# ============================================================================================
model_figures <- function(sfx, fine) {
  GR  <- if (fine) GR_FINE else GR_COARSE
  GRL <- sub("-", "–", GR); names(GRL) <- GR
  mc  <- fread(file.path(DIR_TAB, paste0("model_nb_coef", sfx, ".csv")))
  mc[, `:=`(grp = factor(grp, levels = GR), wave = factor(wave, levels = W$id))]
  sub10 <- "Negativbinomial-Modell je Welle und Altersgruppe, adjustiert für Bundesland, SGB-II-Quote, Anteil 65+ und Tourismus; * = 95 %-KI ohne 1 (nicht für multiples Testen korrigiert)"

  # fig10: IRR der Raumtypen gegenueber Grossstaedten (Ausgangsmodell m1)
  m <- mc[spec == "m1" & grepl("^kt", term)]
  m[, `:=`(tp = factor(term, c("ktT2_staedtisch", "ktT3_laendl_Verdichtung", "ktT4_duenn_besiedelt"),
                       paste0(KT_LAB[2:4], "\nim Vergleich zur Kreisfreien Großstadt")),
           sig = lo > 1 | hi < 1)]
  p10 <- ggplot(m, aes(wave, grp, fill = irr)) + geom_tile(colour = "white", linewidth = .8) +
    geom_text(aes(label = paste0(sprintf("%.2f", irr), fifelse(sig, "*", "")), fontface = fifelse(sig, "bold", "plain")),
              size = if (fine) 2.5 else 3, colour = "grey15") +
    facet_wrap(~tp, nrow = 1) +
    scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", midpoint = 0, trans = "log2",
                         limits = c(0.6, 1.67), oob = squish, breaks = c(.6, .8, 1, 1.25, 1.6),
                         labels = c("0,6", "0,8", "1", "1,25", "1,6"), name = "Inzidenz-\nverhältnis (IRR)") +
    scale_y_discrete(labels = GRL) +
    labs(x = "Welle", y = "Altersgruppe", title = "Raumtyp und Inzidenz: adjustierte Inzidenzverhältnisse", subtitle = sub10) +
    theme_proj() + theme(legend.position = "right", panel.grid = element_blank(), strip.text = element_text(size = 9.5),
                         plot.subtitle = element_text(size = 9, colour = "grey30"))
  save_fig(p10, paste0("fig10_modell_raumtyp_irr", sfx, ".png"), 14, if (fine) 7.4 else 4.8)

  # fig11: Robustheit des Effekts "duenn besiedelt" gegenueber Spezifikation und Nenner
  rb <- mc[term == "ktT4_duenn_besiedelt" & spec %in% c("m0", "m1", "m3", "m1_gen")]
  rb[, spec_lab := factor(spec, c("m0", "m1", "m3", "m1_gen"),
                          c("m0: nur Bundesland", "Ausgangsmodell m1", "m1 + BBSR-Lage (m3)", "m1 mit GENESIS-Nenner"))]
  rb[, grp_lab := factor(paste0(GRL[as.character(grp)], " Jahre"), levels = paste0(GRL, " Jahre"))]
  pd <- position_dodge(width = .6)
  p11 <- ggplot(rb, aes(wave, irr, colour = spec_lab, shape = spec_lab)) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
    geom_errorbar(data = rb[spec == "m1"], aes(ymin = lo, ymax = hi), width = 0, linewidth = .5, position = pd, show.legend = FALSE) +
    geom_point(size = 1.8, position = pd) + facet_wrap(~grp_lab, ncol = if (fine) 5 else 4) +
    scale_y_log10(breaks = c(.6, .8, 1, 1.25, 1.6), labels = c("0,6", "0,8", "1", "1,25", "1,6")) +
    scale_colour_manual(values = setNames(c("#8A97A3", "#D55E00", "#0072B2", "#009E73"), levels(rb$spec_lab)),
                        limits = levels(rb$spec_lab), name = NULL) +
    scale_shape_manual(values = setNames(c(1, 16, 17, 15), levels(rb$spec_lab)),
                       limits = levels(rb$spec_lab), name = NULL) +
    labs(x = "Welle", y = "IRR dünn besiedelter ländlicher Kreis vs. Großstadt (log)",
         title = "Robustheit: Effekt „dünn besiedelt“ je Spezifikation und Nenner",
         subtitle = "Getrennte NB-Modelle je Welle × Altersgruppe (nicht A1); Fehlerbalken: 95 %-KI von m1; Nenner (GENESIS) ändert die Schätzer kaum") +
    guides(colour = guide_legend(nrow = 1), shape = guide_legend(nrow = 1)) +
    theme_proj() + theme(axis.text.x = element_text(size = 7))
  save_fig(p11, paste0("fig11_modell_robustheit", sfx, ".png"), if (fine) 15 else 12, if (fine) 9.5 else 6.8)

  # fig12: Dichte als stetiges Raummass (Robustheit)
  dm <- mc[spec == "m2" & term == "z_ldichte"][, sig := lo > 1 | hi < 1]
  p12 <- ggplot(dm, aes(wave, grp, fill = irr)) + geom_tile(colour = "white", linewidth = .8) +
    geom_text(aes(label = paste0(sprintf("%.2f", irr), fifelse(sig, "*", "")), fontface = fifelse(sig, "bold", "plain")),
              size = if (fine) 2.6 else 3.1, colour = "grey15") +
    scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", midpoint = 0, trans = "log2",
                         limits = c(0.75, 1.33), oob = squish, breaks = c(.8, .9, 1, 1.1, 1.25),
                         labels = c("0,8", "0,9", "1", "1,1", "1,25"), name = "IRR je 1 SD\nlog(Dichte)") +
    scale_y_discrete(labels = GRL) +
    labs(x = "Welle", y = "Altersgruppe", title = "Bevölkerungsdichte und Inzidenz: adjustierte Inzidenzverhältnisse",
         subtitle = "Je 1 Standardabweichung log(Dichte); sonst wie fig10; * = 95 %-KI ohne 1") +
    theme_proj() + theme(legend.position = "right", panel.grid = element_blank(), plot.subtitle = element_text(size = 9.5))
  save_fig(p12, paste0("fig12_modell_dichte_irr", sfx, ".png"), 8.5, if (fine) 6.4 else 4.6)
}

# ============================================================================================
# D. GAM-Abbildungen (aus 13_gam_age.R): fig13 Raumtyp x Alter, fig14 Dichte x Alter
# ============================================================================================
gam_figures <- function() {
  f <- file.path(DIR_CLEAN, "gam_age_curves.rds")
  if (!file.exists(f)) return(invisible())
  cu <- readRDS(f)$curves
  wl <- sprintf("%s  %s–%s", W$id, format(W$start, "%m/%Y"), format(W$end - 7, "%m/%Y"))
  cu[, wave_lab := factor(wave, levels = W$id, labels = wl)]
  # Band: Bootstrap-Perzentil-KI (Kreise innerhalb der Laender), falls 13 mit BOOT_B gelaufen ist; die modellbasierten
  # KI sind seit der altersspezifischen Adjustierung (24.11.2026) deutlich zu schmal (siehe reports/modellauswahl/phase3_modelle.md Teil 2)
  boot <- all(c("lo_b", "hi_b") %in% names(cu)) && !anyNA(cu[spec %in% c("kt_rki", "dens"), lo_b])
  if (boot) cu[, `:=`(lo_band = lo_b, hi_band = hi_b)] else cu[, `:=`(lo_band = lo, hi_band = hi)]
  # Zahl der Wiederholungen aus dem Lauf von 13 (boot: B und erfolgreiche Wiederholungen je Welle), nicht fest eingetragen
  bi <- readRDS(f)$boot
  band <- if (!boot) "Band: 95 %-KI (modellbasiert, eher zu schmal)" else if (is.null(bi)) "Band: 95 %-KI aus Kreis-Bootstrap" else
    if (all(bi$n_ok == bi$B)) sprintf("Band: 95 %%-KI aus Kreis-Bootstrap (%d Wiederholungen)", max(bi$B)) else
      sprintf("Band: 95 %%-KI aus Kreis-Bootstrap (%d Wiederholungen, davon %d–%d erfolgreich)", max(bi$B), min(bi$n_ok), max(bi$n_ok))
  sub13 <- paste0("Negativbinomial-GAM je Welle, Alter (0–79, Einzeljahre) als glatte Funktion; ", band, ";\n",
                  "adjustiert für Bundesland und Kovariaten (SGB-II-Quote, Anteil 65+, Tourismus) mit altersabhängiger Wirkung, Kreis-Zufallseffekt")

  k <- cu[spec == "kt_rki"]
  k[, tp := factor(term, c("T2", "T3", "T4"), KT_LAB[2:4])]
  col3 <- setNames(KT_COL[2:4], KT_LAB[2:4])
  p13 <- ggplot(k, aes(age, irr, colour = tp, fill = tp)) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
    geom_ribbon(aes(ymin = lo_band, ymax = hi_band), alpha = .14, colour = NA) + geom_line(linewidth = .75) +
    facet_wrap(~wave_lab, ncol = 4) +
    scale_y_log10(breaks = c(.5, .7, 1, 1.4, 2), labels = c("0,5", "0,7", "1", "1,4", "2")) +
    coord_cartesian(ylim = c(.45, 2.2)) + scale_x_continuous(breaks = c(0, 20, 40, 60, 79)) +
    scale_colour_manual(values = col3, name = NULL) + scale_fill_manual(values = col3, guide = "none") +
    labs(x = "Alter (Jahre)", y = "Inzidenzverhältnis gegenüber Kreisfreier Großstadt (log)",
         title = "Raumtyp und Inzidenz in Einzeljahren: altersabhängige Inzidenzverhältnisse", subtitle = sub13) +
    guides(colour = guide_legend(nrow = 1, override.aes = list(linewidth = 1.6))) +
    theme_proj() + theme(plot.subtitle = element_text(size = 9, colour = "grey30"))
  save_fig(p13, "fig13_gam_raumtyp_alter.png", 14, 7.4)

  d <- cu[spec == "dens"]
  p14 <- ggplot(d, aes(age, irr)) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
    geom_ribbon(aes(ymin = lo_band, ymax = hi_band), fill = "#0072B2", alpha = .2) + geom_line(colour = "#0072B2", linewidth = .8) +
    facet_wrap(~wave_lab, ncol = 4) +
    scale_y_log10(breaks = c(.7, .8, .9, 1, 1.1, 1.25, 1.4), labels = c("0,7", "0,8", "0,9", "1", "1,1", "1,25", "1,4")) +
    coord_cartesian(ylim = c(.65, 1.5)) + scale_x_continuous(breaks = c(0, 20, 40, 60, 79)) +
    labs(x = "Alter (Jahre)", y = "Inzidenzverhältnis je 1 SD log(Dichte) (log)",
         title = "Bevölkerungsdichte und Inzidenz in Einzeljahren (GAM)",
         subtitle = paste0("Wie fig13, mit log(Dichte) (standardisiert) statt Kreistyp; ", band)) +
    theme_proj() + theme(plot.subtitle = element_text(size = 9.5, colour = "grey30"))
  save_fig(p14, "fig14_gam_dichte_alter.png", 14, 6.4)
}

# ============================================================================================
# E. Vergleich grobes vs. feines Altersschema (aus 15_compare_schemes.R): fig15
# ============================================================================================
scheme_figure <- function() {
  f <- file.path(DIR_TAB, "scheme_compare_model.csv")
  if (!file.exists(f)) return(invisible())
  m <- fread(f)[term == "T4"]
  sm <- fread(file.path(DIR_TAB, "scheme_compare_summary.csv"))
  het <- sprintf("Q-Test auf Unterschiede zwischen Untergruppen: %d von %d Zellen (T2–T4) mit p < 0,05",
                 sum(sm$p_Q < .05), nrow(sm))
  m[, `:=`(x = match(fine, GR_FINE), wave = factor(wave, W$id))]
  # grobe Gruppe als Balken ueber ihre feinen Untergruppen
  cg <- m[, .(x0 = min(x) - .42, x1 = max(x) + .42, irr_c = irr_c[1], lo_c = lo_c[1], hi_c = hi_c[1]), by = .(wave, coarse)]
  wl <- sprintf("%s  %s–%s", W$id, format(W$start, "%m/%Y"), format(W$end - 7, "%m/%Y"))
  m[, wave_lab := factor(wave, W$id, wl)]; cg[, wave_lab := factor(wave, W$id, wl)]
  p15 <- ggplot() +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
    geom_rect(data = cg, aes(xmin = x0, xmax = x1, ymin = lo_c, ymax = hi_c), fill = "#D55E00", alpha = .13) +
    geom_segment(data = cg, aes(x = x0, xend = x1, y = irr_c, yend = irr_c, colour = "grob (7 Gruppen)"), linewidth = 1.1) +
    geom_errorbar(data = m, aes(x = x, ymin = lo_f, ymax = hi_f), width = 0, linewidth = .45, colour = "#0072B2") +
    geom_point(data = m, aes(x = x, y = irr_f, colour = "fein (13 Gruppen)"), size = 1.6) +
    facet_wrap(~wave_lab, ncol = 4) +
    scale_x_continuous(breaks = seq_along(GR_FINE), labels = sub("-", "–", GR_FINE), expand = expansion(add = .3)) +
    scale_y_log10(breaks = c(.5, .7, 1, 1.4, 2), labels = c("0,5", "0,7", "1", "1,4", "2")) +
    coord_cartesian(ylim = c(.45, 2.1)) +
    scale_colour_manual(values = c("grob (7 Gruppen)" = "#D55E00", "fein (13 Gruppen)" = "#0072B2"), name = NULL) +
    labs(x = "Altersgruppe (feines Schema)", y = "IRR dünn besiedelter ländlicher Kreis vs. Großstadt (log)",
         title = "Grobes vs. feines Altersschema: Effekt „dünn besiedelt“ je Welle",
         subtitle = paste0("Ausgangsmodell m1; Balken und Fläche: grobe Gruppe mit 95 %-KI, Punkte: feine Untergruppen mit 95 %-KI. ", het)) +
    guides(colour = guide_legend(override.aes = list(linewidth = 1.1))) +
    theme_proj() + theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = .5, size = 7),
                         plot.subtitle = element_text(size = 9, colour = "grey30"), panel.grid.major.x = element_blank())
  save_fig(p15, "fig15_altersschema_grob_fein.png", 14, 7.6)
}

# ============================================================================================
# F. Karten und raeumliche Autokorrelation (aus 16_spatial.R): fig16 Kreistyp, fig17 Inzidenz je Welle,
#    fig18 Moran's I. Geometrie: BKG VG250, vereinfacht (© GeoBasis-DE / BKG, Daten veraendert).
# ============================================================================================
map_figures <- function() {
  f <- file.path(DIR_CLEAN, "kreis_geo.rds")
  if (!file.exists(f) || !requireNamespace("sf", quietly = TRUE)) return(invisible())
  suppressPackageStartupMessages(library(sf))
  g <- readRDS(f)
  # Laendergrenzen: vereinfachte Kreisflaechen beruehren sich nicht exakt -> kurz puffern, vereinigen, zurueck
  st <- st_buffer(aggregate(st_buffer(g["state"], 150), by = list(land = g$state), FUN = function(x) x[1]), -150)
  map_theme <- theme_proj() + theme(axis.text = element_blank(), panel.grid.major = element_blank(),
                                    axis.title = element_blank())
  geo_cap <- "Kreisgrenzen: © GeoBasis-DE / BKG (Daten verändert), vereinfacht"

  # fig16: BBSR-Kreistyp
  g16 <- merge(g, const[, .(ags, kt = factor(kreistyp_code, 1:4, KT_LAB))], by = "ags")
  p16 <- ggplot(g16) + geom_sf(aes(fill = kt), colour = "white", linewidth = .08) +
    geom_sf(data = st, fill = NA, colour = "grey25", linewidth = .35) +
    scale_fill_manual(values = setNames(KT_COL, KT_LAB), name = NULL) +
    labs(title = "Siedlungsstruktureller Kreistyp (BBSR 2020)", subtitle = "400 Kreise, Linien: Bundesländer",
         caption = geo_cap) +
    guides(fill = guide_legend(ncol = 2)) + map_theme
  save_fig(p16, "fig16_karte_kreistyp.png", 7.5, 9)

  # fig17: kumulative Inzidenz (alle Altersgruppen) relativ zum Bundeswert je Welle
  kw <- readRDS(file.path(DIR_CLEAN, "covid_wave_kreis.rds"))[phase %in% W$id]
  ki <- kw[, .(cases = sum(cases), pop = sum(pop_rki)), by = .(ags, phase)]
  ki[, ratio := (cases / pop) / (sum(cases) / sum(pop)), by = phase]
  wl <- sprintf("%s  %s–%s", W$id, format(W$start, "%m/%Y"), format(W$end - 7, "%m/%Y"))
  ki[, wave_lab := factor(phase, W$id, wl)]
  g17 <- merge(g, ki, by = "ags")
  p17 <- ggplot(g17) + geom_sf(aes(fill = ratio), colour = NA) +
    geom_sf(data = st, fill = NA, colour = "grey25", linewidth = .2) +
    facet_wrap(~wave_lab, ncol = 4) +
    scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", midpoint = 0, trans = "log2",
                         limits = c(.4, 2.5), oob = squish, breaks = c(.5, .7, 1, 1.4, 2),
                         labels = c("0,5", "0,7", "1", "1,4", "2"), name = "Kumulative Inzidenz\nrelativ zum Bundeswert") +
    labs(title = "Kumulative Inzidenz je Kreis und Welle (alle Altersgruppen)",
         subtitle = "Verhältnis zur bundesweiten kumulativen Inzidenz der Welle; Linien: Bundesländer", caption = geo_cap) +
    map_theme + theme(legend.position = "right", strip.text = element_text(size = 10))
  save_fig(p17, "fig17_karte_inzidenz_welle.png", 13, 9.6)

  # fig18: Moran's I je Welle x Altersgruppe
  mo <- fread(file.path(DIR_TAB, "spatial_moran.csv"))
  ml <- rbind(mo[, .(wave, grp, typ = "Kumulative Inzidenz (log)", I = I_inzidenz, p = p_inzidenz)],
              mo[, .(wave, grp, typ = "Residuen Ausgangsmodell m1", I = I_resid, p = p_resid)],
              mo[, .(wave, grp, typ = "Residuen m1 + räumlicher Effekt (MRF)", I = I_resid_sp, p = p_resid_sp)])
  ml[, `:=`(typ = factor(typ, unique(typ)), wave = factor(wave, W$id), grp = factor(grp, GR_COARSE))]
  p18 <- ggplot(ml, aes(wave, grp, fill = I)) + geom_tile(colour = "white", linewidth = .8) +
    geom_text(aes(label = paste0(sprintf("%.2f", I), fifelse(p < .05, "*", "")), fontface = fifelse(p < .05, "bold", "plain")),
              size = 2.9, colour = "grey15") +
    facet_wrap(~typ, nrow = 1) +
    scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", midpoint = 0, limits = c(-.2, .9), oob = squish,
                         breaks = c(0, .3, .6, .9), labels = c("0", "0,3", "0,6", "0,9"), name = "Moran's I") +
    scale_y_discrete(labels = function(x) sub("-", "–", x)) +
    labs(x = "Welle", y = "Altersgruppe", title = "Räumliche Autokorrelation zwischen Nachbarkreisen (Moran's I)",
         subtitle = "Nachbarn: gemeinsame Grenze; * = Permutationstest p < 0,05. Ohne Autokorrelation ist I ≈ 0") +
    theme_proj() + theme(legend.position = "right", panel.grid = element_blank(), plot.subtitle = element_text(size = 9.5))
  save_fig(p18, "fig18_moran_autokorrelation.png", 14, 4.8)
}

# ============================================================================================
# G. Gemeinsames Altersmodell (17_joint_age_models.R): fig19; Dichte x Alter als Flaeche (18_gam_age_density.R):
#    fig20 Flaeche, fig21 Kontrast 90. vs. 10. Perzentil der Dichte
# ============================================================================================
joint_figures <- function() {
  wl <- sprintf("%s  %s–%s", W$id, format(W$start, "%m/%Y"), format(W$end - 7, "%m/%Y")); names(wl) <- W$id
  fmt_p <- function(p) ifelse(p < .001, "< 0,001", paste("=", formatC(p, format = "f", digits = 3, decimal.mark = ",")))
  # Kreistyp-Effekt je Altersgruppe und Welle (fig19: 17 mit MRF, fig27: Modellvorschlag A1, 22); p_lab = Zusatz je Welle
  kt_age_plot <- function(jc, p_lab, title, subtitle) {
    jc[, `:=`(wave_lab = factor(p_lab[wave], p_lab[W$id]), grp = factor(grp, GR_COARSE),
              tp = factor(term, c("T2", "T3", "T4"), KT_LAB[2:4]))]
    pd <- position_dodge(width = .6)
    ggplot(jc, aes(grp, irr, colour = tp)) +
      geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
      geom_errorbar(aes(ymin = lo, ymax = hi), width = 0, linewidth = .5, position = pd) +
      geom_point(size = 1.7, position = pd) + facet_wrap(~wave_lab, ncol = 4) +
      scale_x_discrete(labels = function(x) sub("-", "–", x)) +
      scale_y_log10(breaks = c(.6, .8, 1, 1.25, 1.6), labels = c("0,6", "0,8", "1", "1,25", "1,6")) +
      scale_colour_manual(values = setNames(KT_COL[2:4], KT_LAB[2:4]), name = NULL) +
      labs(x = "Altersgruppe", y = "Inzidenzverhältnis gegenüber Kreisfreier Großstadt (log)", title = title, subtitle = subtitle) +
      guides(colour = guide_legend(nrow = 1)) +
      theme_proj() + theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8), strip.text = element_text(size = 9.5),
                           plot.subtitle = element_text(size = 9, colour = "grey30"))
  }
  f <- file.path(DIR_TAB, "joint_kt_coef.csv")
  if (file.exists(f)) {
    jc <- fread(f)[spec == "int"]
    jt <- fread(file.path(DIR_TAB, "joint_tests.csv"))[test == "alle Typen"]
    lab <- setNames(sprintf("%s\nKreistyp × Alter: p %s", wl[jt$wave], fmt_p(jt$p)), jt$wave)
    p19 <- kt_age_plot(jc, lab, "Sensitivität mit räumlichem Effekt: Kreistyp-Effekt je Altersgruppe",
      "NB-Modell je Welle mit gemeinsamem theta, Kreis-Zufallseffekt und räumlichem Effekt (Nachbarkreise, MRF); Bundesland und Kovariaten altersspezifisch;\n95 %-KI (bei 0–5 und 80+ zu schmal, siehe A1, fig27); p: Wald-Test „gleicher Effekt in allen Altersgruppen“ (18 Kontraste)")
    save_fig(p19, "fig19_gemeinsames_modell_kreistyp_alter.png", 14, 8)
  }
  f <- file.path(DIR_TAB, "main_kt_coef.csv")
  if (file.exists(f)) {
    mc <- fread(f)
    mt <- fread(file.path(DIR_TAB, "main_tests.csv"))[test == "alle Typen"]
    lab <- setNames(sprintf("%s\nKreistyp × Alter: p %s (Holm %s)", wl[mt$wave], fmt_p(mt$p), sub("^= ", "", fmt_p(mt$p_holm))), mt$wave)
    p27 <- kt_age_plot(mc, lab, "Modellvorschlag A1: Kreistyp-Effekt je Altersgruppe",
      "NB-Modell je Welle über alle Altersgruppen mit eigenem theta je Altersgruppe und Kreis-Zufallseffekt (glmmTMB); Kreistyp × Altersgruppe,\nBundesland und Kovariaten altersspezifisch; 95 %-KI (unkorrigiert); p: Wald-Test „gleicher Effekt in allen Altersgruppen“ (18 Kontraste), Holm über 8 Wellen")
    save_fig(p27, "fig27_hauptmodell_kreistyp_alter.png", 14, 8)
  }
  # Option D (23): Gesamtmodell ueber alle Wellen -> Verlauf des Kreistyp-Effekts je Altersgruppe
  f <- file.path(DIR_TAB, "crosswave_kt_coef.csv")
  if (file.exists(f)) {
    cc <- fread(f)[, `:=`(grp = factor(grp, GR_COARSE, sub("-", "–", GR_COARSE)), wave = factor(wave, W$id),
                          tp = factor(term, c("T2", "T3", "T4"), KT_LAB[2:4]))]
    ct <- fread(file.path(DIR_TAB, "crosswave_tests.csv"))[wave == "alle"]
    tl <- sprintf("%s: p %s", gsub("ueber", "über", gsub(" x ", " × ", ct$test)), fmt_p(ct$p))
    pd <- position_dodge(width = .55)
    p28 <- ggplot(cc, aes(wave, irr, colour = tp, group = tp)) +
      geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
      geom_errorbar(aes(ymin = lo, ymax = hi), width = 0, linewidth = .45, position = pd) +
      geom_line(linewidth = .4, alpha = .6, position = pd) + geom_point(size = 1.5, position = pd) +
      facet_wrap(~grp, ncol = 4) +
      scale_y_log10(breaks = c(.6, .8, 1, 1.25, 1.6), labels = c("0,6", "0,8", "1", "1,25", "1,6")) +
      scale_colour_manual(values = setNames(KT_COL[2:4], KT_LAB[2:4]), name = NULL) +
      labs(x = "Welle", y = "Inzidenzverhältnis gegenüber Kreisfreier Großstadt (log)",
           title = "Option D – ein Modell über alle Wellen: Verlauf des Kreistyp-Effekts je Altersgruppe",
           subtitle = paste0("NB-Modell über 8 Wellen × 7 Altersgruppen (glmmTMB): theta je Altersgruppe × Welle, dauerhafter und welle-spezifischer Kreis-Faktor,\n",
                             "Bundesland fest + zufällig je Welle/Altersgruppe; 95 %-KI (unkorrigiert). Wald-Tests im selben Modell:\n",
                             paste(tl[1:2], collapse = "; "), "\n", paste(tl[3:4], collapse = "; "))) +
      guides(colour = guide_legend(nrow = 1)) +
      theme_proj() + theme(strip.text = element_text(size = 10), plot.subtitle = element_text(size = 9, colour = "grey30"))
    save_fig(p28, "fig28_gesamtmodell_verlauf_kreistyp.png", 14, 8)
  }
  # Option III (24): A1 + raeumlicher Kreis-Faktor (BYM2) in einem Modell (INLA)
  f <- file.path(DIR_TAB, "inla_kt_coef.csv")
  if (file.exists(f)) {
    ic <- fread(f)[spec == "bym2"]
    it <- fread(file.path(DIR_TAB, "inla_tests.csv"))[spec == "bym2" & test == "alle Typen"]
    lab <- setNames(sprintf("%s\nKreistyp × Alter: p %s (Holm %s), φ %s", wl[it$wave], fmt_p(it$p), sub("^= ", "", fmt_p(it$p_holm)),
                            formatC(it$phi, format = "f", digits = 2, decimal.mark = ",")), it$wave)
    p29 <- kt_age_plot(ic, lab, "Option III – A1 mit räumlichem Kreis-Effekt: Kreistyp-Effekt je Altersgruppe",
      paste0("Wie A1 (fig27), aber der Kreis-Faktor ist räumlich strukturiert (BYM2, Nachbarkreise); eigenes theta je Altersgruppe; INLA (Bayes),\n",
             "Fallzahlen gerundet; 95 %-Kredibilitätsintervalle; p: Wald-artiger Test aus Posterior-Ziehungen (18 Kontraste), Holm über 8 Wellen; φ: räumlicher Anteil"))
    save_fig(p29, "fig29_inla_bym2_kreistyp_alter.png", 14, 8)
  }
  f <- file.path(DIR_TAB, "gam_surface_grid.csv")
  if (file.exists(f)) {
    gr <- fread(f)[, wave_lab := factor(wl[wave], wl[W$id])]
    # y-Achse auf der Modellskala (z = standardisierte log-Dichte, gleichabstaendiges Raster), beschriftet in Einw./km²
    mu <- mean(log(const$dichte_mean)); sg <- sd(log(const$dichte_mean)); db <- c(50, 100, 200, 500, 1000, 2000)
    u <- sort(unique(gr$z_ld)); gr[, z_ld := seq(min(u), max(u), length.out = length(u))[match(z_ld, u)]]  # CSV-Rundung ausgleichen
    p20 <- ggplot(gr, aes(age, z_ld)) + geom_raster(aes(fill = irr), interpolate = TRUE) +
      geom_hline(yintercept = (log(203) - mu) / sg, colour = "grey35", linewidth = .25, linetype = "dotted") +
      facet_wrap(~wave_lab, ncol = 4) +
      scale_y_continuous(breaks = (log(db) - mu) / sg, labels = lab_de(db), expand = c(0, 0)) +
      scale_x_continuous(breaks = c(0, 20, 40, 60, 79), expand = c(0, 0)) +
      scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", midpoint = 0, trans = "log2",
                           limits = c(.6, 1.67), oob = squish, breaks = c(.6, .8, 1, 1.25, 1.6),
                           labels = c("0,6", "0,8", "1", "1,25", "1,6"), name = "Inzidenzverhältnis\nzum Kreis mittlerer\nDichte (203/km²)") +
      labs(x = "Alter (Jahre)", y = "Bevölkerungsdichte (Einwohner/km², log)",
           title = "Bevölkerungsdichte × Alter: geschätzte Fläche des Inzidenzverhältnisses",
           subtitle = "NB-GAM je Welle mit ti(Alter, Dichte), adjustiert wie fig13; Referenz (gepunktet): Kreis mit Median-Dichte; Dichtebereich 5.–95. Perzentil der Kreise") +
      theme_proj() + theme(legend.position = "right", panel.grid = element_blank(), plot.subtitle = element_text(size = 9, colour = "grey30"))
    save_fig(p20, "fig20_gam_dichte_alter_flaeche.png", 14, 7.4)

    ct <- fread(file.path(DIR_TAB, "gam_surface_contrast.csv"))[, wave_lab := factor(wl[wave], wl[W$id])]
    ct[, spec_lab := factor(spec, c("surf", "dens"), c("Fläche ti(Alter, Dichte)", "linear in log-Dichte (fig14)"))]
    cols <- setNames(c("#D55E00", "#0072B2"), levels(ct$spec_lab))
    p21 <- ggplot(ct, aes(age, irr, colour = spec_lab, fill = spec_lab)) +
      geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
      geom_ribbon(aes(ymin = lo, ymax = hi), alpha = .15, colour = NA) + geom_line(linewidth = .75) +
      facet_wrap(~wave_lab, ncol = 4) +
      scale_y_log10(breaks = c(.6, .8, 1, 1.25, 1.6), labels = c("0,6", "0,8", "1", "1,25", "1,6")) +
      coord_cartesian(ylim = c(.55, 1.8)) + scale_x_continuous(breaks = c(0, 20, 40, 60, 79)) +
      scale_colour_manual(values = cols, name = NULL) + scale_fill_manual(values = cols, guide = "none") +
      labs(x = "Alter (Jahre)", y = "IRR dichter (1.518/km²) vs. dünner Kreis (85/km²) (log)",
           title = "Dicht vs. dünn besiedelt: 90. gegenüber 10. Perzentil der Bevölkerungsdichte",
           subtitle = "Inzidenzverhältnis je Altersjahr aus der Fläche (fig20) und aus dem linearen Dichtemodell; Band: 95 %-KI") +
      guides(colour = guide_legend(nrow = 1, override.aes = list(linewidth = 1.6))) +
      theme_proj() + theme(plot.subtitle = element_text(size = 9.5, colour = "grey30"))
    save_fig(p21, "fig21_gam_dichte_kontrast.png", 14, 7)
  }
}

# ============================================================================================
# H. Kovariaten (19): fig22 PCA-Ladungen, fig23 Kreuzvalidierung; Ankunftszeit (20): fig24 Kaplan-Meier,
#    fig25 Cox je Altersgruppe; Clusteranalyse (21): fig26 Karte der Cluster
# ============================================================================================
extra_figures <- function() {
  wl <- sprintf("%s  %s–%s", W$id, format(W$start, "%m/%Y"), format(W$end - 7, "%m/%Y")); names(wl) <- W$id
  f <- file.path(DIR_TAB, "pca_loadings.csv")
  if (file.exists(f)) {
    ld <- melt(fread(f), id.vars = "variable", variable.name = "pc", value.name = "ladung")
    va <- fread(file.path(DIR_TAB, "pca_variance.csv"))
    pcl <- setNames(sprintf("%s (%.0f %%)", va$pc, 100 * va$anteil), va$pc)
    ld[, `:=`(pc = factor(pcl[as.character(pc)], pcl[levels(pc)]),
              variable = factor(variable, rev(unique(variable))))]
    p22 <- ggplot(ld, aes(pc, variable, fill = ladung)) + geom_tile(colour = "white", linewidth = .6) +
      geom_text(aes(label = formatC(ladung, format = "f", digits = 2, decimal.mark = ","), fontface = fifelse(abs(ladung) >= .3, "bold", "plain")),
                size = 2.6, colour = "grey15") +
      scale_fill_gradient2(low = "#0072B2", mid = "white", high = "#D55E00", midpoint = 0, limits = c(-.7, .7), oob = squish,
                           breaks = c(-.6, -.3, 0, .3, .6), labels = c("−0,6", "−0,3", "0", "0,3", "0,6"), name = "Ladung") +
      labs(x = NULL, y = NULL, title = "Hauptkomponenten der 26 Strukturmerkmale (Kreise, Mittelwerte 2020–2023)",
           subtitle = "Komponenten mit Eigenwert > 1; in Klammern: Anteil erklärter Varianz; fett: |Ladung| ≥ 0,3") +
      theme_proj() + theme(legend.position = "right", panel.grid = element_blank(), axis.text.y = element_text(size = 8.5))
    save_fig(p22, "fig22_pca_ladungen.png", 10, 9)

    cvt <- fread(file.path(DIR_TAB, "cv_covariate_sets.csv"))[set != "S1_bisher"]
    cvt[, `:=`(wave = factor(wave, W$id),
               set = factor(set, c("S0_ohne", "S2_pca", "S3_alle"), c("ohne Kovariaten", "Hauptkomponenten", "alle 26 Merkmale")))]
    cols <- setNames(c("#8A97A3", "#009E73", "#CC79A7"), levels(cvt$set))
    p23 <- ggplot(cvt, aes(wave, d_cv_ll, colour = set)) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40", linewidth = .4) +
      geom_point(position = position_jitterdodge(jitter.width = .15, dodge.width = .7, seed = 1), size = 1.3, alpha = .55) +
      stat_summary(fun = mean, geom = "point", position = position_dodge(width = .7), size = 3.2, shape = 18) +
      scale_colour_manual(values = cols, name = NULL) +
      scale_y_continuous(labels = function(x) formatC(x, format = "f", digits = 2, decimal.mark = ",")) +
      labs(x = "Welle", y = "Δ Test-Log-Likelihood je Kreis gegenüber bisheriger Auswahl",
           title = "Kreuzvalidierung der Kovariatensätze (10-fach über Kreise)",
           subtitle = "Referenz (0): SGB-II, 65+, Tourismus; Punkte: Altersgruppen, Raute: Mittel; > 0 = bessere Vorhersage") +
      theme_proj()
    save_fig(p23, "fig23_kv_kovariatensaetze.png", 11, 6)
  }
  f <- file.path(DIR_TAB, "arrival_km.csv")
  if (file.exists(f)) {
    km <- fread(f)
    km <- rbind(unique(km[, .(wave, kt)])[, `:=`(time = 0, surv = 1)], km)
    cx <- fread(file.path(DIR_TAB, "arrival_cox.csv"))[schwelle == .5 & term == "T4"]
    lab <- setNames(sprintf("%s\nHR Typ 4: %s [%s; %s]", wl[cx$wave], lab_de(round(cx$hr, 2)), lab_de(round(cx$lo, 2)), lab_de(round(cx$hi, 2))), cx$wave)
    km[, `:=`(wave_lab = factor(lab[wave], lab[intersect(W$id, cx$wave)]), kt = factor(kt, c("T1", "T2", "T3", "T4"), KT_LAB))]
    p24 <- ggplot(km[!is.na(wave_lab)], aes(time, surv, colour = kt)) + geom_step(linewidth = .7) +
      facet_wrap(~wave_lab, ncol = 4, scales = "free_x") +
      scale_x_continuous(breaks = function(l) { b <- pretty(l); b[b == round(b)] }) +
      scale_y_continuous(labels = function(x) paste0(round(100 * x), " %")) +
      scale_colour_manual(values = setNames(KT_COL, KT_LAB), name = NULL) +
      labs(x = "Woche der Welle", y = "Anteil Kreise, die noch nicht erreicht sind",
           title = "Wann erreicht eine Welle die Kreise? Kaplan-Meier nach Kreistyp",
           subtitle = "Ereignis: Wocheninzidenz (alle Altersgruppen) erstmals ≥ 50 % des bundesweiten Wellengipfels; HR aus Cox-Modell (strata Bundesland, Kovariaten), < 1 = später als Großstädte; W8 nicht auswertbar") +
      guides(colour = guide_legend(nrow = 2, override.aes = list(linewidth = 1.6))) +
      theme_proj() + theme(strip.text = element_text(size = 9.5), plot.subtitle = element_text(size = 9, colour = "grey30"))
    save_fig(p24, "fig24_ankunft_kaplan_meier.png", 14, 7.6)

    ca <- fread(file.path(DIR_TAB, "arrival_cox_age.csv"))
    wp <- unique(ca[, .(wave, wald_p)])
    lab2 <- setNames(sprintf("%s\nKreistyp × Alter: p %s", wl[wp$wave],
                             ifelse(wp$wald_p < .001, "< 0,001", paste("=", formatC(wp$wald_p, format = "f", digits = 3, decimal.mark = ",")))), wp$wave)
    ca[, `:=`(wave_lab = factor(lab2[wave], lab2[intersect(W$id, wp$wave)]), grp = factor(grp, GR_COARSE),
              tp = factor(term, c("T2", "T3", "T4"), KT_LAB[2:4]))]
    pd <- position_dodge(width = .6)
    p25 <- ggplot(ca, aes(grp, hr, colour = tp)) +
      geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = .4) +
      geom_errorbar(aes(ymin = lo, ymax = hi), width = 0, linewidth = .5, position = pd) +
      geom_point(size = 1.7, position = pd) + facet_wrap(~wave_lab, ncol = 4) +
      scale_x_discrete(labels = function(x) sub("-", "–", x)) +
      scale_y_log10(breaks = c(.25, .5, 1, 2, 4), labels = c("0,25", "0,5", "1", "2", "4")) +
      coord_cartesian(ylim = c(.2, 5)) +
      scale_colour_manual(values = setNames(KT_COL[2:4], KT_LAB[2:4]), name = NULL) +
      labs(x = "Altersgruppe", y = "Hazard Ratio gegenüber Kreisfreier Großstadt (log)",
           title = "Ankunftszeit der Welle je Altersgruppe: Cox-Modell",
           subtitle = "Altersgruppen gestapelt, strata Bundesland × Altersgruppe, robuste SE (Cluster Kreis); HR < 1 = später erreicht; 95 %-KI; p: Wald-Test gleicher Effekte") +
      guides(colour = guide_legend(nrow = 1)) +
      theme_proj() + theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8), strip.text = element_text(size = 9.5),
                           plot.subtitle = element_text(size = 9, colour = "grey30"))
    save_fig(p25, "fig25_ankunft_cox_alter.png", 14, 8)
  }
  f <- file.path(DIR_CLEAN, "kreis_cluster.rds")
  if (file.exists(f) && file.exists(file.path(DIR_CLEAN, "kreis_geo.rds")) && requireNamespace("sf", quietly = TRUE)) {
    suppressPackageStartupMessages(library(sf))
    g <- readRDS(file.path(DIR_CLEAN, "kreis_geo.rds"))
    pr <- fread(file.path(DIR_TAB, "cluster_profile.csv"))
    cl_lab <- setNames(sprintf("Cluster %d (n = %d, %s Einw./km²)", pr$cl4, pr$n, lab_de(pr$dichte)), pr$cl4)
    g26 <- merge(g, readRDS(f)[, .(ags, cl = factor(cl_lab[as.character(cl4)], cl_lab))], by = "ags")
    st <- st_buffer(aggregate(st_buffer(g["state"], 150), by = list(land = g$state), FUN = function(x) x[1]), -150)
    p26 <- ggplot(g26) + geom_sf(aes(fill = cl), colour = "white", linewidth = .08) +
      geom_sf(data = st, fill = NA, colour = "grey25", linewidth = .35) +
      scale_fill_manual(values = setNames(c("#D55E00", "#CC79A7", "#56B4E9", "#0072B2"), cl_lab), name = NULL) +
      labs(title = "Datengetriebene Kreistypologie (k-Means, 4 Cluster)",
           subtitle = "26 Strukturmerkmale + log-Dichte, standardisiert;\nCluster nach mittlerer Dichte sortiert (vgl. BBSR-Kreistyp in fig16)",
           caption = "Kreisgrenzen: © GeoBasis-DE / BKG (Daten verändert), vereinfacht") +
      guides(fill = guide_legend(ncol = 1)) +
      theme_proj() + theme(axis.text = element_blank(), panel.grid.major = element_blank(), plot.subtitle = element_text(size = 9.5))
    save_fig(p26, "fig26_karte_cluster.png", 7.5, 9.5)
  }
}

age_figures("coarse", "",      fine = FALSE)
age_figures("fine",   "_fine", fine = TRUE)
model_figures("",      fine = FALSE)
model_figures("_fine", fine = TRUE)
gam_figures()
scheme_figure()
map_figures()
joint_figures()
extra_figures()
cat("gespeichert: results/modellauswahl/figures/fig01 ... fig29\n")
