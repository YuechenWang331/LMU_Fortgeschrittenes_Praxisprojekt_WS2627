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
  bind_rows(lapply(c("cases", "cases_per_100k"), function(outcome) {
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
write.csv(coverage, file.path(results_dir, "kreis_structural_coverage.csv"), row.names = FALSE)
write.csv(correlation_rows, file.path(results_dir, "kreis_variablen_korrelationen.csv"), row.names = FALSE)
write.csv(category_rows, file.path(results_dir, "kreis_category_summaries.csv"), row.names = FALSE)
saveRDS(predictor_data, file.path(results_dir, "kreis_analysis_predictor_data.rds"))

for (outcome_name in c("cases", "cases_per_100k")) {
  top_predictors <- correlation_rows %>%
    filter(outcome == outcome_name, is.finite(spearman_rho)) %>%
    slice_max(order_by = abs(spearman_rho), n = 5, with_ties = FALSE) %>%
    pull(predictor)

  for (var_name in top_predictors) {
    p <- ggplot(predictor_data, aes(x = .data[[var_name]], y = .data[[outcome_name]])) +
      geom_point(alpha = 0.35, size = 1.5) +
      geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = "steelblue") +
      labs(
        title = paste("Kreisbeziehung:", var_name),
        x = var_name,
        y = if (outcome_name == "cases") "COVID-19-Fälle je Jahr und Kreis" else "Fälle je 100.000 Einwohner"
      ) +
      theme_minimal(base_size = 11)

    ggsave(file.path(results_dir, paste0("scatter_", outcome_name, "_", make.names(substr(var_name, 1, 70)), ".png")),
           p, width = 8, height = 5, dpi = 150)
  }
}
