
# Study settings

# Period boundaries follow Scripts/Kreistyp_Alter_Zeit/run_analysis.R.
period_definitions <- data.frame(
  period = c("P0", "W1", "G1", "W2", "W3", "G2", "W4", "W5", "PostW5"),
  start = as.Date(c("2019-12-30", "2020-03-02", "2020-05-18", "2020-09-28",
                    "2021-03-01", "2021-06-14", "2021-08-02", "2021-12-27", "2022-05-30")),
  end = as.Date(c("2020-03-01", "2020-05-17", "2020-09-27", "2021-02-28",
                  "2021-06-13", "2021-08-01", "2021-12-26", "2022-05-29", "2023-12-31"))
)

study_config <- list(
  years = 2020:2023,
  expected_n_kreise = 400L,
  expected_n_weeks = 209L,
  incidence_scale = 100000,
  periods = period_definitions$period,
  time_origin = period_definitions$start[1L]
)


# Input and output paths

age_data_dir <- "data_processed/Altsgruppen_ZeitlicheEntwicklung"
regional_data_dir <- "data_processed/Kreistyp/Kreistyp_prepare"
paths <- list(
  weekly = setNames(file.path(age_data_dir, c("kreis_weekly_7.rds", "kreis_weekly_13.rds")),
                    c("7", "13")),
  age_mapping = file.path(age_data_dir, "age_mapping.rds"),
  balanced_codes = file.path(age_data_dir, "balanced_kreis_codes.rds"),
  regional = file.path(regional_data_dir, "population_Kreistyp_Raumtyp_2020_2024.rds"),
  snapshot = file.path(regional_data_dir, "raumgliederungen_kreis_2023.rds"),
  area = "data_processed/area_kreis_2023.rds",
  data_processed = "data_processed",
  model_data = "data_processed/Modellierung",
  results = "results/Modellierung",
  reports = "reports/Modellierung"
)


# Candidate data specifications

data_options <- list(

  # Age grouping
  age_scheme = c("7", "13"),

  # Regional structural characteristics
  structure = c(
    "kreistyp",
    "location_type",
    "pop_density",
    "kreistyp_pop_density"
  ),

  # Temporal resolution
  time_resolution = c("weekly", "phase"),

  # Inclusion of the initial pandemic period
  include_p0 = c(TRUE, FALSE),

  # Subdivision of PostW5
  split_postw5 = c(TRUE, FALSE),

  # Temporal classification of districts
  kreistyp_version = c(
    "snapshot_2023",
    "dynamic"
  ),

  # Missing population denominators
  missing_strategy = c(
    "balanced",
    "unbalanced",
    "imputed"
  ),

  # Partial phase coverage and ties in the calendar-week modal classification
  phase_missing = c("complete", "available"),
  phase_type_tie = c("error", "earliest", "latest"),

  # Aggregation of weekly incidence
  aggregation = c(
    "arithmetic",
    "exposure"
  )
)


# Candidate model specifications

model_options <- list(

  # Observation weighting
  weighting = c(
    "unweighted",
    "population",
    "duration",
    "precision",
    "exposure"
  ),

  # Compatible response variables and model families
  response_family = list(
    incidence = c("lm", "lmm"),
    log1p = c("lm", "lmm"),
    count = c(
      "poisson",
      "quasipoisson",
      "negative_binomial",
      "poisson_glmm",
      "negative_binomial_glmm"
    )
  ),

  # Residual correlation is separate from temporal fixed effects and random slopes.
  temporal_fixed_effects = c("week", "period"),
  temporal_correlation = c("none", "ar1", "car1"),
  phase_time = c("start", "midpoint", "end"),

  # Candidate random-effects structures
  random_effects = c(
    "none",
    "kreis",
    "kreis_age",
    "random_slopes"
  ),

  # Fixed-effects model hierarchy
  model_id = c(
    "M0a", "M0b", "M1",
    "M2a", "M2b", "M3"
  )
)


# Reference categories

reference_levels <- list(
  kreistyp = "Kreisfreie Großstädte",
  age_group = list(`7` = "18–39", `13` = NULL),
  period = "W1"
)


# Statistical inference settings

# Apply robust inference separately from the residual covariance model.
inference_config <- list(
  alpha = 0.05,
  confidence_level = 0.95,
  cluster_variable = "geo_code",
  p_adjust_method = "holm",
  robust_covariance = "CR2",
  joint_test = "HTZ",
  contrast_coding = NULL
)

# Substitute the selected structural term for kreistyp_phase where applicable.
model_hierarchy <- c(
  M0a = "age_group + period",
  M0b = "age_group * period",
  M1 = "age_group * period + kreistyp_phase",
  M2a = "age_group * period + kreistyp_phase * period",
  M2b = "(kreistyp_phase + age_group + period)^2",
  M3 = "kreistyp_phase * age_group * period"
)

structure_terms <- list(
  kreistyp = "kreistyp",
  location_type = "location_type",
  pop_density = "pop_density",
  kreistyp_pop_density = c("kreistyp", "pop_density")
)

# Count families use a log link with log(exposure) as an offset.
response_columns <- c(incidence = "incidence", log1p = "log1p_incidence", count = "cases")
count_offset_column <- "log_exposure"
weight_columns <- c(population = "weight_population", duration = "weight_duration",
                    exposure = "weight_exposure")

# Open decisions: panel, P0, PostW5, structural predictors and Kreistyp assignment.
# The 13-group scheme divides 18–39 into three levels. Its reference is open.
# Imputation requires external full age-group denominators and an agreed method.
# Precision weights require an agreed variance estimator.
# Response, family, weighting, random slopes, covariance and contrasts await evaluation.
# Other age schemes and single ages require additional upstream preparation.

# Correlated Gaussian fits use GLS or LME. Count covariance models are open.
correlated_gaussian_engines <- c(lm = "gls", lmm = "lme")
phase_time_columns <- c(start = "phase_start_week", midpoint = "phase_mid_week",
                        end = "phase_end_week")
