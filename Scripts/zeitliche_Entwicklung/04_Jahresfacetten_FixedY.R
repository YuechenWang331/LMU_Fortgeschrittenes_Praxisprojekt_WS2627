# Annual weekly-case facets with shared y scales.
# Run from the project root:
# source("Scripts/zeitliche_Entwicklung/04_Jahresfacetten_FixedY.R")

library(data.table)
library(ggplot2)

processed_dir <- "data_processed/zeitliche_Entwicklung"
output_dir <- "results/zeitliche_entwicklung"
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

w <- as.data.table(readRDS("data_processed/rki_weekly_long.rds"))
weekly_total <- w[iso_year %in% 2020:2023, .(weekly_cases = sum(count)),
                  by = .(iso_year, iso_week, week_start)]
setorder(weekly_total, week_start)
peak_weeks <- weekly_total[, .SD[which.max(weekly_cases)], by = iso_year]

saveRDS(
  list(weekly_total = weekly_total, peak_weeks = peak_weeks),
  file.path(processed_dir, "04_Jahresfacetten_FixedY.rds")
)

plot <- ggplot(weekly_total, aes(x = iso_week, y = weekly_cases)) +
  geom_line(color = "#215E83", linewidth = 0.9) +
  geom_point(data = peak_weeks, color = "#B34B3C", size = 2) +
  scale_x_continuous(breaks = c(1, 13, 26, 39, 52), limits = c(1, 53)) +
  scale_y_continuous(
    labels = function(values) format(round(values), big.mark = ".", scientific = FALSE, trim = TRUE),
    expand = expansion(mult = c(0, 0.06))
  ) +
  labs(title = "Gemeldete COVID-19-Fälle nach Jahr", x = "Woche", y = "Gemeldete Fälle pro Woche") +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank()) +
  facet_wrap(~iso_year, scales = "fixed", ncol = 2) +
  labs(subtitle = paste("Einheitliche y-Skala:", "direkter Vergleich der Wochenfallzahlen"))

ggsave(
  filename = file.path(output_dir, "Zeitverlauf_Jahresfacetten_FixedY.png"),
  plot = plot,
  width = 12,
  height = 8,
  dpi = 200
)
