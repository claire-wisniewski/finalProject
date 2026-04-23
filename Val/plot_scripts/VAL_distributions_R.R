library(ggplot2)
library(gridExtra)

make_dist_df <- function(file) {
  df <- read.csv(file)
  df <- df[tolower(df$noise_model) == "gaussian", ]
  
  data.frame(
    prob = df$y_prob,
    true_class = factor(df$y_true, levels = c(1, 0))
  )
}

plot_distribution <- function(df, title_text, col_1, col_2) {
  ggplot(df, aes(x = prob, fill = true_class)) +
    geom_histogram(aes(y = ..density..), bins = 50, alpha = 0.85, position = "identity") +
    geom_vline(xintercept = 0.5, linetype = "dashed", linewidth = 1) +
    scale_fill_manual(
      values = c("1" = col_1, "0" = col_2),
      labels = c("1" = "True class = 1", "0" = "True class = 0")
    ) +
    labs(
      title = paste0(title_text, " (Gaussian)"),
      x = "Predicted Probability",
      y = "Density",
      fill = "Class"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "top"
    )
}

df_A <- make_dist_df("WindFarmA_combined_prediction_results.csv")
df_B <- make_dist_df("WindFarmB_combined_prediction_results.csv")
df_C <- make_dist_df("WindFarmC_combined_prediction_results.csv")

p1 <- plot_distribution(df_A, "Wind Farm A", "#C7E6F4", "#F4C7D9")
p2 <- plot_distribution(df_B, "Wind Farm B", "#D9D3F2", "#C8F4E6")
p3 <- plot_distribution(df_C, "Wind Farm C", "#C7E6F4", "#F7D9C4")

svg("windfarm_distributions_gaussian_only.svg", width = 14, height = 5)
grid.arrange(p1, p2, p3, ncol = 3)
dev.off()