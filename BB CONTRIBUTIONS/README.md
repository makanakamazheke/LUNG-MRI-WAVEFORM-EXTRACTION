## BB – Robustness Pipeline

The following scripts were written and tested by BB as part of the project’s robustness pipeline.

| Script Name | Purpose |
|-------------|---------|
| `Robust.ipynb` | Takes 256 images (1 slice) and applies Gaussian blur and Rician noise at 8 levels, saving the results to path directories. |
| `Deformation_based_waveform_extraction_pipeline.ipynb` | Takes a folder with 8 slices of varying noise and computes waveforms, saving them as CSV files. |
| `Metrics_calc.ipynb` | Takes in CSV files of waveforms of varying noise, calculates and plots metrics (PCC, RMSE, PTE). |
