library(tidyverse)

# Path settings
data_dir   <- "./data/"
output_dir <- "./output/gamma_hist/"
data_ver   <- "20260618"
output_ver <- "20260625"

# Load data
df_map <- read.csv(paste0(data_dir, data_ver, "_map_filtered.csv"))
df_base <- read.csv(paste0(data_dir, data_ver, "_base.csv"))

# Cases with MAP, dobutamine only
df_filtered <- df_base %>%
  filter(active_ingredient_name == "dobutamine") %>%
  semi_join(df_map %>%
              filter(active_ingredient_name == "dobutamine") %>%
              select(icu_stay_id) %>% distinct(),
            by = "icu_stay_id")

# Create the histogram
p <- ggplot(df_filtered, aes(x = gamma)) +
  geom_histogram(binwidth = 0.25, fill = 'skyblue', color = 'black') +
  scale_x_continuous(
    limits = c(0, 11),
    breaks = seq(0, 11, by = 1)
  ) +
  labs(
    title = "Distribution of Dobutamine Starting Dose",
    x = "Dose (μg/kg/min)",
    y = "Count"
  ) +
  theme_classic() +
  theme(
    text = element_text(family = "Arial"),
    plot.title = element_text(size = 14, hjust = 0.5)
  )

print(p)

# Save
ggsave(
  filename = paste0(output_dir, "gamma_hist_dobutamine_", output_ver, ".png"),
  plot = p,
  width = 6, height = 4, dpi = 600
)
