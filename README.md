```markdown
# Lung MRI Waveform Extraction

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.8%2B-blue)](https://www.python.org/)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2020b%2B-orange)](https://www.mathworks.com/)

> **Year 3 Project – PHAS0052**  
> *Supervisor: Dr Mina Kim, Principal Research Fellow ([mina.kim@ucl.ac.uk](mailto:mina.kim@ucl.ac.uk))*

## 📖 Project Overview

This project compares three practical methods for extracting respiratory waveforms from time‑series lung MRI images. The goal is to systematically evaluate manual, intensity‑based, and deformation‑based approaches in terms of agreement, robustness, and usability. The work addresses a key gap in quantitative lung MRI preprocessing and provides career‑relevant experience in medical image analysis.

## 🎯 Project Goals

- Apply three methods to extract respiratory waveforms from dynamic lung MRI data:
  1. **Manual** (reference)
  2. **Automated intensity‑based**
  3. **Deformation‑based** (using Jacobian maps from co‑registration)
- Quantitatively compare the methods for agreement, robustness, and usability.
- Assess how analysis choices (e.g., ROI selection, preprocessing) affect the resulting signal.
- Develop a reproducible analysis pipeline in **MATLAB** or **Python**.
- Work effectively as a team and communicate results through figures, reports, and presentations.

## 🗂️ Dataset and Provided Inputs

- Dynamic 2D multi‑slice lung MRI time‑series.
- A pre‑trained lung segmentation model.
- Co‑registered outputs, including **Jacobian maps** from non‑rigid registration.
- Example scripts (MATLAB/Python) to reduce implementation overhead.

## 📦 Repository Structure

```
.
├── data/               # Placeholder for input data (not included)
├── src/                # Source code for waveform extraction and analysis
│   ├── manual/         # Manual method scripts
│   ├── intensity/      # Intensity‑based method scripts
│   ├── deformation/    # Deformation‑based method scripts
│   └── utils/          # Utility functions (e.g., I/O, visualisation)
├── results/            # Output figures, tables, and waveforms
├── docs/               # Documentation and reports
├── examples/           # Example scripts and notebooks
├── requirements.txt    # Python dependencies (if using Python)
└── README.md           # This file
```

## 🚀 Getting Started

### Prerequisites

- **MATLAB** (R2020b or later) with Image Processing Toolbox, or
- **Python** 3.8+ with the following packages:
  - `numpy`
  - `scipy`
  - `matplotlib`
  - `scikit-image`
  - `nibabel` (if using NIfTI images)

### Installation

Clone the repository:

```bash
git clone https://github.com/your-username/lung-mri-waveform-extraction.git
cd lung-mri-waveform-extraction
```

For Python, install dependencies:

```bash
pip install -r requirements.txt
```

### Usage

1. Place your input data in the `data/` folder.
2. Run the main pipeline script:

   ```bash
   python src/run_pipeline.py --input data/ --output results/
   ```

   or in MATLAB:

   ```matlab
   run_pipeline('data/', 'results/')
   ```

3. Generated waveforms and comparison figures will be saved in the `results/` directory.

## 📈 Expected Outcomes

By the end of the project, we will deliver:

- A working comparison pipeline for respiratory waveform extraction.
- Evidence‑based guidance on which method is preferable under different constraints (e.g., speed, accuracy, robustness).
- A set of figures and tables that could form the basis of a short methods manuscript, subject to results quality and novelty.

## 🤝 Team

- [Your Name] – [Role]
- [Team Member 2] – [Role]
- [Team Member 3] – [Role]

## 📝 License

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.

## 📧 Contact

For questions or collaboration, please contact Dr Mina Kim at [mina.kim@ucl.ac.uk](mailto:mina.kim@ucl.ac.uk).

---

*This project is part of the PHAS0052 module at University College London (UCL).*
```
