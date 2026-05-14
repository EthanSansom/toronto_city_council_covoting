library(dplyr)
library(tidyr)
library(here)
library(readr)
library(lubridate)
library(glue)
library(stringr)
library(fs)

path <- fs::path # TODO: Resolve the dependency problem with `igraph::path`
source(path(here(), "scripts", "utils.R"))

data_dir <- path(here(), "data")
out_path <- path(data_dir, "01-clean-data", "clean_voting_2022_2026.rds")
raw_data_path <- path(data_dir, "00-raw-data", "raw_voting_2022_2026.csv")
eco_items_path <- path(data_dir, "01-clean-data", "eco_council_items.rds")

assert_file_exits(raw_data_path)
assert_file_exits(eco_items_path)

raw_votes_2022_2026 <- read_csv(raw_data_path)
eco_items <- read_rds(eco_items_path)

# Clean ------------------------------------------------------------------------

clean_votes_2022_2026 <- raw_votes_2022_2026 |>
  select(
    # Dropping unneeded columns for size:
    # id = X_id,
    # term = Term,
    committee = Committee,
    result = Result,
    vote_description = Vote.Description,
    fname = First.Name,
    lname = Last.Name,
    datetime = Date.Time,
    item_id = `Agenda.Item..`,
    item_title = Agenda.Item.Title,
    vote = Vote
  ) |>
  mutate(
    councillor_id = glue("{lname} {fname}"), # Councillor names are unique
    datetime = datetime |>
      str_remove("[AP]M$") |>
      str_squish() |>
      parse_datetime()
  )

# Merge Green Vote Categories --------------------------------------------------

clean_votes_2022_2026 <- clean_votes_2022_2026 |>
  left_join(
    eco_items |> select(item_id, item_eco_category = item_category),
    by = "item_id"
  )

# Save -------------------------------------------------------------------------

write_rds(clean_votes_2022_2026, out_path)
