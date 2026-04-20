import pandas as pd
import numpy as np
import os

path = os.path.expanduser("cleaned_data/WindFarmA_combined.csv")
df = pd.read_csv(path)

corr_matrix = df.corr(numeric_only=True)
corr_with_target = corr_matrix['anomaly_indicator']

k=12
top_k=corr_with_target.abs().sort_values(ascending=False)[:k].index
selected_features=df[top_k]

selected_corr_matrix = selected_features.corr()
print(selected_corr_matrix)
