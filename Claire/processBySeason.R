#!/usr/bin/env Rscript

args = commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
    stop("Usage: script.R <input_file> <output_file>")
}

inputFile = args[1]
outputFile = args[2]

# identify wind farm
if (grepl("WindFarmA", inputFile)) {
    windFarm = "A"
} else if (grepl("WindFarmB", inputFile)) {
    windFarm = "B"
} else if (grepl("WindFarmC", inputFile)) {
    windFarm = "C"
} else {
    stop("Input file path must contain WindFarmA, WindFarmB, or WindFarmC")
}

# read in data and check for required columns
df = read.csv(inputFile, stringsAsFactors = FALSE)
cols = c("time_stamp", "avg_wind_speed", "avg_rotor_speed", "train_test")
missing = setdiff(cols, names(df))
if (length(missing) > 0) {
    stop(paste("Missing columns:", paste(missing, collapse=", ")))
}

df$wind_farm = windFarm
df$avg_wind_speed = abs(as.numeric(df$avg_wind_speed))
df$avg_rotor_speed = abs(as.numeric(df$avg_rotor_speed))

# identify season
df$time_stamp = as.POSIXct(df$time_stamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
monthNum = as.integer(format(df$time_stamp, "%m"))
df$season = ifelse(monthNum %in% 3:5, "Spring",
             ifelse(monthNum %in% 6:8, "Summer",
             ifelse(monthNum %in% 9:11, "Fall",
                    "Winter")))

# summarize
summary_df = aggregate(
    cbind(avg_wind_speed, avg_rotor_speed) ~ wind_farm + season,
    data = df,
    FUN = function(x) c(total = sum(x, na.rm = TRUE), count = sum(!is.na(x)))
)

# flatten
summary_df$total_wind_speed = summary_df$avg_wind_speed[, "total"]
summary_df$count_wind_speed = summary_df$avg_wind_speed[, "count"]
summary_df$total_rotor_speed = summary_df$avg_rotor_speed[, "total"]
summary_df$count_rotor_speed = summary_df$avg_rotor_speed[, "count"]
summary_df$avg_wind_speed = NULL
summary_df$avg_rotor_speed = NULL

# create or append
if (!file.exists(outputFile)) {
    write.csv(summary_df, outputFile, row.names = FALSE)
} else {
    write.table(summary_df, outputFile, sep = ",", col.names = FALSE, row.names = FALSE,
                append = TRUE)
}
