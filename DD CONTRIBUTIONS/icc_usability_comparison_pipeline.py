import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.io import loadmat
from pathlib import Path
import os
import tkinter as tk
from tkinter import filedialog
from datetime import datetime


def load_mat_waveform(mat_path, preferred_keys=("Signal", "Signal_raw")):
    """
    Load waveform from a .mat file.
    Tries preferred variable names first, then falls back to the first numeric 1D/2D array.
    """
    data = loadmat(mat_path)

    # Try preferred keys first
    for key in preferred_keys:
        if key in data:
            arr = np.asarray(data[key]).squeeze()
            if arr.ndim == 1:
                return arr.astype(float), key

    # Fallback: search for first suitable numeric array
    for key, value in data.items():
        if key.startswith("__"):
            continue
        arr = np.asarray(value).squeeze()
        if np.issubdtype(arr.dtype, np.number) and arr.ndim == 1 and arr.size > 1:
            return arr.astype(float), key

    raise ValueError(f"No suitable waveform array found in {mat_path}")


def load_csv_waveform(csv_path, column=None):
    """
    Load waveform from a CSV file.
    If column is None, use the first numeric column.
    """
    df = pd.read_csv(csv_path)

    if column is not None:
        if column not in df.columns:
            raise ValueError(f"Column '{column}' not found in {csv_path}. Available: {list(df.columns)}")
        arr = df[column].to_numpy(dtype=float)
        return arr, column

    numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
    if not numeric_cols:
        raise ValueError(f"No numeric columns found in {csv_path}")

    col = numeric_cols[0]
    arr = df[col].to_numpy(dtype=float)
    return arr, col


def pearson_r(x, y):
    return np.corrcoef(x, y)[0, 1]


def mae(x, y):
    return np.mean(np.abs(x - y))


def rmse(x, y):
    return np.sqrt(np.mean((x - y) ** 2))


def icc_2_1(x, y):
    """
    ICC(2,1): two-way random effects, absolute agreement, single measurement.
    Input: x and y are paired measurements on the same targets.
    """
    X = np.column_stack([x, y])   # shape: n_targets x k_raters
    n, k = X.shape

    if k != 2:
        raise ValueError("This implementation expects exactly 2 raters.")

    mean_row = np.mean(X, axis=1, keepdims=True)
    mean_col = np.mean(X, axis=0, keepdims=True)
    grand_mean = np.mean(X)

    # Mean squares
    MSR = k * np.var(mean_row.squeeze(), ddof=1)   # rows/targets
    MSC = n * np.var(mean_col.squeeze(), ddof=1)   # columns/raters

    residual = X - mean_row - mean_col + grand_mean
    SSE = np.sum(residual ** 2)
    MSE = SSE / ((n - 1) * (k - 1))

    icc = (MSR - MSE) / (MSR + (k - 1) * MSE + (k * (MSC - MSE) / n))
    return icc


def minmax_normalize(x):
    xmin, xmax = np.min(x), np.max(x)
    if np.isclose(xmax, xmin):
        return np.zeros_like(x)
    return (x - xmin) / (xmax - xmin)


def zscore_normalize(x):
    mu, sigma = np.mean(x), np.std(x, ddof=0)
    if np.isclose(sigma, 0):
        return np.zeros_like(x)
    return (x - mu) / sigma


def compare_waveforms(
    mat_path,
    csv_path,
    csv_column=None,
    mat_key_preference=("Signal", "Signal_raw"),
    normalize="none",
    make_plot=True,
    plot_path=None
):
    """
    Compare one .mat waveform with one .csv waveform.
    normalize: 'none', 'minmax', or 'zscore'
    """
    x, mat_key = load_mat_waveform(mat_path, preferred_keys=mat_key_preference)
    y, csv_col = load_csv_waveform(csv_path, column=csv_column)

    if len(x) != len(y):
        raise ValueError(f"Length mismatch: mat has {len(x)} points, csv has {len(y)} points")

    # Optional normalization
    if normalize == "minmax":
        x_cmp = minmax_normalize(x)
        y_cmp = minmax_normalize(y)
    elif normalize == "zscore":
        x_cmp = zscore_normalize(x)
        y_cmp = zscore_normalize(y)
    elif normalize == "none":
        x_cmp = x.copy()
        y_cmp = y.copy()
    else:
        raise ValueError("normalize must be one of: 'none', 'minmax', 'zscore'")
    print("MAT mean/std:", np.mean(x_cmp), np.std(x_cmp, ddof=1))
    print("CSV mean/std:", np.mean(y_cmp), np.std(y_cmp, ddof=1))
    print("Mean difference:", np.mean(x_cmp - y_cmp))
    results = {
        "mat_file": str(mat_path),
        "csv_file": str(csv_path),
        "mat_variable_used": mat_key,
        "csv_column_used": csv_col,
        "n_points": len(x_cmp),
        "normalization": normalize,
        "pearson_r": pearson_r(x_cmp, y_cmp),
        "MAE": mae(x_cmp, y_cmp),
        "RMSE": rmse(x_cmp, y_cmp),
        "ICC_2_1": icc_2_1(x_cmp, y_cmp),
    }

    if make_plot:
        plt.figure(figsize=(10, 4))
        plt.plot(x_cmp, label="CC)")
        plt.plot(y_cmp, label="DD", alpha=0.8)
        plt.xlabel("Time Frame/s")
        plt.ylabel("Mean Lung Jacobian")
        plt.title(f"Jacobian Waveform comparison | normalization = {normalize}")
        plt.legend()
        plt.tight_layout()

        if plot_path is not None:
            plt.savefig(plot_path, dpi=200)
            print(f"Saved plot to: {plot_path}")

        plt.show()

    return results

def select_file(initial_dir, title, file_types):
    """弹出文件选择对话框"""
    root = tk.Tk()
    root.withdraw()  # 隐藏主窗口
    file_path = filedialog.askopenfilename(
        initialdir=initial_dir,
        title=title,
        filetypes=file_types
    )
    root.destroy()
    return file_path

if __name__ == "__main__":
    # 1. 定义路径
    base_dir = r"D:\groupproject2"
    graph_dir = os.path.join(base_dir, "ICCgraphs")
    
    # 2. 检查并创建文件夹 (如果不存在)
    if not os.path.exists(graph_dir):
        os.makedirs(graph_dir)
        print(f"no folder, create: {graph_dir}")

    # 3. 弹出窗口选择文件
    print("waiting for .mat files...")
    mat_file = select_file(base_dir, "waiting for .mat files", [("Data files", "*.mat")])
    
    print("waiting for .csv files...")
    csv_file = select_file(base_dir, "waiting for .csv files", [("CSV files", "*.csv")])

    if mat_file and csv_file:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        mat_name = os.path.basename(mat_file).replace(".mat", "")
        file_name = f"compare_{mat_name}_{timestamp}.png"
        plot_output = os.path.join(graph_dir, file_name)

        results = compare_waveforms(
            mat_path=mat_file,
            csv_path=csv_file,
            csv_column=None,
            mat_key_preference=("Signal", "Signal_raw"),
            normalize="zscore", 
            make_plot=True,
            plot_path=plot_output
        )
        print(f"Done! Saved on: {plot_output}")
    else:
        print("cancel。")

    print("\n===== COMPARISON RESULTS =====")
    for k, v in results.items():
        print(f"{k}: {v}")