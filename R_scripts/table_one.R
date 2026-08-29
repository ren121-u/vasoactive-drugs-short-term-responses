# ===============================
# Packages
# ===============================
if (!require('tidyverse')) install.packages('tidyverse')
if (!require('tableone')) install.packages('tableone')

library(tidyverse)
library(tableone)
library(mgcv)

# ===============================
# Directories
# ===============================
data_dir   <- './data/'
output_dir <- './output/tableone/'
data_ver_pre   <- '20260618'
data_ver   <- '20260706'
output_ver <- '20260706'

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ===============================
# Load data
# ===============================
df <- read.csv(paste0(data_dir, data_ver_pre, '_map_filtered.csv'))
df_base_before_naomit <- read.csv(paste0(data_dir, data_ver, '_base.csv'))

# --- Rename noradrenaline to norepinephrine for the manuscript ---
df$active_ingredient_name[df$active_ingredient_name == "noradrenaline"] <- "norepinephrine"
df_base_before_naomit$active_ingredient_name[df_base_before_naomit$active_ingredient_name == "noradrenaline"] <- "norepinephrine"

# ===============================
# Maximum offset (observation-time filter)
# ===============================
df_max_offset <- df %>%
  group_by(active_ingredient_name, icu_stay_id) %>%
  summarise(max_offset = max(offset), .groups = "drop")

# ===============================
# base (handling of missing values)
# ===============================
df_base <- df_base_before_naomit %>% na.omit()

# ===============================
# Merge (analysis population)
# ===============================
df_joined <- df %>%
  inner_join(df_base, by = c("icu_stay_id", "active_ingredient_name")) %>%
  inner_join(df_max_offset, by = c("icu_stay_id", "active_ingredient_name")) %>%
  filter(max_offset > 10)

# ===============================
# complete_df (base data for the GAM)
# ===============================
complete_df <- df_joined %>%
  select(
    icu_stay_id, active_ingredient_name, offset,
    map_lpf,
    female, age, body_weight, apache2_score, gamma,
    ph, pco2, lactate, hr_pre, map_pre,
    on_vent, on_rrt,
    diagnosis_category
  ) %>%
  na.omit() %>%
  mutate(
    diagnosis_category = factor(diagnosis_category),
    diagnosis_category = relevel(diagnosis_category, ref = "circulatory")
  )

