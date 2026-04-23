import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import classification_report, roc_auc_score, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.utils.validation import check_is_fitted


class PerturbedRandomForestClassifier(BaseEstimator, ClassifierMixin):
    def __init__(
        self,
        n_trees=100,
        max_depth=None,
        min_samples_split=2,
        min_samples_leaf=1,
        max_features_per_tree=None,
        noise_std=0.1,
        n_trials=5,
        baseline_n_trees=100,
        random_state=42,
        noise_model="gaussian",
        class_weight=None,
        threshold=0.5,
    ):
        self.n_trees = n_trees
        self.max_depth = max_depth
        self.min_samples_split = min_samples_split
        self.min_samples_leaf = min_samples_leaf
        self.max_features_per_tree = max_features_per_tree
        self.noise_std = noise_std
        self.n_trials = n_trials
        self.baseline_n_trees = baseline_n_trees
        self.random_state = random_state
        self.noise_model = noise_model
        self.class_weight = class_weight
        self.threshold = threshold

        self.baseline_model_ = None
        self.feature_sensitivity_ = None
        self.feature_sensitivity_norm_ = None
        self.feature_sampling_prob_ = None
        self.trees_ = []
        self.tree_features_ = []
        self.feature_names_ = None
        self.classes_ = np.array([0, 1])
        self.n_features_in_ = None

    def _compute_fpsa(self, X_val, baseline_pos_probs):
        rng = np.random.default_rng(self.random_state)
        n_features = X_val.shape[1]
        sensitivities = np.zeros(n_features, dtype=float)

        for i in range(n_features):
            trial_scores = []
            feature_std = np.std(X_val[:, i])
            scaled_noise_std = self.noise_std * feature_std if feature_std > 0 else self.noise_std

            for _ in range(self.n_trials):
                X_perturbed = X_val.copy()

                if self.noise_model == "gaussian":
                    noise = rng.normal(0.0, scaled_noise_std, size=X_val.shape[0])
                elif self.noise_model == "laplace":
                    noise = rng.laplace(0.0, scaled_noise_std, size=X_val.shape[0])
                elif self.noise_model == "poisson":
                    lam = np.abs(X_val[:, i]) * self.noise_std
                    lam = np.clip(lam, 1e-6, None)
                    noise = rng.poisson(lam) - lam
                else:
                    raise ValueError("Something is wrong int the noise type part of the script")

                X_perturbed[:, i] += noise
                perturbed_pos_probs = self.baseline_model_.predict_proba(X_perturbed)[:, 1]
                score = np.mean(np.abs(perturbed_pos_probs - baseline_pos_probs))
                trial_scores.append(score)

            sensitivities[i] = np.mean(trial_scores)

        return sensitivities

    def _normalize_sensitivities(self, S):
        s_min = np.min(S)
        s_max = np.max(S)
        if np.isclose(s_max, s_min):
            return np.zeros_like(S)
        return (S - s_min) / (s_max - s_min)

    def fit(self, X_train, y_train, X_val, y_val=None, feature_names=None):
        rng = np.random.default_rng(self.random_state)

        X_train = np.asarray(X_train, dtype=float)
        y_train = np.asarray(y_train, dtype=int)
        X_val = np.asarray(X_val, dtype=float)

        unique_labels = np.unique(y_train)
        if not np.array_equal(np.sort(unique_labels), np.array([0, 1])):
            raise ValueError(
                "This classifier expects binary labels encoded as 0 and 1. "
                f"Found labels: {unique_labels}"
            )

        n_samples, n_features = X_train.shape
        self.n_features_in_ = n_features
        self.feature_names_ = feature_names if feature_names is not None else [f"x{i}" for i in range(n_features)]
        self.classes_ = np.array([0, 1])

        self.baseline_model_ = RandomForestClassifier(
            n_estimators=self.baseline_n_trees,
            max_depth=self.max_depth,
            min_samples_split=self.min_samples_split,
            min_samples_leaf=self.min_samples_leaf,
            random_state=self.random_state,
            n_jobs=-1,
            class_weight=self.class_weight,
        )
        self.baseline_model_.fit(X_train, y_train)

        baseline_pos_probs = self.baseline_model_.predict_proba(X_val)[:, 1]
        S = self._compute_fpsa(X_val, baseline_pos_probs)
        S_norm = self._normalize_sensitivities(S)

        self.feature_sensitivity_ = S
        self.feature_sensitivity_norm_ = S_norm

        raw_weights = 1.0 - S_norm
        if np.allclose(raw_weights.sum(), 0):
            probs = np.ones(n_features) / n_features
        else:
            probs = raw_weights / raw_weights.sum()

        self.feature_sampling_prob_ = probs

        if self.max_features_per_tree is None:
            m = max(1, int(np.sqrt(n_features)))
        else:
            m = min(max(1, self.max_features_per_tree), n_features)

        self.trees_ = []
        self.tree_features_ = []

        for tree_idx in range(self.n_trees):
            bootstrap_idx = rng.choice(n_samples, size=n_samples, replace=True)
            X_boot = X_train[bootstrap_idx]
            y_boot = y_train[bootstrap_idx]

            feat_idx = rng.choice(n_features, size=m, replace=False, p=probs)

            tree = DecisionTreeClassifier(
                max_depth=self.max_depth,
                min_samples_split=self.min_samples_split,
                min_samples_leaf=self.min_samples_leaf,
                random_state=self.random_state + tree_idx,
                class_weight=self.class_weight,
            )
            tree.fit(X_boot[:, feat_idx], y_boot)

            self.trees_.append(tree)
            self.tree_features_.append(feat_idx)

        return self

    def predict_proba(self, X):
        check_is_fitted(self, ["trees_", "tree_features_", "feature_sampling_prob_"])
        X = np.asarray(X, dtype=float)

        if len(self.trees_) == 0:
            raise ValueError("The model has no fitted trees. Call fit() first.")

        pos_probs = []
        for tree, feat_idx in zip(self.trees_, self.tree_features_):
            probs = tree.predict_proba(X[:, feat_idx])

            if probs.shape[1] == 2:
                pos_prob = probs[:, 1]
            else:
                present_class = tree.classes_[0]
                if present_class == 1:
                    pos_prob = probs[:, 0]
                else:
                    pos_prob = np.zeros(X.shape[0], dtype=float)

            pos_probs.append(pos_prob)

        mean_pos_prob = np.mean(np.column_stack(pos_probs), axis=1)
        mean_pos_prob = np.clip(mean_pos_prob, 0.0, 1.0)
        return np.column_stack([1.0 - mean_pos_prob, mean_pos_prob])

    def predict(self, X):
        pos_prob = self.predict_proba(X)[:, 1]
        return (pos_prob >= self.threshold).astype(int)

    def score(self, X, y):
        y = np.asarray(y)
        y_pred = self.predict(X)
        return np.mean(y_pred == y)

    def get_feature_importance_table(self):
        check_is_fitted(
            self,
            [
                "feature_names_",
                "feature_sensitivity_",
                "feature_sensitivity_norm_",
                "feature_sampling_prob_",
            ],
        )

        return pd.DataFrame(
            {
                "feature": self.feature_names_,
                "sensitivity": self.feature_sensitivity_,
                "sensitivity_norm": self.feature_sensitivity_norm_,
                "sampling_probability": self.feature_sampling_prob_,
            }
        ).sort_values("sensitivity_norm", ascending=False)


