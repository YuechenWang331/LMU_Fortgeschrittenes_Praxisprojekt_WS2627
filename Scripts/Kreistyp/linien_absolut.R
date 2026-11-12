library(dplyr)
library(ggplot2)

regional_weekly <- readRDS(
  "data_processed/regional_weekly_summary_2020_2024.rds"
)

district_colors <- c(
  "Kreisfreie Großstädte" = "#084594",
  "Städtische Kreise" = "#2171B5",
  "Ländliche Kreise mit Verdichtungsansätzen" = "#6BAED6",
  "Dünn besiedelte ländliche Kreise" = "#C6DBEF"
)

weekly_medians <- regional_weekly %>%
  filter(
    iso_year %in% 2020:2024,
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

weekly_plot <- ggplot(
  weekly_medians,
  aes(x = week_start, y = median_incidence, colour = kreistyp_name)
) +
  geom_line(
    data = filter(
      weekly_medians,
      kreistyp_name == "Dünn besiedelte ländliche Kreise"
    ),
    colour = "#64748B",
    linewidth = 1.25
  ) +
  geom_line(linewidth = 0.85) +
  scale_colour_manual(
    values = district_colors,
    labels = scales::label_wrap(32)
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  guides(colour = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title = "Wöchentliche COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = "Deutschland · Median der Kreiswerte je Kalenderwoche, 2020–2024",
    x = NULL,
    y = "Gemeldete Fälle je 100.000 Einwohner",
    colour = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

print(weekly_plot)
