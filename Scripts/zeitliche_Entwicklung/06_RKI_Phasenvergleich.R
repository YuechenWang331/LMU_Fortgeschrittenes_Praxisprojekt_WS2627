# Reported weekly cases with the existing RKI waves and the W6 start marker.
# Run from the project root:
# source("Scripts/zeitliche_Entwicklung/06_RKI_Phasenvergleich.R")

library(data.table)
library(ggplot2)

processed_dir <- "data_processed/zeitliche_Entwicklung"
output_dir <- "results/zeitliche_entwicklung"
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

w <- as.data.table(readRDS("data_processed/rki_weekly_long.rds"))
weekly_cases <- w[iso_year %in% 2020:2023, .(weekly_cases = sum(count)),
                  by = .(iso_year, iso_week, week_start)]
setorder(weekly_cases, week_start)

# Existing RKI boundaries: Epidemiological Bulletin 38/2022, Table 1 (15 September 2022).
# https://edoc.rki.de/bitstream/handle/176904/10260/EB-38-2022-Phaseneinteilung.pdf?sequence=1
rki_waves <- data.table(
  wave = 1:5,
  start_date = as.Date(c("2020-03-02", "2020-09-28", "2021-03-01", "2021-08-02", "2021-12-27")),
  end_date = as.Date(c("2020-05-17", "2021-02-28", "2021-06-13", "2021-12-26", "2022-05-29"))
)
parts <- rbindlist(lapply(2020:2023, function(year) {
  year_data <- weekly_cases[iso_year == year]
  rki_waves[, .(iso_year = year, wave,
                xmin = pmax(start_date, min(year_data$week_start)),
                xmax = pmin(end_date, max(year_data$week_start) + 6))]
}))[xmin <= xmax]
parts[, midpoint := as.Date((as.numeric(xmin) + as.numeric(xmax)) / 2, origin = "1970-01-01")]
# The W6 start marker belongs only to the 2022 facet; its end remains undefined.
wave6_marker <- weekly_cases[iso_year == 2022L & iso_week == 22L,
                             .(iso_year, marker_date = week_start)]

saveRDS(
  list(
    weekly_cases = weekly_cases,
    rki_waves = rki_waves,
    parts = parts,
    wave6_marker = wave6_marker
  ),
  file.path(processed_dir, "06_RKI_Phasenvergleich.rds")
)

plot <- ggplot(weekly_cases, aes(x = week_start, y = weekly_cases)) +
  geom_rect(
    data = parts,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
    inherit.aes = FALSE,
    fill = "#B7D3E4",
    alpha = 0.4
  ) +
  geom_line(color = "#215E83", linewidth = 0.75) +
  geom_text(
    data = parts,
    aes(x = midpoint, y = Inf, label = paste0("W", wave)),
    inherit.aes = FALSE,
    vjust = 1.2,
    size = 3,
    color = "#34495E"
  ) +
  geom_vline(
    data = wave6_marker,
    aes(xintercept = as.numeric(marker_date)),
    inherit.aes = FALSE,
    linetype = "dashed",
    color = "#B34B3C"
  ) +
  facet_wrap(~iso_year, scales = "free", ncol = 2) +
  scale_x_date(date_breaks = "3 months", date_labels = "%m/%y") +
  scale_y_continuous(
    labels = function(x) format(round(x), big.mark = ".", scientific = FALSE, trim = TRUE)
  ) +
  labs(
    title = "Gemeldete COVID-19-Fälle und RKI-Welleneinteilung",
    subtitle = paste(
      "Schattiert: Wellen 1-5 gemaess RKI (Stand 15.09.2022).",
      "Gestrichelte Linie: Beginn der sechsten Welle (KW 22/2022)."
    ),
    x = "Woche",
    y = "Gemeldete Fälle pro Woche"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 35, hjust = 1),
    plot.caption = element_text(size = 8)
  )

ggsave(
  file.path(output_dir, "RKI_Phasen_Zeitverlauf_2020_2023.png"),
  plot = plot,
  width = 13,
  height = 8,
  dpi = 200
)
