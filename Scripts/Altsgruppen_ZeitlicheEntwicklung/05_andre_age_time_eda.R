library(data.table)
library(ggplot2)

input_dir <- "data_processed/Altsgruppen_ZeitlicheEntwicklung"
age_groups <- list(
  A = c("0–5", "6–17", "18–39", "40–59", "60–69", "70–79", "80+"),
  B = c("0–2", "3–5", "6–9", "10–14", "15–17", "18–24", "25–29",
        "30–39", "40–49", "50–59", "60–69", "70–79", "80+")
)
study_weeks <- seq(as.Date("2019-12-30"), as.Date("2023-12-25"), by = "week")
week_key <- c("week_start", "iso_year", "iso_week")
iso_label <- function(year, week) sprintf("%04d-W%02d", year, week)
input_file <- function(scope, scheme) {
  file.path(input_dir, sprintf("national_%s_%d.rds", scope, length(age_groups[[scheme]])))
}

read_weekly_panel <- function(scope, scheme) {
  panel <- readRDS(input_file(scope, scheme))
  calendar <- unique(panel[, ..week_key])[order(week_start)]
  expected_kreise <- c(balanced = 383L, all400 = 400L)[[scope]]
  stopifnot(
    !anyDuplicated(panel, by = c("week_start", "age_group")),
    setequal(panel$age_group, age_groups[[scheme]]),
    nrow(panel) == length(age_groups[[scheme]]) * length(study_weeks),
    identical(calendar$week_start, study_weeks),
    identical(calendar$iso_year, as.integer(format(study_weeks, "%G"))),
    identical(calendar$iso_week, as.integer(format(study_weeks, "%V"))),
    identical(as.integer(table(calendar$iso_year)), c(53L, 52L, 52L, 52L)),
    all(panel$scope == scope), all(panel$n_kreise == expected_kreise),
    all(is.finite(panel$cases_total) & panel$cases_total >= 0),
    all(panel$cases_total == trunc(panel$cases_total)),
    all(is.finite(panel$population_available) & panel$population_available > 0),
    all(panel$n_missing_age_denominators >= 0),
    all(panel$n_incomplete_kreise >= 0 & panel$n_incomplete_kreise <= expected_kreise),
    identical(panel$denominator_complete, panel$n_missing_age_denominators == 0L),
    identical(panel$denominator_complete, panel$n_incomplete_kreise == 0L),
    identical(is.na(panel$incidence), !panel$denominator_complete),
    !any(is.nan(panel$incidence)),
    all(panel[denominator_complete == TRUE, is.finite(incidence) & incidence >= 0]),
    identical(panel[denominator_complete == TRUE, incidence],
              panel[denominator_complete == TRUE, 1e5 * cases_total / population_available])
  )
  if (scope == "balanced") stopifnot(!anyNA(panel$incidence))
  panel[, ':='(age_group = factor(age_group, levels = age_groups[[scheme]]), scheme = scheme)]
  setorder(panel, week_start, age_group)
  panel
}

validate_case_totals <- function(panels) {
  totals <- lapply(panels, function(d) d[, .(cases = sum(cases_total)), by = week_key])
  stopifnot(identical(totals$A, totals$B))
}

weeks_by_period <- function(balanced) {
  rates <- rbindlist(lapply(balanced, function(d) {
    d[, .(scheme, age_group = as.character(age_group), week_start, iso_year, iso_week, incidence)]
  }))
  rbindlist(list(rates[, period := "Gesamt"], copy(rates)[, period := as.character(iso_year)]))
}

describe_rates <- function(rates) {
  # Get every exact maximizer before any display rounding.
  keys <- c("scheme", "age_group", "period")
  stats <- rates[, {
    quartiles <- quantile(incidence, c(0.25, 0.5, 0.75), type = 7, names = FALSE)
    peak_value <- max(incidence)
    peak_rows <- incidence == peak_value
    .(n_weeks = uniqueN(week_start), n_available = sum(!is.na(incidence)),
      n_missing = sum(is.na(incidence)), min_incidence = min(incidence),
      q1_incidence = quartiles[1L], median_incidence = quartiles[2L],
      q3_incidence = quartiles[3L], max_incidence = peak_value,
      n_peak_weeks = sum(peak_rows), peak_tied = sum(peak_rows) > 1L,
      peak_iso_weeks = paste(iso_label(iso_year[peak_rows], iso_week[peak_rows]), collapse = "; "))
  }, by = keys]
  peaks <- rates[, {
    selected <- incidence == max(incidence)
    .(week_start = week_start[selected], iso_year = iso_year[selected],
      iso_week = iso_week[selected], peak_incidence = incidence[selected],
      n_peak_weeks = sum(selected), peak_tied = sum(selected) > 1L)
  }, by = keys]
  peaks[, peak_iso_week := iso_label(iso_year, iso_week)]
  list(descriptive_statistics = stats, peak_timing = peaks)
}

