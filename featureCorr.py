import pandas as pd
import numpy as np

data = pd.read.csv("~/cleaned_data/WindFarmA_combined.csv")
df = pd.DataFrame(data.data, columns=data.feature_names)
df['anomaly_indicator'] = pd.Series(data.anomaly_indicator)
corrmatrix = df.corr()
corr_with_target = corr_matrix['anomaly_indicator']

k=10
top_k=corr_with_target.abs().sort_values(ascending=False)[:k].index
selected_features=df[top_k]

selected_corr_matrix = selected_features.corr()
print(selected_corr_matrix)
