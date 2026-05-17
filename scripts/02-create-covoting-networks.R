# Preamble ---------------------------------------------------------------------

# Purpose: Generate a co-voting network and cluster City Councilors based on
#          voting preference. Calculate the "Green" voting rate of the clusters.
# Author: Ethan Sansom
# Date: 17 May 2026
# License: MIT

# Setup ------------------------------------------------------------------------

library(tidygraph)
library(igraph)
library(ggraph)
library(dplyr)
library(tidyr)
library(here)
library(readr)
library(lubridate)
library(glue)
library(stringr)
library(forcats)

set.seed(123) # Clustering algorithm for network-coalition is non-deterministic
fs <- fs::path # Prevents conflicts with `igraph::path`

data_dir <- path(here(), "data")
clean_data_path <- path(data_dir, "01-clean-data", "clean_voting_2022_2026.rds")

all_votes <- read_rds(clean_data_path)

# Filter Sample ----------------------------------------------------------------

# Limiting to:
# - Councillors with `>= 400` total network_votes (out of ~700 potential network_votes)
# - Yes or No network_votes (exludes absents)
network_votes <- all_votes |>
  filter(n() >= 400, .by = councillor_id) |>
  filter(vote %in% c("No", "Yes"))

# Networking -------------------------------------------------------------------

# Each node is a councillor, each vote contributes to edge-weights between nodes
nodes <- network_votes |> distinct(name = councillor_id)
network_votes <- network_votes |> select(item_id, councillor_id, vote)

# Each edge's weight is the frequency of agreement between each pair of councillors
# across all network_votes where *both* members of the pair submitted a "Yes" or "No" vote,
# e.g. were not "Absent" or not seated on the council yet.
edges <- inner_join(
  network_votes |> rename(from = councillor_id, from_vote = vote), 
  network_votes |> rename(to = councillor_id, to_vote = vote),
  by = c("item_id"),
  relationship = "many-to-many"
) |>
  summarize(
    n_both_voted = n(), 
    n_agreed = sum(from_vote == to_vote),
    .by = c(from, to)
  ) |>
  mutate(agree_perc = n_agreed / n_both_voted)

# This dataset keeps both the A-B and B-A directions, for easier non-directed 
# summaries.
agreeableness <- edges |> filter(from != to)

# This dataset only keeps distinct pairs, e.g. A-B or B-A, noting that the order
# doesn't matter (i.e. this is an undirected graph).
edges <- edges |> filter(from < to)

covote_network <- tbl_graph(
  nodes = nodes,
  edges = edges |> select(from, to, weight = agree_perc, n_both_voted, n_agreed),
  directed = FALSE
)

# Calculate typically network statistics and cluster members using "modularity"
# similar to Waugh et. al. “Party Polarization in Congress: A Network Science 
# Approach” (2012).
covote_network <- covote_network |>
  activate(nodes) |>
  mutate(
    degree = centrality_degree(weights = weight),
    betweenness = centrality_betweenness(weights = weight, directed = FALSE),
    eigen_centrality = centrality_eigen(weights = weight, directed = FALSE),
    community = group_louvain(
      weights = weight,
      resolution = 1.030 # Lower values typically yield fewer clusters
    ) |> as.factor()
  )

# Test Plot: Verfify that the network is plausible (e.g. should be densly connected).
ggraph(covote_network, layout = "fr") +
  geom_edge_link(aes(alpha = weight, width = weight), colour = "grey60") +
  geom_node_point(aes(colour = community, size = eigen_centrality)) +
  geom_node_label(aes(label = name, colour = community), repel = TRUE, size = 3) +
  scale_edge_width(range = c(0.2, 2)) +
  theme_graph()

# Green Votes by Community -----------------------------------------------------

# Pull node community assignments as a plain tibble for joining
communities <- covote_network |>
  activate(nodes) |>
  as_tibble() |>
  select(councillor_id = name, community)

# Get the % of councillors in each "community" (cluster) who voted "Yes" on each
# item. Then, within community take the mean percentage-of-yes-network_votes for 
# each category of "Green" network_votes (e.g. all network_votes about Expanding 
# the Cycling Network).
community_green_votes <- all_votes |>
  right_join(communities, by = "councillor_id") |>
  filter(!is.na(item_eco_category))

community_green_votes <- community_green_votes |>
  bind_rows(community_green_votes |> mutate(item_eco_category = "All Green Items")) |>
  
  group_by(item_id, community, item_eco_category) |>
  summarize(perc_yes = sum(vote == "Yes") / sum(vote %in% c("Yes", "No"))) |>
  ungroup() |>

  group_by(community, item_eco_category) |>
  summarize(
    mean_perc_yes = mean(perc_yes),
    n_items = n_distinct(item_id)
  ) |>
  ungroup()

# NOTE: `community == 1` is 97.8% "Green" vs. 82.8% in `community == 1`
community_green_votes |> filter(item_eco_category == "All Green Items")

# Test Plot: Mean "Yes" vote percentage across all eco-voter items by community
community_green_votes |>
  mutate(community = if_else(community == 1, "More Green", "Less Green")) |>
  mutate(
    less_green_perc_yes = mean_perc_yes[community == "Less Green"], 
    .by = item_eco_category
  ) |>
  filter(!is.na(item_eco_category)) |>
  mutate(item_eco_category = fct_reorder(item_eco_category, less_green_perc_yes)) |>
  ggplot(aes(x = mean_perc_yes, y = item_eco_category)) +
  geom_col(aes(fill = community), position = "dodge")

# Save -------------------------------------------------------------------------

write_rds(
  covote_network, 
  path(data_dir, "01-clean-data", "covoting_network.rds")
)

write_csv(
  communities,
  path(data_dir, "01-clean-data", "covoting_communities.csv")
)

write_csv(
  community_green_votes, 
  path(data_dir, "01-clean-data", "community_eco_vote_percentage.csv")
)