validate_descriptive <- function(rates, tables) {
  stats <- tables$descriptive_statistics
  peaks <- tables$peak_timing
  keys <- c("scheme", "age_group", "period")
  stopifnot(
    nrow(stats) == 100L, !anyDuplicated(stats, by = keys), sum(stats$n_peak_weeks) == nrow(peaks),
    !anyDuplicated(peaks, by = c(keys, "week_start")),
    all(stats$n_available == stats$n_weeks & stats$n_missing == 0L),
    all(stats[period == "Gesamt", n_weeks] == 209L),
    all(stats[period == "2020", n_weeks] == 53L),
    all(stats[period %chin% c("2021", "2022", "2023"), n_weeks] == 52L)
  )
  for (i in seq_len(nrow(stats))) {
    group <- stats$age_group[i]
    selected_period <- stats$period[i]
    selected_scheme <- stats$scheme[i]
    subset <- rates[age_group == group & period == selected_period & scheme == selected_scheme]
    sorted <- sort(subset$incidence)
    # Interpolate empirical quantiles independently of quantile().
    positions <- 1 + (length(sorted) - 1) * c(0.25, 0.5, 0.75)
    quartiles <- sorted[floor(positions)] +
      (positions - floor(positions)) * (sorted[ceiling(positions)] - sorted[floor(positions)])
    actual <- unlist(stats[i, .(min_incidence, q1_incidence, median_incidence, q3_incidence, max_incidence)],
                     use.names = FALSE)
    peak_rows <- peaks[age_group == group & period == selected_period & scheme == selected_scheme]
    expected_weeks <- subset[incidence == tail(sorted, 1L), week_start]
    stopifnot(isTRUE(all.equal(actual, c(sorted[1L], quartiles, tail(sorted, 1L)), tolerance = 1e-12)),
              identical(peak_rows$week_start, expected_weeks),
              identical(stats$n_peak_weeks[i], nrow(peak_rows)),
              identical(stats$peak_tied[i], nrow(peak_rows) > 1L),
              identical(stats$peak_iso_weeks[i], paste(peak_rows$peak_iso_week, collapse = "; ")),
              all(peak_rows$peak_incidence == tail(sorted, 1L)))
  }
}

compare_scope <- function(balanced, all400) {
  rbindlist(lapply(names(balanced), function(scheme_id) {
    balanced_data <- balanced[[scheme_id]][iso_year %in% 2021:2022]
    full_data <- all400[[scheme_id]][iso_year %in% 2021:2022]
    joined <- merge(balanced_data[, .(week_start, age_group, balanced_rate = incidence)],
                    full_data[, .(week_start, iso_year, iso_week, age_group, all400_rate = incidence)],
                    by = c("week_start", "age_group"))
    stopifnot(nrow(joined) == 104L * length(age_groups[[scheme_id]]),
              !anyNA(joined[, .(balanced_rate, all400_rate)]))
    joined[, difference := balanced_rate - all400_rate]
    joined[, .(
      scheme = scheme_id, n_weeks = .N,
      median_difference = median(difference),
      median_absolute_difference = median(abs(difference)),
      max_absolute_difference = max(abs(difference)),
      max_difference_iso_weeks = paste(format(week_start[abs(difference) == max(abs(difference))],
                                               "%G-W%V"), collapse = "; ")
    ), by = .(age_group = as.character(age_group), iso_year)]
  }))
}

