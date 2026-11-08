library(data.table)
library(ggplot2)

# Run this script from the project root.
input_dir <- "Scripts/age_group/data"
figure_dir <- "Scripts/age_group/figures"
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

age_weekly_incidence <- as.data.table(readRDS(
  file.path(input_dir, "age_weekly_incidence.rds")
))
scheme_weekly_incidence <- as.data.table(readRDS(
  file.path(input_dir, "scheme_weekly_incidence.rds")
))
age_scheme_lookup <- as.data.table(readRDS(
  file.path(input_dir, "age_scheme_lookup.rds")
))

# Calculate annual median weekly incidence for individual ages.
age_incidence_by_year <- age_weekly_incidence[
  !is.na(age),
  .(median_incidence = median(incidence)),
  by = .(iso_year, age)
]
setorder(age_incidence_by_year, iso_year, age)

# Identify the age span of each candidate group.
scheme_boundaries <- age_scheme_lookup[
  age_group != "80+",
  .(age = as.integer(age_group)),
  by = .(scheme, age_group_new)
][, .(
  group_start = min(age),
  group_end = max(age)
), by = .(scheme, age_group_new)]

# Summarize grouped incidence and attach the age boundaries.
scheme_incidence_by_year <- scheme_weekly_incidence[
  age_group_new != "80+",
  .(median_incidence = median(incidence)),
  by = .(scheme, iso_year, age_group_new)
]
scheme_incidence_by_year <- merge(
  scheme_incidence_by_year,
  scheme_boundaries,
  by = c("scheme", "age_group_new"),
  all.x = TRUE
)
scheme_incidence_by_year[, scheme := factor(
  scheme, levels = c("5-year", "10-year", "broad")
)]

# Compare individual ages with the candidate group summaries.
p_compare_schemes <- ggplot() +
  geom_line(
    data = age_incidence_by_year,
    aes(x = age, y = median_incidence),
    color = "grey65", linewidth = 0.7
  ) +
  geom_segment(
    data = scheme_incidence_by_year,
    aes(x = group_start, xend = group_end,
        y = median_incidence, yend = median_incidence),
    color = "#176B69", linewidth = 1.4
  ) +
  facet_grid(iso_year ~ scheme, scales = "free_y") +
  scale_x_continuous(breaks = seq(0, 79, 10), limits = c(0, 79)) +
  labs(
    title = "Comparison of Candidate Age Groupings",
    subtitle = "Median weekly national incidence: individual ages vs. grouped ages",
    x = "Age (years)",
    y = "Median weekly 7-day incidence per 100,000"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

ggsave(file.path(figure_dir, "compare_age_schemes.png"),
       p_compare_schemes, width = 12, height = 10, dpi = 300)
print(p_compare_schemes)

# Summarize weekly incidence across all four years.
age_incidence_all_years <- age_weekly_incidence[
  !is.na(age),
  .(median_incidence = median(incidence, na.rm = TRUE)),
  by = age
]
setorder(age_incidence_all_years, age)

scheme_incidence_all_years <- scheme_weekly_incidence[
  age_group_new != "80+",
  .(median_incidence = median(incidence, na.rm = TRUE)),
  by = .(scheme, age_group_new)
]
scheme_incidence_all_years <- merge(
  scheme_incidence_all_years,
  scheme_boundaries,
  by = c("scheme", "age_group_new"),
  all.x = TRUE
)
scheme_incidence_all_years[, scheme := factor(
  scheme, levels = c("5-year", "10-year", "broad")
)]

# Compare individual ages with grouped ages for 2020-2023 combined.
p_compare_schemes_all_years <- ggplot() +
  geom_line(
    data = age_incidence_all_years,
    aes(x = age, y = median_incidence),
    color = "grey65", linewidth = 0.7
  ) +
  geom_segment(
    data = scheme_incidence_all_years,
    aes(x = group_start, xend = group_end,
        y = median_incidence, yend = median_incidence),
    color = "#176B69", linewidth = 1.4
  ) +
  facet_wrap(~ scheme, nrow = 1) +
  scale_x_continuous(breaks = seq(0, 79, 10), limits = c(0, 79)) +
  labs(
    title = "Comparison of Candidate Age Groupings (2020–2023)",
    subtitle = "Median weekly national incidence: individual ages vs. grouped ages",
    x = "Age (years)",
    y = "Median weekly 7-day incidence per 100,000"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

ggsave(file.path(figure_dir, "compare_age_schemes_all_years.png"),
       p_compare_schemes_all_years, width = 12, height = 5, dpi = 300)
print(p_compare_schemes_all_years)
