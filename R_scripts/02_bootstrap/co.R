# --- Packages ---
if (!require('tidyverse')) install.packages('tidyverse')
if (!require('ggrepel')) install.packages('ggrepel')
if (!require('furrr')) install.packages('furrr')
if (!require('future')) install.packages('future')
if (!require('progressr')) install.packages('progressr')
library(tidyverse)
library(mgcv)
library(ggrepel)
library(furrr)
library(future)
library(progressr)
library(dplyr)
library(tidyr)

plan(multisession, workers = 32)
handlers("progress")
set.seed(123)

# --- Directories ---
data_dir   <- './data/'
output_dir <- './output/bootstrap/'
data_ver_pre     <- '20260618'
data_ver     <- '20260706'
output_ver   <- '20260819'

# --- Load data ---
df <- read.csv(paste0(data_dir, data_ver_pre, '_co_filtered.csv'))
df_base_before_naomit <- read.csv(paste0(data_dir, data_ver, '_base.csv'))

# --- Rename noradrenaline to norepinephrine for the manuscript ---
df$active_ingredient_name[df$active_ingredient_name == "noradrenaline"] <- "norepinephrine"
df_base_before_naomit$active_ingredient_name[df_base_before_naomit$active_ingredient_name == "noradrenaline"] <- "norepinephrine"

# --- Make surgery_category unique at the patient level ---
priority_order <- c("valvular", "coronary", "aortic and vascular", "others")

surgery_category_priority <- df_base_before_naomit %>%
  filter(!is.na(surgery_category), surgery_category != "") %>%
  count(surgery_category) %>%
  mutate(
    priority = match(surgery_category, priority_order),
    priority = if_else(is.na(priority), length(priority_order) + 1, priority)
  ) %>%
  arrange(priority, desc(n), surgery_category) %>%
  select(surgery_category, priority)

patient_surgery <- df_base_before_naomit %>%
  distinct(icu_stay_id, surgery_category) %>%
  filter(!is.na(surgery_category), surgery_category != "") %>%
  left_join(surgery_category_priority, by = "surgery_category") %>%
  group_by(icu_stay_id) %>%
  arrange(priority, surgery_category) %>%
  slice(1) %>%
  ungroup() %>%
  select(icu_stay_id, surgery_category)

df_base_before_naomit <- df_base_before_naomit %>%
  select(-surgery_category) %>%
  left_join(patient_surgery, by = "icu_stay_id") %>%
  mutate(
    surgery_category = if_else(is.na(surgery_category) | surgery_category == "", "unknown", surgery_category)
  ) %>%
  distinct(icu_stay_id, active_ingredient_name, .keep_all = TRUE)

# --- Create the output directory if it does not exist ---
if (!dir.exists(output_dir)) {
  dir.create(
    output_dir,
    recursive = TRUE,
    showWarnings = FALSE,
    mode = "0777"
  )
}

# --- Maximum offset ---
df_max_offset <- df %>%
  group_by(active_ingredient_name, icu_stay_id) %>%
  summarise(max_offset = max(offset), .groups = "drop")

df_base <- df_base_before_naomit %>% na.omit()

df_joined <- df %>%
  inner_join(df_base, by = c("icu_stay_id", "active_ingredient_name")) %>%
  inner_join(df_max_offset, by = c("icu_stay_id", "active_ingredient_name")) %>%
  filter(max_offset > 10)

# ===============================
# complete_df
# ===============================
complete_df <- df_joined %>%
  select(
    icu_stay_id, active_ingredient_name, offset,
    co_lpf,
    female, age, body_weight, apache2_score, gamma,
    ph, pco2, lactate, hr_pre, map_pre,
    on_vent, on_rrt,
    surgery_category
  ) %>%
  na.omit() %>%
  mutate(
    surgery_category = if_else(is.na(surgery_category) | surgery_category == "", "unknown", surgery_category),
    surgery_category = factor(surgery_category),
    surgery_category = relevel(surgery_category, ref = "valvular")
  )

