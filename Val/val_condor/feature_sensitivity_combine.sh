#!/bin/bash

feature_gaussian=$1
feature_laplace=$2
feature_poisson=$3

farm_name=$(basename "$feature_gaussian" | sed 's/_gaussian_feature_sensitivity\.csv//')

outfile="${farm_name}_combined_feature_sensitivity.csv"

awk -F, 'BEGIN{OFS=","}
NR==1 {print $0,"noise_model"}
NR>1  {print $0,"gaussian"}' "$feature_gaussian" > "$outfile"

awk -F, 'BEGIN{OFS=","}
NR>1 {print $0,"laplace"}' "$feature_laplace" >> "$outfile"

awk -F, 'BEGIN{OFS=","}
NR>1 {print $0,"poisson"}' "$feature_poisson" >> "$outfile"
