#!/bin/bash
set -euo pipefail

ORIG_PATH="$1"
INPUT_FILE=$(basename "$ORIG_PATH")

echo "Running on: $(hostname)"
echo "Working dir: $(pwd)"
echo "Original path: ${ORIG_PATH}"
echo "Local input file: ${INPUT_FILE}"

Rscript make_anomaly_summary.R "${INPUT_FILE}" "${ORIG_PATH}"

echo "Done."