comparison_series <- function(balanced) {
  ranges <- data.table(
    scheme = c("A", "B", "B", "A", "B", "B", "B"),
    age_group = c("0–5", "0–2", "3–5", "18–39", "18–24", "25–29", "30–39"),
    comparison = rep(c("0–5 Jahre", "18–39 Jahre"), c(3L, 4L))
  )
  rates <- rbindlist(lapply(balanced, function(d) {
    d[, .(scheme, age_group = as.character(age_group), week_start, iso_year, iso_week, incidence)]
  }))
  out <- merge(ranges, rates, by = c("scheme", "age_group"), sort = FALSE)
  out[, series := factor(paste0(age_group, " (", scheme, ")"),
                         levels = paste0(ranges$age_group, " (", ranges$scheme, ")"))]
  setorder(out, comparison, series, week_start)
  stopifnot(nrow(out) == 7L * length(study_weeks))
  out
}

describe_grouping_examples <- function(series) {
  weekly <- series[, .(
    fine_min = min(incidence[scheme == "B"]),
    fine_max = max(incidence[scheme == "B"]),
    coarse = incidence[scheme == "A"]
  ), by = .(comparison, week_start)]
  weekly[, spread := fine_max - fine_min]
  weekly[, .(
    n_weeks = .N,
    median_fine_spread = median(spread),
    max_fine_spread = max(spread),
    max_spread_iso_weeks = paste(format(week_start[spread == max(spread)], "%G-W%V"), collapse = "; "),
    n_weeks_coarse_outside_fine_range = sum(coarse < fine_min - 1e-10 | coarse > fine_max + 1e-10)
  ), by = comparison]
}

rate_label <- "Gemeldete Fälle je 100.000 Einwohner\nund ISO-Meldewoche"
sample_label <- "Balanced Sample: 383 Kreise"
source_label <- "Quelle: SurvStat@RKI, aufbereitete Wocheninzidenz"
year_starts <- study_weeks[format(study_weeks, "%V") == "01"]
age_colors <- setNames(c("#116589", "#9E4B0E", "#187A60", "#925693", "#997100", "#4C58A3", "#4F555C"),
                      age_groups$A)

report_theme <- function() {
  theme_minimal(base_size = 13, base_family = "sans") +
    theme(
      plot.title.position = "plot", plot.caption.position = "plot",
      plot.title = element_text(face = "bold", size = 20, colour = "#142432", margin = margin(b = 7)),
      plot.subtitle = element_text(colour = "#365064", margin = margin(b = 14)),
      plot.caption = element_text(hjust = 0, size = 10, colour = "#516370", margin = margin(t = 10)),
      axis.title = element_text(size = 12), axis.text = element_text(colour = "#2C3C48"),
      axis.title.x = element_text(margin = margin(t = 7)),
      axis.title.y = element_text(margin = margin(r = 7)),
      panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#E4EBEF", linewidth = 0.35),
      strip.text = element_text(face = "bold", colour = "#203747", size = 12, hjust = 0),
      strip.background = element_rect(fill = "#EFF4F7", colour = NA),
      panel.spacing = grid::unit(1, "lines"),
      legend.position = "bottom", legend.box.just = "left",
      plot.margin = margin(17, 23, 13, 21)
    )
}

date_axis <- function() {
  scale_x_date(breaks = year_starts, labels = format(year_starts, "%G"),
               expand = expansion(mult = c(0.012, 0.02)))
}

rate_axis <- function() {
  scale_y_continuous(labels = scales::label_number(big.mark = ".", decimal.mark = ","),
                     expand = expansion(mult = c(0.015, 0.06)))
}

rate_plot_labels <- function(title, detail, x = "ISO-Meldewoche (Jahresmarken bei KW 01)") {
  labs(title = title, subtitle = paste(sample_label, detail, sep = "  ·  "),
       x = x, y = rate_label, caption = source_label)
}

