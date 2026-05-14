# Setup ------------------------------------------------------------------------

# For network analysis
library(tidygraph)
library(igraph)
library(ggraph)
# For data cleaning and I/O
library(dplyr)
library(tidyr)
library(here)
library(readr)
library(lubridate)
library(glue)
library(stringr)
library(forcats)

# Clustering algorithm for network-coallition is non-deterministic
set.seed(123)

fs <- fs::path # Overwrites `igraph::path`
source(path(here(), "scripts", "utils.R"))

data_dir <- path(here(), "data")
clean_data_path <- path(data_dir, "01-clean-data", "clean_voting_2022_2026.rds")

assert_file_exits(clean_data_path)
clean_votes_2022_2026 <- read_rds(clean_data_path)

# Filter Sample ----------------------------------------------------------------

# NOTE: Limiting to:
# - Only consider "City Council" comittee (e.g. no sub-comittees)
# - Councillors with `>= 600` votes (out of ~1500 potential votes)
# - Yes or No votes (exludes absents)
city_council_votes <- clean_votes_2022_2026 |>
  filter(committee == "City Council") |>
  filter(n() >= 600, .by = councillor_id) |>
  filter(vote %in% c("No", "Yes"))

# Networking -------------------------------------------------------------------

# Each node is a councillor, each vote contributes to edge-weights between nodes.
nodes <- city_council_votes |> distinct(name = councillor_id)
votes <- city_council_votes |> select(item_id, councillor_id, vote, datetime) |> distinct()

# Each edge's weight is the frequency of agreement between each pair of councillors
# across all votes where *both* members of the pair submitted a "Yes" or "No" vote,
# e.g. were not "Absent" or not seated on the council yet.
edges <- inner_join(
  votes |> rename(from = councillor_id, from_vote = vote), 
  votes |> rename(to = councillor_id, to_vote = vote),
  by = c("item_id", "datetime"),
  relationship = "many-to-many"
) |>
  summarize(
    n_votes = n(), 
    n_agree = sum(from_vote == to_vote),
    .by = c(from, to)
  ) |>
  mutate(agree_perc = n_agree / n_votes)

# This dataset keeps both the A-B and B-A directions, for easier non-directed 
# summaries.
agreeableness <- edges |> filter(from != to)

# This dataset only keeps distinct pairs, e.g. A-B or B-A, noting that the order
# doesn't matter (i.e. this is an undirected graph).
edges <- edges |> filter(from < to)

# NOTE: Holyday Stephen is super weird. He votes with the other councillors
#       roughly 50% of the time, regardless of the councillor.
#
# Look at how agree-able each councillor is
agreeableness |>
  group_by(from) |>
  summarize(
    agree_min = min(agree_perc),
    agree_max = max(agree_perc),
    agree_range = abs(agree_max - agree_min),
    agree_mean = mean(agree_perc),
    agree_sd = sd(agree_perc)
  ) |>
  ungroup() |>
  arrange(agree_range) |>
  print(n = 99)

covote_network <- tbl_graph(
  nodes = nodes,
  edges = edges |> select(from, to, weight = agree_perc, n_votes, n_agree),
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
    # TODO: Look into `igraph::cluster_louvain` (the backend) and the other 
    # `tidygraph::group_*` options.
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
# item. Then, within community take the mean percentage-of-yes-votes for each
# category of "Green" votes (e.g. all votes about Expanding the Cycling Network).
community_green_votes <- clean_votes_2022_2026 |>
  right_join(communities, by = "councillor_id") |>
  
  group_by(item_id, community, item_eco_category) |>
  summarize(perc_yes = sum(vote == "Yes") / sum(vote %in% c("Yes", "No"))) |>
  ungroup() |>

  group_by(community, item_eco_category) |>
  summarize(mean_perc_yes = mean(perc_yes)) |>
  ungroup()

# Add the mean within community "Yes" vote percentage across all "Green" items.
community_green_votes <- bind_rows(
  community_green_votes,
  clean_votes_2022_2026 |>
    right_join(communities, by = "councillor_id") |>
    filter(!is.na(item_eco_category)) |>
    
    group_by(item_id, community, item_eco_category) |>
    summarize(perc_yes = sum(vote == "Yes") / sum(vote %in% c("Yes", "No"))) |>
    ungroup() |>

    summarize(mean_perc_yes = mean(perc_yes), .by = community) |>
    mutate(item_eco_category = "All Green Items")
)

# NOTE: `community == 1` is 88% "Green" vs. 80% in `community == 1`
community_green_votes |> filter(item_eco_category == "All Green Items")

# Test Plot: Mean "Yes" vote percentage across all eco-voter items by community.
community_green_votes |>
  mutate(community = if_else(community == 1, "More Green", "Less Green")) |>
  mutate(
    green_perc_yes = mean_perc_yes[community == "More Green"], 
    .by = item_eco_category
  ) |>
  filter(!is.na(item_eco_category)) |>
  mutate(item_eco_category = fct_reorder(item_eco_category, green_perc_yes)) |>
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
