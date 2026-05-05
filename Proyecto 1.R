gps_data <- Movement_ecology_of_the_jaguar_in_the_largest_floodplain_of_the_world_the_Brazilian_Pantanal
rm(Movement_ecology_of_the_jaguar_in_the_largest_floodplain_of_the_world_the_Brazilian_Pantanal)

library(dplyr)

names(gps_data)
head(gps_data)

library(dplyr)

##### Cleaning the file ####
gps_clean <- gps_data %>%
  rename(
    event_id = `event-id`,
    datetime_utc = timestamp,
    lon = `location-long`,
    lat = `location-lat`,
    species = `individual-taxon-canonical-name`,
    tag_id = `tag-local-identifier`,
    animal_id = `individual-local-identifier`,
    utm_x = `utm-easting`,
    utm_y = `utm-northing`,
    utm_zone = `utm-zone`,
    datetime_local = `study-local-timestamp`
  ) %>%
  ungroup()

##### Individual temporal check ####
time_check <- gps_clean %>%
  arrange(animal_id, datetime_utc) %>%
  group_by(animal_id) %>%
  mutate(
    time_lag_hours = as.numeric(
      difftime(datetime_utc, lag(datetime_utc), units = "hours")
    )
  ) %>%
  summarise(
    n_points = n(),
    median_lag = median(time_lag_hours, na.rm = TRUE),
    mean_lag = mean(time_lag_hours, na.rm = TRUE),
    min_lag = min(time_lag_hours, na.rm = TRUE),
    max_lag = max(time_lag_hours, na.rm = TRUE),
    .groups = "drop"
  )

##### IDs with temporal resolution (~1 hour)
valid_ids <- time_check %>%
  filter(median_lag <= 1.5) %>%
  pull(animal_id)

##### Filtered dataset ####
gps_filtered <- gps_clean %>%
  filter(animal_id %in% valid_ids) %>%
  arrange(animal_id, datetime_utc) %>%
  group_by(animal_id) %>%
  mutate(
    time_lag = as.numeric(
      difftime(datetime_utc, lag(datetime_utc), units = "hours")
    )
  ) %>%
  filter(time_lag >= 0.5 & time_lag <= 1.5) %>%
  ungroup()

#### Final resume ####  
gps_filtered %>%
  summarise(
    n_points = n(),
    n_animals = n_distinct(animal_id)
  )

#### Points per individual after filtering #### 
gps_filtered %>%
  count(animal_id, sort = TRUE)

#####-------------------------------------------------------####

#Let's use Picole, jaguar individual with highest observations (n=8177)

install.packages("amt")
library(amt)
library(dplyr)

gps_one <- gps_filtered %>%
  filter(animal_id == "Picole") %>%
  arrange(datetime_utc)

track_picole <- make_track(
  gps_one,
  .x = utm_x,
  .y = utm_y,
  .t = datetime_utc,
  id = animal_id,
  crs = 32721
)

track_picole_resampled <- track_picole %>%
  track_resample(
    rate = hours(1),
    tolerance = minutes(15)
  )
steps_picole <- track_picole_resampled %>%
  steps_by_burst()
head(steps_picole)
summary(steps_picole$sl_)

steps_picole_clean <- steps_picole %>%
  filter(sl_ > 0) %>%
  filter(!is.na(ta_))
summary(steps_picole_clean$sl_)
summary(steps_picole_clean$ta_)

##### Randomize step count #### 

set.seed(123)

random_steps_picole <- steps_picole_clean %>%
  random_steps(n = 10)

head(random_steps_picole)
table(random_steps_picole$case_)
table(random_steps_picole$case_, random_steps_picole$case_)

ssf_picole <- random_steps_picole %>%
  mutate(
    used = if_else(case_ == TRUE, 1, 0)
  )
ssf_picole %>%
  count(used)
ssf_picole %>%
  select(step_id_, used, x1_, y1_, x2_, y2_, sl_, ta_, t1_, t2_) %>%
  head()

#####--- Export GeoPackage ####

library(sf)

points_end <- ssf_picole %>%
  select(step_id_, used, x2_, y2_) %>%
  st_as_sf(coords = c("x2_", "y2_"), crs = 32721)

st_write(points_end, "points_end.gpkg", delete_dsn = TRUE)
getwd()

##### -----------Final table from QGIS - Add environmental variables ------------ #### 

library(sf)
library(dplyr)

env_data <- st_read("temp_pantan.gpkg") %>%
  st_drop_geometry()
names(env_data)

library(dplyr)

ssf_final <- ssf_picole %>%
  left_join(env_data, by = "step_id_")

env_data %>%
  count(step_id_) %>%
  filter(n > 1)

----------------------------------------------------------------------
  
ssf_picole_export <- ssf_picole %>%
  mutate(point_id = row_number())

points_end <- ssf_picole_export %>%
  select(point_id, step_id_, used, x2_, y2_) %>%
  st_as_sf(coords = c("x2_", "y2_"), crs = 32721)

st_write(
  points_end,
  "points_end2.gpkg",
  delete_dsn = TRUE
)

##### ----------- ------------ #### 

env_data <- st_read("points_env_FINAL.gpkg") %>%
  st_drop_geometry()

names(env_data)

ssf_final <- ssf_picole_export %>%
  left_join(env_data, by = "point_id")
nrow(ssf_final)
nrow(ssf_picole_export)
names(ssf_final)

ssf_final <- ssf_final %>%
  rename(
    step_id_ = step_id_.x,
    used = used.x
  ) %>%
  select(-step_id_.y, -used.y)

names(ssf_final)
nrow(ssf_final)
nrow(ssf_picole_export)
summary(ssf_final$NDVI1)
summary(ssf_final$temp1)
table(ssf_final$used)

library(survival)

model_ssf <- clogit(
  used ~ NDVI1 + temp1 + strata(step_id_),
  data = ssf_final
)
summary(model_ssf)

##### Standarize values ####

ssf_final <- ssf_final %>%
  mutate(
    NDVI_sc = scale(NDVI1),
    temp_sc = scale(temp1)
  )

model_ssf3 <- clogit(
  used ~ NDVI_sc + temp_sc + log(sl_) + cos(ta_) + strata(step_id_),
  data = ssf_final
) #This is the final model

summary(model_ssf3)

###### Probability of use #####

library(terra)

ndvi <- rast("ndvi_pantanal (1).tif")
temp <- rast("temp_pantanal.tif")

temp <- resample(temp, ndvi, method = "bilinear")

ndvi_mean <- mean(ssf_final$NDVI1, na.rm = TRUE)
ndvi_sd   <- sd(ssf_final$NDVI1, na.rm = TRUE)

temp_mean <- mean(ssf_final$temp1, na.rm = TRUE)
temp_sd   <- sd(ssf_final$temp1, na.rm = TRUE)

ndvi_sc_r <- (ndvi - ndvi_mean) / ndvi_sd
temp_sc_r <- (temp - temp_mean) / temp_sd

coef(model_ssf3)

b_ndvi <- coef(model_ssf3)["NDVI_sc"]
b_temp <- coef(model_ssf3)["temp_sc"]

logit <- b_ndvi * ndvi_sc_r + b_temp * temp_sc_r

prob <- 1 / (1 + exp(-logit))

writeRaster(
  prob,
  "probabilidad_uso.tif",
  overwrite = TRUE
)

range(gps_data$datetime_utc, na.rm = TRUE)
