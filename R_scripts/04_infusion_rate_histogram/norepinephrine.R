library(tidyverse)

# Path settings (change as needed)
data_dir   <- "./data/"
output_dir <- "./output/gamma_hist/"
data_ver   <- "20260618"
output_ver <- "20260625"

# Load data
df_map <- read.csv(paste0(data_dir, data_ver, "_map_filtered.csv"))
df_base <- read.csv(paste0(data_dir, data_ver, "_base.csv"))

# --- Rename noradrenaline to norepinephrine for the manuscript ---
df_map$active_ingredient_name[df_map$active_ingredient_name == "noradrenaline"] <- "norepinephrine"
df_base$active_ingredient_name[df_base$active_ingredient_name == "noradrenaline"] <- "norepinephrine"

# Cases with MAP, norepinephrine only
df_filtered <- df_base %>%
  filter(active_ingredient_name == "norepinephrine") %>%
  semi_join(df_map %>% 
              filter(active_ingredient_name == "norepinephrine") %>%
              select(icu_stay_id) %>% distinct(),
            by = "icu_stay_id")

# Create the plot
p <- ggplot(df_filtered, aes(x = gamma)) +
  geom_histogram(binwidth = 0.005, fill = 'skyblue', color = 'black') +
  scale_x_continuous(
    limits = c(0, 0.3),
    breaks = seq(0, 0.3, by = 0.025)
  ) +
  labs(
    title = "Distribution of Norepinephrine Starting Dose",
    x = 'Dose (μg/kg/min)',
    y = 'Count'
  ) +
  theme_classic() +
  theme(
    text = element_text(family = "Arial"),
    plot.title = element_text(size = 14, hjust = 0.5)
  )

print(p)

# Save
ggsave(
  filename = paste0(output_dir, "gamma_hist_norepinephrine_", output_ver, ".png"),
  plot = p,
  width = 6, height = 4, dpi = 600
)
