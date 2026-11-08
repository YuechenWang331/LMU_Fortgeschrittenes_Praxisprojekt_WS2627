# Put both RDS files and kreis_urban_rural.csv in the working directory.
# CSV columns: geo_code,urban_rural (values: urban or rural).
# install.packages(c("data.table", "ggplot2"))

library(data.table)
library(ggplot2)

years <- 2020:2024
age_breaks <- c(0, 5, 15, 20, 40, 65, 80, Inf)
age_labels <- c("0–4", "5–14", "15–19", "20–39", "40–64", "65–79", "80+")
key <- c("geo_code", "year", "age")

county_code <- function(x) {
  x <- trimws(as.character(x))
  valid <- !is.na(x) & grepl("^[0-9]{1,5}$", x)
  result <- rep(NA_character_, length(x))
  result[valid] <- sprintf("%05d", as.integer(x[valid]))
  result
}

if (!file.exists("kreis_urban_rural.csv")) {
  stop("Missing kreis_urban_rural.csv. Supply geo_code and urban_rural (urban/rural).")
}
regions <- fread("kreis_urban_rural.csv", colClasses = "character")
stopifnot(all(c("geo_code", "urban_rural") %in% names(regions)))
regions[, geo_code := county_code(geo_code)]
regions[, urban_rural := tolower(trimws(urban_rural))]
stopifnot(!anyNA(regions$geo_code), !anyDuplicated(regions$geo_code),
          all(regions$urban_rural %in% c("urban", "rural")))

weekly <- as.data.table(readRDS("rki_weekly_long.rds"))
population <- as.data.table(readRDS("rki_population_annual.rds"))
weekly <- weekly[iso_year %in% years, .(geo_code, year = as.integer(iso_year),
                                        age = as.character(age_group), count)]
population <- population[year %in% years, .(geo_code, year = as.integer(year),
                                             age = as.character(age_group), population)]
known_ages <- c(as.character(0:79), "80+")
message("Excluded report counts with unknown or unsupported age: ",
        weekly[!age %chin% known_ages, sum(count, na.rm = TRUE)])
weekly <- weekly[age %chin% known_ages]
population <- population[age %chin% known_ages]
weekly[, geo_code := county_code(geo_code)]
population[, geo_code := county_code(geo_code)]
stopifnot(nrow(weekly) > 0L, nrow(population) > 0L,
          !anyNA(weekly$geo_code), !anyNA(population$geo_code))
if (anyDuplicated(population, by = key)) stop("Duplicate population keys.")

annual <- weekly[, .(cases = sum(count)), by = key]
rm(weekly)
missing_population <- annual[!population, on = key]
missing_cases <- population[!annual, on = key]
if (nrow(missing_population) || nrow(missing_cases)) {
  print(head(missing_population))
  print(head(missing_cases))
  stop("Unmatched county/year/age keys. Check the source coverage before aggregating.")
}
data <- merge(annual, population, by = key)
if (any(!is.finite(data$cases) | !is.finite(data$population) | data$population < 0 |
        (data$population == 0 & data$cases != 0))) {
  stop("Missing counts or invalid population denominators.")
}

missing_regions <- setdiff(unique(data$geo_code), regions$geo_code)
if (length(missing_regions)) {
  stop("Missing urban/rural classification for: ", paste(missing_regions, collapse = ", "))
}
data <- merge(data, regions[, .(geo_code, urban_rural)], by = "geo_code")
data[, age_group := cut(as.integer(sub("+", "", age, fixed = TRUE)),
                       breaks = age_breaks, labels = age_labels, right = FALSE)]
summary <- data[, .(cases = sum(cases), population = sum(population)),
                by = .(year, urban_rural, age_group)]
stopifnot(all(summary$population > 0))
summary[, cases_per_100k := 1e5 * cases / population]
setorder(summary, year, age_group, urban_rural)

pairs <- dcast(summary, year + age_group ~ urban_rural, value.var = "cases_per_100k")
stopifnot(all(c("urban", "rural") %in% names(pairs)),
          !anyNA(pairs$urban), !anyNA(pairs$rural),
          nrow(pairs) == length(years) * length(age_labels))
pairs[, urban_minus_rural := urban - rural]
fwrite(summary, "covid_age_urban_rural_summary.csv")
fwrite(pairs, "covid_age_urban_rural_difference.csv")

plot <- ggplot(summary, aes(x = cases_per_100k, y = age_group)) +
  geom_segment(data = pairs, aes(x = rural, xend = urban, yend = age_group),
               colour = "grey65") +
  geom_point(aes(colour = urban_rural), size = 2.5) +
  facet_wrap(~year, ncol = 3) +
  scale_y_discrete(limits = rev(age_labels)) +
  scale_colour_manual(values = c(urban = "#0072B2", rural = "#D55E00"),
                      breaks = c("urban", "rural"),
                      labels = c("Städtisch", "Ländlich")) +
  labs(title = "COVID-19-Meldeinzidenz nach Altersgruppe und Kreistyp",
       subtitle = "2020–2024 · Zuordnung der Meldewochen nach ISO-Jahr",
       x = "Gemeldete Fälle je 100.000 Einwohner", y = "Altersgruppe",
       colour = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
ggsave("covid_age_urban_rural_dumbbell.png", plot, width = 12, height = 7, dpi = 300)
print(plot)
