library(data.table)
library(ggplot2)

focused_weeks <- 1:16
focused_bands <- data.table(
  band = rep(c("0–5 Jahre", "6–17 Jahre", "18–39 Jahre"), c(3L, 4L, 4L)),
  age_group = c("0–5", "0–2", "3–5", "6–17", "6–9", "10–14", "15–17",
                "18–39", "18–24", "25–29", "30–39"),
  scheme = c("A", "B", "B", "A", "B", "B", "B", "A", "B", "B", "B")
)
focused_bands[, series_order := .I]

prepare_focused_2022 <- function() {
  # Load the existing read-only panel checks and plotting theme.
  eda <- new.env()
  sys.source("Scripts/Altsgruppen_ZeitlicheEntwicklung/05_andre_age_time_eda.R", envir = eda)
  panels <- list(A = eda$read_weekly_panel("balanced", "A"),
                 B = eda$read_weekly_panel("balanced", "B"))
  window <- rbindlist(lapply(panels, function(panel) {
    panel[iso_year == 2022L & iso_week %in% focused_weeks,
          .(scheme, age_group = as.character(age_group), week_start, iso_week, incidence)]
  }))
  series <- merge(focused_bands, window, by = c("scheme", "age_group"), sort = FALSE)
  setorder(series, series_order, iso_week)
  series[, ':='(previous_rate = shift(incidence), next_rate = shift(incidence, type = "lead")),
         by = series_order]
  series[, ':='(change_from_previous = incidence - previous_rate,
                 change_to_next = next_rate - incidence)]
  series[, ':='(
    maximum = incidence == max(incidence),
    local_maximum = !is.na(previous_rate) & !is.na(next_rate) &
      incidence > previous_rate & incidence > next_rate
  ), by = series_order]

  pairs <- series[, {
    pair <- combn(.N, 2L)
    left <- pair[1L, ]
    right <- pair[2L, ]
    .(left_age = age_group[left], right_age = age_group[right],
      left_rate = incidence[left], right_rate = incidence[right],
      rate_difference = incidence[left] - incidence[right])
  }, by = .(band, iso_week, week_start)]
  setorder(pairs, band, iso_week)

  expected_dates <- seq(as.Date("2022-01-03"), as.Date("2022-04-18"), by = "week")
  stopifnot(
    nrow(series) == 176L, !anyDuplicated(series, by = c("scheme", "age_group", "iso_week")),
    setequal(series$series_order, focused_bands$series_order),
    nrow(pairs) == 240L, !anyDuplicated(pairs, by = c("band", "iso_week", "left_age", "right_age"))
  )
  for (id in focused_bands$series_order) {
    result <- series[series_order == id]
    age <- result$age_group[1L]
    original <- panels[[result$scheme[1L]]][iso_year == 2022L & iso_week %in% focused_weeks &
                                               age_group == age]
    values <- original$incidence
    steps <- diff(values)
    local_weeks <- which(head(steps, -1L) > 0 & tail(steps, -1L) < 0) + 1L
    stopifnot(
      identical(result$iso_week, focused_weeks), identical(result$week_start, expected_dates),
      identical(original$week_start, expected_dates), identical(result$incidence, values),
      identical(which(result$maximum), which(values == max(values))),
      identical(which(result$local_maximum), local_weeks),
      identical(result$previous_rate, c(NA_real_, head(values, -1L))),
      identical(result$next_rate, c(tail(values, -1L), NA_real_)),
      identical(result$change_from_previous, c(NA_real_, steps)),
      identical(result$change_to_next, c(steps, NA_real_))
    )
  }
  left_rates <- series[pairs, on = .(band, iso_week, age_group = left_age), incidence]
  right_rates <- series[pairs, on = .(band, iso_week, age_group = right_age), incidence]
  stopifnot(identical(pairs$left_rate, left_rates), identical(pairs$right_rate, right_rates),
            identical(pairs$rate_difference, left_rates - right_rates))
  for (band_name in unique(focused_bands$band)) {
    n_age <- focused_bands[band == band_name, .N]
    complete_pairs <- pairs[band == band_name, .N, by = iso_week]
    stopifnot(identical(complete_pairs$iso_week, focused_weeks),
              all(complete_pairs$N == choose(n_age, 2L)))
  }
  list(series = series, comparisons = pairs, eda = eda)
}

