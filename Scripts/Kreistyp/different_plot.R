library(dplyr)
library(ggplot2)
library(tidyr)

regional_weekly <- readRDS(
  "data_processed/Kreistyp/regional_weekly_summary_2020_2023.rds"
)

district_colors <- c(
  "Kreisfreie Großstädte" = "#084594",
  "Städtische Kreise" = "#2171B5",
  "Ländliche Kreise mit Verdichtungsansätzen" = "#6BAED6",
  "Dünn besiedelte ländliche Kreise" = "#8BAFCF"
)

valid_weeks <- regional_weekly %>%
  filter(
    iso_year %in% 2020:2023,
    !is.na(week_start),
    is.finite(incidence)
  ) %>%
  mutate(week_start = as.Date(week_start))

national_weekly <- valid_weeks %>%
  group_by(week_start) %>%
  summarise(
    national_median = median(incidence),
    .groups = "drop"
  )

weekly_type_medians <- valid_weeks %>%
  filter(kreistyp_name %in% names(district_colors)) %>%
  mutate(
    kreistyp_name = factor(kreistyp_name, levels = names(district_colors))
  ) %>%
  group_by(week_start, kreistyp_name) %>%
  summarise(
    n_kreise = n_distinct(geo_code),
    type_median = median(incidence),
    .groups = "drop"
  )

weekly_differences <- weekly_type_medians %>%
  left_join(national_weekly, by = "week_start") %>%
  mutate(difference = type_median - national_median)

city_reference <- "Kreisfreie Großstädte"
city_weekly <- weekly_type_medians %>%
  filter(kreistyp_name == city_reference) %>%
  transmute(week_start, city_median = type_median)

weekly_city_differences <- weekly_type_medians %>%
  filter(kreistyp_name != city_reference) %>%
  inner_join(city_weekly, by = "week_start") %>%
  mutate(difference = type_median - city_median)

# Wöchentliche Differenzen: gemeinsame Darstellung
difference_plot <- ggplot(
  weekly_differences,
  aes(x = week_start, y = difference, colour = kreistyp_name)
) +
  geom_hline(yintercept = 0, colour = "#64748B", linewidth = 0.5) +
  geom_line(linewidth = 0.65, linetype = "solid") +
  scale_colour_manual(
    name = NULL,
    values = district_colors,
    labels = scales::label_wrap(24)
  ) +
  scale_x_date(
    breaks = as.Date(paste0(2020:2023, "-01-01")),
    date_labels = "%Y"
  ) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  guides(colour = guide_legend(nrow = 1, byrow = TRUE)) +
  labs(
    title = "COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = "Wöchentliche Abweichung vom bundesweiten Median der Kreiswerte, 2020–2023",
    x = NULL,
    y = "Differenz in Fällen je 100.000 Einwohner",
    caption = "Die Nulllinie entspricht dem bundesweiten Median der jeweiligen Kalenderwoche."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.key.width = grid::unit(1.4, "cm"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(hjust = 0)
  )

print(difference_plot)

# Differences relative to the weekly median of independent cities ----
city_difference_plot <- difference_plot %+% weekly_city_differences +
  labs(
    subtitle = "Wöchentliche Abweichung vom Median der kreisfreien Großstädte, 2020–2023",
    caption = paste(
      "Nulllinie = Median der kreisfreien Großstädte der jeweiligen Kalenderwoche.",
      "Positive Werte zeigen eine höhere Meldeinzidenz als in der Referenzgruppe.",
      sep = "\n"
    )
  )

print(city_difference_plot)

# Wöchentliche Differenzen: ein Panel je Kreistyp
weekly_difference_facets <- difference_plot +
  facet_wrap(
    vars(kreistyp_name),
    ncol = 2,
    labeller = label_wrap_gen(width = 32)
  ) +
  labs(
    title = "Wöchentliche Abweichung der COVID-19-Meldeinzidenz",
    subtitle = "Kreistyp-Median minus bundesweiter Median der Kreiswerte, 2020–2023",
    x = "Kalenderwoche",
    caption = "Nulllinie = bundesweiter Median der jeweiligen Kalenderwoche"
  ) +
  theme(
    legend.position = "none",
    strip.text = element_text(face = "bold", hjust = 0),
    panel.spacing = grid::unit(1, "lines")
  )

print(weekly_difference_facets)


# Export figures ----
output_dir <- file.path("results", "Kreistyp")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  filename = file.path(output_dir, "05_differenz_bundesmedian.png"),
  plot = difference_plot,
  width = 13,
  height = 6,
  units = "in",
  dpi = 300,
  bg = "white"
)

ggsave(
  filename = file.path(output_dir, "06_differenz_bundesmedian_facetten.png"),
  plot = weekly_difference_facets,
  width = 13,
  height = 7,
  units = "in",
  dpi = 300,
  bg = "white"
)

ggsave(
  filename = file.path(output_dir, "07_differenz_grossstaedte.png"),
  plot = city_difference_plot,
  width = 13,
  height = 6,
  units = "in",
  dpi = 300,
  bg = "white"
)
