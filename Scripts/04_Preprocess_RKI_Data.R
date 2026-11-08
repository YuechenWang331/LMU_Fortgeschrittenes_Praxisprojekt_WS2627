library(data.table)

study_years <- 2020:2024

# 1. Read raw data
map <- fread(
  "data_raw/CountyKey71Map.csv",
  colClasses = "character"
)

map[, geo_code := sub(
  "^\\[([0-9]{5})\\]$",
  "\\1",
  ComponentId
)]

cases <- readRDS(
  "data_raw/Count_COVID_LK_Week_RKI_2020_2024.RData"
)

inc <- readRDS(
  "data_raw/Incidence_COVID_LK_Week_RKI_2020_2024.RData"
)

pop <- as.data.table(
  as.data.frame(
    readRDS(
      "data_raw/Count_Bev_LK_RKI_2020_2024.RData"
    )
  )
)

stopifnot(
  nrow(map) == 411L,
  !anyDuplicated(map$geo_code),
  all(grepl("^[0-9]{5}$", map$geo_code)),
  length(dim(cases)) == 3L,
  identical(dim(cases), dim(inc)),
  identical(dimnames(cases), dimnames(inc)),
  identical(dimnames(cases)[[2]], map$Name)
)

# 2. Select study weeks
ages <- dimnames(cases)[[1]]

raw_dates <- as.Date(
  sub("_.*$", "", dimnames(cases)[[3]])
)

stopifnot(
  !anyNA(raw_dates),
  !anyDuplicated(raw_dates)
)

raw_years <- as.integer(format(raw_dates, "%G"))

keep <- which(raw_years %in% study_years)

dates <- raw_dates[keep]
years <- raw_years[keep]
weeks <- as.integer(format(dates, "%V"))

stopifnot(
  setequal(unique(years), study_years),
  length(dates) == 261L,
  !anyNA(cases[, , keep, drop = FALSE]),
  all(is.finite(cases[, , keep, drop = FALSE])),
  all(cases[, , keep, drop = FALSE] >= 0)
)

# Identify Berlin districts
berlin <- sprintf("110%02d", 1:12)

b <- which(map$geo_code %in% berlin)
other <- which(!map$geo_code %in% berlin)

stopifnot(
  length(b) == 12L,
  length(other) == 399L
)

# 3. Prepare age-specific annual RKI population
pop[, geo_code := map$geo_code[
  match(geo_code, map$Id)
]]

stopifnot(!anyNA(pop$geo_code))

annual <- pop[
  year %in% study_years,
  .(
    geo_code,
    age_group = as.character(age_name),
    year = as.integer(year),
    population = as.numeric(population)
  )
]

stopifnot(
  !anyDuplicated(
    annual,
    by = c("geo_code", "age_group", "year")
  )
)

# Merge Berlin population within age-year groups
bp <- annual[
  geo_code %in% berlin,
  .(
    n = .N,
    population = sum(population)
  ),
  by = .(age_group, year)
]

bp <- bp[
  CJ(
    age_group = ages[!is.na(ages) & ages != "NA"],
    year = study_years
  ),
  on = .(age_group, year)
]

# Incomplete Berlin population groups remain missing
bp[
  is.na(n) | n != 12L,
  population := NA_real_
]

annual <- rbind(
  annual[!geo_code %in% berlin],
  bp[
    ,
    .(
      geo_code = "11000",
      age_group,
      year,
      population
    )
  ],
  use.names = TRUE
)

setorder(annual, geo_code, age_group, year)

# 4. Merge Berlin cases and recalculate Berlin incidence
bc <- apply(
  cases[, b, keep, drop = FALSE],
  c(1, 3),
  sum
)

idx <- match(
  paste(
    rep(ages, times = length(dates)),
    rep(years, each = length(ages))
  ),
  paste(bp$age_group, bp$year)
)

denom <- bp$population[idx]

denom[
  !is.na(denom) & denom <= 0
] <- NA_real_

n_age <- length(ages)
n_week <- length(dates)

count2 <- array(
  NA_real_,
  dim = c(n_age, 400L, n_week)
)

inc2 <- array(
  NA_real_,
  dim = c(n_age, 400L, n_week)
)

