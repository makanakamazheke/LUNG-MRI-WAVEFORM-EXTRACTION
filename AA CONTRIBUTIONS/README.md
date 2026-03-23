## AA – Jacobian Pipeline

The following scripts were written and tested by AA, as part of the project’s quantitative usability comparison pipeline.

| Script Name | Purpose |
|-------------|---------|
| `Deformation_Jacobian_Pipeline.ipynb` | Creates binary masks using `nibabel` and `SimpleITK` libraries. Uses a deformation field and the Jacobian determinant of this field to extract a respiratory waveform. |
| `Visualisation_Demons_Registration.ipynb` | Visualises lung MRI images frame‑by‑frame so movement can be seen. Extracts a respiratory waveform using demons registration, which was used as a simplified Jacobian experiment. |