make_figure <- function(id, balanced, peaks, comparison) {
  seven <- balanced$A
  thirteen <- balanced$B
  if (id == "01") {
    plot <- ggplot(seven, aes(week_start, incidence, colour = age_group)) +
      geom_line(linewidth = 0.88) +
      expand_limits(y = 0) + date_axis() + rate_axis() +
      scale_colour_manual(name = "Alter in Jahren", values = age_colors, guide = guide_legend(nrow = 1)) +
      rate_plot_labels("COVID-19-Inzidenz nach 7 Altersgruppen",
                       "2020–2023 · Unglättete Wochenwerte") +
      report_theme()
    return(list(plot = plot, width = 12, height = 6, traces = 7L, panels = 1L))
  }
  if (id %in% c("02", "03")) {
    groups <- if (id == "02") 7L else 13L
    data <- if (id == "02") seven else thirteen
    plot <- ggplot(data, aes(week_start, incidence, group = age_group)) +
      geom_line(colour = "#126781", linewidth = 0.72) +
      facet_wrap(vars(age_group), ncol = if (id == "02") 4L else 5L) +
      expand_limits(y = 0) + date_axis() + rate_axis() +
      rate_plot_labels(paste("Wocheninzidenz nach", groups, "Altersgruppen"),
                       "2020–2023 · Einheitliche y-Skala · Alter in Jahren") +
      report_theme()
    return(list(plot = plot, width = if (id == "02") 13 else 15,
                height = if (id == "02") 7 else 8.6, traces = groups, panels = groups))
  }
  if (id == "04") {
    plot <- ggplot(thirteen, aes(week_start, age_group, fill = incidence)) +
      geom_tile(width = 7, height = 0.95) +
      geom_vline(xintercept = year_starts[-1L] - 3.5,
                 colour = "white", linewidth = 0.55) +
      date_axis() + scale_y_discrete(limits = rev) +
      scale_fill_viridis_c(
        name = "Fälle je 100.000 Einwohner\nund ISO-Meldewoche",
        option = "cividis", limits = c(0, max(thirteen$incidence)),
        labels = scales::label_number(big.mark = ".", decimal.mark = ","),
        guide = guide_colourbar(barwidth = grid::unit(8, "cm"), barheight = grid::unit(0.45, "cm"))
      ) +
      labs(title = "Heatmap der wöchentlichen COVID-19-Inzidenz",
           subtitle = paste(sample_label, "13 Altersgruppen · Gemeinsame absolute Farbskala", sep = "  ·  "),
           x = "ISO-Meldewoche (Jahresmarken bei KW 01)", y = "Alter in Jahren",
           caption = source_label) +
      report_theme() + theme(panel.grid = element_blank())
    return(list(plot = plot, width = 12, height = 7.1, traces = 13L, panels = 1L))
  }
  if (id == "05") {
    year_data <- copy(seven)
    year_data[, facet_year := sprintf("%d (%d Wochen)", iso_year, max(iso_week)), by = iso_year]
    plot <- ggplot(year_data, aes(iso_week, incidence, colour = age_group)) +
      geom_line(linewidth = 0.82) + facet_wrap(vars(facet_year), ncol = 2) +
      expand_limits(y = 0) + rate_axis() +
      scale_x_continuous(breaks = c(1, 13, 26, 39, 52)) +
      scale_colour_manual(name = "Alter in Jahren", values = age_colors, guide = guide_legend(nrow = 1)) +
      rate_plot_labels("Inzidenzverläufe nach Kalenderjahr",
                       "ISO-Jahre 2020–2023 · 7 Altersgruppen", x = "ISO-Meldewoche (KW)") +
      report_theme()
    return(list(plot = plot, width = 13, height = 8.1, traces = 28L, panels = 4L))
  }
  if (id == "06") {
    colors <- setNames(c("#182B42", "#086F9E", "#BA540B", "#182B42", "#086F9E", "#BA540B", "#7B487F"),
                      levels(comparison$series))
    plot <- ggplot(comparison, aes(week_start, incidence, colour = series,
                                  linetype = scheme, linewidth = scheme)) +
      geom_line() + facet_wrap(vars(comparison), ncol = 1) +
      expand_limits(y = 0) + date_axis() + rate_axis() +
      scale_colour_manual(name = "Alter und Schema", values = colors) +
      scale_linetype_manual(values = c(A = "solid", B = "longdash"), guide = "none") +
      scale_linewidth_manual(values = c(A = 0.96, B = 0.66), guide = "none") +
      guides(colour = guide_legend(nrow = 2, byrow = TRUE,
                                   override.aes = list(linetype = c(1, 5, 5, 1, 5, 5, 5)))) +
      rate_plot_labels("Altersgruppen im Vergleich",
                       "Zwei vorab gewählte Beispiele · A: 7 Gruppen · B: 13 Gruppen") +
      report_theme()
    return(list(plot = plot, width = 12, height = 8.4, traces = 7L, panels = 2L))
  }

  timing <- copy(peaks)
  age_levels <- c(paste("A", age_groups$A), paste("B", age_groups$B))
  timing[, ':='(
    scheme_label = factor(scheme, levels = c("A", "B"), labels = c("A · 7 Altersgruppen", "B · 13 Altersgruppen")),
    age_label = factor(paste(scheme, age_group), levels = rev(age_levels)),
    peak_period = factor(ifelse(period == "Gesamt", "Gesamtmaximum", "Jahresmaximum"),
                         levels = c("Jahresmaximum", "Gesamtmaximum"))
  )]
  setorder(timing, peak_period, week_start)
  plot <- ggplot(timing, aes(week_start, age_label, shape = peak_period, size = peak_period)) +
    geom_point(colour = "#145A77", stroke = 0.85) +
    facet_grid(rows = vars(scheme_label), scales = "free_y", space = "free_y") +
    date_axis() + coord_cartesian(xlim = range(study_weeks)) +
    scale_y_discrete(labels = function(x) sub("^[AB] ", "", x)) +
    scale_shape_manual(name = NULL, values = c(Jahresmaximum = 16, Gesamtmaximum = 1)) +
    scale_size_manual(name = NULL, values = c(Jahresmaximum = 2.05, Gesamtmaximum = 4.3)) +
    labs(title = "Zeitpunkte maximaler Wocheninzidenz nach Alter",
         subtitle = paste(sample_label, "Maxima der unglätteten Wochenwerte", sep = "  ·  "),
         x = "ISO-Meldewoche (Jahresmarken bei KW 01)", y = "Alter in Jahren",
         caption = paste(source_label, "Bei Gleichstand sind alle Wochen eingezeichnet.", sep = "  ·  ")) +
    report_theme()
  list(plot = plot, width = 12, height = 9.7, traces = 20L, panels = 2L)
}

