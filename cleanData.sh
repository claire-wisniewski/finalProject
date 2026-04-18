#!/bin/bash

Rscript -e "install.packages('dplyr', repos='https://cloud.r-project.org')"

BASE_DIR="."

OUT_DIR="./cleaned_data"

mkdir -p "$OUT_DIR"

for farm in WindFarmA WindFarmB WindFarmC
do
    INPUT_PATH="$BASE_DIR/$farm"
    OUTPUT_PATH="$OUT_DIR/$farm"

    mkdir -p "$OUTPUT_PATH"

    Rscript cleanData.R "$INPUT_PATH" "$OUTPUT_PATH"
done
