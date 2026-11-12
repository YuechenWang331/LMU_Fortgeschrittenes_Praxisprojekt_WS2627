library(dplyr)
library(ggplot2)

regional_weekly <- readRDS(
  "data_processed/regional_weekly_summary_2020_2024.rds"
)

week_data <- regional_weekly %>%
  filter(iso_year == 2022, iso_week == 10, is.finite(incidence))

plot_data <- bind_rows(
  week_data %>%
    mutate(district_type = "Alle Kreise"),
  week_data %>%
    filter(!is.na(kreistyp_name)) %>%
    mutate(district_type = as.character(kreistyp_name))
) %>%
  mutate(
    district_type = factor(
      district_type,
      levels = c(
        "Alle Kreise",
        sort(unique(as.character(na.omit(week_data$kreistyp_name))))
      )
    )
  )

district_labels <- c(
  "Alle Kreise" = "Alle Kreise",
  "Kreisfreie Großstädte" = "Kreisfreie\nGroßstädte",
  "Städtische Kreise" = "Städtische\nKreise",
  "Ländliche Kreise mit Verdichtungsansätzen" =
    "Ländliche Kreise mit\nVerdichtungsansätzen",
  "Dünn besiedelte ländliche Kreise" =
    "Dünn besiedelte\nländliche Kreise"
)

district_colors <- c(
  "Alle Kreise" = "#9CA3AF",
  "Kreisfreie Großstädte" = "#084594",
  "Städtische Kreise" = "#2171B5",
  "Ländliche Kreise mit Verdichtungsansätzen" = "#6BAED6",
  "Dünn besiedelte ländliche Kreise" = "#C6DBEF"
)

district_counts <- table(plot_data$district_type)
box_width <- 0.52

ggplot(plot_data, aes(x = district_type, y = incidence)) +
  geom_vline(
    xintercept = 1.5,
    colour = "#D9E0E8",
    linewidth = 0.4,
    linetype = "dashed"
  ) +
  geom_boxplot(
    width = box_width,
    fill = "white",
    colour = "#475569",
    linewidth = 0.4,
    outlier.shape = NA
  ) +
  geom_point(
    aes(fill = district_type, alpha = district_type == "Alle Kreise"),
    position = position_jitter(width = 0.16, height = 0, seed = 10),
    shape = 21,
    colour = "#475569",
    stroke = 0.2,
    size = 1.5
  ) +
  stat_summary(
    fun = median,
    fun.min = median,
    fun.max = median,
    geom = "crossbar",
    width = box_width,
    colour = "#475569",
    linewidth = 0.65
  ) +
  stat_summary(
    aes(colour = district_type),
    fun = median,
    fun.min = median,
    fun.max = median,
    geom = "crossbar",
    width = box_width,
    linewidth = 0.5
  ) +
  scale_fill_manual(values = district_colors, guide = "none") +
  scale_colour_manual(values = district_colors, guide = "none") +
  scale_alpha_manual(
    values = c("TRUE" = 0.28, "FALSE" = 0.72),
    guide = "none"
  ) +
  scale_x_discrete(
    limits = names(district_labels),
    labels = function(x) {
      paste0(district_labels[x], "\n(n = ", district_counts[x], ")")
    }
  ) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  labs(
    title = "COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = "Deutschland · Kalenderwoche 10, 2022",
    x = NULL,
    y = "Gemeldete Fälle je 100.000 Einwohner",
    caption = "Jeder Punkt entspricht einem Kreis. Die Linie im Kasten zeigt den Median."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = 10, lineheight = 0.95),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(colour = "#64748B", hjust = 0)
  )

