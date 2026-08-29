# Vasoactive-Drugs-Short-Term-Responses

This repository contains SQL, R, and Python code to analyze the short-term hemodynamic responses to vasoactive drugs in patients admitted to the ICU after cardiac surgery.
Using data from 17 ICUs in Japan between February 2013 and December 2025, recorded in the OneICU database, the scripts extract hemodynamic measurements from 30 minutes before to 120 minutes after the initiation of norepinephrine, dopamine, or dobutamine, and apply generalized additive models to compare the resulting trajectories across drugs and across starting infusion rates.

---
## Table of Contents
- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Usage](#usage)
  - [SQL Queries](#sql-queries)
  - [Python Scripts](#python-scripts)
  - [R Scripts](#r-scripts)
- [Contact](#contact)
- [License](#license)

---
## Overview
The Vasoactive-Drugs-Short-Term-Responses repository includes:

1. SQL code to extract hemodynamic measurements and clinical covariates from the OneICU database.
2. Python code to apply a low-pass filter to the extracted hemodynamic time series.
3. R scripts to fit generalized additive models, run bootstrap resampling, and generate the figures and the baseline characteristics table.

The study population consists of patients admitted to 17 ICUs in Japan after cardiac surgery between February 2013 and December 2025, who received a continuous infusion of a vasoactive drug. Patients treated with ECMO or Impella, patients younger than 15 years, and patients without a recorded age or sex are excluded. Eight hemodynamic outcomes are analyzed: MAP, DBP, HR, CVP, PAP, MAP-CVP, CO, and SVR.

By running these scripts, researchers can reproduce the analysis of short-term hemodynamic trajectories across vasoactive drugs, starting infusion rates, and patient subgroups.

<!--
TODO (to be completed before making this repository public):
- Citation of the corresponding article, once accepted
-->

---
## Repository Structure
```
Vasoactive-Drugs-Short-Term-Responses
├── README.md
├── LICENSE
├── sql
│   ├── 01_eligibility_criteria.sql
│   ├── 02_static_variables.sql
│   ├── 03_vasoactive_drug_rate.sql ... 08_gamma_from_bodyweight.sql
│   ├── 09_join_covariates.sql
│   └── 10_map.sql ... 17_dbp.sql
├── python_scripts
│   └── lowpass_filter
└── R_scripts
    ├── 01_gam_comparing_by_drug
    ├── 02_bootstrap
    ├── 03_gam_comparing_by_dose
    ├── 04_infusion_rate_histogram
    └── 05_table_one.R
```

### `sql`
SQL scripts to extract the study population, hemodynamic measurements, and covariates from the OneICU database in Google BigQuery. The numbering indicates the order of execution: each script refers to the tables created by the scripts before it.

| Script | Contents |
| --- | --- |
| `01_eligibility_criteria.sql` | Application of the inclusion and exclusion criteria |
| `02_static_variables.sql` | Baseline patient characteristics |
| `03_vasoactive_drug_rate.sql` – `08_gamma_from_bodyweight.sql` | Time-fixed covariates (infusion rate, mechanical ventilation, blood gas, vital signs, renal replacement therapy, and the infusion rate per body weight) |
| `09_join_covariates.sql` | Joining of the covariates into a single table |
| `10_map.sql` – `17_dbp.sql` | Hemodynamic measurements for each outcome (MAP, PAP, CVP, MAP-CVP, CO, SVR, HR, DBP) |

### `python_scripts`
`lowpass_filter` contains one Jupyter notebook per outcome. Each notebook applies a Butterworth low-pass filter to the extracted time series and writes the filtered data used by the R scripts.

### `R_scripts`
Each directory contains one script per outcome, except for `04_infusion_rate_histogram`, which contains one script per drug. The scripts are numbered for reference and do not depend on one another: each of them reads the exported data directly.

| Directory / file | Contents |
| --- | --- |
| `01_gam_comparing_by_drug` | Generalized additive models comparing the trajectories across vasoactive drugs |
| `02_bootstrap` | Bootstrap resampling at the patient level for the confidence intervals |
| `03_gam_comparing_by_dose` | Generalized additive models comparing the trajectories across starting infusion rates |
| `04_infusion_rate_histogram` | Histograms of the starting infusion rate for each drug |
| `05_table_one.R` | Baseline characteristics table |

---
## Requirements
1. Google BigQuery Access
    - To run the SQL scripts, you will need access to Google BigQuery and appropriate credentials to query the OneICU database.
2. Python
    - Python (version 3.12 or higher recommended), with `numpy`, `pandas`, `scipy`, `matplotlib`, and `seaborn`.
3. R
    - R (version 4.4 or higher recommended).
4. R Packages
    - `tidyverse` (including `dplyr` and `tidyr`), `mgcv`, `tableone`, `ggrepel`, and, for the bootstrap scripts, `furrr`, `future`, and `progressr`.

---
## Usage

The scripts read their input from a `data` directory and write their figures and tables to an `output` directory. Neither directory is included in this repository; create them locally and adjust the paths defined at the top of each script to match your environment.

### SQL Queries
1. Navigate to the `sql` directory.
2. Run the scripts in the order given by their numbering, saving the result of each script as a table **named after the script itself** (for example, `03_vasoactive_drug_rate.sql` is saved as the table `03_vasoactive_drug_rate`). Later scripts refer to these tables by that name.
  - Ensure that you have access to the OneICU database and that your [BigQuery billing project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) is configured correctly.
  - The dataset name in the `from` clauses (`medicu-production.research_vasoactive_drugs_short_term_responses_2025`) must be replaced with your own project and dataset.
3. Export the resulting tables as CSV files into your local `data` directory.

### Python Scripts
1. Install Python (3.12 or higher recommended).
2. Open the notebook for the outcome of interest in `python_scripts/lowpass_filter`.
3. Set `data_dir` at the top of the notebook to match your environment.
4. Run the notebook to write the filtered time series back to the `data` directory.

### R Scripts
1. Clone this repository or download the files locally.
2. Open your R environment (RStudio or equivalent).
3. Install any missing R packages with:
  ```r
  install.packages("<package_name>")
  ```
4. Set `data_dir`, `output_dir`, and the data version at the top of each script.
5. Run the scripts to fit the models and generate the figures and tables.
  - The bootstrap scripts run in parallel and are set to 32 workers by default. Adjust `plan(multisession, workers = 32)` to the number of cores available on your machine.

---
## Contact
For questions or collaboration inquiries, please reach out to us by email:
 - [MeDiCU, Inc.](mailto:info@medicu.co.jp)

---
## License
This project is licensed under the GNU General Public License (GPL) - see the [LICENSE](LICENSE) file for details.

---
**Disclaimer:**
The code in this repository is provided for academic research and educational purposes. Individual patient data are not provided.
