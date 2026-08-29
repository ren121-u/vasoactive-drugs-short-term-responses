# --- Packages ---
if (!require('tidyverse')) install.packages('tidyverse')
if (!require('ggrepel')) install.packages('ggrepel')
library(tidyverse)
library(mgcv)
library(ggrepel)

# --- Directories ---
data_dir   <- './data/'
output_dir <- './output/gam_comparing_by_drug/'
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

# ===============================
# time0 svr
# ===============================
svr_time0_df <- complete_df %>%
  filter(offset == 0) %>%
  select(icu_stay_id, active_ingredient_name, svr_lpf) %>%
  rename(svr_time0_value = svr_lpf)

# ===============================
# Difference data for offsets >= 0
# ===============================
df_post <- complete_df %>%
  filter(offset >= -15 & offset <= 120) %>%
  inner_join(svr_time0_df,
             by = c("icu_stay_id", "active_ingredient_name")) %>%
  mutate(
    svr_diff = svr_lpf - svr_time0_value
  ) %>%
  inner_join(
    svr_pre_wide %>% select(-svr_lpf_offset_0),
    by = c("icu_stay_id", "active_ingredient_name")
  )

# ========= Fixed infusion rate (gamma) =========
gamma_values_list <- list(
  dopamine      = 3,
  dobutamine    = 3,
  norepinephrine = 0.03
)

all_predictions <- list()

drug_n_df <- df_post %>%
  distinct(active_ingredient_name, icu_stay_id) %>%
  count(active_ingredient_name, name = "n_patients") %>%
  arrange(active_ingredient_name) %>%
  mutate(
    label = paste0(active_ingredient_name, ": n=", n_patients)
  )

# ===============================
# GAM fitting and prediction
# ===============================
for (drug in names(gamma_values_list)) {

  current_df <- df_post %>% filter(active_ingredient_name == drug)
  g <- gamma_values_list[[drug]]

  # ---- GAM (difference + six pre-initiation values) ----
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
  # Median grid for prediction
  # ===============================
  svr_pre_median <- svr_pre_wide %>%
    filter(active_ingredient_name == drug) %>%
    summarise(across(starts_with("svr_lpf_offset_"),
                     ~ median(., na.rm = TRUE)))

  svr_time0_median <- svr_time0_df %>%
    filter(active_ingredient_name == drug) %>%
    summarise(svr_time0_value = median(svr_time0_value, na.rm = TRUE))

  med_vals <- current_df %>%
  summarise(across(where(is.numeric), ~ median(., na.rm = TRUE)))

  base_grid <- med_vals %>%
    slice(rep(1, 136)) %>%
    mutate(
      offset = seq(-15, 120, length.out = 136),
      gamma  = g,
      surgery_category = factor(
        "valvular",
        levels = levels(complete_df$surgery_category)
      )
    )

  # ===============================
  # Prediction (centered on offset 0)
  # ===============================
  preds <- predict(gam_svr, newdata = base_grid, type = "link")

  ref_idx <- which(base_grid$offset == 0)[1]
  fit_diff <- preds - preds[ref_idx]

  pred_df <- base_grid %>%
    mutate(
      active_ingredient_name = drug,
      svr_diff = fit_diff,
      invasive_svr = svr_time0_value + svr_diff
    )

  all_predictions[[drug]] <- pred_df
}

# Record the patients used within the GAM loop
gam_used_ids <- list()

for (drug in names(gamma_values_list)) {
  current_df <- df_post %>% filter(active_ingredient_name == drug)

  model_vars <- c("svr_diff", "offset", "gamma", "svr_time0_value",
                   "svr_lpf_offset_minus15", "svr_lpf_offset_minus10", "svr_lpf_offset_minus5",
                   "female", "age", "body_weight", "apache2_score",
                   "ph", "pco2", "lactate", "hr_pre", "map_pre",
                   "surgery_category", "on_vent", "on_rrt")

  gam_ready <- current_df %>% select(icu_stay_id, all_of(model_vars)) %>% na.omit()
  gam_used_ids[[drug]] <- unique(gam_ready$icu_stay_id)
}

n_gam_patients <- length(unique(unlist(gam_used_ids)))
print(n_gam_patients)

final_predictions <- bind_rows(all_predictions)

# ===============================
# Draw (only 0 <= offset <= 60)
# ===============================
drug_label_map <- c(
  dopamine      = "Dopamine (3 µg/kg/min)",
  dobutamine    = "Dobutamine (3 µg/kg/min)",
  norepinephrine = "Norepinephrine (0.03 µg/kg/min)"
)

plot_df <- final_predictions %>% filter(offset >= 0, offset <= 60)

y_range <- diff(range(plot_df$invasive_svr, na.rm = TRUE))

drug_n_df <- tibble(
  active_ingredient_name = names(gam_used_ids),
  n_patients = sapply(gam_used_ids, length)
) %>%
  mutate(
    label = paste0(active_ingredient_name, ": n=", n_patients)
  )

print(drug_n_df)

drug_n_df <- drug_n_df %>%
  mutate(
    x_pos = 40,
    y_pos = seq(
      from = 1400 + 50 * (n() - 1),
      by   = -50,
      length.out = n()
    )
  )

svr_spline_combined <- ggplot(
  plot_df,
  aes(x = offset, y = invasive_svr, color = active_ingredient_name)
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

  coord_cartesian(clip = "off") +

  labs(
    x = "Time from catecholamine start (min)",
    y = "Predicted SVR (dyne·s/cm5)",
    color = "Vasoactive Drug",
    title = "Predicted SVR Trajectory"
  ) +

  theme_classic(base_size = 10) +
  theme(
    text = element_text(family = "Arial"),
    legend.position = "none",
    plot.margin = margin(t = 10, r = 90, b = 10, l = 10)
  ) +

  scale_color_manual(
    values = c(
      dobutamine     = "#FF8AB7",
      dopamine       = "#3CA951",
      norepinephrine = "#4269D0"
    ),
    labels = drug_label_map
  ) +

  guides(color = guide_legend(ncol = 1))

print(svr_spline_combined)  

ggsave(
  paste0(output_dir, "fig_svr_compare_drug_", output_ver, ".png"),
  svr_spline_combined,
  width = 6, height = 4, dpi = 600
)