library(readr)
library(dplyr)
library(stringr)
library(lubridate)

df <- read_delim(
  "data_raw/12411-0018 Bevölkerung nach Geschlecht, Altersgruppen und Kreisen.csv",
  delim = ";",
  locale = locale(encoding = "UTF-8"),
  col_types = cols(.default = col_character())
)

pop_clean <- df %>%
  
  # Select and rename relevant variables
  transmute(
    year = as.integer(str_sub(time, 1, 4)),
    date = as.Date(time, format = "%Y/%m/%d"),
    
    geo_code = str_pad(
      `1_variable_attribute_code`,
      width = 5,
      side = "left",
      pad = "0"
    ),
    
    geo_label = str_squish(`1_variable_attribute_label`),
    
    sex = str_squish(`2_variable_attribute_label`),
    
    age_code = `3_variable_attribute_code`,
    age_name = str_squish(`3_variable_attribute_label`),
    
    population = parse_number(
      na_if(str_trim(value), "-"),
      locale = locale(
        decimal_mark = ",",
        grouping_mark = "."
      )
    ),
    
    # Quality flag
    value_q = value_q
  ) %>%
  
  # Clean district names
  mutate(
    valid_until = dmy(
      str_extract(
        geo_label,
        "(?<=bis )\\d{2}\\.\\d{2}\\.\\d{4}"
      ),
      quiet = TRUE
    ),
    
    geo_name = str_remove(
      geo_label,
      "\\s*\\(bis\\s+\\d{2}\\.\\d{2}\\.\\d{4}\\)"
    ),
    
    kreis_type = case_when(
      str_detect(
        geo_name,
        regex(",\\s*Landkreis$", ignore_case = TRUE)
      ) ~ "Landkreis",
      
      str_detect(
        geo_name,
        regex(",\\s*kreisfreie Stadt$", ignore_case = TRUE)
      ) ~ "kreisfreie Stadt",
      
      TRUE ~ "Other"
    ),
    
    geo_name = str_remove(
      geo_name,
      regex(
        ",\\s*(Landkreis|kreisfreie Stadt)$",
        ignore_case = TRUE
      )
    ),
    
    geo_name = str_squish(geo_name)
  ) %>%
  
  # Extract age-group boundaries
  mutate(
    age_low = case_when(
      str_detect(age_name, "^unter \\d+ Jahre") ~ 0L,
      
      str_detect(age_name, "^\\d+ bis unter \\d+ Jahre") ~
        as.integer(str_extract(age_name, "^\\d+")),
      
      str_detect(age_name, "^\\d+ Jahre und (mehr|älter)") ~
        as.integer(str_extract(age_name, "^\\d+")),
      
      TRUE ~ NA_integer_
    ),
    
    age_high = case_when(
      str_detect(age_name, "^unter \\d+ Jahre") ~
        as.integer(str_extract(age_name, "\\d+")),
      
      str_detect(age_name, "^\\d+ bis unter \\d+ Jahre") ~
        as.integer(str_extract(age_name, "(?<=unter )\\d+")),
      
      TRUE ~ NA_integer_
    )
  ) %>%
  
  # Keep all three sex categories separately
  filter(sex %in% c("männlich", "weiblich", "Insgesamt")) %>%
  
  # Match RKI column structure
  select(
    geo_code,
    geo_label,
    geo_name,
    kreis_type,
    sex,
    age_code,
    age_name,
    population,
    year,
    age_low,
    age_high
  ) %>%
  
  arrange(geo_code, year, age_code, sex)

View(pop_clean)