#!/bin/bash

prediction_gaussian=$1
prediction_laplace=$2
prediction_poisson=$3

farm_name=$(basename "$prediction_gaussian" | sed 's/_gaussian_prediction_results\.csv//')
outfile="${farm_name}_combined_prediction_results.csv"

awk -F, 'BEGIN{OFS=","}
NR==1 {print $0,"noise_model"}
NR>1  {print $0,"gaussian"}' "$prediction_gaussian" > "$outfile"

awk -F, 'BEGIN{OFS=","}
NR>1 {print $0,"laplace"}' "$prediction_laplace" >> "$outfile"

awk -F, 'BEGIN{OFS=","}
NR>1 {print $0,"poisson"}' "$prediction_poisson" >> "$outfile"