make_focused_plot <- function(figure, prepared) {
  data <- copy(prepared$series)
  data[, band := factor(band, levels = unique(focused_bands$band))]
  ymax <- ceiling(max(data$incidence) / 500) * 500
  e <- prepared$eda
  if (figure == "08") {
    data[, age_group := factor(age_group, levels = focused_bands$age_group)]
    colors <- setNames(c("#1D2939", "#116987", "#A24D13",
                         "#1D2939", "#116987", "#A24D13", "#724F91",
                         "#1D2939", "#116987", "#A24D13", "#724F91"), focused_bands$age_group)
    # An outer ring and a diamond distinguish the nearly coincident KW 05 maxima.
    shapes <- setNames(c(16, 16, 17, 16, 1, 18, 17, 16, 16, 18, 17), focused_bands$age_group)
    points <- data[maximum == TRUE]
    points[, point_size := fifelse(age_group == "6–9", 4.3, 2.75)]
    markers <- data.table(band = factor("0–5 Jahre", levels = levels(data$band)), iso_week = c(4L, 12L))
    plot <- ggplot(data, aes(iso_week, incidence, colour = age_group, group = age_group)) +
      geom_line(aes(linetype = scheme), linewidth = 0.9) +
      geom_point(data = points, aes(shape = age_group, size = point_size), stroke = 1.05, show.legend = FALSE) +
      geom_vline(data = markers, aes(xintercept = iso_week), colour = "#9EAEB9",
                 linetype = "dotted", linewidth = 0.42) +
      facet_wrap(vars(band), ncol = 1) +
      scale_colour_manual(name = "Alter in Jahren", values = colors) +
      scale_shape_manual(values = shapes) + scale_size_identity() +
      scale_linetype_manual(values = c(A = "solid", B = "longdash"), guide = "none") +
      guides(colour = guide_legend(
        nrow = 2, byrow = TRUE,
        override.aes = list(linetype = ifelse(focused_bands$scheme == "A", 1, 5))
      )) +
      scale_x_continuous(breaks = focused_weeks, labels = sprintf("%02d", focused_weeks)) +
      labs(title = "COVID-19-Wocheninzidenz nach Alter, Anfang 2022",
           caption = paste0(e$source_label, ". Symbole: Fenstermaxima. ",
                            "Hilfslinien im Panel 0–5 Jahre: KW 04 und 12.\n",
                            "Durchgezogen: breite Gruppen. Gestrichelt: feinere Gruppen.")) +
      theme(legend.key.width = grid::unit(1.05, "cm"))
    spec <- list(plot = plot, points = points, width = 12, height = 9, panels = 3L, traces = 11L)
  } else {
    fine <- focused_bands[scheme == "B", age_group]
    data <- data[scheme == "B"]
    data[, age_group := factor(age_group, levels = fine)]
    points <- data[maximum == TRUE]
    points[, label := sprintf("KW %02d", iso_week)]
    plot <- ggplot(data, aes(iso_week, incidence, group = age_group)) +
      geom_line(colour = "#146780", linewidth = 0.88) +
      geom_point(data = points, colour = "#146780", size = 2.65) +
      geom_text(data = points, aes(label = label), colour = "#183849", size = 3.7,
                vjust = -0.85, show.legend = FALSE) +
      facet_wrap(vars(age_group), ncol = 4) +
      scale_x_continuous(breaks = c(1L, 4L, 8L, 12L, 16L),
                         labels = c("01", "04", "08", "12", "16")) +
      labs(title = "COVID-19-Wocheninzidenz nach feineren Altersgruppen",
           caption = paste0(e$source_label, ". Markierungen zeigen die Fenstermaxima (Alter in Jahren)."))
    spec <- list(plot = plot, points = points, width = 14, height = 7, panels = 8L, traces = 8L)
  }
  spec$plot <- spec$plot +
    scale_y_continuous(breaks = seq(0, ymax, by = 1000),
                       labels = scales::label_number(big.mark = ".", decimal.mark = ","),
                       expand = expansion(mult = c(0, 0.035))) +
    coord_cartesian(ylim = c(0, ymax)) +
    labs(subtitle = paste(e$sample_label, "2022 · KW 01–16 · Unglättete Wochenwerte", sep = "  ·  "),
         x = "ISO-Meldewoche (KW)", y = e$rate_label) +
    e$report_theme()
  spec$y_limits <- c(0, ymax)
  spec
}

