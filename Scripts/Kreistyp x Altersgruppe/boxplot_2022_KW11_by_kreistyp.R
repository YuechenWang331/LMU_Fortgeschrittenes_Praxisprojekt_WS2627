library(data.table)
library(ggplot2)

# 1. Read the weekly district-level data.
input_file <- file.path(
  "data_processed",
  "Kreistyp x Altersgruppe",
  "kreis_weekly_age_kreistyp_2020_2023.rds"
)

if (!file.exists(input_file)) {
  stop("Input file not found. Run the script from the RStudio project root.")
}

weekly <- as.data.table(readRDS(input_file))

age_levels <- c("6-17", "18-39", "70-79")
age_labels <- c("6–17 Jahre", "18–39 Jahre", "70–79 Jahre")

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

# 2. Select the three age groups in KW 11/2022.
selected <- weekly[
  iso_year == 2022L &
    iso_week == 11L &
    age_group %in% age_levels &
    is.finite(incidence),
  .(
    geo_code,
    age_group = as.character(age_group),
    kreistyp_code,
    incidence
  )
]

if (nrow(selected) == 0L) {
  stop("No valid observations found for KW 11/2022.")
}

# Include each district in the nationwide overview and its own district type.
plot_data <- rbind(
  selected[, .(geo_code, age_group, incidence, group_id = 1L)],
  selected[, .(
    geo_code, age_group, incidence,
    group_id = kreistyp_code + 1L
  )]
)

plot_data[, age_panel := factor(
  age_group,
  levels = age_levels,
  labels = age_labels
)]

plot_data[, district_type := factor(
  group_id,
  levels = seq_along(type_labels),
  labels = type_labels
)]

# 3. Calculate medians and sample sizes.
plot_summary <- plot_data[
  ,
  .(
    n_kreise = uniqueN(geo_code),
    median_incidence = median(incidence)
  ),
  by = .(age_panel, district_type)
]

district_counts <- plot_summary[
  ,
  .(min_n = min(n_kreise), max_n = max(n_kreise)),
  by = district_type
]

district_counts[, count_label := ifelse(
  min_n == max_n,
  sprintf("n = %d", min_n),
  sprintf("n = %d–%d", min_n, max_n)
)]

row_labels <- setNames(
  sprintf(
    "%s\n(%s)",
    as.character(district_counts$district_type),
    district_counts$count_label
  ),
  as.character(district_counts$district_type)
)

# Print exact medians for the three age groups.
setorder(plot_summary, age_panel, district_type)
print(plot_summary[, .(
  age_panel,
  district_type = gsub("\n", " ", as.character(district_type), fixed = TRUE),
  n_kreise,
  median_incidence = round(median_incidence, 1)
)])

# 4. Draw all panels on the same y-axis scale.
box_width <- 0.32

kw11_plot <- ggplot(plot_data, aes(x = 1, y = incidence)) +
  geom_boxplot(
    aes(group = district_type),
    width = box_width,
    fill = NA,
    color = "#5B6776",
    linewidth = 0.45,
    outlier.shape = NA
  ) +
  geom_point(
    aes(color = district_type),
    position = position_jitter(width = 0.12, height = 0, seed = 123),
    size = 0.85,
    alpha = 0.44
  ) +
  geom_errorbar(
    data = plot_summary,
    aes(
      x = 1,
      ymin = median_incidence,
      ymax = median_incidence,
      color = district_type
    ),
    inherit.aes = FALSE,
    width = box_width,
    linewidth = 1.05
  ) +
  facet_grid(
    rows = vars(district_type),
    cols = vars(age_panel),
    scales = "fixed",
    switch = "y",
    labeller = labeller(district_type = as_labeller(row_labels))
  ) +
  scale_x_continuous(
    limits = c(0.55, 1.45),
    breaks = NULL,
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    breaks = seq(0, 8000, by = 2000),
    labels = scales::label_number(big.mark = ".", decimal.mark = ","),
    expand = expansion(mult = c(0, 0.035))
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
      "Die farbige Linie zeigt den Median.",
      "\nDie y-Achsenskala ist innerhalb jeder Altersgruppe einheitlich."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "#E8EBEF", linewidth = 0.4),
    panel.spacing.x = grid::unit(0.65, "lines"),
    panel.spacing.y = grid::unit(0.4, "lines"),
    strip.placement = "outside",
    strip.text.x = element_text(face = "bold", margin = margin(b = 5)),
    strip.text.y.left = element_text(
      angle = 0,
      hjust = 0,
      face = "bold",
      size = 9,
      margin = margin(r = 7)
    ),
    axis.text.y = element_text(size = 8),
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(margin = margin(b = 8)),
    plot.caption = element_text(hjust = 0, color = "#5B6776"),
    plot.margin = margin(10, 12, 10, 10)
  )

print(kw11_plot)

# 5. Export a single PNG.
output_dir <- file.path("results", "Kreistyp x Altersgruppe")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  filename = file.path(
    output_dir,
    "boxplot_2022_KW11_by_kreistyp.png"
  ),
  plot = kw11_plot,
  width = 10.5,
  height = 8,
  units = "in",
  dpi = 300,
  bg = "white"
)
