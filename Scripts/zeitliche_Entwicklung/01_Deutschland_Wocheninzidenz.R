# National weekly incidence, known ages, 2020-2023.
# Run from the project root:
# source("Scripts/zeitliche_Entwicklung/01_Deutschland_Wocheninzidenz.R")

library(data.table)
library(ggplot2)

processed_dir <- "data_processed/zeitliche_Entwicklung"
output_dir <- "results/zeitliche_entwicklung"
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

w <- as.data.table(readRDS("data_processed/rki_weekly_long.rds"))[iso_year %in% 2020:2023]
p <- as.data.table(readRDS("data_processed/rki_population_annual.rds"))[year %in% 2020:2023]
# Preserve the known-age population and the original 99% cell-coverage rule.
known <- merge(w[!is.na(age_group) & age_group != "NA"], p,
               by.x = c("geo_code", "age_group", "iso_year"),
               by.y = c("geo_code", "age_group", "year"), all.x = TRUE, sort = FALSE)
weekly <- known[is.finite(count) & count >= 0 & is.finite(population) & population > 0,
                .(cases = sum(count), population = sum(population), usable_cells = .N),
                by = .(iso_year, week_start)]
weekly[, `:=`(incidence = 1e5 * cases / population,
               coverage = usable_cells / (uniqueN(w$geo_code) * 81L))]
weekly <- weekly[is.finite(incidence) & coverage >= 0.99]
setorder(weekly, week_start)

saveRDS(weekly, file.path(processed_dir, "01_Deutschland_Wocheninzidenz.rds"))

plot <- ggplot(weekly, aes(x = week_start, y = incidence)) +
  geom_line(color = "#265A84", linewidth = 0.65) +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  labs(
    title = "COVID-19: Wöchentliche Inzidenz in Deutschland",
    subtitle = "Alle bekannten Altersgruppen, 2020–2023 ",
    x = "Woche",
    y = "Gemeldete Fälle je 100.000 / Woche"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom")

ggsave(
  file.path(output_dir, "01_Deutschland_gesamt.png"),
  plot,
  width = 11,
  height = 5.2,
  dpi = 180
)
