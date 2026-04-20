#!/usr/bin/env Rscript

df = read.csv("season_summary.csv", stringsAsFactors = FALSE)

df$avg_wind_speed = df$total_wind_speed / df$count_wind_speed
df$avg_rotor_speed = df$total_rotor_speed / df$count_rotor_speed

write.csv(df, "season_summary.csv", row.names = FALSE)
