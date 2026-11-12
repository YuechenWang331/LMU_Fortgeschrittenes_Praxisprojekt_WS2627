library(dplyr)
library(ggplot2)

regional_weekly <- readRDS(
  "data_processed/Kreistyp/regional_weekly_summary_2020_2023.rds"
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

all_weeks <- regional_weekly %>%
  filter(iso_year %in% 2020:2023, is.finite(incidence))

plot_data <- bind_rows(
  all_weeks %>%
    transmute(incidence, district_type = "Alle Kreise"),
  all_weeks %>%
    filter(kreistyp_name %in% names(district_labels)[-1]) %>%
    transmute(incidence, district_type = as.character(kreistyp_name))
) %>%
  mutate(
    district_type = factor(district_type, levels = names(district_labels))
  )

district_counts <- table(plot_data$district_type)
box_width <- 0.52
format_number <- scales::label_number(
  accuracy = 1,
  big.mark = ".",
  decimal.mark = ","
)

boxplot_full <- ggplot(plot_data, aes(x = district_type, y = incidence)) +
  geom_vline(
    xintercept = 1.5,
    colour = "#D9E0E8",
    linewidth = 0.4,
    linetype = "dashed"
  ) +
  geom_boxplot(
    aes(colour = district_type),
    width = box_width,
    fill = "white",
    linewidth = 0.45,
    outlier.shape = 16,
    outlier.size = 0.65,
    outlier.alpha = 0.15
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
    linewidth = 0.45
  ) +
  scale_colour_manual(values = district_colors, guide = "none") +
  scale_x_discrete(
    labels = function(x) {
      paste0(
        district_labels[x],
        "\n(n = ", format_number(as.integer(district_counts[x])), ")"
      )
    }
  ) +
  scale_y_continuous(labels = format_number) +
  labs(
    title = "COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = "Deutschland · Alle Kalenderwochen 2020–2023",
    x = NULL,
    y = "Gemeldete Fälle je 100.000 Einwohner",
    caption = "Punkte = Ausreißer nach der Boxplot-Regel. Linie im Kasten = Median.\nn = Anzahl der Kreis-Wochen."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = 10, lineheight = 0.95),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(
      size = 11, colour = "#334155", hjust = 0,
      lineheight = 1.15, margin = margin(t = 10)
    ),
    plot.margin = margin(12, 16, 16, 12)
  )

# Zoom without filtering the data ----
boxplot_zoom <- boxplot_full +
  coord_cartesian(ylim = c(0, 300)) +
  labs(
    caption = paste(
      "Punkte = Ausreißer nach der Boxplot-Regel. Linie im Kasten = Median.",
      "Ausschnitt 0–300. Die Boxplots beruhen auf allen Beobachtungen.",
      sep = "\n"
    )
  )

print(boxplot_full)
print(boxplot_zoom)

# Export figures ----
output_dir <- file.path("results", "Kreistyp")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  filename = file.path(output_dir, "01_boxplot_alle_wochen.png"),
  plot = boxplot_full,
  width = 13,
  height = 7,
  units = "in",
  dpi = 300,
  bg = "white"
)

ggsave(
  filename = file.path(output_dir, "02_boxplot_alle_wochen_zoom.png"),
  plot = boxplot_zoom,
  width = 13,
  height = 7,
  units = "in",
  dpi = 300,
  bg = "white"
)
