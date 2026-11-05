library(readr)
library(dplyr)
library(stringr)

# ------------------------------------------------------------
# 1. Read raw population data
# ------------------------------------------------------------

source_file <- list.files(
  "data_raw",
  pattern = "^12411-0018.*\\.csv$",
  full.names = TRUE
)

stopifnot(length(source_file) == 1)

df <- read_delim(
  source_file,
  delim = ";",
  locale = locale(encoding = "UTF-8"),
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

# ------------------------------------------------------------
# 2. Load 2023 Kreis reference
# ------------------------------------------------------------

kreis_ref <- readRDS(
  "data_processed/raumgliederungen_kreis_2023.rds"
) %>%
  select(geo_code)

stopifnot(
  nrow(kreis_ref) == 400,
  !anyDuplicated(kreis_ref$geo_code)
)

# ------------------------------------------------------------
# 3. Select and clean raw variables
# ------------------------------------------------------------

pop_raw <- df %>%
  transmute(
    geo_code = str_pad(
      str_trim(`1_variable_attribute_code`),
      width = 5,
      side = "left",
      pad = "0"
    ),
    year = as.integer(substr(time, 1, 4)),
    age_name = str_squish(
      `3_variable_attribute_label`
    ),
    sex = str_squish(
      `2_variable_attribute_label`
    ),
    population = parse_number(
      na_if(str_trim(value), "-"),
      locale = locale(
        decimal_mark = ",",
        grouping_mark = "."
      )
    )
  ) %>%
  filter(
    year %in% 2020:2023,
    sex %in% c("männlich", "weiblich")
  )

# ------------------------------------------------------------
# 4. Identify active districts by year
# ------------------------------------------------------------

active_codes <- pop_raw %>%
  filter(!is.na(population)) %>%
  distinct(year, geo_code)

pop_active <- pop_raw %>%
  semi_join(
    active_codes,
    by = c("year", "geo_code")
  )

# Verify original district counts
original_coverage <- active_codes %>%
  count(year, name = "kreise") %>%
  arrange(year)

print(original_coverage)

stopifnot(
  identical(original_coverage$year, 2020:2023),
  identical(
    original_coverage$kreise,
    c(401L, 400L, 400L, 400L)
  )
)

# ------------------------------------------------------------
# 5. Check sex-specific records
# ------------------------------------------------------------

stopifnot(
  !anyNA(pop_active),
  !anyDuplicated(
    pop_active[
      c("geo_code", "year", "age_name", "sex")
    ]
  ),
  all(pop_active$population >= 0)
)

sex_check <- pop_active %>%
  count(geo_code, year, age_name, name = "n_sex")

stopifnot(all(sex_check$n_sex == 2))

# ------------------------------------------------------------
# 6. Harmonize 2020 district boundaries
# ------------------------------------------------------------

pop_harmonized <- pop_active %>%
  mutate(
    geo_code = if_else(
      year == 2020 & geo_code == "16056",
      "16063",
      geo_code
    )
  )

# ------------------------------------------------------------
# 7. Aggregate male and female population
# ------------------------------------------------------------

pop_clean <- pop_harmonized %>%
  group_by(geo_code, year, age_name) %>%
  summarise(
    population = sum(population),
    .groups = "drop"
  ) %>%
  select(
    geo_code,
    year,
    age_name,
    population
  ) %>%
  arrange(geo_code, year, age_name)

# ------------------------------------------------------------
# 8. Data quality checks
# ------------------------------------------------------------

stopifnot(
  nrow(pop_clean) > 0,
  !anyNA(pop_clean),
  !anyDuplicated(
    pop_clean[c("geo_code", "year", "age_name")]
  ),
  isTRUE(all.equal(
    sum(pop_active$population),
    sum(pop_clean$population)
  ))
)

# Check district coverage and consistency
stopifnot(
  all(
    pop_clean %>%
      distinct(year, geo_code) %>%
      count(year) %>%
      pull(n) == 400
  ),
  
  all(vapply(
    2020:2023,
    function(y) {
      setequal(
        pop_clean$geo_code[pop_clean$year == y],
        kreis_ref$geo_code
      )
    },
    logical(1)
  ))
)

# ------------------------------------------------------------
# 9. Save cleaned data
# ------------------------------------------------------------

saveRDS(
  pop_clean,
  "data_processed/population_kreis.rds"
)

cat(
  "Saved", nrow(pop_clean),
  "rows with", ncol(pop_clean),
  "variables.\n"
)
