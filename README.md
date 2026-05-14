# Identifying Coalitions in the 2022-2026 Toronto City Council via Co-Voting Network Analysis

> [!WARNING]
> This repository is a work in progress. The code and associated paper are under active development.

### Overview

Following the methodology of “Party Polarization in Congress: A Network Science Approach” (Waugh et al., 2009), 
this paper identifies two coalitions of Toronto City Councillors seated during the 2022-2026 term based on their
voting behaviour on 744 agenda items.

The Toronto City Council is a non-partisan committee: unlike in federal or provincial elections, councillors appear on 
the ballot with no party label. This absence of party signal has been shown to make candidate evaluation difficult 
for voters in municipal elections, who are often unaware of the available candidates prior to casting their vote.
While the City of Toronto publishes the full voting record of its councillors as open data, this dataset is 
consumed primarily by an expert audience.

This paper demonstrates the use of co-voting network analysis to cluster City Councillors into ideological 
groups based on their revealed voting behaviour, making voting patterns more legible to a general audience.
Councillors who frequently vote together are connected by stronger edges in the network, and two communities 
of similar councillors are identified via the [Louvain](https://en.wikipedia.org/wiki/Louvain_method) network-clustering algorithm. Using data from the 
[Climate Voting Records Toronto](https://votingrecords.climatefast.ca/) project, which tracks climate-related 
City Council votes, the two coalitions are shown to differ by nine percentage points in their support for 
pro-climate items, such as expanding cycling infrastructure. This suggests that co-voting network analysis 
can be used to  automatically identify ideological groups among non-partisan councillors whose policy 
positions are otherwise opaque to voters without a party affiliation signal.

### Data

Voting records are sourced from the [City of Toronto Open Data portal](https://open.toronto.ca/dataset/members-of-toronto-city-council-voting-record/),
covering all recorded votes from the 2022–2026 council term. The dataset contains one row per councillor per
vote, with variables for councillor name, vote (Yes, No, or Absent), agenda item identifier, and agenda
item title. The same item may be voted on several times, resulting in multiple rows per item. This analysis is 
restricted to full City Council votes (excluding committee votes) and to Yes/No votes only, yielding a 
dataset of 30 councilors and 744 agenda items.

74 agenda items are categorized as pro-climate votes across 13 categories including plastic reduction, 
public transit growth, and promoting electric vehicle adoption, using data collected from the [Climate Voting Records Toronto](https://votingrecords.climatefast.ca/)
website for the 2022-2026 City Council session.

### Repository Structure

Dependencies of this project are managed by [{renv}](https://rstudio.github.io/renv/). To reproduce
this paper, run the following `R` commands from the repository root.

1. `renv::init()` loads the required dependenices.
2. `source("00-download-eco-council-items.R")` scrapes items from [Climate Voting Records Toronto](https://votingrecords.climatefast.ca/), which are subject to change. Skip this step to use the `eco_council_items.rds` dataset, current as of May 14, 2026.
3. `source("00-download-vote-data.R")` downloads City Council voting data from the [City of Toronto Open Data portal](https://open.toronto.ca/dataset/members-of-toronto-city-council-voting-record/).
4. `source("02-create-covoting-networks.R")` creates the co-voting network and performs Louvain network-clustering.
5. `paper.qmd` renders the paper as a PDF. In RStudio, Positron, or another IDE, open `paper.qmd` and click render to generate the paper. Alternatively use the terminal command `quarto render paper/paper.qmd`.


```
├── data
│   ├── 00-raw-data
│   │   └── raw_voting_2022_2026.csv           # Raw 2022-2026 council votes from OpenData Toronto
│   └── 01-clean-data
│       ├── clean_voting_2022_2026.rds         # Clean 2022-2026 council votes
│       ├── community_eco_vote_percentage.csv  # Frequency of pro-climate votes by cluster
│       ├── covoting_communities.csv           # Councillor cluster identification
│       ├── covoting_network.rds               # {tidygraph} co-voting network
│       ├── eco_council_items.rds              # Council item climate categorization
│       └── log_download_eco_council_items.rds # Error/success log from climate item download
├── paper
│   └── paper.qmd # Generates the paper PDF
├── renv
│   └── ...
├── renv.lock
├── scripts
│   ├── 00-download-eco-council-items.R # Downloads, logs, and saves `eco_council_items.rds`
│   ├── 00-download-vote-data.R         # Downloads and saves `raw_voting_2022_2026.csv`
│   ├── 01-clean-vote-data.R            # Cleans voter roles and saves `clean_voting_2022_2026.rds`
│   ├── 02-create-covoting-networks.R   # Generate the co-voting network and cluster councillors
│   └── utils.R
└── toronto_city_council_covoting.Rproj
```

### Statement on LLM Usage

A statement of LLM usage for this paper will be included at `other/llm/usage.txt`.
