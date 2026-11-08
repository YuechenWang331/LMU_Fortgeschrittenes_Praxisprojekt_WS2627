# Reusable candidate age-group definitions.

assign_age_groups <- function(data, scheme = "5-year") {
  scheme <- match.arg(scheme, c("5-year", "10-year", "broad"))

  data %>%
    dplyr::mutate(
      age = suppressWarnings(as.integer(as.character(age_group))),
      age_group_new = dplyr::case_when(
        as.character(age_group) == "80+" ~ "80+",
        scheme == "5-year" & !is.na(age) & age %in% 0:79 ~
          paste0((age %/% 5) * 5, "-", (age %/% 5) * 5 + 4),
        scheme == "10-year" & !is.na(age) & age %in% 0:79 ~
          paste0((age %/% 10) * 10, "-", (age %/% 10) * 10 + 9),
        scheme == "broad" & !is.na(age) & age %in% 0:4 ~ "0-4",
        scheme == "broad" & !is.na(age) & age %in% 5:14 ~ "5-14",
        scheme == "broad" & !is.na(age) & age %in% 15:24 ~ "15-24",
        scheme == "broad" & !is.na(age) & age %in% 25:49 ~ "25-49",
        scheme == "broad" & !is.na(age) & age %in% 50:64 ~ "50-64",
        scheme == "broad" & !is.na(age) & age %in% 65:79 ~ "65-79",
        TRUE ~ NA_character_
      )
    ) %>%
    dplyr::select(-age)
}

prepare_age_schemes <- function(data) {
  dplyr::bind_rows(
    assign_age_groups(data, "5-year") %>% dplyr::mutate(scheme = "5-year"),
    assign_age_groups(data, "10-year") %>% dplyr::mutate(scheme = "10-year"),
    assign_age_groups(data, "broad") %>% dplyr::mutate(scheme = "broad")
  )
}

age_group_metadata <- function(data) {
  data %>%
    dplyr::mutate(
      group_start = dplyr::if_else(
        age_group_new == "80+", 80L,
        as.integer(sub("-.*$", "", age_group_new))
      ),
      group_end = dplyr::if_else(
        age_group_new == "80+", NA_integer_,
        as.integer(sub("^.*-", "", age_group_new))
      ),
      age_mid = dplyr::if_else(
        age_group_new == "80+", 85,
        (group_start + group_end) / 2
      ),
      expected_ages = dplyr::if_else(
        age_group_new == "80+", 1L, group_end - group_start + 1L
      )
    )
}
