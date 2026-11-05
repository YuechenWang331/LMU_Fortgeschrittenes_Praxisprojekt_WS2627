library(data.table)

# 1. Read raw data
map <- fread("data_raw/CountyKey71Map.csv",
             colClasses = "character")
map[, geo_code := sub("^\\[([0-9]{5})\\]$", "\\1", ComponentId)]

cases <- readRDS("data_raw/Count_COVID_LK_Week_RKI_2020_2024.RData")
inc <- readRDS("data_raw/Incidence_COVID_LK_Week_RKI_2020_2024.RData")
pop <- as.data.table(as.data.frame(
  readRDS("data_raw/Count_Bev_LK_RKI_2020_2024.RData")
))

stopifnot(
  nrow(map) == 411,
  identical(dimnames(cases), dimnames(inc)),
  identical(dimnames(cases)[[2]], map$Name)
)

# 2. Select years and regions
ages <- dimnames(cases)[[1]]
dates <- as.Date(sub("_.*$", "", dimnames(cases)[[3]]))
keep <- which(as.integer(format(dates, "%G")) %in% 2020:2023)

dates <- dates[keep]
years <- as.integer(format(dates, "%G"))
weeks <- as.integer(format(dates, "%V"))

berlin <- sprintf("110%02d", 1:12)
b <- which(map$geo_code %in% berlin)
other <- which(!map$geo_code %in% berlin)

stopifnot(length(b) == 12, length(other) == 399)

# 3. Prepare annual population
pop[, geo_code := map$geo_code[match(geo_code, map$Id)]]
stopifnot(!anyNA(pop$geo_code))

annual <- pop[year %in% 2020:2023, .(
  geo_code,
  age_group = as.character(age_name),
  year = as.integer(year),
  population = as.numeric(population)
)]

# Merge Berlin population
bp <- annual[geo_code %in% berlin, .(
  n = .N,
  population = sum(population)
), by = .(age_group, year)]

bp <- bp[
  CJ(age_group = ages[ages != "NA"], year = 2020:2023),
  on = .(age_group, year)
]

bp[is.na(n) | n != 12, population := NA_real_]

annual <- rbind(
  annual[!geo_code %in% berlin],
  bp[, .(geo_code = "11000", age_group, year, population)]
)

setorder(annual, geo_code, age_group, year)

# 4. Merge Berlin cases and recalculate incidence
bc <- apply(cases[, b, keep, drop = FALSE], c(1, 3), sum)

idx <- match(
  paste(rep(ages, times = length(dates)),
        rep(years, each = length(ages))),
  paste(bp$age_group, bp$year)
)

denom <- bp$population[idx]
denom[!is.na(denom) & denom <= 0] <- NA_real_

n_age <- length(ages)
n_week <- length(dates)

count2 <- array(NA_real_, c(n_age, 400, n_week))
inc2 <- array(NA_real_, c(n_age, 400, n_week))

count2[, 1:399, ] <- cases[, other, keep]
inc2[, 1:399, ] <- inc[, other, keep]

count2[, 400, ] <- bc
inc2[, 400, ] <- as.vector(bc) / denom * 100000

# 5. Weekly dataset
weekly <- data.table(
  geo_code = rep(c(map$geo_code[other], "11000"),
                 each = n_age, times = n_week),
  age_group = rep(ages, times = 400 * n_week),
  week_start = rep(dates, each = 400 * n_age),
  iso_year = rep(years, each = 400 * n_age),
  iso_week = rep(weeks, each = 400 * n_age),
  count = as.vector(count2),
  incidence = as.vector(inc2)
)

weekly[age_group == "NA", incidence := NA_real_]
setorder(weekly, geo_code, age_group, week_start)

# 6. Monthly dataset
# Assign each week to the month containing Monday

monthly <- weekly[, .(
  count = sum(count)
), by = .(
  geo_code,
  age_group,
  month = as.Date(format(week_start, "%Y-%m-01"))
)]

# Remove December 2019 boundary week
monthly <- monthly[month >= as.Date("2020-01-01")]
monthly[, year := as.integer(format(month, "%Y"))]


# Calculate monthly incidence using annual population
monthly <- merge(
  monthly, annual,
  by = c("geo_code", "age_group", "year"),
  all.x = TRUE
)

monthly[, incidence := fifelse(
  !is.na(population) & population > 0 & age_group != "NA",
  count / population * 100000,
  NA_real_
)]

monthly[, population := NULL]

setcolorder(monthly, c(
  "geo_code", "age_group", "month",
  "year", "count", "incidence"
))
setorder(monthly, geo_code, age_group, month)

# 7. Essential checks
ref <- readRDS(
  "data_processed/raumgliederungen_kreis_2023.rds"
)$geo_code

stopifnot(
  setequal(unique(weekly$geo_code), ref),
  setequal(unique(monthly$geo_code), ref),
  setequal(unique(annual$geo_code), ref),
  !anyDuplicated(weekly, by = c("geo_code", "age_group", "week_start")),
  !anyDuplicated(monthly, by = c("geo_code", "age_group", "month")),
  !anyDuplicated(annual, by = c("geo_code", "age_group", "year")),
  all(annual[, uniqueN(geo_code), by = year]$V1 == 400)
)

# 8. Save
saveRDS(weekly, "data_processed/rki_weekly_long.rds")
saveRDS(monthly, "data_processed/rki_monthly_long.rds")
saveRDS(annual, "data_processed/rki_population_annual.rds")

cat("Weekly:", nrow(weekly), "rows\n")
cat("Monthly:", nrow(monthly), "rows\n")
cat("Annual population:", nrow(annual), "rows\n")
cat("Missing weekly counts:", sum(is.na(weekly$count)), "\n")
cat("Missing monthly incidence:", sum(is.na(monthly$incidence)), "\n")
cat("All checks passed.\n")

