args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Usage: Rscript make_anomaly_summary.R <local_input_csv> <original_path>")
}

input_file <- args[1]
orig_path <- args[2]

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

farm_name <- if (grepl("WindFarmA", orig_path)) {
  "WindFarmA"
} else if (grepl("WindFarmB", orig_path)) {
  "WindFarmB"
} else if (grepl("WindFarmC", orig_path)) {
  "WindFarmC"
} else {
  stop("Could not infer farm from path: ", orig_path)
}

df <- read_csv(input_file, show_col_types = FALSE)

required_cols <- c("train_test", "avg_wind_speed", "anomaly_indicator")
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
}

df <- df %>%
  filter(train_test == "train") %>%
  filter(!is.na(avg_wind_speed), !is.na(anomaly_indicator)) %>%
  filter(avg_wind_speed >= 0, avg_wind_speed <= 25) %>%
  mutate(
    wind_speed_bin = case_when(
      avg_wind_speed < 2  ~ "0-2",
      avg_wind_speed < 4  ~ "2-4",
      avg_wind_speed < 6  ~ "4-6",
      avg_wind_speed < 8  ~ "6-8",
      avg_wind_speed < 12 ~ "8-12",
      TRUE                ~ "12+"
    )
  )

if (farm_name %in% c("WindFarmA", "WindFarmB")) {
  if (!("avg_wind_abs_direction" %in% names(df))) {
    stop("avg_wind_abs_direction missing for ", farm_name)
  }

  df <- df %>%
    filter(!is.na(avg_wind_abs_direction)) %>%
    mutate(
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
    filter(!is.na(direction_sector))
} else {
  df <- df %>%
    mutate(direction_sector = NA_character_)
}

summary_df <- df %>%
  count(direction_sector, wind_speed_bin, anomaly_indicator, name = "n") %>%
  mutate(farm = farm_name) %>%
  select(farm, direction_sector, wind_speed_bin, anomaly_indicator, n)

out_file <- paste0(farm_name, "_anomaly_summary.csv")
write_csv(summary_df, out_file)

cat("Wrote", out_file, "\n")