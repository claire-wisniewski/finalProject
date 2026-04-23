#!/bin/bash

CSV_PATH=$1

python3 p_rand_forest.py "$CSV_PATH" --noise-model gaussian
python3 p_rand_forest.py "$CSV_PATH" --noise-model laplace
python3 p_rand_forest.py "$CSV_PATH" --noise-model poisson
