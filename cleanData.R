#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Usage: script.R <input_dir> <output_dir>")
}

inputPath <- args[1]
outputDir <- args[2]

library(data.table)
library(dplyr)

if (!dir.exists(inputPath)) {
  stop("Must be a directory")
}

if (!dir.exists(outputDir)) {
  dir.create(outputDir, recursive = TRUE)
}

files <- list.files(
  inputPath,
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

if (length(files) == 0) {
  stop("No CSV files found in input directory")
}

dirName <- basename(inputPath)

map_A <- c(
  "time_stamp" = "time_stamp",
  "asset_id" = "asset_id",
  "train_test" = "train_test",
  "status_type" = "status_type_id",
  "avg_temp" = "sensor_0_avg",
  "avg_wind_speed" = "wind_speed_3_avg",
  "power_avg" = "power_29_avg",
  "min_wind_speed" = "wind_speed_3_min",
  "max_wind_speed" = "wind_speed_3_max",
  "avg_wind_abs_direction" = "sensor_1_avg",
  "avg_wind_rel_direction" = "sensor_2_avg",
  "avg_rotor_speed" = "sensor_52_avg",
  "min_rotor_speed" = "sensor_52_min",
  "max_rotor_speed" = "sensor_52_max",
  "voltage_1" = "sensor_32_avg",
  "voltage_2" = "sensor_33_avg",
  "voltage_3" = "sensor_34_avg"
)

map_B <- c(
  "time_stamp" = "time_stamp",
  "asset_id" = "asset_id",
  "train_test" = "train_test",
  "status_type" = "status_type_id",
  "avg_temp" = "sensor_8_avg",
  "min_temp" = "sensor_8_min",
  "max_temp" = "sensor_8_max",
  "avg_wind_speed" = "wind_speed_61_avg",
  "power_avg" = "sensor_3_avg",
  "min_wind_speed" = "wind_speed_61_min",
  "max_wind_speed" = "wind_speed_61_max",
  "avg_wind_abs_direction" = "sensor_4_avg",
  "avg_rotor_speed" = "sensor_25_avg",
  "min_rotor_speed" = "sensor_25_min",
  "max_rotor_speed" = "sensor_25_max",
  "grid_freq" = "sensor_23_avg",
  "grid_voltage" = "sensor_24_avg"
)

map_C <- c(
  "time_stamp" = "time_stamp",
  "asset_id" = "asset_id",
  "train_test" = "train_test",
  "status_type" = "status_type_id",
  "avg_temp" = "sensor_7_avg",
  "min_temp" = "sensor_7_min",
  "max_temp" = "sensor_7_max",
  "avg_wind_speed" = "wind_speed_235_avg",
  "power_avg" = "power_6_avg",
  "min_wind_speed" = "wind_speed_235_min",
  "max_wind_speed" = "wind_speed_235_max",
  "avg_wind_rel_direction" = "sensor_125_avg",
  "avg_rotor_speed" = "sensor_144_avg",
  "min_rotor_speed" = "sensor_144_min",
  "max_rotor_speed" = "sensor_144_max"
)

if (startsWith(dirName, "WindFarmA")) {
  map <- map_A
} else if (startsWith(dirName, "WindFarmB")) {
  map <- map_B
} else if (startsWith(dirName, "WindFarmC")) {
  map <- map_C
} else {
  stop("Unknown directory")
}

for (path in files) {
  file_name <- basename(path)

  if (startsWith(file_name, "comma_")) {
    message("Skipping file starting with 'comma_': ", path)
    next
  }

  if (file_name == "event_info.csv") {
    output_file <- file.path(outputDir, paste0(dirName, "_", file_name))
    file.copy(path, output_file, overwrite = TRUE)
    message("Copied event_info.csv to: ", output_file)
    next
  }

  data <- tryCatch(
    fread(path),
    error = function(e) {
      message("Skipping file due to fread error: ", path)
      return(NULL)
    }
  )

  if (is.null(data)) {
    next
  }

  required_cols <- unique(c("train_test", unname(map)))
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    message(
      "Skipping file due to missing columns: ", path,
      "\nMissing: ", paste(missing_cols, collapse = ", ")
    )
    next
  }

  cleaned <- tryCatch({
    data %>%
      rename(!!!map) %>%
      mutate(
        anomaly_indicator = case_when(
          status_type %in% c(0, 2) ~ 0L,
          status_type %in% c(1, 3, 4, 5) ~ 1L,
          TRUE ~ NA_integer_
        )
      ) %>%
      select(any_of(c(names(map), "anomaly_indicator")))
  }, error = function(e) {
    message("Skipping file due to processing error: ", path)
    return(NULL)
  })

  if (is.null(cleaned)) {
    next
  }

  if (ncol(cleaned) == 0) {
    message("Skipping file with no matching columns after processing: ", path)
    next
  }

  base_name <- tools::file_path_sans_ext(file_name)
  output_file <- file.path(outputDir, paste0(base_name, "_cleaned.csv"))

  tryCatch(
    fwrite(cleaned, output_file),
    error = function(e) {
      message("Failed to write output for file: ", path)
    }
  )
}