validate_figure <- function(id, fig) {
  built <- ggplot_build(fig$plot)
  geometry <- built$data[[1L]]
  source <- fig$plot$data
  stopifnot(nrow(geometry) == nrow(source), length(unique(geometry$PANEL)) == fig$panels,
            all(is.finite(geometry$x)), all(is.finite(geometry$y)))
  if (id == "04") {
    stopifnot(uniqueN(geometry$y) == fig$traces, uniqueN(geometry$x) == 209L,
              identical(built$plot$scales$get_scales("fill")$get_limits(), c(0, max(source$incidence))),
              all(!is.na(geometry$fill)))
  } else if (id == "07") {
    stopifnot(uniqueN(source$age_label) == fig$traces,
              identical(sort(as.numeric(source$week_start)), sort(as.numeric(geometry$x))))
  } else {
    stopifnot(nrow(unique(geometry[, c("PANEL", "group")])) == fig$traces,
              identical(sort(as.numeric(source$incidence)), sort(as.numeric(geometry$y))),
              all(vapply(built$layout$panel_params, function(panel) {
                panel$y.range[1L] <= 0 && panel$y.range[2L] >= max(source$incidence)
              }, logical(1))))
  }
}

write_verified_rds <- function(data, path) {
  saveRDS(data, path)
  stopifnot(identical(as.data.frame(readRDS(path)), as.data.frame(data)))
}

