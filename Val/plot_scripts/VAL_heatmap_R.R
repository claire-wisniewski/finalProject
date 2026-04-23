library(data.table)

noise_order <- c("gaussian", "laplace", "poisson")

datasets_feat <- list(
  A = fread("WindFarmA_combined_feature_sensitivity.csv"),
  B = fread("WindFarmB_combined_feature_sensitivity.csv"),
  C = fread("WindFarmC_combined_feature_sensitivity.csv")
)

plot_feature_agreement <- function(farm_label, feat_df, col_1, col_2) {
  feat_df <- copy(feat_df)
  names(feat_df) <- make.unique(names(feat_df))
  feat_df[, noise_model := tolower(as.character(noise_model))]
  
  required_cols <- c("feature", "sensitivity", "noise_model")
  missing <- setdiff(required_cols, names(feat_df))
  
  feat_df <- feat_df[, .(feature, sensitivity, noise_model)]
  
  wide <- dcast(
    feat_df,
    feature ~ noise_model,
    value.var = "sensitivity",
    fun.aggregate = mean
  )
  
  keep_cols <- intersect(noise_order, names(wide))
  wide <- wide[, c("feature", keep_cols), with = FALSE]
  
  if (length(keep_cols) > 0) {
    wide <- wide[complete.cases(wide[, ..keep_cols])]
  }

  
  corr_mat <- matrix(
    NA_real_,
    nrow = length(noise_order),
    ncol = length(noise_order),
    dimnames = list(noise_order, noise_order)
  )
  
  for (n1 in noise_order) {
    for (n2 in noise_order) {
      if (n1 %in% names(wide) && n2 %in% names(wide)) {
        corr_mat[n1, n2] <- suppressWarnings(
          cor(wide[[n1]], wide[[n2]], method = "spearman", use = "complete.obs")
        )
      }
    }
  }
  
  pal <- colorRampPalette(c(col_1, "white", col_2))(200)
  
  svg(sprintf("feature_agreement_farm_%s.svg", farm_label), width = 5.2, height = 4.6)
  
  par(mar = c(4.5, 4.5, 3, 5))
  
  image(
    1:ncol(corr_mat),
    1:nrow(corr_mat),
    t(corr_mat[nrow(corr_mat):1, ]),
    col = pal,
    zlim = c(-1, 1),
    axes = FALSE,
    xlab = "Noise Model",
    ylab = "Noise Model",
    main = paste("Feature Sensitivity Agreement (Farm", farm_label, ")")
  )
  
  axis(1, at = 1:3, labels = c("Gaussian", "Laplace", "Poisson"))
  axis(2, at = 1:3, labels = rev(c("Gaussian", "Laplace", "Poisson")))
  
  abline(v = seq(0.5, 3.5, by = 1), col = "gray70")
  abline(h = seq(0.5, 3.5, by = 1), col = "gray70")
  
  for (i in 1:nrow(corr_mat)) {
    for (j in 1:ncol(corr_mat)) {
      val <- corr_mat[i, j]
      if (!is.na(val)) {
        text(j, 4 - i, labels = sprintf("%.2f", val), cex = 0.9, font = 2)
      }
    }
  }
  
  usr <- par("usr")
  xleft <- usr[2] + 0.2
  xright <- usr[2] + 0.45
  ybottom <- usr[3]
  ytop <- usr[4]
  
  yvals <- seq(ybottom, ytop, length.out = length(pal) + 1)
  for (k in seq_along(pal)) {
    rect(xleft, yvals[k], xright, yvals[k + 1], col = pal[k], border = pal[k], xpd = NA)
  }
  
  axis(
    4,
    at = seq(ybottom, ytop, length.out = 5),
    labels = sprintf("%.1f", seq(-1, 1, length.out = 5)),
    las = 1
  )
  
  mtext("Spearman Correlation", side = 4, line = 3)
  box()
  dev.off()
  
  print(corr_mat)
  invisible(corr_mat)
}

corr_A <- plot_feature_agreement("A", datasets_feat[["A"]], "#C7E6F4", "#F4C7D9")
corr_B <- plot_feature_agreement("B", datasets_feat[["B"]], "#D9D3F2", "#C8F4E6")
corr_C <- plot_feature_agreement("C", datasets_feat[["C"]], "#C7E6F4", "#F7D9C4")