args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Usage: Rscript make_direction_summary.R <local_input_csv> <original_path>")
}

input_file <- args[1]
orig_path <- args[2]

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# infer farm from ORIGINAL path, not local filename
farm_name <- if (grepl("WindFarmA", orig_path)) {
  "WindFarmA"
} else if (grepl("WindFarmB", orig_path)) {
  "WindFarmB"
} else {
  stop("Could not infer farm from path: ", orig_path)
}

df <- read_csv(input_file, show_col_types = FALSE)

df <- df %>%
  select(time_stamp, asset_id, train_test, avg_wind_abs_direction) %>%
  filter(train_test == "train") %>%
  filter(!is.na(time_stamp), !is.na(avg_wind_abs_direction))

if (nrow(df) == 0) {
  message("No usable rows in ", input_file)
  quit(save = "no", status = 0)
}

df <- df %>%
  mutate(
    time_stamp = as.POSIXct(time_stamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    month_num = as.integer(format(time_stamp, "%m")),
    season = case_when(
      month_num %in% c(3, 4, 5) ~ "Spring",
      month_num %in% c(6, 7, 8) ~ "Summer",
      month_num %in% c(9, 10, 11) ~ "Fall",
      TRUE ~ "Winter"
    ),
    direction_sector = case_when(
      (avg_wind_abs_direction >= 337.5 & avg_wind_abs_direction <= 360) |
        (avg_wind_abs_direction >= 0 & avg_wind_abs_direction < 22.5) ~ "N",
      avg_wind_abs_direction >= 22.5  & avg_wind_abs_direction < 67.5  ~ "NE",
      avg_wind_abs_direction >= 67.5  & avg_wind_abs_direction < 112.5 ~ "E",
      avg_wind_abs_direction >= 112.5 & avg_wind_abs_direction < 157.5 ~ "SE",
      avg_wind_abs_direction >= 157.5 & avg_wind_abs_direction < 202.5 ~ "S",
      avg_wind_abs_direction >= 202.5 & avg_wind_abs_direction < 247.5 ~ "SW",
      avg_wind_abs_direction >= 247.5 & avg_wind_abs_direction < 292.5 ~ "W",
      avg_wind_abs_direction >= 292.5 & avg_wind_abs_direction < 337.5 ~ "NW",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(season), !is.na(direction_sector))

if (nrow(df) == 0) {
  message("No valid season/direction rows in ", input_file)
  quit(save = "no", status = 0)
}

summary_df <- df %>%
  count(asset_id, season, direction_sector, name = "n") %>%
  group_by(asset_id, season) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  mutate(
    farm = farm_name,
    source_file = basename(input_file)
  ) %>%
  select(farm, asset_id, source_file, season, direction_sector, n, prop)

base_name <- tools::file_path_sans_ext(basename(input_file))
out_file <- paste0(farm_name, "_", base_name, "_direction_summary.csv")

write_csv(summary_df, out_file)
cat("Wrote", out_file, "\n")