count2[, 1:399, ] <- cases[
  , other, keep, drop = FALSE
]

inc2[, 1:399, ] <- inc[
  , other, keep, drop = FALSE
]

count2[, 400, ] <- bc

inc2[, 400, ] <- matrix(
  as.vector(bc) / denom * 100000,
  nrow = n_age,
  ncol = n_week
)

# Verify case preservation for every week
raw_weekly_totals <- apply(
  cases[, , keep, drop = FALSE],
  3,
  sum
)

merged_weekly_totals <- apply(
  count2,
  3,
  sum
)

stopifnot(
  isTRUE(
    all.equal(
      as.numeric(raw_weekly_totals),
      as.numeric(merged_weekly_totals),
      tolerance = 1e-10
    )
  )
)

# 5. Build age-specific weekly data
weekly <- data.table(
  geo_code = rep(
    c(map$geo_code[other], "11000"),
    each = n_age,
    times = n_week
  ),
  age_group = rep(
    ages,
    times = 400L * n_week
  ),
  week_start = rep(
    dates,
    each = 400L * n_age
  ),
  iso_year = rep(
    years,
    each = 400L * n_age
  ),
  iso_week = rep(
    weeks,
    each = 400L * n_age
  ),
  count = as.vector(count2),
  incidence = as.vector(inc2)
)

weekly[
  is.na(age_group) | age_group == "NA",
  incidence := NA_real_
]

setorder(
  weekly,
  geo_code,
  age_group,
  week_start
)

# 6. Build monthly data
# Assign each weekly count to the month containing Monday.
monthly <- weekly[
  ,
  .(
    count = sum(count)
  ),
  by = .(
    geo_code,
    age_group,
    month = as.Date(
      format(week_start, "%Y-%m-01")
    )
  )
]

# Preserve the original monthly boundary rule.
# ISO week 2020-W01 starts in December 2019 and is excluded here.
monthly <- monthly[
  month >= as.Date("2020-01-01") &
    month <= as.Date("2024-12-01")
]

monthly[
  ,
  year := as.integer(format(month, "%Y"))
]

monthly <- merge(
  monthly,
  annual,
  by = c("geo_code", "age_group", "year"),
  all.x = TRUE,
  sort = FALSE
)

monthly[
  ,
  incidence := fifelse(
    !is.na(population) &
      population > 0 &
      !is.na(age_group) &
      age_group != "NA",
    count / population * 100000,
    NA_real_
  )
]

monthly[, population := NULL]

setcolorder(
  monthly,
  c(
    "geo_code",
    "age_group",
    "month",
    "year",
    "count",
    "incidence"
  )
)

setorder(
  monthly,
  geo_code,
  age_group,
  month
)

# 7. Validate outputs
# The 2023 reference is used only to check district codes.
ref <- as.character(
  readRDS(
    "data_processed/raumgliederungen_kreis_2023.rds"
  )$geo_code
)

stopifnot(
  setequal(unique(weekly$geo_code), ref),
  setequal(unique(monthly$geo_code), ref),
  setequal(unique(annual$geo_code), ref),
  
  setequal(unique(weekly$iso_year), study_years),
  setequal(unique(monthly$year), study_years),
  setequal(unique(annual$year), study_years),
  
  uniqueN(weekly$week_start) == 261L,
  
  !anyDuplicated(
    weekly,
    by = c("geo_code", "age_group", "week_start")
  ),
  !anyDuplicated(
    monthly,
    by = c("geo_code", "age_group", "month")
  ),
  !anyDuplicated(
    annual,
    by = c("geo_code", "age_group", "year")
  ),
  
  all(
    weekly[
      , uniqueN(geo_code), by = iso_year
    ]$V1 == 400L
  ),
  all(
    annual[
      , uniqueN(geo_code), by = year
    ]$V1 == 400L
  ),
  
  nrow(weekly) == 400L * n_age * 261L
)

# 8. Save prepared data
dir.create(
  "data_processed",
  showWarnings = FALSE
)

saveRDS(
  weekly,
  "data_processed/rki_weekly_long.rds"
)

saveRDS(
  monthly,
  "data_processed/rki_monthly_long.rds"
)

saveRDS(
  annual,
  "data_processed/rki_population_annual.rds"
)
