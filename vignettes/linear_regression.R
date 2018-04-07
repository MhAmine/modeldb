## ----setup, include=FALSE------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)
library(dplyr)
library(dbplyr)
library(purrr)
library(rlang)
library(readr)
library(nycflights13)
library(DBI)
library(modeldb)
library(tidypredict)

## ------------------------------------------------------------------------
con <- DBI::dbConnect(RSQLite::SQLite(), path = ":memory:")
RSQLite::initExtension(con)

## ------------------------------------------------------------------------
library(dplyr)
db_flights <- copy_to(con, nycflights13::flights, "flights")

db_sample <- db_flights %>%
  filter(!is.na(arr_time)) %>%
  head(20000) 

## ------------------------------------------------------------------------
db_sample %>%
  select(arr_delay, dep_delay, distance) %>%
  linear_regression(arr_delay)

## ------------------------------------------------------------------------
db_sample %>%
  select(arr_delay, origin) %>%
  add_dummy_variables(origin, values = c("EWR", "JFK", "LGA"))

## ------------------------------------------------------------------------
origins <- db_flights %>%
  group_by(origin) %>%
  summarise() %>%
  pull()

origins

## ------------------------------------------------------------------------
db_sample %>%
  select(arr_delay, origin) %>%
  add_dummy_variables(origin, values = origins) %>%
  linear_regression(arr_delay)

## ------------------------------------------------------------------------
db_sample %>%
  select(arr_delay, arr_time, dep_delay, dep_time) %>%
  linear_regression(arr_delay, sample_size = 20000)

## ------------------------------------------------------------------------
db_sample %>%
  mutate(distanceXarr_time = distance * arr_time) %>%
  select(arr_delay, distanceXarr_time) %>% 
  linear_regression(arr_delay, sample_size = 20000)

## ------------------------------------------------------------------------
db_sample %>%
  mutate(distanceXarr_time = distance * arr_time) %>%
  select(arr_delay, distance, arr_time, distanceXarr_time) %>% 
  linear_regression(arr_delay, sample_size = 20000)

## ------------------------------------------------------------------------
remote_model <- db_sample %>%
  mutate(distanceXarr_time = distance * arr_time) %>%
  select(arr_delay, dep_time, distanceXarr_time, origin) %>% 
  add_dummy_variables(origin, values = origins) %>%
  linear_regression(y_var = arr_delay, sample_size = 20000)

remote_model

## ------------------------------------------------------------------------
parsed <- as_parsed_model(remote_model)

parsed

## ------------------------------------------------------------------------
library(tidypredict)

tidypredict_sql(parsed, dbplyr::simulate_dbi())

## ------------------------------------------------------------------------
db_flights %>%
  mutate(distanceXarr_time = distance * arr_time) %>%
  select(arr_delay, dep_time, distanceXarr_time, origin) %>% 
  add_dummy_variables(origin, values = origins) %>%
  tidypredict_to_column(parsed)

## ------------------------------------------------------------------------
dbDisconnect(con)
