## CC Contributions

The following scripts were written and tested by CC as part of the project’s quantitative comparison pipeline. Full code is available in the group repository.

| Script Name | Purpose |
|-------------|---------|
| `manual_waveform_extraction.m` | Extracts respiratory waveforms using manual ROI (right hemi‑diaphragm). Implements batch modes, ROI reuse, standardised saving (ROI, raw signal, normalisation data). |
| `ML_waveform_extraction.m` | Extracts waveforms using nnU‑Net lung masks. Includes interactive and auto‑accept modes; saves waveform and overlay images. |
| `agreeability_all_methods.m` | Loads manual, automated, deformation waveforms; computes per‑slice and per‑patient metrics (correlation, MAE, lag, phase agreement, cycle counts, RR, EE/EI differences); generates overlay plots, heatmaps, and summary tables. |
| `detect_abnormal_agreement.m` | Runs RR‑outlier detection on all three methods independently; computes pairwise overlaps; saves raw intervals for Gantt plots and CSV exports. |
| `generate_robustness_waveforms.m` | Processes noise and blur levels for a fixed slice (HV_002/raw_IM_0025) to generate CSV waveforms for BB's robustness analysis. |
