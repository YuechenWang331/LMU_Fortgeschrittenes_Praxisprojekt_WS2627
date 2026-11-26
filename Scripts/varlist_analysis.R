suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(ggplot2)
  library(readxl)
})

project_root <- "/Users/hilal/Desktop/LMU_Fortgeschrittenes_Praxisprojekt_WS2627"

population <- read.csv(file.path(project_root, "data_raw", "Count_Bev_LK_RKI_2020_2024.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
weekly_case_incidence <- readRDS(file.path(project_root, "data_processed", "rki_weekly_long.rds"))
monthly_case_incidence <- readRDS(file.path(project_root, "data_processed", "rki_monthly_long.rds"))

geo_info <- read.csv(file.path(project_root,"data_raw/CountyKey71Map.csv"),colClasses = "character",stringsAsFactors = FALSE,fileEncoding = "UTF-8")
raumtypen <- read.csv2(file.path(project_root, "data_raw", "raumtypen-lage-2020.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "Windows-1252")
kreistypen <- read.csv2(file.path(project_root, "data_raw", "siedlungsstrukt-kreistypen-2020.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "Windows-1252")

einpendelnde2021 <- read.csv2(file.path(project_root, "data_raw", "einpendelnde21_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
einpendelnde2022 <- read.csv2(file.path(project_root, "data_raw", "einpendelnde22_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
einpendelnde2023 <- read.csv2(file.path(project_root, "data_raw", "einpendelnde23_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
einpendelnde <- bind_rows(
  "2021" = einpendelnde2021,
  "2022" = einpendelnde2022,
  "2023" = einpendelnde2023,
  .id = "time")

auspendelnde2021 <- read.csv2(file.path(project_root, "data_raw", "auspendelnde21_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
auspendelnde2022 <- read.csv2(file.path(project_root, "data_raw", "auspendelnde22_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
auspendelnde2023 <- read.csv2(file.path(project_root, "data_raw", "auspendelnde23_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
auspendelnde <- bind_rows(
  "2021" = auspendelnde2021,
  "2022" = auspendelnde2022,
  "2023" = auspendelnde2023,
  .id = "time")

beschaeftigte <- read.csv2(file.path(project_root, "data_raw", "beschaeftigte_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
arbeitslose <- read.csv2(file.path(project_root, "data_raw", "arbeitslose_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
tourismus <- read.csv2(file.path(project_root, "data_raw", "tourismus_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
schutzsuchende <- read.csv2(file.path(project_root, "data_raw", "schutzsuchende_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
tageseinrichtungen <- read.csv2(file.path(project_root, "data_raw", "tageseinrichtungen_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
pflegestat <- read.csv2(file.path(project_root, "data_raw", "pflegestat_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
abschlusse <- read.csv2(file.path(project_root, "data_raw", "abschlusse_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
grundsicherung <- read.csv2(file.path(project_root, "data_raw", "grundsicherung_flat.csv"), stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")

genesis_datasets <- c("einpendelnde", "auspendelnde", "beschaeftigte", "arbeitslose", "tourismus", "schutzsuchende", "tageseinrichtungen", "pflegestat", "abschlusse", "grundsicherung")

names(geo_info)[names(geo_info) == "Name"] <- "geo_name"
names(geo_info)[names(geo_info) == "ComponentId"] <- "geo_code"
geo_info$geo_code <- gsub("\\[|\\]", "", geo_info$geo_code)

for (name in genesis_datasets) {
  assign(name,
         get(name) %>%
           rename(geo_name = `1_variable_attribute_label`) %>%
           rename(geo_code = `1_variable_attribute_code`) %>%
           rename(iso_year = time) %>%
           mutate(iso_year = str_sub(as.character(iso_year), 1, 4))
  )
}

for (name in c("kreistypen", "raumtypen")) {
  assign(name,
         get(name) %>%
           rename(geo_name = `Kreise (2020) Name`) %>%
           mutate(
             geo_name = str_trim(str_remove(geo_name, ",.*")),
             geo_prefix = str_sub(`Kreise (2020) Kennziffer`, 1, 4)) %>%
           left_join(
             geo_info %>%
               mutate(geo_suffix = str_sub(as.character(geo_code), -4, -1)) %>%
               select(geo_name, geo_code, geo_suffix),
             by = "geo_name",
             relationship = "many-to-many") %>%
           filter(is.na(geo_code) | geo_prefix == geo_suffix) %>%
           select(-geo_prefix, -geo_suffix) %>%
           group_by(`Kreise (2020) Kennziffer`) %>%
           slice(1) %>%
           ungroup()
  )
  # Fallback: search for Landkreis + geo_name
  missing <- get(name) %>%
    filter(is.na(geo_code)) %>%
    mutate(
      lookup_name = paste("Landkreis", geo_name)) %>%
    select(`Kreise (2020) Kennziffer`, lookup_name)
  fallback <- missing %>%
    left_join(
      geo_info %>%
        select(geo_name, geo_code),
      by = c("lookup_name" = "geo_name")) %>%
    select(`Kreise (2020) Kennziffer`, geo_code)
  assign(name,
         get(name) %>%
           select(-geo_code) %>%
           left_join(fallback, by = "Kreise (2020) Kennziffer")
  )
}


for (name in c("weekly_case_incidence", "monthly_case_incidence")) {
  assign(name,
         get(name) %>%
           left_join(
             geo_info %>%
               select(geo_code, geo_name) %>%
               distinct(),
             by = "geo_code")
  )
}

yearly_case_incidence <- monthly_case_incidence %>%
  group_by(geo_code, geo_name, age_group, year) %>%
  summarise(
    count = sum(count, na.rm = TRUE),
    incidence = sum(incidence, na.rm = TRUE),
    .groups = "drop")

names(population)[names(population) == ""] <- "id"
population$geo_name <- sub("^(LK|SK) ", "", population$geo_name)
population <- population %>% rename(iso_year = year)

# ------------------------------------------------------------------------------
# 33. Kreisebene: Zusammenhang zwischen Strukturmerkmalen und COVID-19-Fällen
# ------------------------------------------------------------------------------

normalize_geo_name <- function(x) {
  # This normalizes spelling and administrative suffixes so names can be matched
  # consistently across the cleaned GENESIS tables and the CountyKey table.
  y <- str_squish(str_to_lower(as.character(x)))
  y <- str_replace_all(y, c("ß" = "ss", "ä" = "ae", "ö" = "oe", "ü" = "ue"))
  y <- str_replace_all(y, "[^[:alnum:] ]", " ")
  y <- str_squish(y)
  y <- str_remove(y, "^(landkreis |kreis |stadt |statistische region )")
  y <- str_remove(y, "( kreisfreie stadt| landeshauptstadt| kreisstadt| landkreis| kreis| stadtkreis| stadt| statistische region| regierungsbezirk)$")
  str_squish(y)
}

# The lookup table supplies one official 5-digit geo_code for every cleaned name.
# It deliberately uses geo_info, which was already prepared and harmonized above.
geo_lookup <- geo_info %>%
  transmute(
    geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
    geo_name = str_squish(as.character(geo_name)),
    match_name = normalize_geo_name(geo_name)
  ) %>%
  filter(grepl("^[0-9]{5}$", geo_code), !is.na(match_name), match_name != "") %>%
  distinct(match_name, geo_code)

# Aggregate monthly RKI observations to one annual case count per Kreis.
# age_group is intentionally summed first across groups; the year is 2020–2023.
annual_cases <- yearly_case_incidence %>%
  transmute(
    geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
    year = as.integer(year),
    cases = as.numeric(count)
  ) %>%
  filter(grepl("^[0-9]{5}$", geo_code), year %in% 2020:2023) %>%
  group_by(geo_code, year) %>%
  summarise(cases = sum(cases, na.rm = TRUE), .groups = "drop")

# Population is aggregated to annual Kreis totals because the structural data
# is annual and the incidence denominator must not be pooled across age groups.
annual_population <- population %>%
  mutate(
    match_name = normalize_geo_name(geo_name),
    year = suppressWarnings(as.integer(iso_year)),
    population = suppressWarnings(as.numeric(population))
  ) %>%
  inner_join(geo_lookup, by = "match_name", relationship = "many-to-many") %>%
  filter(year %in% 2020:2023, !is.na(population)) %>%
  group_by(geo_code, year) %>%
  summarise(population = sum(population, na.rm = TRUE), .groups = "drop")

# Combine cases and population. cases_per_100k is a standardized outcome that
# makes large and small Kreise comparable.
kreis_outcomes <- annual_cases %>%
  left_join(annual_population, by = c("geo_code", "year")) %>%
  mutate(cases_per_100k = if_else(population > 0, 100000 * cases / population, NA_real_))

# Convert German-formatted numeric strings where necessary.
parse_de_number <- function(x) {
  suppressWarnings(as.numeric(str_replace_all(
    str_squish(as.character(x)),
    c("\\." = "", "," = "\\.", " " = "", "-" = NA_character_)
  )))
}

extract_structural_variable <- function(df, dataset_name) {
  # Only data frames already cleaned above are accepted. The required columns
  # are the cleaned geo_name, iso_year, and value columns.
  if (!all(c("geo_name", "iso_year", "value") %in% names(df))) return(tibble::tibble())

  d <- df %>%
    mutate(
      match_name = normalize_geo_name(geo_name),
      year = suppressWarnings(as.integer(iso_year)),
      value_num = parse_de_number(value)
    ) %>%
    # geo_code is removed from the cleaned table before joining. This prevents
    # duplicate geo_code.x/geo_code.y columns and keeps one official Kreis key.
    select(-any_of("geo_code")) %>%
    inner_join(geo_lookup, by = "match_name", relationship = "many-to-many") %>%
    filter(year %in% 2020:2023, !is.na(value_num))

  if (nrow(d) == 0) return(tibble::tibble())

  # If a category table contains an explicit total/overall row, use that row.
  # Otherwise, the remaining rows are averaged for a single Kreis-year value.
  if ("2_variable_attribute_label" %in% names(d)) {
    total_rows <- d %>% filter(grepl("insgesamt|zusammen", `2_variable_attribute_label`, ignore.case = TRUE))
    if (nrow(total_rows) > 0) d <- total_rows
  }
  if ("3_variable_attribute_label" %in% names(d)) {
    total_rows <- d %>% filter(grepl("insgesamt|zusammen", `3_variable_attribute_label`, ignore.case = TRUE))
    if (nrow(total_rows) > 0) d <- total_rows
  }

  d %>%
    mutate(metric = paste0(
      dataset_name,
      if ("value_variable_label" %in% names(d)) {
        paste0(" | ", str_squish(as.character(value_variable_label)))
      } else ""
    )) %>%
    group_by(geo_code, year, metric) %>%
    summarise(value = mean(value_num, na.rm = TRUE), .groups = "drop")
}

structural_tables <- list(
  einpendelnde = einpendelnde,
  auspendelnde = auspendelnde,
  beschaeftigte = beschaeftigte,
  arbeitslose = arbeitslose,
  tourismus = tourismus,
  schutzsuchende = schutzsuchende,
  tageseinrichtungen = tageseinrichtungen,
  pflegestat = pflegestat,
  abschlusse = abschlusse,
  grundsicherung = grundsicherung
)

structural_long <- bind_rows(lapply(
  names(structural_tables),
  function(nm) extract_structural_variable(structural_tables[[nm]], nm)
))

structural_wide <- structural_long %>%
  tidyr::pivot_wider(names_from = metric, values_from = value)

basis <- readRDS(file.path(project_root, "data_processed", "raumgliederungen_kreis_2023.rds")) %>%
  transmute(
    geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
    kreistyp = as.character(kreistyp_label),
    location_type = as.character(location_type_label),
    administrative_type = as.character(administrative_type_label)
  )

predictor_data <- kreis_outcomes %>%
  left_join(basis, by = "geo_code") %>%
  left_join(structural_wide, by = c("geo_code", "year"))

coverage <- structural_long %>%
  group_by(metric) %>%
  summarise(n_observations = n(), n_kreise = n_distinct(geo_code),
            n_jahre = n_distinct(year), .groups = "drop") %>%
  arrange(metric)

numeric_predictors <- setdiff(
  names(predictor_data),
  c("geo_code", "year", "cases", "cases_per_100k", "population",
    "kreistyp", "location_type", "administrative_type")
)

correlation_rows <- bind_rows(lapply(numeric_predictors, function(pred) {
  bind_rows(lapply("cases_per_100k", function(outcome) {
    x <- suppressWarnings(as.numeric(predictor_data[[pred]]))
    y <- suppressWarnings(as.numeric(predictor_data[[outcome]]))
    ok <- is.finite(x) & is.finite(y)
    if (sum(ok) < 3) return(tibble::tibble())

    pearson <- suppressWarnings(cor.test(x[ok], y[ok], method = "pearson"))
    spearman <- suppressWarnings(cor.test(x[ok], y[ok], method = "spearman", exact = FALSE))

    tibble(
      predictor = pred,
      outcome = outcome,
      n = sum(ok),
      pearson_r = unname(pearson$estimate),
      pearson_p = pearson$p.value,
      spearman_rho = unname(spearman$estimate),
      spearman_p = spearman$p.value
    )
  }))
})) %>% arrange(outcome, desc(abs(spearman_rho)))

category_rows <- bind_rows(lapply(c("kreistyp", "location_type", "administrative_type"), function(cat_col) {
  predictor_data %>%
    filter(!is.na(.data[[cat_col]]), is.finite(cases_per_100k)) %>%
    group_by(category = cat_col, level = as.character(.data[[cat_col]])) %>%
    summarise(n = n(), mean_cases = mean(cases, na.rm = TRUE),
              mean_cases_per_100k = mean(cases_per_100k, na.rm = TRUE),
              median_cases_per_100k = median(cases_per_100k, na.rm = TRUE),
              .groups = "drop")
}))

print("=== Coverage of structural variables ===")
print(coverage, n = Inf)
print("=== Numeric Kreis associations ===")
print(correlation_rows %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)
print("=== Regional category summaries ===")
print(category_rows, n = Inf)

results_dir <- file.path(project_root, "results/varlist_analysis")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
saveRDS(coverage, file.path(results_dir, "kreis_structural_coverage.rds"))
saveRDS(correlation_rows, file.path(results_dir, "kreis_variablen_korrelationen.rds"))
saveRDS(category_rows, file.path(results_dir, "kreis_category_summaries.rds"))

for (outcome_name in "cases_per_100k") {
  top_predictors <- correlation_rows %>%
    filter(outcome == outcome_name, is.finite(spearman_rho)) %>%
    slice_max(order_by = abs(spearman_rho), n = 5, with_ties = FALSE) %>%
    pull(predictor)

  for (var_name in top_predictors) {
    p <- ggplot(predictor_data,
                aes(x = .data[[var_name]],
                    y = .data[[outcome_name]],
                    colour = location_type)) +
      geom_point(alpha = 0.65, size = 1.8) +
      geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                  colour = "black", linewidth = 0.7) +
      facet_wrap(~year, nrow = 1) +
      scale_colour_brewer(palette = "Set1", na.value = "grey70") +
      labs(
        title = paste("Kreisbeziehung:", var_name),
        x = var_name,
        y = if (outcome_name == "cases") "COVID-19-Fälle je Jahr und Kreis" else "Fälle je 100.000 Einwohner",
        colour = "Raumtyp"
      ) +
      theme_minimal(base_size = 11)

    ggsave(file.path(results_dir, paste0("scatter_", outcome_name, "_", make.names(substr(var_name, 1, 70)), ".png")),
           p, width = 8, height = 5, dpi = 150)
  }
}

# ------------------------------------------------------------------------------
# 34. Altersgruppenspezifische Kreisbeziehungen
# ------------------------------------------------------------------------------

# Functionally broad RKI age bands keep the correlations stable while still
# allowing clear differences between younger, working-age, and older groups.
age_band_map <- tibble::tribble(
  ~age_group, ~age_band,
  "0","0-17", "1","0-17", "2","0-17", "3","0-17", "4","0-17",
  "5","0-17", "6","0-17", "7","0-17", "8","0-17", "9","0-17",
  "10","0-17", "11","0-17", "12","0-17", "13","0-17", "14","0-17",
  "15","0-17", "16","0-17", "17","0-17",
  "18","18-29", "19","18-29", "20","18-29", "21","18-29",
  "22","18-29", "23","18-29", "24","18-29", "25","18-29",
  "26","18-29", "27","18-29", "28","18-29", "29","18-29",
  "30","30-44", "31","30-44", "32","30-44", "33","30-44",
  "34","30-44", "35","30-44", "36","30-44", "37","30-44",
  "38","30-44", "39","30-44", "40","30-44", "41","30-44",
  "42","30-44", "43","30-44", "44","30-44",
  "45","45-64", "46","45-64", "47","45-64", "48","45-64",
  "49","45-64", "50","45-64", "51","45-64", "52","45-64",
  "53","45-64", "54","45-64", "55","45-64", "56","45-64",
  "57","45-64", "58","45-64", "59","45-64", "60","45-64",
  "61","45-64", "62","45-64", "63","45-64", "64","45-64",
  "65","65+", "66","65+", "67","65+", "68","65+", "69","65+",
  "70","65+", "71","65+", "72","65+", "73","65+", "74","65+",
  "75","65+", "76","65+", "77","65+", "78","65+", "79","65+", "80+","65+"
)

# Age-specific cases: monthly observations are summed for each Kreis, year,
# and broad age band. Rows with unknown age are excluded.
monthly_age <- readRDS(file.path(project_root, "data_processed", "rki_monthly_long.rds")) %>%
  as.data.frame() %>%
  mutate(age_group = as.character(age_group)) %>%
  inner_join(age_band_map, by = "age_group") %>%
  transmute(
    geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
    year = as.integer(year),
    age_band,
    cases = as.numeric(count)
  ) %>%
  filter(year %in% 2020:2023, is.finite(cases))

age_cases <- monthly_age %>%
  group_by(geo_code, year, age_band) %>%
  summarise(cases = sum(cases, na.rm = TRUE), .groups = "drop")

# Age-specific populations come from the harmonized RKI population table.
# They provide a valid denominator for each age band and year.
age_population <- readRDS(file.path(project_root, "data_processed", "rki_population_annual.rds")) %>%
  as.data.frame() %>%
  mutate(age_group = as.character(age_group)) %>%
  inner_join(age_band_map, by = "age_group") %>%
  transmute(
    geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
    year = as.integer(year),
    age_band,
    population = as.numeric(population)
  ) %>%
  filter(year %in% 2020:2023, is.finite(population), population > 0) %>%
  group_by(geo_code, year, age_band) %>%
  summarise(population = sum(population, na.rm = TRUE), .groups = "drop")

age_outcomes <- age_cases %>%
  left_join(age_population, by = c("geo_code", "year", "age_band")) %>%
  mutate(cases_per_100k = if_else(population > 0, 100000 * cases / population, NA_real_))

# The structural predictors are the same predictors used in the all-age analysis.
# Rejoining them here creates an explicit Kreis-year-age-band panel.
age_predictor_data <- age_outcomes %>%
  left_join(basis, by = "geo_code") %>%
  left_join(structural_wide, by = c("geo_code", "year"))

age_numeric_predictors <- setdiff(
  names(age_predictor_data),
  c("geo_code", "year", "age_band", "cases", "cases_per_100k", "population",
    "kreistyp", "location_type", "administrative_type")
)

# Pearson and Spearman coefficients are calculated separately within every age
# band, so differences in strength or direction can be compared directly.
age_correlation_rows <- bind_rows(lapply(age_numeric_predictors, function(pred) {
  bind_rows(lapply(c("cases_per_100k"), function(outcome) {
    bind_rows(lapply(sort(unique(age_predictor_data$age_band)), function(ab) {
      d <- age_predictor_data %>% filter(age_band == ab)
      x <- suppressWarnings(as.numeric(d[[pred]]))
      y <- suppressWarnings(as.numeric(d[[outcome]]))
      ok <- is.finite(x) & is.finite(y)
      if (sum(ok) < 3) return(tibble::tibble())

      pearson <- suppressWarnings(cor.test(x[ok], y[ok], method = "pearson"))
      spearman <- suppressWarnings(cor.test(x[ok], y[ok], method = "spearman", exact = FALSE))

      tibble(
        age_band = ab,
        predictor = pred,
        outcome = outcome,
        n = sum(ok),
        pearson_r = unname(pearson$estimate),
        pearson_p = pearson$p.value,
        spearman_rho = unname(spearman$estimate),
        spearman_p = spearman$p.value
      )
    }))
  }))
})) %>% arrange(age_band, outcome, desc(abs(spearman_rho)))

# Compare Kreistyp, location type, and administrative type descriptively within
# every age band for mean and median age-specific incidence.
age_category_rows <- bind_rows(lapply(c("kreistyp", "location_type", "administrative_type"), function(cat_col) {
  age_predictor_data %>%
    filter(!is.na(.data[[cat_col]]), is.finite(cases_per_100k)) %>%
    group_by(age_band, category = cat_col, level = as.character(.data[[cat_col]])) %>%
    summarise(
      n = n(),
      mean_cases = mean(cases, na.rm = TRUE),
      mean_cases_per_100k = mean(cases_per_100k, na.rm = TRUE),
      median_cases_per_100k = median(cases_per_100k, na.rm = TRUE),
      .groups = "drop"
    )
}))

print("=== Altersgruppenspezifische numeric associations ===")
print(age_correlation_rows %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)
print("=== Altersgruppenspezifische category summaries ===")
print(age_category_rows, n = Inf)

# ------------------------------------------------------------------------------
# 35. Population-normalized structural variables
# ------------------------------------------------------------------------------

# Instead of comparing absolute numbers of employees, commuters, tourists,
# or social-service users, this section expresses each structural variable
# relative to the total population of the Kreis and year.
#
# Example: structural_count = 5,000 and population = 100,000 becomes
#          5.0 percent of the Kreis population.
#
# For variables such as unemployment, this is a share of the total population,
# not an official unemployment rate. An official rate would require a separate
# labour-force denominator.

structural_metric_names <- setdiff(names(structural_wide), c("geo_code", "year"))

normalized_all_age_data <- predictor_data %>%
  mutate(across(
    all_of(structural_metric_names),
    ~ if_else(is.finite(population) & population > 0,
              100 * .x / population,
              NA_real_),
    .names = "{.col} | share_pct"
  ))

normalized_predictors_all_age <- grep("\\| share_pct$", names(normalized_all_age_data), value = TRUE)

normalized_correlation_all_age <- bind_rows(lapply(normalized_predictors_all_age, function(pred) {
  bind_rows(lapply(c("cases_per_100k"), function(outcome) {
    x <- suppressWarnings(as.numeric(normalized_all_age_data[[pred]]))
    y <- suppressWarnings(as.numeric(normalized_all_age_data[[outcome]]))
    ok <- is.finite(x) & is.finite(y)
    if (sum(ok) < 3) return(tibble::tibble())

    pearson <- suppressWarnings(cor.test(x[ok], y[ok], method = "pearson"))
    spearman <- suppressWarnings(cor.test(x[ok], y[ok], method = "spearman", exact = FALSE))

    tibble(
      predictor = pred,
      outcome = outcome,
      n = sum(ok),
      pearson_r = unname(pearson$estimate),
      pearson_p = pearson$p.value,
      spearman_rho = unname(spearman$estimate),
      spearman_p = spearman$p.value
    )
  }))
})) %>% arrange(outcome, desc(abs(spearman_rho)))

normalized_category_all_age <- bind_rows(lapply(
  c("kreistyp", "location_type", "administrative_type"),
  function(cat_col) {
    normalized_all_age_data %>%
      filter(!is.na(.data[[cat_col]]), is.finite(cases_per_100k)) %>%
      group_by(category = cat_col, level = as.character(.data[[cat_col]])) %>%
      summarise(
        n = n(),
        mean_cases = mean(cases, na.rm = TRUE),
        mean_cases_per_100k = mean(cases_per_100k, na.rm = TRUE),
        median_cases_per_100k = median(cases_per_100k, na.rm = TRUE),
        .groups = "drop"
      )
  }
))

print("=== Population-normalized structural associations: all ages ===")
print(normalized_correlation_all_age %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)

# Apply the same normalization within the age-band panel. The age-specific
# population remains the outcome denominator, while structural variables use
# the total Kreis population (annual_population), preventing age-size confounding.
age_normalized_data <- age_predictor_data %>%
  left_join(annual_population, by = c("geo_code", "year")) %>%
  rename(kreis_population = population.y,
         age_band_population = population.x)

age_normalized_data <- age_normalized_data %>%
  mutate(across(
    all_of(structural_metric_names),
    ~ if_else(is.finite(kreis_population) & kreis_population > 0,
              100 * .x / kreis_population,
              NA_real_),
    .names = "{.col} | share_pct"
  ))

normalized_predictors_age <- grep("\\| share_pct$", names(age_normalized_data), value = TRUE)

normalized_correlation_age <- bind_rows(lapply(normalized_predictors_age, function(pred) {
  bind_rows(lapply(c("cases_per_100k"), function(outcome) {
    bind_rows(lapply(sort(unique(age_normalized_data$age_band)), function(ab) {
      d <- age_normalized_data %>% filter(age_band == ab)
      x <- suppressWarnings(as.numeric(d[[pred]]))
      y <- suppressWarnings(as.numeric(d[[outcome]]))
      ok <- is.finite(x) & is.finite(y)
      if (sum(ok) < 3) return(tibble::tibble())

      pearson <- suppressWarnings(cor.test(x[ok], y[ok], method = "pearson"))
      spearman <- suppressWarnings(cor.test(x[ok], y[ok], method = "spearman", exact = FALSE))

      tibble(
        age_band = ab,
        predictor = pred,
        outcome = outcome,
        n = sum(ok),
        pearson_r = unname(pearson$estimate),
        pearson_p = pearson$p.value,
        spearman_rho = unname(spearman$estimate),
        spearman_p = spearman$p.value
      )
    }))
  }))
})) %>% arrange(age_band, outcome, desc(abs(spearman_rho)))

normalized_category_age <- bind_rows(lapply(
  c("kreistyp", "location_type", "administrative_type"),
  function(cat_col) {
    age_normalized_data %>%
      filter(!is.na(.data[[cat_col]]), is.finite(cases_per_100k)) %>%
      group_by(age_band, category = cat_col,
               level = as.character(.data[[cat_col]])) %>%
      summarise(
        n = n(),
        mean_cases = mean(cases, na.rm = TRUE),
        mean_cases_per_100k = mean(cases_per_100k, na.rm = TRUE),
        median_cases_per_100k = median(cases_per_100k, na.rm = TRUE),
        .groups = "drop"
      )
  }
))

print("=== Population-normalized structural associations: by age band ===")
print(normalized_correlation_age %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)

saveRDS(normalized_correlation_all_age,
        file.path(results_dir, "normalized_kreis_variablen_korrelationen.rds"))
saveRDS(normalized_category_all_age,
        file.path(results_dir, "normalized_kreis_category_summaries.rds"))
saveRDS(normalized_correlation_age,
        file.path(results_dir, "normalized_alter_kreis_variablen_korrelationen.rds"))
saveRDS(normalized_category_age,
        file.path(results_dir, "normalized_alter_kreis_category_summaries.rds"))
saveRDS(normalized_all_age_data,
        file.path(results_dir, "normalized_kreis_analysis_predictor_data.rds"))
saveRDS(age_normalized_data,
        file.path(results_dir, "normalized_alter_kreis_analysis_predictor_data.rds"))

# All-age scatterplots: strongest population-normalized predictors.
for (outcome_name in "cases_per_100k") {
  top_predictors <- normalized_correlation_all_age %>%
    filter(outcome == outcome_name, is.finite(spearman_rho)) %>%
    slice_max(order_by = abs(spearman_rho), n = 5, with_ties = FALSE) %>%
    pull(predictor)

  for (var_name in top_predictors) {
    p <- ggplot(normalized_all_age_data,
                aes(x = .data[[var_name]], y = .data[[outcome_name]],
                    colour = location_type)) +
      geom_point(alpha = 0.65, size = 1.8) +
      geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                  colour = "black", linewidth = 0.7) +
      facet_wrap(~year, nrow = 1) +
      scale_colour_brewer(palette = "Set1", na.value = "grey70") +
      labs(
        title = paste("Population-normalized Kreisbeziehung:", var_name),
        x = "Share of the total Kreis population (%)",
        y = if (outcome_name == "cases") "COVID-19-Fälle je Jahr und Kreis" else "Fälle je 100.000 Einwohner",
        colour = "Jahr"
      ) +
      theme_minimal(base_size = 11)

    ggsave(
      file.path(results_dir, paste0("normalized_", outcome_name, "_", make.names(substr(var_name, 1, 70)), ".png")),
      p, width = 8, height = 5, dpi = 150
    )
  }
}

# Age-specific scatterplots: strongest population-normalized standardized predictors.
for (ab in sort(unique(normalized_correlation_age$age_band))) {
  top_predictors <- normalized_correlation_age %>%
    filter(age_band == ab, outcome == "cases_per_100k", is.finite(spearman_rho)) %>%
    slice_max(order_by = abs(spearman_rho), n = 5, with_ties = FALSE) %>%
    pull(predictor)

  for (var_name in top_predictors) {
    d <- age_normalized_data %>% filter(age_band == ab)
    p <- ggplot(d, aes(x = .data[[var_name]], y = cases_per_100k,
                        colour = location_type)) +
      geom_point(alpha = 0.65, size = 1.8) +
      geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                  colour = "black", linewidth = 0.7) +
      facet_wrap(~year, nrow = 1) +
      scale_colour_brewer(palette = "Set1", na.value = "grey70") +
      labs(
        title = paste("Alter", ab, "– normalized Kreisbeziehung:", var_name),
        x = "Share of the total Kreis population (%)",
        y = "Fälle je 100.000 Einwohner",
        colour = "Jahr"
      ) +
      theme_minimal(base_size = 11)

    ggsave(
      file.path(results_dir, paste0("normalized_alter_", make.names(ab), "_", make.names(substr(var_name, 1, 70)), ".png")),
      p, width = 8, height = 5, dpi = 150
    )
  }
}

# ------------------------------------------------------------------------------
# 36. Correlations by year and for the full period
# ------------------------------------------------------------------------------

# calculate_correlations_by_scope() creates both a pooled "total" result and
# one result for every year present in the supplied panel. This keeps yearly
# correlations and the full-period correlations in the same R table.
calculate_correlations_by_scope <- function(panel, numeric_predictors,
                                            outcomes = "cases_per_100k") {
  bind_rows(lapply(numeric_predictors, function(pred) {
    bind_rows(lapply(outcomes, function(outcome) {
      available_years <- sort(unique(panel$year[is.finite(panel$year)]))

      bind_rows(lapply(c("total", as.character(available_years)), function(scope) {
        d <- panel
        if (scope != "total") d <- d %>% filter(year == as.integer(scope))

        x <- suppressWarnings(as.numeric(d[[pred]]))
        y <- suppressWarnings(as.numeric(d[[outcome]]))
        ok <- is.finite(x) & is.finite(y)
        if (sum(ok) < 3) return(tibble::tibble())

        pearson <- suppressWarnings(cor.test(x[ok], y[ok], method = "pearson"))
        spearman <- suppressWarnings(cor.test(x[ok], y[ok], method = "spearman", exact = FALSE))

        tibble::tibble(
          scope = scope,
          year = if (scope == "total") NA_integer_ else as.integer(scope),
          predictor = pred,
          outcome = outcome,
          n = sum(ok),
          pearson_r = unname(pearson$estimate),
          pearson_p = pearson$p.value,
          spearman_rho = unname(spearman$estimate),
          spearman_p = spearman$p.value
        )
      }))
    }))
  })) %>% arrange(outcome, scope, desc(abs(spearman_rho)))
}

all_age_numeric_predictors <- setdiff(
  names(predictor_data),
  c("geo_code", "year", "cases", "cases_per_100k", "population",
    "kreistyp", "location_type", "administrative_type")
)
all_age_correlations_by_year <- calculate_correlations_by_scope(
  predictor_data,
  all_age_numeric_predictors
)

normalized_all_age_numeric_predictors <- grep(
  "\\| share_pct$", names(normalized_all_age_data), value = TRUE
)
normalized_all_age_correlations_by_year <- calculate_correlations_by_scope(
  normalized_all_age_data,
  normalized_all_age_numeric_predictors
)

age_numeric_predictors_for_scope <- setdiff(
  names(age_predictor_data),
  c("geo_code", "year", "age_band", "cases", "cases_per_100k", "population",
    "kreistyp", "location_type", "administrative_type")
)
age_correlations_by_year <- bind_rows(lapply(
  sort(unique(age_predictor_data$age_band)),
  function(ab) {
    calculate_correlations_by_scope(
      age_predictor_data %>% filter(age_band == ab),
      age_numeric_predictors_for_scope
    ) %>% mutate(age_band = ab, .before = 1)
  }
))

normalized_age_numeric_predictors_for_scope <- grep(
  "\\| share_pct$", names(age_normalized_data), value = TRUE
)
normalized_age_correlations_by_year <- bind_rows(lapply(
  sort(unique(age_normalized_data$age_band)),
  function(ab) {
    calculate_correlations_by_scope(
      age_normalized_data %>% filter(age_band == ab),
      normalized_age_numeric_predictors_for_scope
    ) %>% mutate(age_band = ab, .before = 1)
  }
))

print("=== All-age correlations: total and by year ===")
print(all_age_correlations_by_year %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)

print("=== Broad age-band correlations: total and by year ===")
print(age_correlations_by_year %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)

saveRDS(all_age_correlations_by_year,
        file.path(results_dir, "all_age_correlations_total_and_by_year.rds"))
saveRDS(normalized_all_age_correlations_by_year,
        file.path(results_dir, "normalized_all_age_correlations_total_and_by_year.rds"))
saveRDS(age_correlations_by_year,
        file.path(results_dir, "age_band_correlations_total_and_by_year.rds"))
saveRDS(normalized_age_correlations_by_year,
        file.path(results_dir, "normalized_age_band_correlations_total_and_by_year.rds"))

saveRDS(coverage,
        file.path(results_dir, "kreis_structural_coverage.rds"))
saveRDS(category_rows,
        file.path(results_dir, "kreis_category_summaries.rds"))
saveRDS(age_category_rows,
        file.path(results_dir, "alter_kreis_category_summaries.rds"))
saveRDS(normalized_category_all_age,
        file.path(results_dir, "normalized_kreis_category_summaries.rds"))
saveRDS(normalized_category_age,
        file.path(results_dir, "normalized_alter_kreis_category_summaries.rds"))

# ------------------------------------------------------------------------------
# 37. Outliers in the normalized table, calculated separately by year
# ------------------------------------------------------------------------------

# An observation is an outlier within a specific year and column if it lies
# outside [Q1 - 1.5 * IQR, Q3 + 1.5 * IQR]. This is the standard Tukey/IQR
# rule. The analysis is not performed over all four years pooled, because
# year-specific distributions can differ substantially.
normalized_outlier_input <- normalized_kreis_analysis_predictor_data <- readRDS(
  file.path(results_dir, "normalized_kreis_analysis_predictor_data.rds")
)

# Geo names are useful for reporting, but the Kreis code remains the unique key.
kreis_name_lookup_outlier <- geo_info %>%
  transmute(
    geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
    geo_name = str_squish(as.character(geo_name))
  ) %>%
  distinct(geo_code, geo_name)

# Keep population-normalized structural percentages and the incidence outcome.
# Absolute variables are intentionally excluded, because the request concerns
# the normalized table and the outliers should be comparable across Kreise.
outlier_column_names <- c(
  "cases_per_100k",
  grep("\\| share_pct$", names(normalized_outlier_input), value = TRUE)
)

outlier_records_by_year <- bind_rows(lapply(outlier_column_names, function(col_name) {
  bind_rows(lapply(sort(unique(normalized_outlier_input$year)), function(y) {
    d <- normalized_outlier_input %>%
      filter(year == y) %>%
      transmute(
        geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
        year,
        value = suppressWarnings(as.numeric(.data[[col_name]]))
      ) %>%
      filter(is.finite(value))

    if (nrow(d) < 4) return(tibble::tibble())

    q1 <- stats::quantile(d$value, 0.25, na.rm = TRUE, names = FALSE)
    q3 <- stats::quantile(d$value, 0.75, na.rm = TRUE, names = FALSE)
    iqr <- q3 - q1
    lower_fence <- q1 - 1.5 * iqr
    upper_fence <- q3 + 1.5 * iqr

    d %>%
      mutate(
        column = col_name,
        q1 = q1,
        q3 = q3,
        iqr = iqr,
        lower_fence = lower_fence,
        upper_fence = upper_fence,
        direction = case_when(
          value < lower_fence ~ "low",
          value > upper_fence ~ "high",
          TRUE ~ NA_character_
        )
      ) %>%
      filter(!is.na(direction))
  }))
})) %>%
  left_join(kreis_name_lookup_outlier, by = "geo_code") %>%
  select(year, geo_code, geo_name, column, value, direction,
         lower_fence, upper_fence, q1, q3, iqr) %>%
  arrange(year, column, direction, desc(value))

# One row per Kreis-year-column: a compact summary of the number and direction
# of outliers found in each column.
outlier_summary_by_year <- outlier_records_by_year %>%
  group_by(year, column, direction) %>%
  summarise(n_outliers = n(),
            kreis_codes = paste(sort(unique(geo_code)), collapse = ", "),
            .groups = "drop") %>%
  arrange(year, column, direction)

outlier_summary_columns_by_year <- outlier_records_by_year %>%
  group_by(year, column) %>%
  summarise(n_outliers = n(),
            n_high = sum(direction == "high"),
            n_low = sum(direction == "low"),
            kreis_codes = paste(sort(unique(geo_code)), collapse = ", "),
            .groups = "drop") %>%
  arrange(year, desc(n_outliers), column)

print("=== IQR outliers by year (1.5 * IQR outside the quartile fences) ===")
print(outlier_records_by_year, n = Inf)

print("=== Number of outliers by year and column ===")
print(outlier_summary_columns_by_year, n = Inf)

saveRDS(outlier_records_by_year,
        file.path(results_dir, "outlier_records_normalized_by_year.rds"))
saveRDS(outlier_summary_by_year,
        file.path(results_dir, "outlier_summary_direction_normalized_by_year.rds"))
saveRDS(outlier_summary_columns_by_year,
        file.path(results_dir, "outlier_summary_columns_normalized_by_year.rds"))

# ------------------------------------------------------------------------------
# 38. Long standardized outlier table (z-score and IQR within each year)
# ------------------------------------------------------------------------------

# This table preserves every Kreis-year-column combination as one row. It adds
# both the classical z-score and the Tukey/IQR statistics. Statistics are
# calculated separately for each calendar year and for each column.
long_outlier_columns <- c(
  "cases_per_100k",
  grep("\\| share_pct$", names(normalized_outlier_input), value = TRUE)
)

outlier_long_by_year <- bind_rows(lapply(long_outlier_columns, function(col_name) {
  bind_rows(lapply(sort(unique(normalized_outlier_input$year)), function(y) {
    d <- normalized_outlier_input %>%
      filter(year == y) %>%
      transmute(
        geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
        year,
        value = suppressWarnings(as.numeric(.data[[col_name]]))
      ) %>%
      left_join(kreis_name_lookup_outlier, by = "geo_code") %>%
      filter(is.finite(value))

    if (nrow(d) < 2) return(tibble::tibble())

    column_mean <- mean(d$value, na.rm = TRUE)
    column_sd <- stats::sd(d$value, na.rm = TRUE)
    q1 <- stats::quantile(d$value, 0.25, na.rm = TRUE, names = FALSE)
    median_value <- stats::median(d$value, na.rm = TRUE)
    q3 <- stats::quantile(d$value, 0.75, na.rm = TRUE, names = FALSE)
    iqr_value <- q3 - q1
    lower_fence <- q1 - 1.5 * iqr_value
    upper_fence <- q3 + 1.5 * iqr_value

    d %>%
      mutate(
        column = col_name,
        mean = column_mean,
        sd = column_sd,
        z_score = if (is.finite(column_sd) && column_sd > 0) {
          (value - column_mean) / column_sd
        } else {
          NA_real_
        },
        q1 = q1,
        median = median_value,
        q3 = q3,
        iqr = iqr_value,
        lower_fence = lower_fence,
        upper_fence = upper_fence,
        iqr_outlier = value < lower_fence | value > upper_fence,
        iqr_direction = case_when(
          value < lower_fence ~ "low",
          value > upper_fence ~ "high",
          TRUE ~ "not outlier"
        ),
        z_outlier_abs_gt2 = is.finite(z_score) & abs(z_score) > 2,
        z_outlier_abs_gt3 = is.finite(z_score) & abs(z_score) > 3,
        z_direction = case_when(
          !is.finite(z_score) ~ "not available",
          z_score < -2 ~ "low",
          z_score > 2 ~ "high",
          TRUE ~ "not outlier"
        )
      )
  }))
})) %>%
  select(year, geo_code, geo_name, column, value, mean, sd, z_score,
         q1, median, q3, iqr, lower_fence, upper_fence,
         iqr_outlier, iqr_direction,
         z_outlier_abs_gt2, z_outlier_abs_gt3, z_direction) %>%
  arrange(year, column, geo_code)

print("=== Long standardized/IQR table: first 30 rows ===")
print(head(outlier_long_by_year, 30), n = 30)

print("=== Count of IQR and |z| > 2 outliers by year and column ===")
print(outlier_long_by_year %>%
  group_by(year, column) %>%
  summarise(n_iqr_outliers = sum(iqr_outlier, na.rm = TRUE),
            n_z2_outliers = sum(z_outlier_abs_gt2, na.rm = TRUE),
            n_z3_outliers = sum(z_outlier_abs_gt3, na.rm = TRUE),
            .groups = "drop") %>%
  arrange(year, desc(n_iqr_outliers), column), n = Inf)

saveRDS(outlier_long_by_year,
        file.path(results_dir, "long_zscore_iqr_normalized_by_year.rds"))

# ------------------------------------------------------------------------------
# 39. Reanalysis excluding jointly extreme z-score / IQR points
# ------------------------------------------------------------------------------

# Read the complete long standardized/IQR table. The exclusion rule is deliberately
# strict: remove a datapoint only when it is both a Tukey IQR outlier AND has
# z_score > 7. Negative extreme z-scores are not removed unless z_score is > 7,
# matching the user's threshold literally.
long_outlier_table <- readRDS(
  file.path(results_dir, "long_zscore_iqr_normalized_by_year.rds")
)

extreme_keys <- long_outlier_table %>%
  filter(iqr_outlier, is.finite(z_score), z_score > 7) %>%
  distinct(year, geo_code, geo_name) %>%
  arrange(year, geo_code)

no_extreme_dir <- file.path(results_dir, "analysis_noextremes")
dir.create(no_extreme_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(extreme_keys,
        file.path(no_extreme_dir, "excluded_extreme_kreis_year_keys.rds"))

# A Kreis-year pair is removed from the full panel if it contains at least one
# column-level point satisfying the joint exclusion rule.
filter_extreme_keys <- function(panel) {
  anti_join(
    panel,
    extreme_keys %>% transmute(
      geo_code = str_pad(as.character(geo_code), 5, "left", "0"),
      year = as.integer(year)
    ),
    by = c("geo_code", "year")
  )
}

normalized_noextreme <- filter_extreme_keys(normalized_all_age_data)
age_normalized_noextreme <- filter_extreme_keys(age_normalized_data)
all_age_noextreme <- filter_extreme_keys(predictor_data)
age_noextreme <- filter_extreme_keys(age_predictor_data)

# Recalculate incidence correlations for the all-age normalized panel.
normalized_all_age_numeric_noextreme <- grep(
  "\\| share_pct$", names(normalized_noextreme), value = TRUE
)
normalized_correlations_noextreme <- bind_rows(lapply(
  normalized_all_age_numeric_noextreme,
  function(pred) {
    bind_rows(lapply(sort(unique(normalized_noextreme$year)), function(y) {
      d <- normalized_noextreme %>% filter(year == y)
      x <- suppressWarnings(as.numeric(d[[pred]]))
      y_value <- suppressWarnings(as.numeric(d[["cases_per_100k"]]))
      ok <- is.finite(x) & is.finite(y_value)
      if (sum(ok) < 3) return(tibble::tibble())

      pearson <- suppressWarnings(cor.test(x[ok], y_value[ok], method = "pearson"))
      spearman <- suppressWarnings(cor.test(x[ok], y_value[ok], method = "spearman", exact = FALSE))

      tibble::tibble(
        scope = as.character(y), year = y, predictor = pred,
        outcome = "cases_per_100k", n = sum(ok),
        pearson_r = unname(pearson$estimate), pearson_p = pearson$p.value,
        spearman_rho = unname(spearman$estimate), spearman_p = spearman$p.value
      )
    }))
  }
))

# Pooled full-period correlations are retained in the same table.
pooled_normalized_noextreme <- bind_rows(lapply(
  normalized_all_age_numeric_noextreme,
  function(pred) {
    x <- suppressWarnings(as.numeric(normalized_noextreme[[pred]]))
    y_value <- suppressWarnings(as.numeric(normalized_noextreme[["cases_per_100k"]]))
    ok <- is.finite(x) & is.finite(y_value)
    if (sum(ok) < 3) return(tibble::tibble())

    pearson <- suppressWarnings(cor.test(x[ok], y_value[ok], method = "pearson"))
    spearman <- suppressWarnings(cor.test(x[ok], y_value[ok], method = "spearman", exact = FALSE))

    tibble::tibble(
      scope = "total", year = NA_integer_, predictor = pred,
      outcome = "cases_per_100k", n = sum(ok),
      pearson_r = unname(pearson$estimate), pearson_p = pearson$p.value,
      spearman_rho = unname(spearman$estimate), spearman_p = spearman$p.value
    )
  }
))

normalized_correlations_noextreme <- bind_rows(
  normalized_correlations_noextreme,
  pooled_normalized_noextreme
) %>% arrange(outcome, scope, desc(abs(spearman_rho)))

# Recalculate age-specific normalized incidence correlations.
age_normalized_predictors_noextreme <- grep(
  "\\| share_pct$", names(age_normalized_noextreme), value = TRUE
)
normalized_age_correlations_noextreme <- bind_rows(lapply(
  age_normalized_predictors_noextreme,
  function(pred) {
    bind_rows(lapply(sort(unique(age_normalized_noextreme$age_band)), function(ab) {
      d_age <- age_normalized_noextreme %>% filter(age_band == ab)

      yearly_results <- bind_rows(lapply(sort(unique(d_age$year)), function(y) {
        d <- d_age %>% filter(year == y)
        x <- suppressWarnings(as.numeric(d[[pred]]))
        y_value <- suppressWarnings(as.numeric(d[["cases_per_100k"]]))
        ok <- is.finite(x) & is.finite(y_value)
        if (sum(ok) < 3) return(tibble::tibble())

        pearson <- suppressWarnings(cor.test(x[ok], y_value[ok], method = "pearson"))
        spearman <- suppressWarnings(cor.test(x[ok], y_value[ok], method = "spearman", exact = FALSE))

        tibble::tibble(
          age_band = ab, scope = as.character(y), year = y,
          predictor = pred, outcome = "cases_per_100k", n = sum(ok),
          pearson_r = unname(pearson$estimate), pearson_p = pearson$p.value,
          spearman_rho = unname(spearman$estimate), spearman_p = spearman$p.value
        )
      }))

      pooled_x <- suppressWarnings(as.numeric(d_age[[pred]]))
      pooled_y <- suppressWarnings(as.numeric(d_age[["cases_per_100k"]]))
      pooled_ok <- is.finite(pooled_x) & is.finite(pooled_y)
      pooled_result <- tibble::tibble()

      if (sum(pooled_ok) >= 3) {
        pearson <- suppressWarnings(cor.test(pooled_x[pooled_ok], pooled_y[pooled_ok], method = "pearson"))
        spearman <- suppressWarnings(cor.test(pooled_x[pooled_ok], pooled_y[pooled_ok], method = "spearman", exact = FALSE))
        pooled_result <- tibble::tibble(
          age_band = ab, scope = "total", year = NA_integer_,
          predictor = pred, outcome = "cases_per_100k", n = sum(pooled_ok),
          pearson_r = unname(pearson$estimate), pearson_p = pearson$p.value,
          spearman_rho = unname(spearman$estimate), spearman_p = spearman$p.value
        )
      }

      bind_rows(yearly_results, pooled_result)
    }))
  }
)) %>% arrange(age_band, outcome, scope, desc(abs(spearman_rho)))

# Recalculate category summaries without extreme Kreis-year points.
category_summary_noextreme <- bind_rows(lapply(
  c("kreistyp", "location_type", "administrative_type"),
  function(cat_col) {
    normalized_noextreme %>%
      filter(!is.na(.data[[cat_col]]), is.finite(cases_per_100k)) %>%
      group_by(category = cat_col, level = as.character(.data[[cat_col]])) %>%
      summarise(
        n = n(), mean_cases = mean(cases, na.rm = TRUE),
        mean_cases_per_100k = mean(cases_per_100k, na.rm = TRUE),
        median_cases_per_100k = median(cases_per_100k, na.rm = TRUE),
        .groups = "drop"
      )
  }
))

age_category_summary_noextreme <- bind_rows(lapply(
  c("kreistyp", "location_type", "administrative_type"),
  function(cat_col) {
    age_normalized_noextreme %>%
      filter(!is.na(.data[[cat_col]]), is.finite(cases_per_100k)) %>%
      group_by(age_band, category = cat_col,
               level = as.character(.data[[cat_col]])) %>%
      summarise(
        n = n(), mean_cases = mean(cases, na.rm = TRUE),
        mean_cases_per_100k = mean(cases_per_100k, na.rm = TRUE),
        median_cases_per_100k = median(cases_per_100k, na.rm = TRUE),
        .groups = "drop"
      )
  }
))

print("=== Excluded z>7 + IQR-outlier Kreis-year keys ===")
print(extreme_keys, n = Inf)
print("=== No-extremes normalized all-age correlations ===")
print(normalized_correlations_noextreme %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)
print("=== No-extremes normalized age-band correlations ===")
print(normalized_age_correlations_noextreme %>%
  mutate(across(c(pearson_r, spearman_rho), ~ round(.x, 3)),
         across(c(pearson_p, spearman_p), ~ signif(.x, 3))), n = Inf)

saveRDS(normalized_noextreme,
        file.path(no_extreme_dir, "normalized_kreis_analysis_predictor_data_noextremes.rds"))
saveRDS(age_normalized_noextreme,
        file.path(no_extreme_dir, "normalized_alter_kreis_analysis_predictor_data_noextremes.rds"))
saveRDS(normalized_correlations_noextreme,
        file.path(no_extreme_dir, "normalized_kreis_correlations_noextremes.rds"))
saveRDS(normalized_age_correlations_noextreme,
        file.path(no_extreme_dir, "normalized_age_band_correlations_noextremes.rds"))
saveRDS(category_summary_noextreme,
        file.path(no_extreme_dir, "normalized_kreis_category_summaries_noextremes.rds"))
saveRDS(age_category_summary_noextreme,
        file.path(no_extreme_dir, "normalized_alter_kreis_category_summaries_noextremes.rds"))

# Recreate incidence scatterplots, faceted by year and colored by Raumtyp.
for (var_name in normalized_correlations_noextreme %>%
     filter(scope == "total", is.finite(spearman_rho)) %>%
     slice_max(order_by = abs(spearman_rho), n = 5, with_ties = FALSE) %>%
     pull(predictor)) {
  p <- ggplot(normalized_noextreme,
              aes(x = .data[[var_name]], y = cases_per_100k,
                  colour = location_type)) +
    geom_point(alpha = 0.65, size = 1.8) +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                colour = "black", linewidth = 0.7) +
    facet_wrap(~year, nrow = 1) +
    scale_colour_brewer(palette = "Set1", na.value = "grey70") +
    labs(
      title = paste("No-extreme normalized Kreisbeziehung:", var_name),
      x = "Share of the total Kreis population (%)",
      y = "Fälle je 100.000 Einwohner",
      colour = "Raumtyp"
    ) +
    theme_minimal(base_size = 11)

  ggsave(
    file.path(no_extreme_dir,
              paste0("normalized_noextremes_cases_per_100k_",
                     make.names(substr(var_name, 1, 70)), ".png")),
    p, width = 11, height = 5, dpi = 150
  )
}

for (ab in sort(unique(normalized_age_correlations_noextreme$age_band))) {
  top_predictors <- normalized_age_correlations_noextreme %>%
    filter(age_band == ab, scope == "total", is.finite(spearman_rho)) %>%
    slice_max(order_by = abs(spearman_rho), n = 5, with_ties = FALSE) %>%
    pull(predictor)

  for (var_name in top_predictors) {
    d <- age_normalized_noextreme %>% filter(age_band == ab)
    p <- ggplot(d, aes(x = .data[[var_name]], y = cases_per_100k,
                       colour = location_type)) +
      geom_point(alpha = 0.65, size = 1.8) +
      geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                  colour = "black", linewidth = 0.7) +
      facet_wrap(~year, nrow = 1) +
      scale_colour_brewer(palette = "Set1", na.value = "grey70") +
      labs(
        title = paste("No-extreme Alter", ab, "– normalized Kreisbeziehung:", var_name),
        x = "Share of the total Kreis population (%)",
        y = "Fälle je 100.000 Einwohner",
        colour = "Raumtyp"
      ) +
      theme_minimal(base_size = 11)

    ggsave(
      file.path(no_extreme_dir,
                paste0("normalized_noextremes_alter_", make.names(ab), "_",
                       make.names(substr(var_name, 1, 70)), ".png")),
      p, width = 11, height = 5, dpi = 150
    )
  }
}
