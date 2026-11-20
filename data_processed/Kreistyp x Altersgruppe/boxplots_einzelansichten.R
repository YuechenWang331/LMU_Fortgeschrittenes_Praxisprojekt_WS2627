library(data.table)
library(ggplot2)

input_file <- file.path(
  "data_processed",
  "Kreistyp x Altersgruppe",
  "kreis_weekly_age_kreistyp_2020_2023.rds"
)

weekly <- as.data.table(readRDS(input_file))

type_labels <- c(
  "Alle Kreise",
  "Kreisfreie\nGroßstädte",
  "Städtische\nKreise",
  "Ländliche Kreise mit\nVerdichtungsansätzen",
  "Dünn besiedelte\nländliche Kreise"
)

type_colors <- setNames(
  c("#A0A8B3", "#D0582B", "#F2C06E", "#C5DAA1", "#69AD55"),
  type_labels
)

plot_week_age <- function(year, week, age) {
  selected <- weekly[
    iso_year == year & iso_week == week &
      age_group == age & is.finite(incidence)
  ]
  stopifnot(nrow(selected) > 0L, all(selected$kreistyp_code %in% 1:4))

  plot_data <- rbind(
    selected[, .(geo_code, incidence, group_id = 1L)],
    selected[, .(geo_code, incidence, group_id = kreistyp_code + 1L)]
  )
  plot_data[, district_type := factor(
    group_id,
    levels = seq_along(type_labels),
    labels = type_labels
  )]

  summary <- plot_data[
    ,
    .(n_kreise = uniqueN(geo_code), median_incidence = median(incidence)),
    by = district_type
  ]
  groups <- as.character(summary$district_type)
  axis_labels <- setNames(sprintf("%s\n(n = %d)", groups, summary$n_kreise), groups)
  box_width <- 0.54

  ggplot(plot_data, aes(x = district_type, y = incidence)) +
    geom_vline(
      xintercept = 1.5,
      color = "#D7DFE8",
      linewidth = 0.45,
      linetype = "dashed"
    ) +
    geom_boxplot(
      width = box_width,
      fill = NA,
      color = "#5B6776",
      linewidth = 0.45,
      outlier.shape = NA
    ) +
    geom_point(
      aes(color = district_type),
      position = position_jitter(width = 0.17, height = 0, seed = 123),
      size = 1.4,
      alpha = 0.55
    ) +
    geom_errorbar(
      data = summary,
      aes(
        x = district_type,
        ymin = median_incidence,
        ymax = median_incidence,
        color = district_type
      ),
      inherit.aes = FALSE,
      width = box_width,
      linewidth = 1.05
    ) +
    scale_x_discrete(labels = axis_labels) +
    scale_y_continuous(
      labels = scales::label_number(big.mark = ".", decimal.mark = ",")
    ) +
    expand_limits(y = 0) +
    scale_color_manual(values = type_colors, guide = "none") +
    labs(
      title = "COVID-19-Meldeinzidenz nach Kreistyp",
      subtitle = sprintf("Deutschland · KW %02d/%d · %s Jahre", week, year, age),
      x = NULL,
      y = "Gemeldete Fälle je 100.000 Einwohner",
      caption = paste(
        "Jeder Punkt entspricht einem Kreis mit gültiger Meldeinzidenz.",
        "Die farbige Linie im Kasten zeigt den Median."
      )
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "#E8EBEF", linewidth = 0.4),
      axis.text.x = element_text(size = 10, margin = margin(t = 6)),
      plot.title = element_text(face = "bold", size = 17),
      plot.subtitle = element_text(margin = margin(b = 10)),
      plot.caption = element_text(hjust = 0, color = "#5B6776"),
      plot.margin = margin(14, 18, 12, 14)
    )
}

output_dir <- file.path("results", "Kreistyp x Altersgruppe")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

weeks <- data.frame(year = c(2022L, 2023L), week = c(11L, 1L))
for (i in seq_len(nrow(weeks))) {
  year <- weeks$year[i]
  week <- weeks$week[i]
  for (age in c("6-17", "18-39", "70-79")) {
    ggsave(
      filename = file.path(
        output_dir, sprintf("incidence_boxplot_%d_KW%02d_age_%s.png", year, week, age)
      ),
      plot = plot_week_age(year, week, age),
      width = 14,
      height = 8,
      units = "in",
      dpi = 300,
      bg = "white"
    )
  }
}