def _coerce_binary_target(series: pd.Series) -> pd.Series:
    if pd.api.types.is_bool_dtype(series):
        return series.astype(int)

    if pd.api.types.is_numeric_dtype(series):
        unique_vals = set(pd.Series(series).dropna().unique().tolist())
        if unique_vals.issubset({0, 1}):
            return series.astype(int)

    lowered = series.astype(str).str.strip().str.lower()
    mapping = {
        "0": 0,
        "1": 1,
        "false": 0,
        "true": 1,
        "normal": 0,
        "anomaly": 1,
        "no": 0,
        "yes": 1,
    }
    mapped = lowered.map(mapping)
    if mapped.isna().any():
        bad = series[mapped.isna()].dropna().unique()[:10]
        raise ValueError(f"ERORR!!! Example bad values: {bad}")
    return mapped.astype(int)


def load_wind_data(
    csv_path,
    target_col="anomaly_indicator",
    drop_cols=None,
):
    df = pd.read_csv(csv_path)

    if target_col not in df.columns:
        raise ValueError(f"Target column '{target_col}' not found. Columns are: {list(df.columns)}")

    if drop_cols is None:
        drop_cols = ["time_stamp", "asset_id", "train_test", "status_type"]

    y = _coerce_binary_target(df[target_col])

    feature_df = df.drop(columns=[c for c in [target_col] + drop_cols if c in df.columns]).copy()
    feature_df = feature_df.select_dtypes(include=[np.number]).copy()

    if feature_df.shape[1] == 0:
        raise ValueError("No numerical colums")

    feature_names = feature_df.columns.tolist()

    imputer = SimpleImputer(strategy="median")
    X_all = imputer.fit_transform(feature_df)

    meta_cols = [
        c for c in [
            "time_stamp",
            "asset_id",
            "train_test",
            "status_type",
            "power_avg",
            "avg_wind_speed",
            "avg_rotor_speed",
        ] if c in df.columns
    ]
    meta_df = df[meta_cols].copy()

    if "train_test" in df.columns:
        tt = df["train_test"].astype(str).str.strip().str.lower()
        train_mask = tt.isin(["train", "training"])
        test_mask = tt.isin(["test", "prediction", "pred", "predict", "validation"])

        if train_mask.any() and test_mask.any():
            X_train_full = X_all[train_mask.to_numpy()]
            y_train_full = y.loc[train_mask].to_numpy()

            X_test = X_all[test_mask.to_numpy()]
            y_test = y.loc[test_mask].to_numpy()

            test_meta_df = meta_df.loc[test_mask].copy().reset_index(drop=True)
            test_meta_df["y_true"] = y_test

            X_train, X_val, y_train, y_val = train_test_split(
                X_train_full,
                y_train_full,
                test_size=0.2,
                stratify=y_train_full if len(np.unique(y_train_full)) > 1 else None,
                random_state=42,
            )

            return X_train, X_val, X_test, y_train, y_val, y_test, feature_names, test_meta_df

    X_train_full, X_test, y_train_full, y_test, idx_train_full, idx_test = train_test_split(
        X_all,
        y.to_numpy(),
        np.arange(len(df)),
        test_size=0.2,
        stratify=y.to_numpy() if len(np.unique(y)) > 1 else None,
        random_state=42,
    )

    test_meta_df = meta_df.iloc[idx_test].copy().reset_index(drop=True)
    test_meta_df["y_true"] = y_test

    X_train, X_val, y_train, y_val = train_test_split(
        X_train_full,
        y_train_full,
        test_size=0.25,
        stratify=y_train_full if len(np.unique(y_train_full)) > 1 else None,
        random_state=42,
    )

    return X_train, X_val, X_test, y_train, y_val, y_test, feature_names, test_meta_df

