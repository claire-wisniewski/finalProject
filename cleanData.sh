#!/bin/bash

Rscript -e "packages <- c('dplyr','data.table'); installed <- rownames(installed.packages()); to_install <- setdiff(packages, installed); if(length(to_install)) install.packages(to_install, repos='https://cloud.r-project.org')"

BASE_DIR="."
OUT_DIR="./cleaned_data"

mkdir -p "$OUT_DIR"

for farm in WindFarmA WindFarmB WindFarmC
do
    INPUT_PATH="$BASE_DIR/$farm"
    OUTPUT_PATH="$OUT_DIR/$farm"

    mkdir -p "$OUTPUT_PATH"

    Rscript cleanData.R "$INPUT_PATH" "$OUTPUT_PATH"

    OUTPUT_FILE="$OUT_DIR/${farm}_combined.csv"
    first=1

    for file in "$OUTPUT_PATH"/*_cleaned.csv; do
        [ -f "$file" ] || continue

        if [ $first -eq 1 ]; then
            cat "$file" > "$OUTPUT_FILE"
            first=0
        else
            tail -n +2 "$file" >> "$OUTPUT_FILE"
        fi
    done
done
