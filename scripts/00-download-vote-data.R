# Preamble ---------------------------------------------------------------------

# Purpose: Downloads and saves data from OpenData Toronto.
# Author: Ethan Sansom
# Date: 17 May 2026
# License: MIT

# Work -------------------------------------------------------------------------

library(here)
library(fs)
library(readr)
library(opendatatoronto)

data_dir <- path(here(), "data")
out_path <- path(data_dir, "00-raw-data", "raw_voting_2022_2026.csv")

# See the "For Developers" instructions here for details on the OpenData API:
# https://open.toronto.ca/dataset/members-of-toronto-city-council-voting-record/
raw_voting_2022_2026 <- opendatatoronto::get_resource("c4feb78c-c867-42a9-b803-7c6d859df969")
write_csv(raw_voting_2022_2026, out_path)
