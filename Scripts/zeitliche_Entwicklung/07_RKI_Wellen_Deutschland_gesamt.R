# National weekly incidence with the existing RKI waves 1-5 in color.
# Run from the project root:
# source("Scripts/zeitliche_Entwicklung/07_RKI_Wellen_Deutschland_gesamt.R")

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

# Existing RKI boundaries: Epidemiological Bulletin 38/2022, Table 1 (15 September 2022).
# https://edoc.rki.de/bitstream/handle/176904/10260/EB-38-2022-Phaseneinteilung.pdf?sequence=1
rki_waves <- data.table(
  wave = 1:5,
  start_date = as.Date(c("2020-03-02", "2020-09-28", "2021-03-01", "2021-08-02", "2021-12-27")),
  end_date = as.Date(c("2020-05-17", "2021-02-28", "2021-06-13", "2021-12-26", "2022-05-29"))
)
rki_waves[, wave := factor(paste0("W", wave), levels = paste0("W", 1:5))]
rki_waves[, label_date := as.Date((as.numeric(start_date) + as.numeric(end_date)) / 2,
                                 origin = "1970-01-01")]
wave_colors <- c(W1 = "#0072B2", W2 = "#E69F00", W3 = "#009E73", W4 = "#CC79A7", W5 = "#D55E00")
wave_lines <- rbindlist(lapply(seq_len(nrow(rki_waves)), function(i) {
    current <- rki_waves[i]
    points <- weekly[week_start >= current$start_date & week_start <= current$end_date]
    points[, `:=`(wave, current$wave)]
    points
}))
wave_lines[, wave := factor(as.character(wave), levels = levels(rki_waves$wave))]
y_max <- max(weekly$incidence)
rki_waves[, label_y := 1.115 * y_max]
y_upper <- 1.24 * y_max

saveRDS(
  list(weekly = weekly, rki_waves = rki_waves, wave_lines = wave_lines),
  file.path(processed_dir, "07_RKI_Wellen_Deutschland_gesamt.rds")
)

plot <- ggplot(weekly, aes(x = week_start, y = incidence)) +
  geom_rect(
    data = rki_waves,
    aes(xmin = start_date, xmax = end_date, ymin = -Inf, ymax = Inf, fill = wave),
    inherit.aes = FALSE,
    alpha = 0.13,
    color = NA
  ) +
  geom_line(color = "#82909A", linewidth = 0.65, na.rm = TRUE) +
  geom_line(
    data = wave_lines,
    aes(color = wave, group = wave),
    linewidth = 1.05,
    show.legend = TRUE
  ) +
  geom_label(
    data = rki_waves,
    aes(x = label_date, y = label_y, label = wave, color = wave),
    inherit.aes = FALSE,
    size = 4.2,
    fontface = "bold",
    fill = "white",
    label.size = 0,
    label.padding = grid::unit(0.22, "lines"),
    show.legend = FALSE
  ) +
  scale_color_manual(values = wave_colors, limits = names(wave_colors), name = "RKI-Welle") +
  scale_fill_manual(values = wave_colors, guide = "none") +
  scale_x_date(
    date_breaks = "3 months",
    date_labels = "%m/%Y",
    expand = expansion(mult = c(0.005, 0.005))
  ) +
  scale_y_continuous(
    limits = c(0, y_upper),
    labels = function(x) format(round(x), big.mark = ".", scientific = FALSE, trim = TRUE),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = "Gemeldete COVID-19-Fälle und RKI-Welleneinteilung",
    subtitle = "RKI-Wellen 1-5 farbig hervorgehoben; uebriger Zeitverlauf grau",
    x = "Woche",
    y = "Gemeldete Fälle je 100.000 Einwohner / Woche"
  ) +
  guides(color = guide_legend(nrow = 1, override.aes = list(linewidth = 2))) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(face = "bold", size = 15),
    legend.position = "bottom",
    plot.caption = element_text(size = 8, hjust = 0),
    plot.margin = margin(14, 18, 12, 12)
  )

ggsave(
  file.path(output_dir, "RKI_Wellen_Deutschland_gesamt_Farben.png"),
  plot = plot,
  width = 14,
  height = 7,
  dpi = 220
)