# ===============================
# Reshape CO at offsets -15 to 0 into wide format
# ===============================
co_pre_wide <- complete_df %>%
  filter(offset >= -15 & offset <= 0) %>%
  select(icu_stay_id, active_ingredient_name, offset, co_lpf) %>%
  group_by(icu_stay_id, active_ingredient_name, offset) %>%
  summarise(co_lpf = median(co_lpf, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(
    names_from  = offset,
    values_from = co_lpf,
    names_prefix = "co_lpf_offset_"
  ) %>%
  rename_with(~ gsub("-", "minus", .x))

# ===============================
# time0 co
# ===============================
co_time0_df <- complete_df %>%
  filter(offset == 0) %>%
  select(icu_stay_id, active_ingredient_name, co_lpf) %>%
  rename(co_time0_value = co_lpf)

# ===============================
# Difference data for offsets >= 0
# ===============================
df_post <- complete_df %>%
  filter(offset >= -15 & offset <= 120) %>%
  inner_join(co_time0_df,
             by = c("icu_stay_id", "active_ingredient_name")) %>%
  mutate(
    co_diff = co_lpf - co_time0_value
  ) %>%
  inner_join(
    co_pre_wide %>% select(-co_lpf_offset_0),
    by = c("icu_stay_id", "active_ingredient_name")
  )

# ========= Fixed infusion rate (gamma) =========
gamma_values_list <- list(
  dopamine      = 3,
  dobutamine    = 3,
  norepinephrine = 0.03
)

case_counts <- df_post %>%
  distinct(active_ingredient_name, icu_stay_id) %>%
  count(active_ingredient_name, name = "n_cases")

print(case_counts)

#-----------------------------
# Bootstrap function
#-----------------------------

bootstrap_once_drug <- function(drug_name) {

  tryCatch({

    df_drug <- df_post %>% 
      filter(active_ingredient_name == drug_name)

    # Resample at the case level
    id_sample <- df_drug %>%
      distinct(icu_stay_id) %>%
      sample_n(n_distinct(df_drug$icu_stay_id), replace = TRUE)

    df_sample <- id_sample %>%
      left_join(df_drug, by = "icu_stay_id", relationship = "many-to-many")

    # ---- GAM ----
    gam_fit <- gam(
      co_diff ~
        s(offset) +
        gamma +
        ti(gamma, offset) +
        s(co_time0_value) +
        co_lpf_offset_minus15 +
        co_lpf_offset_minus10 + co_lpf_offset_minus5 +
        female + age + body_weight +
        apache2_score + ph + pco2 + lactate +
        hr_pre + map_pre +
        surgery_category +
        on_vent + on_rrt,
      data   = df_sample,
      family = gaussian(),
      method = "REML"
    )

    g <- gamma_values_list[[drug_name]]

    med_vals <- df_sample %>% summarise(across(where(is.numeric), ~ median(., na.rm = TRUE)))

    pred_grid <- med_vals %>%
      slice(rep(1, 2)) %>%
      mutate(
        offset = c(0, 60),
        gamma  = g,
        surgery_category = factor("valvular",
          levels = levels(df_sample$surgery_category))
      )

    preds <- predict(gam_fit, newdata = pred_grid)

    return(preds[2] - preds[1])

  }, error = function(e) {
    return(NA_real_)
  })
}

#-----------------------------
# Run the bootstrap
#-----------------------------

bootstrap_results <- map(names(gamma_values_list), function(drug){

  cat("Bootstrap:", drug, "\n")

  diffs <- future_map_dbl(
    1:1000,
    ~ bootstrap_once_drug(drug),
    .options = furrr_options(seed = TRUE)
  )

  diffs <- diffs[!is.na(diffs)]

  tibble(
    drug = drug,
    n_success = length(diffs),
    point_estimate = mean(diffs),
    ci_low  = quantile(diffs, 0.025, na.rm = TRUE),
    ci_high = quantile(diffs, 0.975, na.rm = TRUE),
    p_value = 2 * min(mean(diffs > 0), mean(diffs < 0)),
    sd_boot = sd(diffs)
  )
}) %>% bind_rows()

# -----------------------------
# Save the bootstrap results
# -----------------------------

print(bootstrap_results)

write.csv(
  bootstrap_results,
  file = paste0(output_dir, "bootstrap_results_co_", output_ver, ".csv"),
  row.names = FALSE
)