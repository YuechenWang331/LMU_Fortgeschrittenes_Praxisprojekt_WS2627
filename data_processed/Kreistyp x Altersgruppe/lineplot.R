library(data.table)
library(ggplot2)

# 1. Read the weekly data
input_file <- file.path(
  "data_processed",
  "Kreistyp x Altersgruppe",
  "kreis_weekly_age_kreistyp_2020_2023.rds"
)

if (!file.exists(input_file)) {
  stop("Input file not found. Open the RStudio project and run from its root.")
}

weekly <- as.data.table(readRDS(input_file))

# 2. Calculate weekly medians across districts
age_levels <- c("0-5", "6-17", "18-39", "40-59", "60-69", "70-79", "80+")

type_labels <- c(
  "Kreisfreie Großstädte",
  "Städtische Kreise",
  "Ländliche Kreise mit Verdichtungsansätzen",
  "Dünn besiedelte ländliche Kreise"
)

age_colors <- setNames(
  c("#7A5195", "#D55E00", "#0072B2", "#00866A",
    "#B47A00", "#B84986", "#343A40"),
  age_levels
)

weekly_medians <- weekly[
  !is.na(incidence),
  .(
    median_incidence = median(incidence),
    n_kreise = uniqueN(geo_code)
  ),
  by = .(week_start, age_group, kreistyp_code)
]

weekly_medians[, age_group := factor(age_group, levels = age_levels)]
weekly_medians[, kreistyp := factor(
  kreistyp_code,
  levels = 1:4,
  labels = type_labels
)]

setorder(weekly_medians, age_group, kreistyp_code, week_start)

# 3. Plot the weekly trends
trend_plot <- ggplot(
  weekly_medians,
  aes(x = week_start, y = median_incidence, color = age_group)
) +
  geom_line(linewidth = 0.65, linetype = "solid") +
  facet_wrap(
    vars(kreistyp),
    ncol = 2,
    scales = "fixed",
    labeller = label_wrap_gen(width = 34)
  ) +
  scale_color_manual(
    values = age_colors,
    breaks = age_levels,
    labels = c("0–5", "6–17", "18–39", "40–59", "60–69", "70–79", "80+")
  ) +
  scale_x_date(
    breaks = as.Date(paste0(2020:2023, "-01-01")),
    date_labels = "%Y"
  ) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  labs(
    title = "Wöchentliche COVID-19-Meldeinzidenz nach Altersgruppe innerhalb der Kreistypen",
    subtitle = "Median der Kreise je Kalenderwoche, 2020–2023",
    x = NULL,
    y = "Meldeinzidenz je 100.000 Personen der Altersgruppe",
    color = "Alter in Jahren",
    caption = "Beobachtungen ohne gültige Meldeinzidenz wurden ausgeschlossen."
  ) +
  guides(color = guide_legend(nrow = 1)) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 9),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(hjust = 0)
  )

print(trend_plot)

# 4. Save the plot
output_dir <- file.path("results", "Kreistyp x Altersgruppe")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  filename = file.path(output_dir, "lineplot_age_and_kreistyp.png"),
  plot = trend_plot,
  width = 16,
  height = 10,
  units = "in",
  dpi = 300,
  bg = "white"
)
