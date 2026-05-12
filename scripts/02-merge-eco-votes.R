library(dplyr)
library(tidyr)
library(here)
library(readr)
library(lubridate)
library(glue)
library(stringr)
library(fs)

source(path(here(), "scripts", "utils.R"))

data_dir <- path(here(), "data")
votes_path <- path(data_dir, "01-clean-data", "clean_voting_2022_2026.rds")
eco_items_path <- path(data_dir, "01-clean-data", "eco_council_items.rds")

assert_file_exits(votes_path)
assert_file_exits(eco_items_path)

votes <- read_rds(votes_path)
eco_items <- read_rds(eco_items_path)

