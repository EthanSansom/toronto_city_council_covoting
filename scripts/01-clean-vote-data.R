# Preamble ---------------------------------------------------------------------

# TODO

# Setup ------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(here)
library(readr)
library(lubridate)
library(glue)
library(stringr)
library(fs)

path <- fs::path # Prevents conflicts with `igraph::path`

data_dir <- path(here(), "data")
out_path <- path(data_dir, "01-clean-data", "clean_voting_2022_2026.rds")
raw_data_path <- path(data_dir, "00-raw-data", "raw_voting_2022_2026.csv")
eco_items_path <- path(data_dir, "01-clean-data", "eco_council_items.rds")

raw_votes <- read_csv(raw_data_path)
eco_items <- read_rds(eco_items_path)

# Clean ------------------------------------------------------------------------

clean_votes <- raw_votes |>
  filter(Committee == "City Council") |> # Only interested in full council votes
  select(
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

# Unduplicate ------------------------------------------------------------------

# Agenda items may be voted on several times, for example item "2025.EC25.1"
# was voted on twice (passing unanimously both times) to allow everyone the
# chance to cast their vote.
#
# To avoid double counting, only the most recent vote is kept.
clean_votes <- clean_votes |>
  filter(datetime == max(datetime), .by = c(item_id)) |>

  # Removes 9 remaining items with 2+ simultaneous votes. Note that the council
  # has at most 26 voting members.
  filter(n() <= 26, .by = item_id)

# Merge Green Vote Categories --------------------------------------------------

clean_votes <- clean_votes |>
  left_join(
    eco_items |> select(item_id, item_eco_category = item_category),
    by = "item_id"
  )

# Save -------------------------------------------------------------------------

write_rds(clean_votes, out_path)