run_andre_age_time_eda <- function(figure_ids = sprintf("%02d", 1:7),
                                   result_dir = "results/Altsgruppen_ZeitlicheEntwicklung",
                                   plot_data_dir = "data_processed/Altsgruppen_ZeitlicheEntwicklung/eda") {
  filenames <- c("01_timeseries_7_groups", "02_facets_7_groups", "03_facets_13_groups",
                 "04_heatmap_13_groups", "05_yearly_comparison", "06_grouping_comparison", "07_peak_timing")
  available <- sprintf("%02d", seq_along(filenames))
  stopifnot(length(figure_ids) >= 1L, !anyDuplicated(figure_ids), all(figure_ids %in% available))
  full_run <- setequal(figure_ids, available)
  stems <- filenames[match(figure_ids, available)]
  table_names <- c("descriptive_statistics", "peak_timing", "grouping_examples", "sensitivity_balanced_all400")

  figure_files <- paste0(stems, ".png")
  rds_files <- paste0(stems, ".rds")
  targets <- list(list(files = figure_files, directory = result_dir),
                  list(files = rds_files, directory = plot_data_dir))
  if (full_run) {
    targets[[3L]] <- list(files = paste0(table_names, ".rds"), directory = file.path(plot_data_dir, "tables"))
  }
  already_exists <- vapply(targets, function(target) {
    any(file.exists(file.path(target$directory, target$files)))
  }, logical(1))
  if (any(already_exists)) {
    stop("Output already exists. Use new output directories for a rerun.", call. = FALSE)
  }

  # All plots read the validated source panels, independently of other plot files.
  balanced <- setNames(lapply(names(age_groups), function(scheme) read_weekly_panel("balanced", scheme)),
                       names(age_groups))
  message("PASS: Balanced coverage, ISO dates, population, cases and incidence")
  rates <- weeks_by_period(balanced)
  if (full_run || "07" %in% figure_ids) {
    tables <- describe_rates(rates)
    validate_descriptive(rates, tables)
    # Also exercise the tie rule when real snapshots contain no ties.
    tie_rows <- copy(rates[scheme == "A" & age_group == "0–5" & period == "2020"][1:3])
    tie_rows[, incidence := c(3, 1, 3)]
    tie_test <- describe_rates(tie_rows)
    stopifnot(tie_test$descriptive_statistics$n_peak_weeks == 2L,
              tie_test$descriptive_statistics$peak_tied, nrow(tie_test$peak_timing) == 2L)
    message("PASS: descriptive statistics, peak weeks and exact ties")
  }
  if (full_run) {
    all400 <- setNames(lapply(names(age_groups), function(scheme) read_weekly_panel("all400", scheme)),
                       names(age_groups))
    validate_case_totals(balanced)
    validate_case_totals(all400)
    tables$sensitivity_balanced_all400 <- compare_scope(balanced, all400)
    stopifnot(nrow(tables$sensitivity_balanced_all400) == 40L,
              all(tables$sensitivity_balanced_all400$n_weeks == 52L),
              all(grepl("^20(21|22)-W[0-9]{2}(; 20(21|22)-W[0-9]{2})*$",
                        tables$sensitivity_balanced_all400$max_difference_iso_weeks)))
    message("PASS: All400 coverage, missing denominators, weekly case totals and 2021–2022 comparisons")
  }
  comparison <- if ("06" %in% figure_ids) comparison_series(balanced)
  if (full_run) tables$grouping_examples <- describe_grouping_examples(comparison)

  stage <- tempfile("andre_eda_")
  stopifnot(dir.create(stage))
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  for (i in seq_along(figure_ids)) {
    id <- figure_ids[i]
    figure <- make_figure(id, balanced, if (id == "07") tables$peak_timing else NULL, comparison)
    validate_figure(id, figure)
    png_path <- file.path(stage, figure_files[i])
    ggsave(png_path, plot = figure$plot, device = ragg::agg_png, width = figure$width,
           height = figure$height, units = "in", dpi = 300, bg = "white")
    raster <- png::readPNG(png_path, native = TRUE)
    stopifnot(identical(dim(raster), as.integer(300 * c(figure$height, figure$width))),
              any(raster != raster[1L]))
    write_verified_rds(figure$plot$data, file.path(stage, rds_files[i]))
    message("PASS: ", stems[i], " (", nrow(figure$plot$data), " rows)")
  }
  if (full_run) {
    for (name in table_names) write_verified_rds(tables[[name]], file.path(stage, paste0(name, ".rds")))
    message("PASS: all four summary RDS tables can be read back")
  }

  for (target in targets) {
    if (!dir.exists(target$directory)) stopifnot(dir.create(target$directory, recursive = TRUE))
    ok <- file.copy(file.path(stage, target$files), target$directory, overwrite = FALSE)
    stopifnot(all(ok))
  }
  message("Validated outputs saved to ", result_dir, " and ", plot_data_dir)
}

if (sys.nframe() == 0L) {
  ids <- commandArgs(trailingOnly = TRUE)
  if (length(ids)) run_andre_age_time_eda(ids) else run_andre_age_time_eda()
}