validate_focused_plot <- function(spec) {
  built <- ggplot_build(spec$plot)
  curve <- built$data[[1L]]
  marks <- built$data[[2L]]
  plotted_coordinates <- function(x, y) {
    rows <- order(x, y)
    cbind(as.numeric(x[rows]), as.numeric(y[rows]))
  }
  stopifnot(
    length(built$layout$panel_params) == spec$panels,
    nrow(unique(curve[, c("PANEL", "group")])) == spec$traces,
    identical(plotted_coordinates(curve$x, curve$y),
              plotted_coordinates(spec$plot$data$iso_week, spec$plot$data$incidence)),
    identical(plotted_coordinates(marks$x, marks$y),
              plotted_coordinates(spec$points$iso_week, spec$points$incidence)),
    identical(built$plot$coordinates$limits$y, spec$y_limits),
    all(curve$y >= min(spec$y_limits) & curve$y <= max(spec$y_limits))
  )
}

run_andre_focused_2022 <- function(figures = c("08", "09"), result_dir = "results/Altsgruppen_ZeitlicheEntwicklung",
                                   data_dir = "data_processed/Altsgruppen_ZeitlicheEntwicklung/eda") {
  stems <- c("08" = "08_focused_2022_age_patterns", "09" = "09_focused_2022_fine_groups")
  stopifnot(length(figures) >= 1L, !anyDuplicated(figures), all(figures %in% names(stems)))
  png_names <- paste0(stems[figures], ".png")
  rds_names <- paste0(stems[figures], ".rds")
  if (any(file.exists(c(file.path(result_dir, png_names), file.path(data_dir, rds_names))))) {
    stop("Output already exists. Supply new output directories for a rerun.", call. = FALSE)
  }

  prepared <- prepare_focused_2022()
  message("PASS: 11 age groups × 16 ISO weeks (2022-W01–W16), raw rates and common population scope")
  message("PASS: ", prepared$series[maximum == TRUE, .N], " window maxima and ",
          prepared$series[local_maximum == TRUE, .N], " strict interior local maxima")
  message("PASS: Adjacent-week changes and ", nrow(prepared$comparisons), " same-week rate differences")

  stage <- tempfile("focused_2022_")
  stopifnot(dir.create(stage))
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  for (i in seq_along(figures)) {
    spec <- make_focused_plot(figures[i], prepared)
    validate_focused_plot(spec)
    path <- file.path(stage, png_names[i])
    ggsave(path, plot = spec$plot, device = ragg::agg_png, width = spec$width, height = spec$height,
           units = "in", dpi = 300, bg = "white")
    raster <- png::readPNG(path, native = TRUE)
    stopifnot(identical(dim(raster), as.integer(c(spec$height, spec$width) * 300)),
              any(raster != raster[1L]))
    snapshot <- list(series = as.data.frame(spec$plot$data), maxima = as.data.frame(spec$points),
                     y_limits = spec$y_limits)
    snapshot_path <- file.path(stage, rds_names[i])
    saveRDS(snapshot, snapshot_path)
    stopifnot(identical(readRDS(snapshot_path), snapshot))
    message("PASS: ", png_names[i], " and ", rds_names[i], " validated and reopened")
  }
  for (directory in c(result_dir, data_dir)) {
    if (!dir.exists(directory)) stopifnot(dir.create(directory, recursive = TRUE))
  }
  stopifnot(
    all(file.copy(file.path(stage, png_names), result_dir, overwrite = FALSE)),
    all(file.copy(file.path(stage, rds_names), data_dir, overwrite = FALSE))
  )
  invisible(prepared)
}

if (sys.nframe() == 0L) {
  ids <- commandArgs(trailingOnly = TRUE)
  if (length(ids)) run_andre_focused_2022(ids) else run_andre_focused_2022()
}
