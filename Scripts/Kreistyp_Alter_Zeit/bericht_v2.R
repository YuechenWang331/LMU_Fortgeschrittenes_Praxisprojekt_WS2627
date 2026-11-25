# Abbildungen F1–F6 für den Bericht v2 (gegliedert nach Forschungsfragen).
# Aufruf im Projektverzeichnis: source('Scripts/Kreistyp_Alter_Zeit/bericht_v2.R')
# Nutzt die geprüften Ergebnistabellen; nur die bevölkerungsgewichtete Sensitivität
# wird neu aus dem Eingabedatensatz berechnet.
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

bericht_v2_abbildungen <- function() {
  ein <- 'results/Kreistyp_Alter_Zeit'
  aus <- file.path(ein, 'bericht_v2')
  dir.create(aus, recursive = TRUE, showWarnings = FALSE)
  lesen <- function(datei) fread(file.path(ein, datei))

  # ---- Beschriftungen und Farben -------------------------------------------
  alter <- c('0-5', '6-17', '18-39', '40-59', '60-69', '70-79', '80+')
  altersnamen <- c('0–5', '6–17', '18–39', '40–59', '60–69', '70–79', '80+')
  typen <- c('Großstädte', 'Städtische Kreise', 'Ländlich, verdichtet', 'Ländlich, dünn besiedelt')
  typfarben <- setNames(c('#C2491D', '#D9A23A', '#7FA65A', '#2F7D4F'), typen)
  typformen <- setNames(c(16, 17, 15, 18), typen)
  paarschluessel <- c('1-2', '1-3', '1-4', '2-3', '2-4', '3-4')
  paarnamen <- c('Großstädte / städtische Kreise', 'Großstädte / ländlich, verdichtet',
                 'Großstädte / ländlich, dünn', 'Städtische Kreise / ländlich, verdichtet',
                 'Städtische Kreise / ländlich, dünn', 'Ländlich, verdichtet / ländlich, dünn')
  phasen <- c('P0', 'W1', 'G1', 'W2', 'W3', 'G2', 'W4', 'W5', 'PostW5')
  phasennamen <- c('Vor W1', 'W1', 'Zw. W1/W2', 'W2', 'W3', 'Zw. W3/W4', 'W4', 'W5', 'Nach W5')
  artfarben <- c('Gesamt' = '#1F3B4D', 'Welle' = '#1B7F8C', 'Zwischen-/Nachphase' = '#9AA7AD')
  art_von <- function(p) fifelse(p == 'All', 'Gesamt', fifelse(grepl('^W', p), 'Welle', 'Zwischen-/Nachphase'))
  paar_von <- function(a, b) factor(paste(a, b, sep = '-'), paarschluessel, paarnamen)

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
  fuss <- '383 Kreise mit vollständigen Nennern · gleiche Kreisgewichte · jährliche Kreistypzuordnung · altersstandardisiert (Referenz 2021)'
  speichern <- function(name, grafik, breite = 11, hoehe = 7.5) {
    g <- grafik + grund
    ggsave(file.path(aus, paste0(name, '.png')), g, width = breite, height = hoehe, dpi = 200, bg = 'white')
    pdf_geraet <- if (capabilities('aqua')) function(filename, ...) grDevices::quartz(file = filename, type = 'pdf', ...) else grDevices::pdf
    ggsave(file.path(aus, paste0(name, '.pdf')), g, width = breite, height = hoehe, device = pdf_geraet, bg = 'white')
    message('gespeichert: ', name)
  }

  perioden <- lesen('period_definitions.csv')
  perioden[, `:=`(start = as.Date(start), end = as.Date(end))]
  kontraste <- lesen('pairwise_contrasts.csv')
  wochen <- lesen('weekly_district_rates.csv')
  wochen[, week_start := as.Date(week_start)]

  # ---- F1: Wochenverlauf der standardisierten Raten -------------------------
  w1 <- wochen[outcome == 'standard']
  w1[, typ := factor(type, 1:4, typen)]
  wellen <- perioden[grepl('^W', period)]
  wellen[, mitte := start + as.numeric(end - start) / 2]
  f1 <- ggplot() +
    geom_rect(data = wellen, aes(xmin = start, xmax = end, ymin = 0, ymax = Inf),
              fill = '#E8F1F2', inherit.aes = FALSE) +
    geom_text(data = wellen, aes(x = mitte, y = Inf, label = period), vjust = 1.6,
              size = 3.6, color = '#1B7F8C', fontface = 'bold', inherit.aes = FALSE) +
    geom_line(data = w1, aes(week_start, mean, color = typ), linewidth = .7) +
    scale_color_manual(values = typfarben, name = NULL) +
    scale_y_sqrt(breaks = c(0, 25, 100, 250, 500, 1000, 1500, 2000),
                 labels = function(x) format(x, big.mark = '.', decimal.mark = ',')) +
    scale_x_date(date_breaks = '6 months', date_labels = '%m/%Y', expand = expansion(mult = .01)) +
    labs(title = 'F1  Alle vier Kreistypen durchlaufen dieselben Wellen',
         subtitle = 'Altersstandardisierte Meldeinzidenz je 100.000 und Woche, Mittel der Kreise je Typ; y-Achse auf Wurzelskala',
         x = NULL, y = 'Fälle je 100.000 und Woche (Wurzelskala)', caption = fuss)
  speichern('F1_wochenverlauf', f1, 12, 6.5)

  # ---- F2: Standardisierte Ratenverhältnisse je Phase -----------------------
  k2 <- kontraste[outcome == 'standard' & scale == 'relative' & period != 'P0' & is.finite(lower)]
  k2[, paar := paar_von(type_a, type_b)]
  k2[, phase := factor(period, c('All', phasen[-1]), c('Gesamt 2020–2023', phasennamen[-1]))]
  k2[, art := art_von(period)]
  f2 <- ggplot(k2, aes(x = estimate, y = phase, color = art)) +
    geom_vline(xintercept = 1, linetype = 2, color = '#7D8A90') +
    geom_linerange(aes(xmin = lower, xmax = upper), linewidth = .8) +
    geom_point(size = 2.2) +
    facet_wrap(~paar, ncol = 2) +
    scale_y_discrete(limits = rev) +
    scale_x_log10(breaks = c(.6, .8, 1, 1.25, 1.5, 2, 2.5),
                  labels = function(x) format(x, decimal.mark = ',')) +
    scale_color_manual(values = artfarben, name = NULL) +
    labs(title = 'F2  Großstädte liegen vor allem in W4 und W5 niedriger',
         subtitle = 'Ratenverhältnis erster / zweiter Typ (log-Skala); < 1 = erster Typ niedriger; Linien = punktweise 95%-Intervalle aus dem Kreis-Bootstrap',
         x = 'Ratenverhältnis (log-Skala)', y = NULL,
         caption = paste0(fuss, '\nVor W1 ausgelassen (Raten nahe null). Intervalle nicht für Mehrfachvergleiche adjustiert.'))
  speichern('F2_verhaeltnis_phasen', f2, 11, 9.5)

  # ---- F3: Ratenverhältnisse je Altersgruppe --------------------------------
  k3 <- kontraste[period == 'All' & scale == 'relative' & outcome %in% alter]
  k3[, paar := paar_von(type_a, type_b)]
  k3[, altersgruppe := factor(outcome, alter, altersnamen)]
  f3 <- ggplot(k3, aes(x = altersgruppe, y = estimate)) +
    geom_hline(yintercept = 1, linetype = 2, color = '#7D8A90') +
    geom_linerange(aes(ymin = lower, ymax = upper), linewidth = .8, color = '#1B7F8C') +
    geom_point(size = 2.2, color = '#1B7F8C') +
    facet_wrap(~paar, ncol = 3) +
    scale_y_log10(breaks = c(.85, .9, .95, 1, 1.05, 1.1),
                  labels = function(x) format(x, decimal.mark = ',')) +
    labs(title = 'F3  Der Stadt-Land-Abstand ist bei jungen Erwachsenen am größten',
         subtitle = 'Ratenverhältnis je Altersgruppe, Gesamtzeitraum 2020–2023 (log-Skala); Linien = punktweise 95%-Intervalle',
         x = 'Altersgruppe (Jahre)', y = 'Ratenverhältnis (log-Skala)',
         caption = '383 Kreise · gleiche Kreisgewichte · jährliche Kreistypzuordnung · altersspezifische Raten (keine Standardisierung nötig)')
  speichern('F3_verhaeltnis_alter', f3, 12, 7.5)

  # ---- F4: Führende Altersinteraktion je Phase ------------------------------
  ia <- lesen('age_interactions.csv')
  k4 <- ia[type_a == 1 & type_b == 4 & age_a == '18-39' & age_b == '70-79' & period != 'P0']
  k4[, skala := factor(scale, c('relative', 'absolute'),
                       c('Relativ: Verhältnis der Ratenverhältnisse (1 = kein Unterschied)',
                         'Absolut: Differenz der Differenzen je 100.000 und Woche (0 = kein Unterschied)'))]
  k4[, phase := factor(period, c('All', phasen[-1]), c('Gesamt', phasennamen[-1]))]
  k4[, art := art_von(period)]
  referenz <- data.table(skala = factor(levels(k4$skala), levels(k4$skala)), wert = c(1, 0))
  f4 <- ggplot(k4, aes(x = phase, y = estimate, color = art)) +
    geom_hline(data = referenz, aes(yintercept = wert), linetype = 2, color = '#7D8A90') +
    geom_linerange(aes(ymin = lower, ymax = upper), linewidth = .8) +
    geom_point(size = 2.3) +
    facet_wrap(~skala, ncol = 1, scales = 'free_y') +
    scale_y_continuous(labels = function(x) format(x, decimal.mark = ',')) +
    scale_color_manual(values = artfarben, name = NULL) +
    labs(title = 'F4  Das Altersmuster des Stadt-Land-Abstands ist in W5 am stärksten',
         subtitle = 'Großstädte vs. ländlich, dünn besiedelt: Abstand bei 18–39 im Vergleich zu 70–79 Jahren, je Phase',
         x = NULL, y = NULL,
         caption = '383 Kreise · Kreis-Bootstrap, punktweise 95%-Intervalle · Altersvergleich explorativ aus allen 126 Interaktionen als größter Effekt ausgewählt')
  speichern('F4_altersinteraktion_phasen', f4, 11, 8)

  # ---- F5: Verteilung der Kreiswerte in W4, W5 und nach W5 -----------------
  vt <- fread(file.path(ein, 'district_period_distribution.csv'), colClasses = list(character = 'geo_code'))
  k5 <- vt[outcome == 'standard' & period %in% c('W4', 'W5', 'PostW5')]
  k5[, typ := factor(type, 1:4, typen)]
  k5[, phase := factor(period, c('W4', 'W5', 'PostW5'), c('W4', 'W5', 'Nach W5'))]
  haupt <- wochen[outcome == 'standard' & period %in% c('W4', 'W5', 'PostW5'), .(wert = mean(mean)), by = .(type, period)]
  haupt[, `:=`(typ = factor(type, 1:4, typen), phase = factor(period, c('W4', 'W5', 'PostW5'), c('W4', 'W5', 'Nach W5')))]
  f5 <- ggplot(k5, aes(x = typ, y = mean_rate, color = typ)) +
    geom_point(position = position_jitter(width = .18, height = 0, seed = 1), alpha = .35, size = 1.2, shape = 16) +
    geom_boxplot(fill = NA, outlier.shape = NA, width = .55, color = '#33444C') +
    geom_point(data = haupt, aes(y = wert), shape = 23, size = 3, fill = 'white', color = '#1F3B4D') +
    facet_wrap(~phase, scales = 'free_y') +
    scale_color_manual(values = typfarben, guide = 'none') +
    scale_x_discrete(labels = c('Großstädte', 'Städtische\nKreise', 'Ländlich,\nverdichtet', 'Ländlich,\ndünn besiedelt')) +
    labs(title = 'F5  Kreise desselben Typs streuen stark; die Verteilungen überlappen',
         subtitle = 'Ein Punkt = ein Kreis (mittlere standardisierte Wochenrate in der Phase); Box = mittlere 50 %, Raute = Hauptmaß (Mittel der Wochenmittel)',
         x = NULL, y = 'Fälle je 100.000 und Woche', caption = paste0(fuss, '\nJede Phase hat eine eigene y-Skala. Kreise mit Typwechsel erscheinen je Zugehörigkeitsabschnitt.'))
  speichern('F5_kreisverteilung', f5, 12, 6.5)

  # ---- F6: Robustheit inkl. bevölkerungsgewichteter Sicht -------------------
  x <- as.data.table(readRDS('data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds'))
  x[, age_group := as.character(age_group)]
  ref <- lesen('standard_population_2021.csv')[, .(age_group, weight)]
  voll <- x[, .(ok = all(is.finite(incidence))), by = geo_code][ok == TRUE, geo_code]
  stopifnot(length(voll) == 383L)
  z <- merge(x[geo_code %in% voll], ref, by = 'age_group')
  kw <- z[, .(std = sum(weight * incidence), pop = sum(population)),
          by = .(geo_code, week_start, type = kreistyp_code)]
  tw <- kw[, .(gleich = mean(std), bevoelkerung = weighted.mean(std, pop)), by = .(type, week_start)]
  tw[, period := perioden$period[findInterval(as.numeric(as.Date(week_start)), as.numeric(perioden$start))]]
  stopifnot(!anyNA(tw$period))
  pm <- rbind(tw[, .(gleich = mean(gleich), bevoelkerung = mean(bevoelkerung)), by = .(type, period)],
              tw[, .(period = 'All', gleich = mean(gleich), bevoelkerung = mean(bevoelkerung)), by = type])
  paare <- combn(1:4, 2, simplify = FALSE)
  verh <- rbindlist(lapply(paare, function(p) {
    a <- pm[type == p[1]]; b <- pm[type == p[2]][match(a$period, period)]
    data.table(period = a$period, type_a = p[1], type_b = p[2],
               gleich = a$gleich / b$gleich, bevoelkerung = a$bevoelkerung / b$bevoelkerung)
  }))
  fwrite(verh, file.path(aus, 'sensitivitaet_bevoelkerungsgewicht.csv'))
  rob <- lesen('robustness_pairwise.csv')[outcome == 'standard']
  check <- merge(verh, rob[method == 'complete_mean', .(period, type_a, type_b, ratio)],
                 by = c('period', 'type_a', 'type_b'))
  abw <- max(abs(check$gleich - check$ratio), na.rm = TRUE)
  message('Kontrolle gleiche Gewichte vs. Hauptanalyse, max. Abweichung: ', signif(abw, 3))
  if (abw > 1e-6) warning('Gleichgewichtete Neuberechnung weicht von robustness_pairwise.csv ab.')
  k6 <- rbind(rob[period %in% c('All', 'W4', 'W5'), .(period, type_a, type_b, methode = method, ratio)],
              verh[period %in% c('All', 'W4', 'W5'), .(period, type_a, type_b, methode = 'population_weighted', ratio = bevoelkerung)])
  methoden <- c('complete_mean', 'complete_median', 'available_mean', 'population_weighted')
  methodennamen <- c('Hauptanalyse: Mittel, 383 Kreise', 'Median statt Mittel', 'Alle verfügbaren Kreiswochen', 'Bevölkerungsgewichtet')
  k6[, `:=`(paar = paar_von(type_a, type_b),
            methode = factor(methode, methoden, methodennamen),
            phase = factor(period, c('All', 'W4', 'W5'), c('Gesamt 2020–2023', 'W4', 'W5')))]
  f6 <- ggplot(k6, aes(x = ratio, y = paar, color = methode, shape = methode)) +
    geom_vline(xintercept = 1, linetype = 2, color = '#7D8A90') +
    geom_point(size = 2.6, position = position_dodge(width = .55)) +
    facet_wrap(~phase, nrow = 1) +
    scale_y_discrete(limits = rev) +
    scale_x_log10(labels = function(x) format(x, decimal.mark = ',')) +
    scale_color_manual(values = setNames(c('#1F3B4D', '#D9A23A', '#7FA65A', '#C2491D'), methodennamen), name = NULL) +
    scale_shape_manual(values = setNames(c(16, 17, 15, 18), methodennamen), name = NULL) +
    guides(color = guide_legend(nrow = 2), shape = guide_legend(nrow = 2)) +
    labs(title = 'F6  Großstädte liegen in jeder Variante unter den ländlichen Kreisen',
         subtitle = 'Standardisiertes Ratenverhältnis erster / zweiter Typ (log-Skala) unter vier Berechnungsweisen; deskriptiv, ohne neue Tests',
         x = 'Ratenverhältnis (log-Skala)', y = NULL,
         caption = 'Bevölkerungsgewichtet: Kreise innerhalb jeder Woche nach Einwohnerzahl gewichtet (Sicht der Einwohner statt des typischen Kreises).')
  speichern('F6_robustheit', f6, 13, 6.5)

  writeLines(c(paste('Abgeschlossen:', Sys.time()),
               paste('Kontrolle gleiche Gewichte, max. Abweichung:', signif(abw, 3)),
               paste('Abbildungen:', paste(list.files(aus, pattern = '[.]png$'), collapse = ', '))),
             file.path(aus, 'BERICHT_V2_COMPLETE.txt'))
  invisible(verh)
}

bericht_v2_ergebnis <- bericht_v2_abbildungen()
