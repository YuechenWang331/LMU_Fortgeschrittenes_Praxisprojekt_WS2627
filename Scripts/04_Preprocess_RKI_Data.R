# Prepare the T004-verified RKI snapshot; run from the project root.
# CountyKey71Map.csv is copied from F_Praktikum/Analyse/config/T004.
library(data.table)
library(digest)

paths <- c(
  map = "data_raw/CountyKey71Map.csv",
  count = "data_raw/Count_COVID_LK_Week_RKI_2020_2024.RData",
  incidence = "data_raw/Incidence_COVID_LK_Week_RKI_2020_2024.RData",
  population = "data_raw/Count_Bev_LK_RKI_2020_2024.RData"
)
# The region order was validated for this exact source snapshot in T004.
expected_sha256 <- c(
  map = "4c37086dc08690444ac4a52bff425217694fc0cdeaef866d887c31af87db76ad",
  count = "2a7d2159c20c7b0cf337bb6d8ca5e457130c474c4da941d50671c99a332e03e0",
  incidence = "e317405442773a2e050f83ba46374448b05cf9e963ca7b3e7adac433f2986ce1",
  population = "db8919a1a21af541ddc9d1909dc47c6819f6a63d0091fa6c780f032fa8ff869d"
)
stopifnot(all(vapply(paths, digest, character(1), algo = "sha256", file = TRUE) == expected_sha256))

map <- fread(paths["map"], colClasses = "character")
map[, geo_code := sub("^\\[([0-9]{5})\\]$", "\\1", ComponentId)]
count_raw <- readRDS(paths["count"])
incidence_raw <- readRDS(paths["incidence"])
population_raw <- as.data.table(as.data.frame(readRDS(paths["population"])))

ages <- dimnames(count_raw)[[1]]
weeks <- dimnames(count_raw)[[3]]
week_start <- as.Date(sub("_.*$", "", weeks))
iso_year <- as.integer(format(week_start, "%G"))
iso_week <- as.integer(format(week_start, "%V"))
berlin_codes <- sprintf("110%02d", 1:12)
berlin_pos <- which(map$geo_code %in% berlin_codes)
other_pos <- which(!map$geo_code %in% berlin_codes)

stopifnot(
  nrow(map) == 411L,
  identical(as.integer(map$region_position), seq_len(nrow(map))),
  !anyDuplicated(map$Id), !anyDuplicated(map$geo_code),
  all(grepl("^[0-9]{5}$", map$geo_code)),
  identical(dimnames(count_raw), dimnames(incidence_raw)),
  identical(dimnames(count_raw)[[2]], map$Name),
  identical(ages, c(as.character(0:79), "80+", "NA")),
  length(berlin_pos) == 12L, setequal(map$geo_code[berlin_pos], berlin_codes),
  length(other_pos) == 399L, !"11000" %in% map$geo_code,
  !anyNA(week_start), !anyDuplicated(week_start),
  all(format(week_start, "%u") == "1"),
  all(as.integer(sub("^.*_", "", weeks)) == iso_year),
  identical(sort(unique(iso_year)), 2020:2024)
)

# Map population by the complete SurvStat ID, never by the district name.
population_raw[, map_index := match(geo_code, map$Id)]
stopifnot(!anyNA(population_raw$map_index),
          !anyDuplicated(population_raw, by = c("geo_code", "age_name", "year")))
population <- population_raw[, .(
  geo_code = map$geo_code[map_index], geo_name = map$Name[map_index],
  age_group = age_name, year, population
)]

# Require all 12 districts for each Berlin age/year sum. A small Berlin-only
# grid also preserves NA when an entire age/year group is absent.
berlin_population <- population[geo_code %in% berlin_codes,
  .(districts = .N, population = sum(population)), by = .(age_group, year)]
berlin_population[districts != 12L, population := NA_real_]
berlin_grid <- CJ(age_group = ages[ages != "NA"], year = sort(unique(iso_year)))
berlin_population <- berlin_population[berlin_grid, on = .(age_group, year)]
berlin_population[, c("geo_code", "geo_name") := .("11000", "Berlin")]
annual <- rbindlist(list(
  population[!geo_code %in% berlin_codes],
  berlin_population[, .(geo_code, geo_name, age_group, year, population)]
))
setorder(annual, geo_code, age_group, year)
stopifnot(uniqueN(annual$geo_code) == 400L,
          !anyDuplicated(annual, by = c("geo_code", "age_group", "year")))

# Sum district counts without removing NAs; compute Berlin incidence from the
# corresponding ISO year's summed population, not the district incidences.
berlin_count <- apply(count_raw[, berlin_pos, , drop = FALSE], c(1, 3), sum)
pop_index <- match(
  paste(rep(ages, times = length(weeks)), rep(iso_year, each = length(ages))),
  paste(berlin_population$age_group, berlin_population$year)
)
denominator <- berlin_population$population[pop_index]
denominator[!is.na(denominator) & denominator <= 0] <- NA_real_
berlin_incidence <- as.vector(berlin_count) / denominator * 100000

# Keep the original non-Berlin values in their validated array positions.
n_age <- length(ages); n_week <- length(weeks); n_geo <- 400L
count <- array(NA_real_, dim = c(n_age, n_geo, n_week))
incidence <- array(NA_real_, dim = c(n_age, n_geo, n_week))
count[, seq_along(other_pos), ] <- count_raw[, other_pos, ]
count[, n_geo, ] <- berlin_count
incidence[, seq_along(other_pos), ] <- incidence_raw[, other_pos, ]
incidence[, n_geo, ] <- berlin_incidence
stopifnot(identical(as.vector(apply(count_raw, c(1, 3), sum)),
                    as.vector(apply(count, c(1, 3), sum))))

weekly <- data.table(
  geo_code = rep(c(map$geo_code[other_pos], "11000"), each = n_age, times = n_week),
  geo_name = rep(c(map$Name[other_pos], "Berlin"), each = n_age, times = n_week),
  age_group = rep(ages, times = n_geo * n_week),
  week_start = rep(week_start, each = n_geo * n_age),
  iso_year = rep(iso_year, each = n_geo * n_age),
  iso_week = rep(iso_week, each = n_geo * n_age),
  count = as.vector(count), incidence = as.vector(incidence)
)
weekly[age_group == "NA", incidence := NA_real_]
setorder(weekly, geo_code, age_group, week_start)
stopifnot(uniqueN(weekly$geo_code) == 400L,
          !anyDuplicated(weekly, by = c("geo_code", "age_group", "iso_year", "iso_week")))

cat("Annual:", nrow(annual), "rows; Berlin missing population:",
    sum(is.na(berlin_population$population)), "\n")
cat("Missing non-Berlin age/year population combinations:",
    length(other_pos) * (length(ages) - 1L) * length(unique(iso_year)) -
      nrow(population[!geo_code %in% berlin_codes]), "\n")
cat("Weekly:", nrow(weekly), "rows; missing counts:", sum(is.na(weekly$count)),
    "; missing incidence:", sum(is.na(weekly$incidence)), "\n")
saveRDS(annual, "data_processed/rki_population_annual.rds")
saveRDS(weekly, "data_processed/rki_weekly_long.rds")
