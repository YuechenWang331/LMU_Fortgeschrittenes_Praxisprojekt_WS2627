library(data.table)
library(ggplot2)

# Run this script from the project root.
input_dir <- "Scripts/age_group/data"
figure_dir <- "Scripts/age_group/figures"
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

age_weekly_incidence <- as.data.table(readRDS(
  file.path(input_dir, "age_weekly_incidence.rds")
))

# Summarize the weekly national incidence for each age and year.
age_incidence_by_year <- age_weekly_incidence[
  !is.na(age),
  .(
    median_incidence = median(incidence),
    q25 = as.numeric(quantile(incidence, 0.25)),
    q75 = as.numeric(quantile(incidence, 0.75))
  ),
  by = .(iso_year, age)
]
setorder(age_incidence_by_year, iso_year, age)

p_age_by_year <- ggplot(age_incidence_by_year, aes(x = age)) +
  geom_ribbon(aes(ymin = q25, ymax = q75), fill = "#287C79", alpha = 0.2) +
  geom_line(aes(y = median_incidence), color = "#287C79", linewidth = 0.8) +
  facet_wrap(~ iso_year, scales = "free_y") +
  scale_x_continuous(breaks = seq(0, 79, 10)) +
  labs(
    title = "Weekly COVID-19 Incidence by Age and Year",
    subtitle = "Weekly national incidence: median and interquartile range",
    x = "Age (years)",
    y = "7-day incidence per 100,000"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path(figure_dir, "age_incidence_by_year.png"),
       p_age_by_year, width = 10, height = 6, dpi = 300)

# Summarize the weekly national incidence over 2020–2023.
age_incidence_all_years <- age_weekly_incidence[
  !is.na(age),
  .(
    median_incidence = median(incidence),
    q25 = as.numeric(quantile(incidence, 0.25)),
    q75 = as.numeric(quantile(incidence, 0.75))
  ),
  by = age
]
setorder(age_incidence_all_years, age)

p_age_all_years <- ggplot(age_incidence_all_years, aes(x = age)) +
  geom_ribbon(aes(ymin = q25, ymax = q75), fill = "#287C79", alpha = 0.2) +
  geom_line(aes(y = median_incidence), color = "#287C79", linewidth = 0.8) +
  scale_x_continuous(breaks = seq(0, 79, 5)) +
  labs(
    title = "Weekly COVID-19 Incidence by Age (2020–2023)",
    subtitle = "Weekly national incidence: median and interquartile range",
    x = "Age (years)",
    y = "7-day incidence per 100,000"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path(figure_dir, "age_incidence_all_years.png"),
       p_age_all_years, width = 10, height = 6, dpi = 300)

print(p_age_by_year)
print(p_age_all_years)

