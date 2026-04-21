#!/usr/bin/env Rscript

args = commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
    stop("Usage: computeAverages.R <file>")
}

file = args[1]

df = read.csv(file, stringsAsFactors = FALSE)

df$avg_wind_speed = df$total_wind_speed / df$count_wind_speed
df$avg_rotor_speed = df$total_rotor_speed / df$count_rotor_speed

write.csv(df, file, row.names = FALSE)
