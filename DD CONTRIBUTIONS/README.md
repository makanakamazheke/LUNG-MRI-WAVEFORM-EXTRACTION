## DD – Usability Comparison Pipeline

The following scripts were written and tested by DD as part of the project’s quantitative usability comparison pipeline.

| Script Name | Purpose |
|-------------|---------|
| `manualroiextraction_time.py` | Extracts respiratory waveforms via interactive manual ROI selection; features integrated time tracking to quantify manual labour duration as a key usability metric. |
| `icc_usability_comparison_pipeline.py` | Extracts respiratory waveforms from automated nnU-Net lung masks; records total processing time to evaluate algorithmic efficiency; saves waveform and overlay images. |
| `icc_usability_comparison_pipeline.py` | Inter-operator validation: statistically validates intensity‑based waveforms (`.csv`) against mean lung Jacobian sources (`.mat`) across the timeframe; computes agreement metrics including Pearson correlation (r), MAE, RMSE, and Intraclass Correlation Coefficient (ICC 2,1). |
| `barchart.py` | Generates standardised visualisations of usability scores (S_T, S_S, S_R, S_C); aggregates time efficiency and statistical accuracy to determine the final Usability Index (U_i) across the three methods. |
