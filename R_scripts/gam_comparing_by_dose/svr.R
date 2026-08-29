# --- Packages ---
if (!require('tidyverse')) install.packages('tidyverse')
if (!require('ggrepel')) install.packages('ggrepel')
library(tidyverse)
library(mgcv)
library(ggrepel)

# --- Directories ---
data_dir   <- './data/'
output_dir <- './output/gam_comparing_by_dose/'
data_ver_pre     <- '20260618'
data_ver     <- '20260706'
output_ver   <- '20260819'

# --- Load data ---
df <- read.csv(paste0(data_dir, data_ver_pre, '_svr_filtered.csv'))
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
  dir.create(output_dir, recursive = TRUE)
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
    svr_lpf,
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
# Reshape SVR at offsets -15 to 0 into wide format
# ===============================
svr_pre_wide <- complete_df %>%
  filter(offset >= -15 & offset <= 0) %>%
  select(icu_stay_id, active_ingredient_name, offset, svr_lpf) %>%
  group_by(icu_stay_id, active_ingredient_name, offset) %>%
  summarise(svr_lpf = median(svr_lpf, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(
    names_from  = offset,
    values_from = svr_lpf,
    names_prefix = "svr_lpf_offset_"
  ) %>%
  rename_with(~ gsub("-", "minus", .x))

# -------------------------------
# Create the SVR value at time 0 for each drug and ICU stay
# -------------------------------
svr_time0_df <- complete_df %>%
  filter(offset == 0) %>%
  select(icu_stay_id, active_ingredient_name, svr_lpf) %>%
  rename(svr_time0_value = svr_lpf)

# -------------------------------
# Join offsets 1 to 120 with the value at time 0
# -------------------------------
df_post <- complete_df %>%
  filter(offset >= -15 & offset <= 120) %>%
  inner_join(svr_time0_df, by = c("icu_stay_id", "active_ingredient_name")) %>%
  mutate(
    svr_diff = svr_lpf - svr_time0_value
  ) %>%
  inner_join(
    svr_pre_wide %>% select(-svr_lpf_offset_0),
    by = c("icu_stay_id", "active_ingredient_name")
  )

# ===============================
# Specify the infusion rate (gamma)
# ===============================
gamma_values_list <- list(
  dopamine      = c(3, 5),
  dobutamine    = c(3, 5),
  norepinephrine = c(0.03, 0.10)
)

# ===============================
# Infusion-rate (gamma) groups (for case counts)
# ===============================
df_gamma_grouped <- df_post %>%
  mutate(
    gamma_group = case_when(
      active_ingredient_name %in% c("dopamine", "dobutamine") ~
        case_when(
          gamma <= 3            ~ "≤3",
          gamma > 3 & gamma <= 5 ~ "3–5",
          gamma > 5             ~ ">5"
        ),
      active_ingredient_name == "norepinephrine" ~
        case_when(
          gamma <= 0.03               ~ "≤0.03",
          gamma > 0.03 & gamma <= 0.10 ~ "0.03–0.10",
          gamma > 0.10                ~ ">0.10"
        ),
      TRUE ~ NA_character_
    )
  )

gamma_counts <- df_gamma_grouped %>%
  distinct(active_ingredient_name, icu_stay_id, gamma_group) %>%
  group_by(active_ingredient_name, gamma_group) %>%
  summarise(
    n_patients = n(),
    .groups = "drop"
  ) %>%
  mutate(
    gamma_group = case_when(
      active_ingredient_name %in% c("dopamine", "dobutamine") ~
        factor(gamma_group, levels = c(">5", "3–5", "≤3")),
      active_ingredient_name == "norepinephrine" ~
        factor(gamma_group, levels = c(">0.10", "0.03–0.10", "≤0.03"))
    )
  )

print(gamma_counts)

gamma_label_df <- gamma_counts %>%
  mutate(
    gamma_label = paste0(gamma_group, ": n=", n_patients)
  )

# ===============================
# Drug name mapping (for figure titles)
# ===============================
drug_title_map <- c(
  dopamine      = "Dopamine",
  dobutamine    = "Dobutamine",
  norepinephrine = "Norepinephrine"
)

# ===============================
# Loop
# ===============================
for (drug in names(gamma_values_list)) {

  current_df <- df_post %>%
    filter(active_ingredient_name == drug)

  model_vars <- c(
    "svr_diff", "offset", "gamma", "svr_time0_value",
    "svr_lpf_offset_minus15",
    "svr_lpf_offset_minus10",
    "svr_lpf_offset_minus5",
    "female", "age", "body_weight",
    "apache2_score",
    "ph", "pco2", "lactate",
    "hr_pre", "map_pre",
    "surgery_category",
    "on_vent", "on_rrt"
  )

  gam_ready <- current_df %>%
    select(
      icu_stay_id,
      all_of(model_vars)
    ) %>%
    na.omit()

  # --- GAM (difference + six pre-initiation SVR values) ---
  gam_svr <- gam(
    svr_diff ~
      s(offset) +
      gamma +
      ti(gamma, offset) +
      s(svr_time0_value) +
      svr_lpf_offset_minus15 +
      svr_lpf_offset_minus10 +
      svr_lpf_offset_minus5 +
      female + age + body_weight +
      apache2_score + ph + pco2 + lactate +
      hr_pre + map_pre +
      surgery_category +
      on_vent + on_rrt,
    data   = current_df,
    family = gaussian(),
    method = "REML"
  )

  # ===============================
  # Median data for prediction (base grid)
  # ===============================
  svr_pre_median <- svr_pre_wide %>%
    filter(active_ingredient_name == drug) %>%
    summarise(across(starts_with("svr_lpf_offset_"),
                     ~ median(., na.rm = TRUE)))

  svr_time0_median <- svr_time0_df %>%
    filter(active_ingredient_name == drug) %>%
    summarise(svr_time0_value = median(svr_time0_value, na.rm = TRUE))

  base_grid <- current_df %>%
    summarise(across(
      c(female, age, body_weight, apache2_score,
        ph, pco2, lactate, hr_pre, map_pre,
        on_vent, on_rrt),
      ~ median(., na.rm = TRUE)
    )) %>%
    bind_cols(svr_pre_median) %>%
    bind_cols(svr_time0_median) %>%
    slice(rep(1, 136)) %>%
    mutate(
      offset = seq(-15, 120, length.out = 136),
      surgery_category = factor(
        "valvular",
        levels = levels(current_df$surgery_category)
      )
    )

  # ===============================
  # Predict for each infusion rate (gamma)
  # ===============================
  pred_list <- list()

  for (g in gamma_values_list[[drug]]) {

    pred_grid <- base_grid %>% mutate(gamma = g)

    # Prediction (point estimates only)
    preds <- predict(gam_svr, newdata = pred_grid, type = "link")

    # reference index (offset == 0)
    ref_idx <- which(pred_grid$offset == 0)[1]
    if (is.na(ref_idx)) stop("reference (offset==0) row not found in pred_grid")

    # Center on offset 0 (point estimates)
    fit_diff <- preds - preds[ref_idx]

    pred_list[[as.character(g)]] <-
      pred_grid %>%
      mutate(
        svr_diff = fit_diff,
        predicted_svr = svr_time0_value + svr_diff,
        gamma_value = g
      )
  }

  pred_df <- bind_rows(pred_list)

  label_text <- gamma_label_df %>%
    filter(active_ingredient_name == drug) %>%
    pull(gamma_label)

  # ===============================
  # Plot (only 0 <= offset <= 60)
  # ===============================
  plot_df <- pred_df %>% filter(offset >= 0, offset <= 60)

  y_range <- diff(range(plot_df$predicted_svr, na.rm = TRUE))

  label_df <- gam_ready %>%
    mutate(
      gamma_group = case_when(
        drug %in% c("dopamine","dobutamine") ~ case_when(
          gamma <= 3 ~ "≤3",
          gamma <= 5 ~ "3–5",
          TRUE ~ ">5"
        ),
        TRUE ~ case_when(
          gamma <= 0.03 ~ "≤0.03",
          gamma <= 0.10 ~ "0.03–0.10",
          TRUE ~ ">0.10"
        )
      )
    ) %>%
    distinct(icu_stay_id, gamma_group) %>%
    count(gamma_group, name = "n_patients") %>%
    mutate(
      gamma_group = if (drug %in% c("dopamine", "dobutamine")) {
        factor(gamma_group, levels = c(">5", "3–5", "≤3"))
      } else {
        factor(gamma_group, levels = c(">0.10", "0.03–0.10", "≤0.03"))
      }
    ) %>%
    arrange(gamma_group) %>%
    mutate(
      gamma_label = paste0(gamma_group, ": n=", n_patients),
      x_pos = 45,
      y_pos = seq(1400, by = 50, length.out = n())
    )

  if (drug == "dobutamine") {

    dose_colors <- setNames(
      c("#FFD6E7", "#FF8AB7"),
      as.character(gamma_values_list[[drug]])
    )

  } else if (drug == "dopamine") {

    dose_colors <- setNames(
      c("#BFE8C7", "#3CA951"),
      as.character(gamma_values_list[[drug]])
    )

  } else if (drug == "norepinephrine") {

    dose_colors <- setNames(
      c("#C9DAFA", "#4269D0"),
      as.character(gamma_values_list[[drug]])
    )

  }    

  p <- ggplot(
  plot_df,
  aes(
    x = offset,
    y = predicted_svr,
    color = factor(gamma_value),
    group = factor(gamma_value)
  )
  ) +
  scale_color_manual(
    values = dose_colors
  ) +
  geom_line(linewidth = 0.8) +
  scale_x_continuous(
    limits = c(0, 60),
    expand = c(0, 0)
  ) +

  scale_y_continuous(
    limits = c(800, 1600),
    breaks = seq(800, 1600, by = 200)
  ) +

  labs(
    title = paste("Predicted SVR Trajectory (", drug_title_map[[drug]], ")", sep = ""),
    x = "Time from catecholamine start (min)",
    y = "Predicted SVR (dyne·s/cm5)",
    color = "dose (µg/kg/min)"
  ) +

  coord_cartesian(clip = "off") + 

  theme_classic(base_size = 10) +
  theme(
    text = element_text(family = "Arial"),
    legend.position = "none",
    plot.margin = margin(
      t = 10,
      r = 80,
      b = 10,
      l = 10
    )
  )

print(p)

  ggsave(
    filename = paste0(output_dir, "fig_svr_compare_dose_", drug, "_", output_ver, ".png"),
    plot = p,
    width = 6, height = 4, dpi = 600
  )
}