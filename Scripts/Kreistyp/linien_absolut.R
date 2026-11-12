# Setup ----
library(dplyr)
library(ggplot2)

analysis_years <- 2020:2023

# Read weekly data ----
regional_weekly <- readRDS(
  "data_processed/Kreistyp/regional_weekly_summary_2020_2023.rds"
)

# Match the colours used in Kreistyp_geo.R ----
district_colors <- c(
  "Kreisfreie Großstädte" = "#084594",
  "Städtische Kreise" = "#2171B5",
  "Ländliche Kreise mit Verdichtungsansätzen" = "#6BAED6",
  "Dünn besiedelte ländliche Kreise" = "#C6DBEF"
)

# Calculate weekly medians by district type ----
weekly_medians <- regional_weekly %>%
  filter(
    iso_year %in% analysis_years,
    kreistyp_name %in% names(district_colors)
  ) %>%
  mutate(
    week_start = as.Date(week_start),
    kreistyp_name = factor(kreistyp_name, levels = names(district_colors))
  ) %>%
  group_by(week_start, kreistyp_name) %>%
  summarise(
    n_kreise = sum(is.finite(incidence)),
    median_incidence = if (n_kreise > 0) {
      median(incidence[is.finite(incidence)])
    } else {
      NA_real_
    },
    .groups = "drop"
  )

# Plot weekly incidence ----
weekly_plot <- ggplot(
  weekly_medians,
  aes(
    x = week_start,
    y = median_incidence,
    colour = kreistyp_name
  )
) +
  geom_line(linewidth = 0.65, linetype = "solid") +
  scale_colour_manual(
    values = district_colors,
    labels = scales::label_wrap(24)
  ) +
  scale_x_date(
    breaks = as.Date(paste0(analysis_years, "-01-01")),
    date_labels = "%Y"
  ) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  guides(colour = guide_legend(nrow = 1, byrow = TRUE)) +
  labs(
    title = "Wöchentliche COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = "Deutschland · Median der Kreiswerte je Kalenderwoche, 2020–2023",
    x = NULL,
    y = "Gemeldete Fälle je 100.000 Einwohner",
    colour = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 9),
    legend.key.width = grid::unit(1.3, "cm"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

print(weekly_plot)

# Export figure ----
output_dir <- file.path("results", "Kreistyp")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  filename = file.path(output_dir, "04_woechentliche_mediane.png"),
  plot = weekly_plot,
  width = 13,
  height = 6,
  units = "in",
  dpi = 300,
  bg = "white"
)
