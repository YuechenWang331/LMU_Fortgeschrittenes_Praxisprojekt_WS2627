library(data.table)
library(ggplot2)

input_file <- file.path(
  "data_processed",
  "Kreistyp x Altersgruppe",
  "kreis_weekly_age_kreistyp_2020_2023.rds"
)

weekly <- as.data.table(readRDS(input_file))
valid_weekly <- weekly[is.finite(incidence)]

age_levels <- c("0-5", "6-17", "18-39", "40-59", "60-69", "70-79", "80+")
type_levels <- c(
  "Kreisfreie Großstädte",
  "Städtische Kreise",
  "Ländliche Kreise mit Verdichtungsansätzen",
  "Dünn besiedelte ländliche Kreise"
)

# Calculate the median within each district type.
weekly_medians <- valid_weekly[
  ,
  .(median_incidence = median(incidence)),
  by = .(week_start, age_group, kreistyp_code, kreistyp_name)
]

weekly_medians[, age_group := factor(age_group, levels = rev(age_levels))]
weekly_medians[, kreistyp_name := factor(kreistyp_name, levels = type_levels)]

# Calculate the arithmetic mean across all districts.
mean_reference <- valid_weekly[
  ,
  .(reference_incidence = mean(incidence)),
  by = .(week_start, age_group)
]
mean_reference[, age_group := factor(age_group, levels = rev(age_levels))]

# Use the median of Kreisfreie Großstädte as the second reference.
city_reference <- weekly_medians[
  kreistyp_code == 1L,
  .(week_start, age_group, reference_incidence = median_incidence)
]

reference_keys <- c("week_start", "age_group")

mean_differences <- merge(
  weekly_medians, mean_reference,
  by = reference_keys, all.x = TRUE
)
city_differences <- merge(
  weekly_medians[kreistyp_code != 1L], city_reference,
  by = reference_keys, all.x = TRUE
)

mean_differences[, difference := median_incidence - reference_incidence]
city_differences[, difference := median_incidence - reference_incidence]

# Use one symmetric color scale for both plots.
fill_limit <- max(
  abs(mean_differences$difference),
  abs(city_differences$difference),
  na.rm = TRUE
)

plot_heatmap <- function(plot_data, title, subtitle, caption) {
  ggplot(plot_data, aes(week_start, age_group, fill = difference)) +
    geom_tile(width = 7, height = 0.92) +
    facet_wrap(vars(kreistyp_name), ncol = 1) +
    scale_x_date(
      breaks = as.Date(c("2019-12-30", "2021-01-04", "2022-01-03", "2023-01-02")),
      labels = as.character(2020:2023),
      expand = expansion(mult = 0)
    ) +
    scale_fill_gradient2(
      low = "#6A3D9A",
      mid = "#FAFAFA",
      high = "#D95F02",
      midpoint = 0,
      limits = c(-fill_limit, fill_limit),
      na.value = "grey80",
      labels = scales::label_number(big.mark = ".", decimal.mark = ",")
    ) +
    labs(
      title = title,
      subtitle = subtitle,
      x = NULL,
      y = "Altersgruppe (Jahre)",
      fill = "Differenz je 100.000 Einwohner",
      caption = paste(
        caption,
        "Beobachtungen ohne gültige Meldeinzidenz wurden ausgeschlossen.",
        sep = "\n"
      )
    ) +
    guides(fill = guide_colorbar(
      title.position = "top",
      barwidth = grid::unit(10, "cm")
    )) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid = element_blank(),
      panel.spacing = grid::unit(1, "lines"),
      strip.text = element_text(face = "bold", hjust = 0),
      legend.position = "bottom",
      plot.title = element_text(face = "bold"),
      plot.caption = element_text(hjust = 0)
    )
}

mean_plot <- plot_heatmap(
  mean_differences,
  title = "COVID-19-Meldeinzidenz im Vergleich zum bundesweiten Durchschnitt",
  subtitle = "Kreistypmedian minus Mittelwert aller Kreise je Altersgruppe und Kalenderwoche, 2020–2023",
  caption = "Violett = unter dem Durchschnitt, Orange = über dem Durchschnitt."
)

city_plot <- plot_heatmap(
  city_differences,
  title = "COVID-19-Meldeinzidenz im Vergleich zu Großstädten",
  subtitle = "Differenz der Kreismediane je Altersgruppe und Kalenderwoche, 2020–2023",
  caption = paste(
    "Referenzgruppe: Kreisfreie Großstädte.",
    "Violett = unter dem Referenzwert, Orange = über dem Referenzwert."
  )
)

output_dir <- file.path("results", "Kreistyp x Altersgruppe")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  file.path(output_dir, "weekly_incidence_difference_vs_mean.png"),
  plot = mean_plot, width = 13, height = 11, dpi = 300, bg = "white"
)

ggsave(
  file.path(output_dir, "weekly_incidence_difference_vs_grossstaedte.png"),
  plot = city_plot, width = 13, height = 9, dpi = 300, bg = "white"
)

print(mean_plot)
print(city_plot)
