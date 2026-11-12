# Weekly case counts with the original annual ISO-week peak labels.
# Run from the project root:
# source("Scripts/zeitliche_Entwicklung/08_Wochenfaelle_Peaks_KW.R")

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
format_de <- function(x) {
    format(round(x), big.mark = ".", scientific = FALSE, trim = TRUE)
}
peaks <- weekly_total[, .SD[which.max(weekly_cases)], by = iso_year]
peaks[, kw_label := sprintf("KW %02d/%d", iso_week, iso_year)]

saveRDS(
  list(weekly_total = weekly_total, peaks = peaks),
  file.path(processed_dir, "08_Wochenfaelle_Peaks_KW.rds")
)

plot <- ggplot(weekly_total, aes(x = week_start, y = weekly_cases)) +
  geom_line(color = "#215E83", linewidth = 0.8) +
  geom_point(data = peaks, color = "#B34B3C", size = 2.8) +
  geom_label(
    data = peaks,
    aes(label = kw_label),
    color = "#973E32",
    fill = "white",
    size = 3.6,
    fontface = "bold",
    vjust = -0.75,
    label.size = 0.2,
    show.legend = FALSE
  ) +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  scale_y_continuous(labels = format_de, expand = expansion(mult = c(0.02, 0.18))) +
  labs(
    title = "Gemeldete COVID-19-Fälle in Deutschland, 2020-2023",
    subtitle = "Wochenfallzahlen nach Woche; Jahresmaxima mit Kalenderwoche",
    x = "Woche",
    y = "Gemeldete Fälle pro Woche"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), plot.caption = element_text(size = 9))

ggsave(
  file.path(output_dir, "Zeitverlauf_Wochenfaelle_Peaks_KW.png"),
  plot = plot,
  width = 12.5,
  height = 6.2,
  dpi = 220
)