def main():
    parser = argparse.ArgumentParser(description="Train the perturbed random forest classifier on a cleaned wind CSV.")
    parser.add_argument("csv_path", type=str, help="Path to the cleaned CSV file")
    parser.add_argument("--target", type=str, default="anomaly_indicator", help="Binary target column name")
    parser.add_argument("--threshold", type=float, default=0.5, help="Classification threshold")
    parser.add_argument("--n-trees", type=int, default=100, help="Number of custom ensemble trees")
    parser.add_argument("--baseline-n-trees", type=int, default=100, help="Number of baseline RF trees")
    parser.add_argument("--n-trials", type=int, default=3, help="FPSA trials per feature")
    parser.add_argument("--noise-std", type=float, default=0.1, help="Noise level used in FPSA")
    parser.add_argument("--noise-model", type=str, default="laplace", choices=["gaussian", "laplace", "poisson"])
    parser.add_argument("--top-k", type=int, default=10, help="How many top sensitive features to print")
    args = parser.parse_args()

    X_train, X_val, X_test, y_train, y_val, y_test, feature_names, test_meta_df = load_wind_data(
        args.csv_path,
        target_col=args.target,
    )

    clf = PerturbedRandomForestClassifier(
        n_trees=args.n_trees,
        baseline_n_trees=args.baseline_n_trees,
        n_trials=args.n_trials,
        noise_std=args.noise_std,
        noise_model=args.noise_model,
        class_weight="balanced",
        threshold=args.threshold,
        random_state=42,
    )

    clf.fit(X_train, y_train, X_val, y_val, feature_names=feature_names)
    y_pred = clf.predict(X_test)
    y_prob = clf.predict_proba(X_test)[:, 1]

    stem = Path(args.csv_path).stem

    farm_name = stem.replace("_combined", "")
    noise_name = args.noise_model.lower()
    output_stem = f"{farm_name}_{noise_name}"

    results_df = test_meta_df.copy()
    results_df["farm"] = farm_name
    results_df["noise_model"] = noise_name
    results_df["y_pred"] = y_pred
    results_df["y_prob"] = y_prob

    results_df.to_csv(f"{output_stem}_prediction_results.csv", index=False)


    feature_df = clf.get_feature_importance_table()
    feature_df["farm"] = farm_name
    feature_df["noise_model"] = noise_name
    feature_df.to_csv(f"{output_stem}_feature_sensitivity.csv", index=False)
    

    
    print(f"Loaded: {Path(args.csv_path).name}")
    print(f"Train shape: {X_train.shape}")
    print(f"Validation shape: {X_val.shape}")
    print(f"Test shape: {X_test.shape}")
    print(f"Positive rate in test set: {np.mean(y_test):.4f}")
    print()
    print(f"Accuracy: {clf.score(X_test, y_test):.4f}")

    if len(np.unique(y_test)) > 1:
        print(f"ROC-AUC: {roc_auc_score(y_test, y_prob):.4f}")
    else:
        print("ROC-AUC: not defined because the test split has only one class.")

    print("\nConfusion matrix:")
    print(confusion_matrix(y_test, y_pred))
    print("\nClassification report:")
    print(classification_report(y_test, y_pred, digits=4, zero_division=0))
    print(f"\nTop {args.top_k} most sensitive features:")
    print(feature_df.head(args.top_k).to_string(index=False))

    print(f"\nSaved prediction results to: {output_stem}_prediction_results.csv")
    print(f"Saved feature sensitivity table to: {output_stem}_feature_sensitivity.csv")

if __name__ == "__main__":
    main()
