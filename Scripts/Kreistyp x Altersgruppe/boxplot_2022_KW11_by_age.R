library(data.table)
library(ggplot2)

input_file <- file.path(
  "data_processed",
  "Kreistyp x Altersgruppe",
  "kreis_weekly_age_kreistyp_2020_2023.rds"
)

weekly <- as.data.table(readRDS(input_file))

age_levels <- c("6-17", "18-39", "70-79")

type_labels <- c(
  "Alle Kreise",
  "Kreisfreie\nGroßstädte",
  "Städtische\nKreise",
  "Ländliche Kreise mit\nVerdichtungsansätzen",
  "Dünn besiedelte\nländliche Kreise"
)

type_colors <- setNames(
  c("#A0A8B3", "#08306B", "#2171B5", "#4292C6", "#82B5D8"),
  type_labels
)

# Select valid district observations for KW 11/2022.
selected <- weekly[
  iso_year == 2022L & iso_week == 11L &
    age_group %in% age_levels & is.finite(incidence),
  .(
    geo_code,
    age_group = as.character(age_group),
    kreistyp_code,
    incidence
  )
]

# Include each district in the national overview and its own district type.
plot_data <- rbind(
  selected[, .(geo_code, age_group, incidence, group_id = 1L)],
  selected[, .(geo_code, age_group, incidence, group_id = kreistyp_code + 1L)]
)

plot_data[, age_panel := factor(
  age_group,
  levels = age_levels,
  labels = c("6–17 Jahre", "18–39 Jahre", "70–79 Jahre")
)]

plot_data[, district_type := factor(
  group_id,
  levels = seq_along(type_labels),
  labels = type_labels
)]

plot_summary <- plot_data[
  ,
  .(
    n_kreise = uniqueN(geo_code),
    median_incidence = median(incidence)
  ),
  by = .(age_panel, group_id, district_type)
]

# Print exact medians and differences from Kreisfreie Großstädte.
city_medians <- plot_summary[
  group_id == 2L,
  .(age_panel, city_median = median_incidence)
]

comparison <- merge(
  plot_summary,
  city_medians,
  by = "age_panel",
  all.x = TRUE
)

comparison[, difference_vs_city := median_incidence - city_median]
setorder(comparison, age_panel, group_id)

print(comparison[, .(
  age_panel,
  district_type,
  n_kreise,
  median_incidence = round(median_incidence, 1),
  difference_vs_city = round(difference_vs_city, 1)
)])

# Show one sample size per x-axis label when all panels have the same counts.
axis_counts <- plot_summary[
  ,
  .(same_count = uniqueN(n_kreise) == 1L, n_kreise = first(n_kreise)),
  by = district_type
]

axis_labels <- setNames(type_labels, type_labels)

if (all(axis_counts$same_count)) {
  group_names <- as.character(axis_counts$district_type)
  axis_labels[group_names] <- sprintf(
    "%s\n(n = %d)", group_names, axis_counts$n_kreise
  )
}

box_width <- 0.54

kw11_plot <- ggplot(plot_data, aes(x = district_type, y = incidence)) +
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
    size = 0.85,
    alpha = 0.44
  ) +
  geom_errorbar(
    data = plot_summary,
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
  facet_grid(rows = vars(age_panel), switch = "y") +
  scale_x_discrete(labels = axis_labels) +
  scale_y_continuous(
    breaks = seq(0, 8000, by = 2000),
    labels = scales::label_number(big.mark = ".", decimal.mark = ","),
    expand = expansion(mult = c(0.01, 0.06))
  ) +
  expand_limits(y = 0) +
  scale_color_manual(values = type_colors, guide = "none") +
  labs(
    title = "COVID-19-Meldeinzidenz nach Altersgruppe und Kreistyp",
    subtitle = "Deutschland · KW 11/2022",
    x = NULL,
    y = "Gemeldete Fälle je 100.000 Personen der Altersgruppe",
    caption = paste(
      "Jeder Punkt steht für einen Kreis mit gültiger Meldeinzidenz.",
      "Die farbige Linie im Kasten zeigt den Median."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "#E8EBEF", linewidth = 0.4),
    panel.spacing.y = grid::unit(0.8, "lines"),
    strip.placement = "outside",
    strip.text.y.left = element_text(angle = 0, face = "bold"),
    axis.text.x = element_text(size = 10, margin = margin(t = 6)),
    plot.title = element_text(face = "bold", size = 17),
    plot.subtitle = element_text(margin = margin(b = 10)),
    plot.caption = element_text(hjust = 0, color = "#5B6776"),
    plot.margin = margin(14, 18, 12, 14)
  )

print(kw11_plot)

output_dir <- file.path("results", "Kreistyp x Altersgruppe")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  filename = file.path(output_dir, "boxplot_2022_KW11_by_age.png"),
  plot = kw11_plot,
  width = 12,
  height = 10,
  units = "in",
  dpi = 300,
  bg = "white"
)
