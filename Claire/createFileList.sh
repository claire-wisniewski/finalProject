#!/bin/bash

find cleaned_data/WindFarmA -name "*.csv" > file_list.txt
find cleaned_data/WindFarmB -name "*.csv" >> file_list.txt
find cleaned_data/WindFarmC -name "*.csv" >> file_list.txt

echo "Created file_list.txt with $(wc -l < file_list.txt) files."