# ===============================
# MAP at offsets -15 to 0 (pre-initiation condition)
# ===============================
map_pre_wide <- complete_df %>%
  filter(offset >= -15 & offset <= 0) %>%
  select(icu_stay_id, active_ingredient_name, offset, map_lpf) %>%
  group_by(icu_stay_id, active_ingredient_name, offset) %>%
  summarise(map_lpf = median(map_lpf, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(
    names_from  = offset,
    values_from = map_lpf,
    names_prefix = "map_lpf_offset_"
  ) %>%
  rename_with(~ gsub("-", "minus", .x))

# ===============================
# offset=0
# ===============================
map_time0_df <- complete_df %>%
  filter(offset == 0) %>%
  select(icu_stay_id, active_ingredient_name, map_lpf) %>%
  rename(map_time0_value = map_lpf)

# ===============================
# df_post (final analysis data)
# ===============================
df_post <- complete_df %>%
  filter(offset >= -15 & offset <= 120) %>%
  inner_join(map_time0_df,
             by = c("icu_stay_id", "active_ingredient_name")) %>%
  mutate(map_diff = map_lpf - map_time0_value) %>%
  inner_join(
    map_pre_wide %>% select(-map_lpf_offset_0),
    by = c("icu_stay_id", "active_ingredient_name")
  )
# ===============================
# Patient IDs actually used in the GAM
# ===============================

model_vars <- c(
  "map_diff", "offset", "gamma", "map_time0_value",
  "map_lpf_offset_minus15",
  "map_lpf_offset_minus10",
  "map_lpf_offset_minus5",
  "female", "age", "body_weight",
  "apache2_score", "ph", "pco2", "lactate",
  "hr_pre", "map_pre",
  "diagnosis_category",
  "on_vent", "on_rrt"
)

drug_list <- c("dobutamine", "dopamine", "norepinephrine")

gam_used_df <- map_dfr(drug_list, function(drug){

  current_df <- df_post %>%
    filter(active_ingredient_name == drug)

  current_df %>%
    select(
      icu_stay_id,
      active_ingredient_name,
      all_of(model_vars)
    ) %>%
    na.omit() %>%
    distinct(icu_stay_id, active_ingredient_name)

})

# ===============================
# Data for Table 1 (only the cases actually used in the GAM)
# ===============================

table_df <- df_base_before_naomit %>%
  inner_join(
    gam_used_df,
    by = c("icu_stay_id","active_ingredient_name")
  ) %>%
  distinct(
    icu_stay_id,
    active_ingredient_name,
    .keep_all = TRUE
  )

# ===============================
# Variable formatting
# ===============================
table_df <- table_df %>%
  mutate(
    # Drugs
    drug = factor(active_ingredient_name,
                  levels = c("dobutamine", "dopamine", "norepinephrine"),
                  labels = c("Dobutamine", "Dopamine", "Norepinephrine")),

    # Categorical variables
    # Because only Male is reported for sex and only Yes for mv / rrt,
    # Place the level to be reported as the first level of the factor
    sex = factor(female, levels = c(0,1), labels = c("Male","Female")),
    mv  = factor(on_vent, levels = c(1,0), labels = c("Yes","No")),
    rrt = factor(on_rrt, levels = c(1,0), labels = c("Yes","No"))
  )

# ===============================
# Variable definitions
# ===============================
vars <- c(
  "age", "sex", "body_weight",
  "apache2_score",
  "map_pre", "hr_pre",
  "ph", "pco2", "lactate",
  "mv", "rrt"
)

catVars <- c("sex", "mv", "rrt")

# ===============================
# Build Table 1
# ===============================
table1 <- CreateTableOne(
  vars = vars,
  strata = "drug",
  data = table_df,
  factorVars = catVars,
  addOverall = TRUE
)

# ===============================
# Output (median [IQR], n (%))
# Use one decimal place for both continuous and categorical variables
# Because units and the " (median [IQR])" / " (%)" annotations are given in the table legend,
# removed from the body of the table.
# ===============================
table1_out <- print(
  table1,
  nonnormal = vars,
  quote = FALSE,
  noSpaces = TRUE,
  showAllLevels = TRUE,
  test = FALSE,
  printToggle = FALSE,
  contDigits = 1,
  catDigits = 1
)

# ===============================
# Helper function to control the number of digits displayed
# ===============================
format_median_iqr <- function(x, digits = 1){

  med <- median(x, na.rm = TRUE)
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)

  sprintf(
    paste0("%.", digits, "f [%." , digits, "f, %.", digits, "f]"),
    med, q1, q3
  )
}

replace_row <- function(table1_out, row_name, variable, digits){

  vals <- c(
    format_median_iqr(table_df[[variable]], digits),

    format_median_iqr(
      table_df[[variable]][table_df$drug=="Dobutamine"],
      digits
    ),

    format_median_iqr(
      table_df[[variable]][table_df$drug=="Dopamine"],
      digits
    ),

    format_median_iqr(
      table_df[[variable]][table_df$drug=="Norepinephrine"],
      digits
    )
  )

  stat_cols <- setdiff(colnames(table1_out), "level")

  table1_out[row_name, stat_cols] <- vals

  table1_out
}

# ===============================
# Remove unnecessary level rows
#   - Drop the "Female" row for sex (show "Male" only)
#   - Drop the "No" rows for mv / rrt (show "Yes" only)
# Because the first level of each factor is set to the level to be kept,
#   The rows to keep (Male / Yes) are header rows, and the rows to drop are those immediately below them.
# ===============================
level_col <- table1_out[, "level"]
rows_to_drop <- level_col %in% c("Female", "No")
table1_out <- table1_out[!rows_to_drop, , drop = FALSE]

# ===============================
# Format labels for the manuscript
#   - Capitalize the first letter
#   - Append units in parentheses
#   - Replace underscores with spaces
# ===============================
label_map <- c(
  "age" = "Age, years",
  "sex" = "Male, n (%)",
  "body_weight" = "Body weight, kg",
  "apache2_score" = "APACHE II score",

  "map_pre" = "MAP before drug initiation, mmHg",
  "hr_pre" = "Heart rate before drug initiation, beats/min",

  "ph" = "pH",
  "pco2" = "PaCO2, mmHg",
  "lactate" = "Lactate, mmol/L",

  "mv" = "Mechanical ventilation, n (%)",
  "rrt" = "Renal replacement therapy, n (%)"
)

# the suffixes " (median [IQR])", " (%)" and " = <level>" that tableone adds automatically are
# they are stripped to recover the original variable names.
strip_suffix <- function(x) {
  x <- sub(" \\(median \\[IQR\\]\\)$", "", x)
  x <- sub(" \\(%\\)$", "", x)
  x <- sub(" = .*$", "", x)
  x
}

new_rownames <- vapply(
  rownames(table1_out),
  function(x) {
    var <- strip_suffix(x)
    if (nzchar(var) && var %in% names(label_map)) {
      label_map[[var]]
    } else {
      x
    }
  },
  character(1)
)

rownames(table1_out) <- new_rownames

# ==================================================
# Surgical category (duplicates retained)
# ==================================================

surgery_df <- df_base_before_naomit %>%
  inner_join(
    gam_used_df,
    by = c("icu_stay_id", "active_ingredient_name")
  ) %>%
  mutate(
    drug = factor(
      active_ingredient_name,
      levels = c("dobutamine", "dopamine", "norepinephrine"),
      labels = c("Dobutamine", "Dopamine", "Norepinephrine")
    ),
    surgery_category = if_else(
      is.na(surgery_category) | surgery_category == "",
      "unknown",
      surgery_category
    ),
    surgery_group = factor(
      surgery_category,
      levels = c(
        "valvular",
        "coronary",
        "aortic and vascular",
        "others",
        "unknown"
      ),
      labels = c(
        "Valvular",
        "Coronary",
        "Aortic and vascular",
        "Others",
        "Unknown"
      )
    )
  )

format_n_pct <- function(df, level){

  N <- dplyr::n_distinct(df$icu_stay_id, df$active_ingredient_name)

  n <- df %>%
    dplyr::filter(surgery_group == level) %>%
    dplyr::distinct(icu_stay_id, active_ingredient_name) %>%
    nrow()

  sprintf("%d (%.1f)", n, 100 * n / N)
}

surgery_levels <- levels(surgery_df$surgery_group)

surgery_header <- "Surgical category, n (%)"

surgery_rows <- matrix(
  "",
  nrow = length(surgery_levels) + 1,
  ncol = ncol(table1_out),
  dimnames = list(
    c(surgery_header, surgery_levels),
    colnames(table1_out)
  )
)

for(i in seq_along(surgery_levels)){

  lev <- surgery_levels[i]

  surgery_rows[lev, "Overall"] <-
    format_n_pct(surgery_df, lev)

  surgery_rows[lev, "Dobutamine"] <-
    format_n_pct(
      subset(surgery_df, drug=="Dobutamine"),
      lev
    )

  surgery_rows[lev, "Dopamine"] <-
    format_n_pct(
      subset(surgery_df, drug=="Dopamine"),
      lev
    )

  surgery_rows[lev, "Norepinephrine"] <-
    format_n_pct(
      subset(surgery_df, drug=="Norepinephrine"),
      lev
    )
}

idx <- which(rownames(table1_out) == "APACHE II score")

table1_out <- rbind(
  table1_out[1:idx, ],
  surgery_rows,
  table1_out[(idx+1):nrow(table1_out), ]
)

table1_out <- replace_row(table1_out, "pH", "ph", 2)

table1_out <- replace_row(table1_out, "Age, years", "age", 0)

table1_out <- replace_row(table1_out, "APACHE II score", "apache2_score", 0)

table1_out <- replace_row(
  table1_out,
  "MAP before drug initiation, mmHg",
  "map_pre",
  0
)

table1_out <- replace_row(
  table1_out,
  "Heart rate before drug initiation, beats/min",
  "hr_pre",
  0
)

# ===============================
# Display
# ===============================
View(table1_out)
print(table1_out)

# ===============================
# Save
# ===============================
write.csv(
  table1_out,
  paste0(output_dir, "table1_", output_ver, ".csv"),
  row.names = TRUE
)
