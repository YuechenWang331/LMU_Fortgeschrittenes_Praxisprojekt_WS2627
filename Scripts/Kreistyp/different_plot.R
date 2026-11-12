library(dplyr)
library(ggplot2)
library(tidyr)

regional_weekly <- readRDS(
  "data_processed/regional_weekly_summary_2020_2024.rds"
)

district_colors <- c(
  "Kreisfreie Großstädte" = "#084594",
  "Städtische Kreise" = "#2171B5",
  "Ländliche Kreise mit Verdichtungsansätzen" = "#6BAED6",
  "Dünn besiedelte ländliche Kreise" = "#C6DBEF"
)

valid_weeks <- regional_weekly %>%
  filter(
    iso_year %in% 2020:2024,
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

weekly_differences <- valid_weeks %>%
  filter(kreistyp_name %in% names(district_colors)) %>%
  mutate(
    kreistyp_name = factor(kreistyp_name, levels = names(district_colors))
  ) %>%
  group_by(week_start, kreistyp_name) %>%
  summarise(
    n_kreise = n_distinct(geo_code),
    type_median = median(incidence),
    .groups = "drop"
  ) %>%
  left_join(national_weekly, by = "week_start") %>%
  mutate(difference = type_median - national_median)

# Wöchentliche Differenzen: gemeinsame Darstellung
difference_plot <- ggplot(
  weekly_differences,
  aes(x = week_start, y = difference, colour = kreistyp_name)
) +
  geom_hline(yintercept = 0, colour = "#64748B", linewidth = 0.5) +
  geom_line(linewidth = 0.9, linetype = "solid") +
  scale_colour_manual(
    name = NULL,
    values = district_colors,
    labels = scales::label_wrap(32)
  ) +
  scale_x_date(
    breaks = as.Date(paste0(2020:2024, "-01-01")),
    date_labels = "%Y"
  ) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  guides(colour = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title = "COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = "Wöchentliche Abweichung vom bundesweiten Median der Kreiswerte, 2020–2024",
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

# Wöchentliche Differenzen: ein Panel je Kreistyp
weekly_difference_facets <- difference_plot +
  facet_wrap(
    vars(kreistyp_name),
    ncol = 2,
    labeller = label_wrap_gen(width = 32)
  ) +
  labs(
    title = "Wöchentliche Abweichung der COVID-19-Meldeinzidenz",
    subtitle = "Kreistyp-Median minus bundesweiter Median der Kreiswerte, 2020–2024",
    x = "Kalenderwoche",
    caption = "Nulllinie = bundesweiter Median der jeweiligen Kalenderwoche"
  ) +
  theme(
    legend.position = "none",
    strip.text = element_text(face = "bold", hjust = 0),
    panel.spacing = grid::unit(1, "lines")
  )

print(weekly_difference_facets)

# Jahreskennzahlen
annual_deviations <- weekly_differences %>%
  filter(is.finite(difference)) %>%
  mutate(iso_year = as.integer(format(week_start, "%G"))) %>%
  group_by(iso_year, kreistyp_name) %>%
  summarise(
    n_weeks = n_distinct(week_start),
    mean_difference = mean(difference),
    sum_absolute_difference = sum(abs(difference)),
    sum_squared_difference = sum(difference^2),
    mean_absolute_difference = mean(abs(difference)),
    root_mean_squared_difference = sqrt(mean(difference^2)),
    .groups = "drop"
  ) %>%
  arrange(iso_year, desc(mean_absolute_difference))

metric_labels <- c(
  mean_absolute_difference = "Mittlere absolute Abweichung",
  mean_difference = "Mittlere vorzeichenbehaftete Differenz",
  root_mean_squared_difference = "Quadratische Mittelabweichung (RMSE)"
)

annual_plot_data <- annual_deviations %>%
  pivot_longer(
    cols = all_of(names(metric_labels)),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(
    metric = factor(
      metric,
      levels = names(metric_labels),
      labels = unname(metric_labels)
    ),
    kreistyp_name = factor(
      kreistyp_name,
      levels = names(district_colors)
    )
  )

annual_deviation_plot <- ggplot(
  annual_plot_data,
  aes(x = factor(iso_year), y = value, fill = kreistyp_name)
) +
  geom_hline(yintercept = 0, colour = "#64748B", linewidth = 0.4) +
  geom_point(
    aes(group = kreistyp_name),
    position = position_dodge(width = 0.65),
    shape = 21,
    colour = "#334155",
    size = 3.2,
    stroke = 0.4
  ) +
  facet_wrap(vars(metric), ncol = 1) +
  scale_fill_manual(
    values = district_colors,
    labels = scales::label_wrap(32)
  ) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title = "Abweichung der COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = "Jahreswerte aus den wöchentlichen Differenzen zum bundesweiten Median",
    x = "ISO-Kalenderjahr",
    y = "Differenz in Fällen je 100.000 Einwohner",
    fill = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.spacing.y = grid::unit(0.9, "lines"),
    strip.text = element_text(face = "bold", hjust = 0),
    plot.title = element_text(face = "bold")
  )

print(annual_deviation_plot)


#------------------------------------------------------------------------------
library(dplyr)

mae_mse_by_kreistyp <- weekly_differences %>%
  filter(is.finite(difference)) %>%
  group_by(kreistyp_name) %>%
  summarise(
    n_weeks = n_distinct(week_start),
    MAE = mean(abs(difference)),
    MSE = mean(difference^2),
    .groups = "drop"
  ) %>%
  arrange(desc(MAE))

#View(mae_mse_by_kreistyp)

mae_mse_by_week <- weekly_differences %>%
  filter(is.finite(difference)) %>%
  group_by(week_start) %>%
  summarise(
    n_kreistypen = n_distinct(kreistyp_name),
    MAE = mean(abs(difference)),
    MSE = mean(difference^2),
    .groups = "drop"
  ) %>%
  filter(n_kreistypen == 4) %>%
  arrange(week_start)

#View(mae_mse_by_week)

library(dplyr)
library(tidyr)
library(ggplot2)

metric_labels <- c(
  MAE = "MAE · Mittlere absolute Abweichung (Fälle je 100.000 Einwohner)",
  MSE = "MSE · Mittlere quadrierte Abweichung (quadrierte Einheit)"
)

weekly_error_plot_data <- mae_mse_by_week %>%
  pivot_longer(
    cols = c(MAE, MSE),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(
    metric = factor(
      metric,
      levels = names(metric_labels),
      labels = unname(metric_labels)
    )
  ) %>%
  group_by(metric) %>%
  arrange(week_start, .by_group = TRUE) %>%
  mutate(
    segment = cumsum(
      as.integer(week_start - lag(week_start, default = first(week_start))) > 7
    )
  ) %>%
  ungroup()

weekly_error_plot <- ggplot(
  weekly_error_plot_data,
  aes(
    x = week_start,
    y = value,
    colour = metric,
    group = interaction(metric, segment)
  )
) +
  geom_line(linewidth = 0.9) +
  facet_wrap(vars(metric), ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c("#2171B5", "#084594"), guide = "none") +
  scale_x_date(
    breaks = as.Date(paste0(2020:2024, "-01-01")),
    date_labels = "%Y"
  ) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ".", decimal.mark = ",")
  ) +
  expand_limits(y = 0) +
  labs(
    title = "Wöchentliche Abweichungen der vier Kreistypen",
    subtitle = "Referenz: bundesweiter Median der Kreiswerte je Kalenderwoche",
    x = "Kalenderwoche",
    y = NULL,
    caption = "Alle vier Kreistypen gehen je Kalenderwoche gleichgewichtet ein."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.spacing.y = grid::unit(1, "lines"),
    strip.text = element_text(face = "bold", hjust = 0),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(hjust = 0)
  )

print(weekly_error_plot)


#------------------------------------------------------
library(dplyr)

peak_weeks <- mae_mse_by_week %>%
  slice_max(MAE, n = 1, with_ties = TRUE) %>%
  select(week_start, MAE)

peak_week_details <- weekly_differences %>%
  inner_join(peak_weeks, by = "week_start") %>%
  group_by(week_start) %>%
  mutate(
    iso_week = format(week_start, "%G-KW%V"),
    gap_between_types = max(type_median) - min(type_median)
  ) %>%
  ungroup() %>%
  arrange(week_start, desc(difference)) %>%
  select(
    iso_week, kreistyp_name, type_median, national_median,
    difference, MAE, gap_between_types
  )

print(peak_week_details, n = Inf, width = Inf)

library(dplyr)
library(ggplot2)

selected_week <- "2022-KW11"

peak_plot_data <- valid_weeks %>%
  filter(
    format(week_start, "%G-KW%V") == selected_week,
    kreistyp_name %in% names(district_colors)
  ) %>%
  mutate(
    kreistyp_name = factor(kreistyp_name, levels = names(district_colors))
  )

peak_labels <- peak_week_details %>%
  filter(iso_week == selected_week)

format_number <- scales::label_number(
  accuracy = 1, big.mark = ".", decimal.mark = ","
)

peak_week_plot <- ggplot(
  peak_plot_data,
  aes(x = kreistyp_name, y = incidence)
) +
  geom_boxplot(
    width = 0.45,
    fill = "white",
    colour = "#475569",
    outlier.shape = NA
  ) +
  geom_point(
    aes(fill = kreistyp_name),
    position = position_jitter(width = 0.15, height = 0, seed = 11),
    shape = 21,
    colour = "#475569",
    stroke = 0.2,
    size = 1.7,
    alpha = 0.6
  ) +
  geom_hline(
    yintercept = peak_labels$national_median[1],
    colour = "#475569",
    linetype = "dashed",
    linewidth = 0.55
  ) +
  geom_point(
    data = peak_labels,
    aes(y = type_median, fill = kreistyp_name),
    shape = 23,
    colour = "#334155",
    size = 3.6
  ) +
  geom_label(
    data = peak_labels,
    aes(y = type_median, label = sprintf("%+.0f", difference)),
    nudge_x = 0.30,
    hjust = 0,
    size = 3.5,
    fill = "white",
    colour = "#1E293B"
  ) +
  scale_fill_manual(values = district_colors, guide = "none") +
  scale_x_discrete(
    labels = scales::label_wrap(23),
    expand = expansion(add = c(0.6, 0.85))
  ) +
  scale_y_continuous(labels = format_number) +
  labs(
    title = "COVID-19-Meldeinzidenz nach Kreistyp",
    subtitle = paste0(
      selected_week, " · Bundesweiter Median der Kreiswerte: ",
      format_number(peak_labels$national_median[1])
    ),
    x = NULL,
    y = "Gemeldete Fälle je 100.000 Einwohner",
    caption = paste(
      "Punkt = Kreis · Raute = Median des Kreistyps",
      "Zahl = Differenz zum bundesweiten Median",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(hjust = 0)
  )

print(peak_week_plot)
