# Annual reported-case totals with the original value labels.
# Run from the project root:
# source("Scripts/zeitliche_Entwicklung/09_Jahressummen_mit_Zahlen.R")

library(data.table)
library(ggplot2)

processed_dir <- "data_processed/zeitliche_Entwicklung"
output_dir <- "results/zeitliche_entwicklung"
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

w <- as.data.table(readRDS("data_processed/rki_weekly_long.rds"))
annual <- w[iso_year %in% 2020:2023, .(total_reported_cases = sum(count)), by = iso_year]
setorder(annual, iso_year)
format_de <- function(x) {
    format(round(x), big.mark = ".", scientific = FALSE, trim = TRUE)
}
annual[, total_label := format_de(total_reported_cases)]

saveRDS(annual, file.path(processed_dir, "09_Jahressummen_mit_Zahlen.rds"))

plot <- ggplot(annual, aes(x = factor(iso_year), y = total_reported_cases)) +
  geom_col(fill = "#215E83", width = 0.65) +
  geom_text(
    aes(label = total_label),
    vjust = -0.65,
    size = 4.7,
    fontface = "bold",
    color = "#233B4C"
  ) +
  scale_y_continuous(labels = format_de, expand = expansion(mult = c(0, 0.16))) +
  labs(
    title = "Gesamte gemeldete COVID-19-Faelle pro ISO-Jahr",
    subtitle = "Exakte Jahressummen der gemeldeten Wochenfaelle",
    x = "ISO-Meldejahr",
    y = "Gemeldete Faelle insgesamt"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), plot.caption = element_text(size = 9))

ggsave(
  file.path(output_dir, "Zeitverlauf_Jahressummen_mit_Zahlen.png"),
  plot = plot,
  width = 10.5,
  height = 6.5,
  dpi = 220
)
