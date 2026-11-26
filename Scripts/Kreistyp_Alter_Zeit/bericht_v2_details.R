# Erklärende Zusatzabbildungen zum Bericht v2 (Rechenwege sichtbar machen).
# Aufruf im Projektverzeichnis: source('Scripts/Kreistyp_Alter_Zeit/bericht_v2_details.R')
# Nutzt ausschließlich die geprüften Ergebnistabellen in results/Kreistyp_Alter_Zeit.
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

bericht_v2_details <- function() {
  ein <- 'results/Kreistyp_Alter_Zeit'
  aus <- file.path(ein, 'bericht_v2')
  dir.create(aus, recursive = TRUE, showWarnings = FALSE)
  lesen <- function(datei) fread(file.path(ein, datei))
  komma <- function(x, d = 1) format(round(x, d), nsmall = d, decimal.mark = ',', big.mark = '.', trim = TRUE)

  alter <- c('0-5', '6-17', '18-39', '40-59', '60-69', '70-79', '80+')
  altersnamen <- c('0–5', '6–17', '18–39', '40–59', '60–69', '70–79', '80+')
  typen <- c('Großstädte', 'Städtische Kreise', 'Ländlich, verdichtet', 'Ländlich, dünn besiedelt')
  typfarben <- setNames(c('#C2491D', '#E39B1B', '#4FB39A', '#2D7A4A'), typen)
  phasen <- c('P0', 'W1', 'G1', 'W2', 'W3', 'G2', 'W4', 'W5', 'PostW5')
  phasennamen <- c('Vor W1', 'W1', 'Zw. W1/W2', 'W2', 'W3', 'Zw. W3/W4', 'W4', 'W5', 'Nach W5')
  # Wellenfarben bewusst in Violett/Blau, damit sie sich von den Kreistypfarben unterscheiden.
  phasenfarben <- setNames(c('#C8CDD0', '#C2185B', '#C8CDD0', '#E07AA6', '#5AA4DE', '#C8CDD0', '#244C9A', '#A066CC', '#8A9196'), phasennamen)
  akzent <- '#B8001F'
  grau <- '#7D8A90'
  fuss <- '383 Kreise mit vollständigen Nennern · gleiche Kreisgewichte · jährliche Kreistypzuordnung'

  grund <- theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = 'bold', size = 16, color = '#174B57'),
          plot.subtitle = element_text(size = 11, color = '#50616A', margin = margin(b = 12)),
          plot.title.position = 'plot', plot.caption.position = 'plot',
          plot.caption = element_text(size = 9, color = '#64737A', hjust = 0, margin = margin(t = 12)),
          plot.margin = margin(16, 22, 14, 16), panel.grid.minor = element_blank(),
          strip.text = element_text(face = 'bold', size = 10.5, color = '#214C57', hjust = 0),
          strip.background = element_rect(fill = '#EDF4F5', color = NA),
          legend.position = 'top', legend.justification = 'left',
          legend.title = element_text(size = 10, face = 'bold'))
  speichern <- function(name, grafik, breite = 11, hoehe = 7) {
    g <- grafik + grund
    ggsave(file.path(aus, paste0(name, '.png')), g, width = breite, height = hoehe, dpi = 200, bg = 'white')
    pdf_geraet <- if (capabilities('aqua')) function(filename, ...) grDevices::quartz(file = filename, type = 'pdf', ...) else grDevices::pdf
    ggsave(file.path(aus, paste0(name, '.pdf')), g, width = breite, height = hoehe, device = pdf_geraet, bg = 'white')
    message('gespeichert: ', name)
  }

  wochen <- lesen('weekly_district_rates.csv')
  wochen[, week_start := as.Date(week_start)]
  kontraste <- lesen('pairwise_contrasts.csv')
  ia <- lesen('age_interactions.csv')
  ueberblick <- lesen('period_difference_overview.csv')

  # ---- Altersraten: Warum Standardisierung nötig ist -------------------------
  ar <- wochen[outcome %in% alter, .(t = sum(mean * n), n = sum(n)), by = .(week_start, outcome)][, .(wert = mean(t / n)), by = outcome]
  ar[, `:=`(altersgruppe = factor(outcome, alter, altersnamen), fokus = factor(outcome %in% c('18-39', '70-79'), c(FALSE, TRUE), c('nein', 'ja')))]
  g_ar <- ggplot(ar, aes(altersgruppe, wert, fill = fokus)) +
    geom_col(width = .68) +
    geom_text(aes(label = komma(wert)), vjust = -.45, size = 3.6, color = '#33444C') +
    scale_fill_manual(values = c(nein = '#9FB8BE', ja = '#1B7F8C'), guide = 'none') +
    scale_y_continuous(expand = expansion(mult = c(0, .1))) +
    labs(title = 'Junge Menschen werden viel häufiger gemeldet als Ältere',
         subtitle = 'Mittlere Wochenrate 2020–2023 je 100.000 in der jeweiligen Altersgruppe, alle 383 Kreise',
         x = 'Altersgruppe (Jahre)', y = 'Fälle je 100.000 und Woche',
         caption = paste0(fuss, ' · 18–39 Jahre etwa 2,6-mal so hoch wie 70–79 Jahre'))
  speichern('A01_altersraten', g_ar, 10, 5.5)

  # ---- Altersanteile 2021 alle vier Typen -----------------------------------
  ant <- lesen('age_composition.csv')[iso_year == 2021]
  ant[, `:=`(typ = factor(type, 1:4, typen), altersgruppe = factor(age_group, alter, altersnamen))]
  g0a <- ggplot(ant, aes(altersgruppe, mean_share, fill = typ)) +
    geom_col(position = position_dodge(width = .82), width = .78) +
    geom_text(aes(label = komma(100 * mean_share)), position = position_dodge(width = .82),
              vjust = -.45, size = 2.6, color = '#33444C') +
    scale_fill_manual(values = typfarben, name = NULL) +
    scale_y_continuous(labels = function(x) paste0(komma(100 * x, 0), ' %'), expand = expansion(mult = c(0, .12))) +
    labs(title = 'Großstädte haben mehr junge Erwachsene, ländliche Kreise mehr Ältere',
         subtitle = 'Bevölkerungsanteil je Altersgruppe 2021 in Prozent (Mittel der Kreisanteile innerhalb des Typs)',
         x = 'Altersgruppe (Jahre)', y = 'Anteil an der Bevölkerung', caption = fuss)
  speichern('F0a_altersanteile_2021', g0a, 12, 6)

  # ---- Roh vs. standardisiert als Säulen (Typfarbe hell = roh, dunkel = standardisiert)
  cs <- wochen[outcome %in% c('crude', 'standard'), .(wert = mean(mean)), by = .(type, outcome)]
  artnamen <- c('Hell: roh (eigene Altersanteile des Kreises)', 'Dunkel: standardisiert (gemeinsame Altersanteile, Referenz 2021)')
  cs[, `:=`(typ = factor(type, 1:4, typen), art = factor(outcome, c('crude', 'standard'), artnamen))]
  g0b <- ggplot(cs, aes(typ, wert, fill = typ, alpha = art)) +
    geom_col(position = position_dodge(width = .75), width = .7, color = 'white', linewidth = .6) +
    geom_text(aes(label = komma(wert, 2), group = art), position = position_dodge(width = .75), vjust = -.45, size = 3.5,
              color = '#33444C', alpha = 1) +
    scale_fill_manual(values = typfarben, guide = 'none') +
    scale_alpha_manual(values = setNames(c(.38, 1), artnamen), name = NULL) +
    guides(alpha = guide_legend(override.aes = list(fill = '#5B6B73'))) +
    coord_cartesian(ylim = c(200, 240)) +
    scale_y_continuous(breaks = seq(200, 240, 10)) +
    labs(title = 'Nach Standardisierung sinken Großstädte, ländliche Kreise steigen',
         subtitle = 'Mittel aller 209 Wochen 2020–2023, Fälle je 100.000 und Woche. Nur die Gewichtung nach Alter unterscheidet hell und dunkel; y-Achse beginnt bei 200',
         x = NULL, y = 'Fälle je 100.000 und Woche',
         caption = paste0(fuss, '\nGroßstädte − ländlich, dünn: roh −12,77, standardisiert −22,07.'))
  speichern('F0b_roh_vs_standardisiert', g0b, 11, 6)

  # ---- Lehrbeispiel: hohe Korrelation heißt nicht gleiche Höhe -------------
  a <- c(10, 20, 40, 70, 90, 80, 60, 40, 30, 20, 15, 10)
  fall1 <- data.table(woche = 1:12, A = a, B = a + 100, fall = 'Fall 1: B = A + 100')
  fall2 <- data.table(woche = 1:12, A = a, B = rev(a), fall = 'Fall 2: gleiche Höhe, andere Zeitpunkte')
  bsp <- rbind(fall1, fall2)
  r_bsp <- bsp[, .(r = cor(A, B), abstand = mean(B - A)), by = fall]
  bsp <- merge(bsp, r_bsp, by = 'fall')
  bsp[, fall_lbl := paste0(fall, ' (r = ', komma(r, 2), ', Abstand im Mittel ', komma(abstand, 0), ')')]
  verlauf <- melt(bsp, id.vars = c('fall_lbl', 'woche'), measure.vars = c('A', 'B'), variable.name = 'reihe', value.name = 'wert')
  verlauf[, ansicht := 'Verlauf über 12 Wochen']
  streu <- bsp[, .(fall_lbl, x = A, y = B, ansicht = 'Streudiagramm: jede Woche ein Punkt')]
  ansichten <- c('1  Verlauf über 12 Wochen', '2  Streudiagramm (x = A, y = B)')
  verlauf[, ansicht := factor(ansichten[1], ansichten)]
  streu[, ansicht := factor(ansichten[2], ansichten)]
  g_bsp <- ggplot() +
    geom_line(data = verlauf, aes(woche, wert, color = reihe), linewidth = 1.1) +
    geom_point(data = verlauf, aes(woche, wert, color = reihe), size = 2) +
    geom_smooth(data = streu, aes(x, y), method = 'lm', formula = y ~ x, se = FALSE, color = '#222222', linewidth = .6) +
    geom_point(data = streu, aes(x, y), size = 2.4, color = '#1B7F8C') +
    facet_wrap(~ fall_lbl + ansicht, ncol = 2, scales = 'free') +
    scale_color_manual(values = c(A = '#5B6B73', B = '#1B7F8C'), name = 'Reihe') +
    labs(title = 'Korrelation misst gleichen Verlauf, nicht gleiche Höhe',
         subtitle = 'Zwei erfundene Beispiele. Links: beide Reihen über die Zeit. Rechts: dieselben 12 Wochen als Punkte',
         x = NULL, y = NULL,
         caption = 'Fall 1: B liegt immer 100 höher, steigt und fällt aber genau mit A → r = 1. Fall 2: gleiche Höhe im Mittel, aber Gipfel zu anderen Zeiten → r niedrig.')
  speichern('A02_korrelation_beispiel', g_bsp, 12, 7.5)

  # ---- Korrelation als Streudiagramm ----------------------------------------
  s1 <- dcast(wochen[outcome == 'standard' & type %in% c(1, 4)], week_start + period ~ type, value.var = 'mean')
  setnames(s1, c('1', '4'), c('gross', 'land'))
  setorder(s1, week_start)
  s1[, `:=`(d_gross = gross - shift(gross), d_land = land - shift(land))]
  r_n <- cor(s1$gross, s1$land)
  r_a <- cor(s1$d_gross, s1$d_land, use = 'complete.obs')
  panelnamen <- c(paste0('Niveau: Wochenrate (r = ', komma(r_n, 3), ', 209 Wochen)'),
                  paste0('Veränderung zur Vorwoche (r = ', komma(r_a, 3), ', 208 Werte)'))
  kd <- rbind(s1[, .(panel = panelnamen[1], x = land, y = gross, period)],
              s1[!is.na(d_gross), .(panel = panelnamen[2], x = d_land, y = d_gross, period)])
  kd[, `:=`(panel = factor(panel, panelnamen), phase = factor(period, phasen, phasennamen))]
  g1b <- ggplot(kd, aes(x, y)) +
    geom_abline(slope = 1, intercept = 0, linetype = 2, color = grau) +
    geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, color = '#222222', linewidth = .7) +
    geom_point(aes(color = phase), size = 1.3, alpha = .85) +
    facet_wrap(~panel, scales = 'free') +
    scale_color_manual(values = phasenfarben, name = 'Phase') +
    guides(color = guide_legend(nrow = 1, override.aes = list(size = 3))) +
    labs(title = 'Großstädte und ländliche Kreise steigen und fallen gemeinsam',
         subtitle = 'Ein Punkt = eine Woche; x = ländlich, dünn besiedelt, y = Großstädte (standardisiert, je 100.000). Gestrichelt: y = x; Linie: lineare Anpassung',
         x = 'Ländlich, dünn besiedelt', y = 'Großstädte',
         caption = 'Links: die Wochenraten selbst. Rechts: Veränderung gegenüber der Vorwoche (diese Woche minus letzte Woche).')
  speichern('F1b_korrelation_streudiagramm', g1b, 12, 6.5)

  # ---- Phasenüberblick Großstadt / ländlich dünn ----------------------------
  pn7 <- c('A  Verhältnis Großstädte / ländlich, dünn mit 95%-Intervall (1 = gleich)', 'B  Mittlere Differenz Großstädte − ländlich, dünn je 100.000 und Woche (0 = gleich)')
  v7 <- kontraste[outcome == 'standard' & scale == 'relative' & type_a == 1 & type_b == 4 & period %in% phasen[-1]]
  d7 <- ueberblick[outcome == 'standard' & type_a == 1 & type_b == 4 & period %in% phasen[-1]]
  v7[, `:=`(phase = factor(period, phasen[-1], phasennamen[-1]), panel = factor(pn7[1], pn7))]
  d7[, `:=`(phase = factor(period, phasen[-1], phasennamen[-1]), panel = factor(pn7[2], pn7))]
  d7[, v := fifelse(mean_difference < 0, 1.4, -.5)]
  ref7 <- data.table(panel = factor(pn7, pn7), y = c(1, 0))
  g7 <- ggplot() +
    geom_hline(data = ref7, aes(yintercept = y), linetype = 2, color = grau) +
    geom_linerange(data = v7, aes(phase, ymin = lower, ymax = upper, color = phase), linewidth = 1.1) +
    geom_point(data = v7, aes(phase, estimate, color = phase), size = 3) +
    geom_text(data = v7, aes(phase, upper, label = komma(estimate, 2)), vjust = -.6, size = 3.4) +
    geom_col(data = d7, aes(phase, mean_difference, fill = phase), width = .6) +
    geom_text(data = d7, aes(phase, mean_difference, label = komma(mean_difference, 1), vjust = v), size = 3.4) +
    facet_wrap(~panel, ncol = 1, scales = 'free_y') +
    scale_color_manual(values = phasenfarben, guide = 'none') +
    scale_fill_manual(values = phasenfarben, guide = 'none') +
    scale_y_continuous(expand = expansion(mult = .15)) +
    labs(title = 'Der Abstand entsteht in W4 und W5',
         subtitle = 'Großstädte gegenüber ländlich, dünn besiedelten Kreisen je Phase: oben relativ, unten absolut',
         x = NULL, y = NULL,
         caption = paste0(fuss, ' · Intervalle aus dem Kreis-Bootstrap · Vor W1 ausgelassen (Raten nahe null)'))
  speichern('F2a_phasen_grossstadt_land', g7, 11, 8)

  # ---- W4 und W5 Woche für Woche --------------------------------------------
  zeit <- wochen[outcome == 'standard' & week_start >= as.Date('2021-08-02') & week_start <= as.Date('2022-05-29')]
  zeit[, typ := factor(type, 1:4, typen)]
  pn <- c('Wochenrate je 100.000 (standardisiert)', 'Verhältnis zu „ländlich, dünn besiedelt“')
  vv <- merge(zeit[type != 4], zeit[type == 4, .(week_start, land = mean)], by = 'week_start')
  dd <- rbind(zeit[, .(week_start, typ, wert = mean, panel = pn[1])],
              vv[, .(week_start, typ, wert = mean / land, panel = pn[2])])
  dd[, panel := factor(panel, pn)]
  eins <- data.table(panel = factor(pn[2], pn), y = 1)
  baender <- data.table(start = as.Date(c('2021-08-02', '2021-12-27')), ende = as.Date(c('2021-12-26', '2022-05-29')), welle = c('W4', 'W5'))
  beschr <- data.table(panel = factor(pn[1], pn), x = as.Date(c('2021-10-15', '2022-03-10')), label = c('W4', 'W5'))
  g2b <- ggplot(dd, aes(week_start, wert, color = typ)) +
    geom_rect(data = baender, aes(xmin = start, xmax = ende, ymin = -Inf, ymax = Inf, fill = welle), inherit.aes = FALSE, alpha = .1) +
    scale_fill_manual(values = phasenfarben[c('W4', 'W5')], guide = 'none') +
    geom_hline(data = eins, aes(yintercept = y), linetype = 2, color = grau) +
    geom_line(linewidth = .8) + geom_point(size = 1.2) +
    geom_text(data = beschr, aes(x = x, y = Inf, label = label), inherit.aes = FALSE,
              vjust = 1.5, fontface = 'bold', color = phasenfarben[beschr$label], size = 4.2) +
    facet_wrap(~panel, ncol = 1, scales = 'free_y') +
    scale_color_manual(values = typfarben, name = NULL) +
    scale_x_date(date_breaks = '1 month', date_labels = '%m/%y') +
    labs(title = 'W4 und W5 Woche für Woche',
         subtitle = 'Oben: Wochenraten der vier Typen. Unten: jede Woche geteilt durch den Wert der ländlich-dünnen Kreise (< 1 = niedriger)',
         x = NULL, y = NULL, caption = fuss)
  speichern('F2b_w4_w5_wochen', g2b, 12, 8)

  # ---- W4 und W5 je Altersgruppe: Verhältnis und Differenz -------------------
  pn9 <- c('A  Verhältnis Großstädte / ländlich, dünn (1 = gleich)', 'B  Differenz Großstädte − ländlich, dünn je 100.000 und Woche (0 = gleich)')
  k2c <- kontraste[type_a == 1 & type_b == 4 & period %in% c('W4', 'W5') & outcome %in% c(alter, 'standard')]
  k2c[, `:=`(altersgruppe = factor(outcome, c(alter, 'standard'), c(altersnamen, 'Standard-\nisiert')), phase = factor(period, c('W4', 'W5')),
             panel = factor(fifelse(scale == 'relative', pn9[1], pn9[2]), pn9))]
  k2c[, beschriftung := fifelse(scale == 'relative', komma(estimate, 2), komma(estimate, 0))]
  ref9 <- data.table(panel = factor(pn9, pn9), y = c(1, 0))
  dodge <- position_dodge(width = .55)
  g2c <- ggplot(k2c, aes(altersgruppe, estimate, color = phase)) +
    geom_hline(data = ref9, aes(yintercept = y), linetype = 2, color = grau) +
    geom_linerange(aes(ymin = lower, ymax = upper), position = dodge, linewidth = .9) +
    geom_point(position = dodge, size = 2.6) +
    geom_text(aes(y = upper, label = beschriftung), position = dodge, vjust = -.6, size = 3, show.legend = FALSE) +
    facet_wrap(~panel, ncol = 1, scales = 'free_y') +
    scale_color_manual(values = phasenfarben[c('W4', 'W5')], name = NULL) +
    scale_y_continuous(expand = expansion(mult = c(.05, .15))) +
    labs(title = 'W4: alle Altersgruppen niedriger · W5: vor allem Jüngere',
         subtitle = 'Großstädte gegenüber ländlich, dünn besiedelten Kreisen je Altersgruppe, mit punktweisem 95%-Intervall',
         x = 'Altersgruppe (Jahre)', y = NULL, caption = paste0(fuss, ' · Intervalle aus dem Kreis-Bootstrap'))
  speichern('F2c_w4_w5_alter', g2c, 11, 8.5)

  # ---- Rechenweg der Altersinteraktion: Raten, Verhältnis, Differenz ---------
  pn3 <- c('A  Mittlere Wochenrate je 100.000 (2020–2023)', 'B  Verhältnis Großstädte / ländlich, dünn (1 = gleich)',
           'C  Differenz Großstädte − ländlich, dünn je 100.000 und Woche (0 = gleich)')
  basis <- wochen[outcome %in% alter & type %in% c(1, 4), .(wert = mean(mean)), by = .(type, outcome)]
  basis[, `:=`(altersgruppe = factor(outcome, alter, altersnamen), typ = factor(type, c(1, 4), typen[c(1, 4)]), panel = factor(pn3[1], pn3))]
  basis[, v := fifelse(type == 1, 2, -1.1)]
  vrh <- kontraste[period == 'All' & type_a == 1 & type_b == 4 & outcome %in% alter]
  vrh[, `:=`(altersgruppe = factor(outcome, alter, altersnamen),
             panel = factor(fifelse(scale == 'relative', pn3[2], pn3[3]), pn3),
             fokus = factor(outcome %in% c('18-39', '70-79'), c(FALSE, TRUE), c('nein', 'ja')))]
  vrh[, beschriftung := fifelse(scale == 'relative', komma(estimate, 3), komma(estimate, 1))]
  ref3 <- data.table(panel = factor(pn3[2:3], pn3), y = c(1, 0))
  g3e <- ggplot() +
    geom_line(data = basis, aes(altersgruppe, wert, color = typ, group = typ), linewidth = .6, alpha = .5) +
    geom_point(data = basis, aes(altersgruppe, wert, color = typ), size = 2.8) +
    geom_text(data = basis[outcome %in% c('18-39', '70-79')], aes(altersgruppe, wert, label = komma(wert), color = typ, vjust = v),
              size = 3.4, fontface = 'bold', show.legend = FALSE) +
    geom_hline(data = ref3, aes(yintercept = y), linetype = 2, color = grau) +
    geom_linerange(data = vrh, aes(altersgruppe, ymin = lower, ymax = upper, alpha = fokus), color = '#1B7F8C', linewidth = .9) +
    geom_point(data = vrh, aes(altersgruppe, estimate, alpha = fokus), color = '#1B7F8C', size = 2.8) +
    geom_text(data = vrh[fokus == 'ja'], aes(altersgruppe, upper, label = beschriftung),
              vjust = -.6, size = 3.6, fontface = 'bold', color = akzent) +
    facet_wrap(~panel, ncol = 1, scales = 'free_y') +
    scale_color_manual(values = typfarben[c(1, 4)], name = NULL) +
    scale_alpha_manual(values = c(nein = .4, ja = 1), guide = 'none') +
    scale_y_continuous(expand = expansion(mult = c(.18, .18))) +
    labs(title = 'So entsteht die Altersinteraktion',
         subtitle = 'A: Raten beider Typen. B: Großstadt geteilt durch Land. C: Großstadt minus Land. Hervorgehoben: 18–39 und 70–79 Jahre',
         x = 'Altersgruppe (Jahre)', y = NULL,
         caption = 'Relativ: 0,879 / 0,966 = 0,910.  Absolut: (−36,7) − (−3,9) = −32,8 Fälle je 100.000 und Woche.  Intervalle aus dem Kreis-Bootstrap.')
  speichern('F3e_altersinteraktion_rechenweg', g3e, 11, 10.5)

  # ---- Altersprofil je Phase als kleine Vielfache ---------------------------
  ph4 <- c('All', 'W2', 'W3', 'W4', 'W5', 'PostW5')
  ph4namen <- c('Gesamt 2020–2023', 'W2', 'W3', 'W4', 'W5', 'Nach W5')
  k4a <- kontraste[type_a == 1 & type_b == 4 & scale == 'relative' & period %in% ph4 & outcome %in% alter]
  k4a[, `:=`(altersgruppe = factor(outcome, alter, altersnamen), phase = factor(period, ph4, ph4namen),
             fokus = factor(outcome %in% c('18-39', '70-79'), c(FALSE, TRUE), c('nein', 'ja')))]
  farben4 <- c('Gesamt 2020–2023' = '#222222', W2 = phasenfarben[['W2']], W3 = phasenfarben[['W3']],
               W4 = phasenfarben[['W4']], W5 = phasenfarben[['W5']], 'Nach W5' = phasenfarben[['Nach W5']])
  g4a <- ggplot(k4a, aes(altersgruppe, estimate, color = phase, group = phase)) +
    geom_hline(yintercept = 1, linetype = 2, color = grau) +
    geom_line(linewidth = .7, alpha = .6) +
    geom_linerange(aes(ymin = lower, ymax = upper, alpha = fokus), linewidth = .9) +
    geom_point(aes(alpha = fokus), size = 2.6) +
    geom_text(data = k4a[fokus == 'ja'], aes(y = upper, label = komma(estimate, 2)), vjust = -.5, size = 3.3, fontface = 'bold') +
    facet_wrap(~phase, ncol = 3) +
    scale_color_manual(values = farben4, guide = 'none') +
    scale_alpha_manual(values = c(nein = .45, ja = 1), guide = 'none') +
    scale_y_log10(breaks = c(.6, .7, .8, .9, 1, 1.1, 1.25, 1.5), labels = function(x) komma(x, 2)) +
    scale_x_discrete(labels = c('0–5', '6–17', '18–\n39', '40–\n59', '60–\n69', '70–\n79', '80+')) +
    labs(title = 'Jede Welle hat ihr eigenes Altersprofil',
         subtitle = 'Großstädte / ländlich, dünn besiedelt je Altersgruppe und Phase (log-Skala, < 1 = Großstädte niedriger); beschriftet: 18–39 und 70–79 Jahre',
         x = 'Altersgruppe (Jahre)', y = 'Ratenverhältnis',
         caption = paste0(fuss, ' · Linien = punktweise 95%-Intervalle (Kreis-Bootstrap) · W1 wegen sehr breiter Intervalle nicht gezeigt'))
  speichern('F4a_altersprofil_wellen', g4a, 12, 8)

  # ---- Hantelgrafik: Verhältnis bei 18–39 und 70–79 je Phase ----------------
  ph5 <- c('All', 'W1', 'W2', 'W3', 'W4', 'W5', 'PostW5')
  ph5namen <- c('Gesamt', 'W1', 'W2', 'W3', 'W4', 'W5', 'Nach W5')
  hv <- kontraste[type_a == 1 & type_b == 4 & scale == 'relative' & period %in% ph5 & outcome %in% c('18-39', '70-79')]
  hb <- dcast(hv, period ~ outcome, value.var = 'estimate')
  setnames(hb, c('18-39', '70-79'), c('jung', 'alt'))
  ir <- ia[type_a == 1 & type_b == 4 & age_a == '18-39' & age_b == '70-79' & scale == 'relative' & period %in% ph5, .(period, inter = estimate)]
  hb <- merge(hb, ir, by = 'period')
  hb[, `:=`(phase = factor(period, ph5, ph5namen), oben = pmax(jung, alt))]
  hv[, `:=`(phase = factor(period, ph5, ph5namen), alter_lbl = factor(outcome, c('18-39', '70-79'), c('18–39 Jahre', '70–79 Jahre')))]
  farben5 <- c(Gesamt = '#222222', W1 = phasenfarben[['W1']], W2 = phasenfarben[['W2']], W3 = phasenfarben[['W3']],
               W4 = phasenfarben[['W4']], W5 = phasenfarben[['W5']], 'Nach W5' = phasenfarben[['Nach W5']])
  g4b <- ggplot() +
    geom_hline(yintercept = 1, linetype = 2, color = grau) +
    geom_segment(data = hb, aes(x = phase, xend = phase, y = jung, yend = alt, color = phase), linewidth = 2.2, alpha = .45) +
    geom_point(data = hv, aes(phase, estimate, shape = alter_lbl, color = phase), size = 3.6, stroke = 1.4, fill = 'white') +
    geom_text(data = hb, aes(phase, oben, label = paste0('÷ = ', komma(inter, 2))), vjust = -1.2, size = 3.5, fontface = 'bold') +
    scale_shape_manual(values = c('18–39 Jahre' = 16, '70–79 Jahre' = 21), name = NULL) +
    scale_color_manual(values = farben5, guide = 'none') +
    scale_y_log10(breaks = c(.6, .7, .8, .9, 1, 1.1, 1.25), labels = function(x) komma(x, 2), expand = expansion(mult = c(.05, .12))) +
    labs(title = 'In W5 klafft der Abstand zwischen Jüngeren und Älteren am weitesten',
         subtitle = 'Je Phase: Verhältnis Großstädte / ländlich, dünn bei 18–39 (gefüllt) und bei 70–79 Jahren (offen); Zahl = Verhältnis jung ÷ alt',
         x = NULL, y = 'Ratenverhältnis (log-Skala)',
         caption = '÷ unter 1: Der Großstadt-Vorteil ist bei Jüngeren größer. Kurzer Balken = ähnlicher Abstand in beiden Altersgruppen.')
  speichern('F4b_altersinteraktion_phasen', g4b, 11, 6.5)

  # ---- Monate nach W5, durchgezogene Linien -------------------------------
  mo <- lesen('post_w5_monthly.csv')[outcome == 'standard']
  mo[, `:=`(monat = as.Date(month), typ = factor(type, 1:4, typen), teil = factor(partial_month, c(FALSE, TRUE), c('voller Monat', 'Teilmonat')))]
  g_mo <- ggplot(mo, aes(monat, mean_weekly_rate, color = typ)) +
    geom_line(linewidth = .9) +
    geom_point(aes(shape = teil), size = 2.2) +
    scale_color_manual(values = typfarben, name = NULL) +
    scale_shape_manual(values = c('voller Monat' = 16, 'Teilmonat' = 1), name = NULL) +
    scale_x_date(date_breaks = '2 months', date_labels = '%m/%y') +
    labs(title = 'Nach W5 wechselt der Abstand mehrmals die Richtung',
         subtitle = 'Mittlere standardisierte Wochenrate je Monat (Zuordnung nach Wochenmontag), Mai 2022 bis Dezember 2023',
         x = NULL, y = 'Fälle je 100.000 und Woche',
         caption = paste0(fuss, ' · Mai 2022 enthält nur die Woche ab 30.05.'))
  speichern('F4c_monate_nach_w5', g_mo, 11, 6)

  # ---- Tabelle zur Kreisverteilung ------------------------------------------
  vt <- fread(file.path(ein, 'district_period_distribution.csv'), colClasses = list(character = 'geo_code'))
  k5 <- vt[outcome == 'standard' & period %in% c('W4', 'W5', 'PostW5')]
  f5 <- k5[, .(eintraege = .N, median = median(mean_rate), q25 = quantile(mean_rate, .25), q75 = quantile(mean_rate, .75),
               min = min(mean_rate), max = max(mean_rate)), by = .(period, type)]
  ueberlappung <- k5[, {
    m4 <- median(mean_rate[type == 4]); g <- mean_rate[type == 1]; r <- mean_rate[type == 4]
    .(anteil_grossstadt_ueber_landmedian = mean(g > m4), p_grossstadt_niedriger = mean(outer(g, r, '<')))
  }, by = period]
  fwrite(f5, file.path(aus, 'kreisverteilung_kennzahlen.csv'))
  fwrite(ueberlappung, file.path(aus, 'kreisverteilung_ueberlappung.csv'))

  writeLines(c(paste('Abgeschlossen:', Sys.time()),
               paste('Korrelation Niveau:', signif(r_n, 6), '· Veränderung:', signif(r_a, 6))),
             file.path(aus, 'BERICHT_V2_DETAILS_COMPLETE.txt'))
  invisible(ueberlappung)
}

bericht_v2_details_ergebnis <- bericht_v2_details()
