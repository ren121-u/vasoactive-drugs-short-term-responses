# Vasoactive-Drugs-Short-Term-Responses

This repository contains SQL, R, and Python code to analyze the short-term hemodynamic responses to vasoactive drugs in ICU patients.
Using data from the OneICU database in Japan, the scripts extract hemodynamic measurements around the initiation of noradrenaline, adrenaline, dopamine, and dobutamine, and apply statistical models to compare the trajectories of blood pressure and other hemodynamic variables across drugs and starting doses.

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

1. SQL code to extract hemodynamic measurements and relevant clinical data from the OneICU database.
2. Python code used for signal processing of the hemodynamic waveforms and for descriptive summaries.
3. R scripts to clean data, fit statistical models, and generate figures showing hemodynamic changes after the initiation of each vasoactive drug.

By running these scripts, researchers can reproduce the analysis of short-term hemodynamic trajectories across vasoactive drugs, starting doses, and patient subgroups.

<!--
TODO (公開前に埋める):
- 対象施設数と対象期間（例: seven ICUs in Japan, 2013-2024）
- 対象アウトカム（MAP, DBP, HR, CVP, PAP, SVR, CO など）の最終的な一覧
- 観察ウィンドウ（投与開始前後の何分間か）
- 対応する論文の書誌情報（受理後に追記）
-->

---
## Repository Structure
```
Vasoactive-Drugs-Short-Term-Responses
├── README.md
├── LICENSE
├── sql
├── python_scripts
└── R_scripts
```
- `sql`
  - SQL scripts to extract hemodynamic measurements and clinical variables from the OneICU database in Google BigQuery.
- `python_scripts`
  - Python scripts used for signal processing of hemodynamic measurements and descriptive summaries.
- `R_scripts`
  - R scripts for data cleaning, statistical modeling, and figure generation.

---
## Requirements
1. Google BigQuery Access
    - To run the SQL scripts, you will need access to Google BigQuery and appropriate credentials to query the OneICU database.
2. Python
    - Python (version 3.12 or higher recommended).
3. R
    - R (version 4.4 or higher recommended) is required to run the R scripts for data cleaning, statistical modeling, and figure generation.
4. R Packages
    - Common data analysis packages such as tidyverse, ggplot2, mgcv, and tableone.
    - Check the top of each R script for specific library requirements.

---
## Usage

### SQL Queries
1. Navigate to the `sql` directory.
2. Open the SQL script of interest.
3. Copy the script into your BigQuery console.
4. Run the query.
  - Ensure you have access to the OneICU database and that your [BigQuery billing project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) is configured correctly.

### Python Scripts
1. Install Python (3.12 or higher recommended).
2. Run the scripts in the `python_scripts` folder as described in each file.

### R Scripts
1. Clone this repository or download the files locally.
2. Open your R environment (RStudio or equivalent).
3. Install any missing R packages with:
  ```r
  install.packages("<package_name>")
  ```
4. Run the scripts in the `R_scripts` folder in the recommended order to:
   - Load query outputs.
   - Perform data cleaning and statistical modeling.
   - Generate figures showing hemodynamic changes after the initiation of vasoactive drugs.

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
