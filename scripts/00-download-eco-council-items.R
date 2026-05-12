library(here)
library(fs)
library(readr)
library(rlang)
library(cli)
library(purrr)
library(httr2)
library(rvest)
library(dplyr)
library(stringr)
library(glue)

# FLAG: This code scrapes data from `url` as of May 5, 2026, but might not work
#       in the future if the website changes. A copy of the originally scraped
#       data is available in the `data/00-clean-data` directory, along with a log
#       of the successful and failed HTTP requests.
data_dir <- path(here(), "data")
out_path <- path(data_dir, "01-clean-data", "eco_council_items.rds")
log_path <- path(data_dir, "01-clean-data", "log_download_eco_council_items.rds")
url <- "https://votingrecords.climatefast.ca/voting-records/items/"

# Helpers ----------------------------------------------------------------------

# Extract the item information (e.g. item_id = "2025.MM35.10", item_category = 
# "Expand the Cycling Network and Make It Safe", etc.) from a Climate Voting
# Records Toronto item page, see link for an example item page:
# https://votingrecords.climatefast.ca/voting-records/item/385544
resp_parse_item_metadata <- function(response) {
  page <- response |> resp_body_html()

  # The HTML doesn't have section classes, but each section (e.g. Background) is
  # an <h3> with the `section` text (e.g. "Background") followed by <p> contents:
  # <h3>{section}</h3><p>The content text...</p>
  item_section_text <- function(html, section) {
    xpath <- glue("//h3[normalize-space(text())='{section}']/following-sibling::p[1]")
    html |>
      html_node(xpath = xpath) |>
      html_text(trim = TRUE)
  }

  tibble(
    item_id = page |> html_node("h1.item-id a") |> html_text(trim = TRUE),
    item_category = page |> html_node("a.item-category") |> html_text(trim = TRUE),
    item_background = item_section_text(page, "Background"),
    item_description = item_section_text(page, "Item Description"),
    item_proposed_by = item_section_text(page, "Proposed by")
  )
}

# Download ---------------------------------------------------------------------

response <- url |> request() |> req_perform()
page <- response |> resp_body_html()

# `page` is a listing of links to per-item pages, describing the item (e.g. Make
# Groceries Free), it's category (e.g. Food), and the councillor's votes.
voting_item_stubs <- page |>
  html_nodes("a") |>
  html_attr("href") |>
  str_subset("^/voting-records/item/") |>
  unique()

item_requests <- map(
  voting_item_stubs,
  \(stub) {
    url |> 
      request() |>
      req_url_path(stub) |>
      req_throttle(rate = 10 / 60) |>
      req_retry(max_tries = 3)
  }
)

item_requests_urls <- item_requests |> map_chr("url")
item_responses <- item_requests |> req_perform_sequential(on_error = "continue")

# Parse ------------------------------------------------------------------------

# Result is either a tibble of metadata, a HTTP request error, or a parsing error
item_results <- map(
  item_responses,
  \(response) {
    if (is_error(response)) return(response) # HTTP Error
    try_fetch(
      resp_parse_item_metadata(response), 
      error = function(e) e # Parsing Error
    )
  }
)

log <- map2(
  item_results,
  item_requests_urls,
  \(result, url) {
    if (is_tibble(result)) {
      tibble(url = url, status = "Success", error_msg = NA)
    } else if (inherits(result, "httr2_error")) {
      tibble(url = url, status = "HTTP Error", error_msg = result$message)
    } else {
      tibble(url = url, status = "Parsing Error", error_msg = cnd_message(result))
    }
  }
) |>
  bind_rows() |>
  distinct()

successes <- item_results |> keep(is_tibble)
if (!is_empty(successes)) {
  item_metadata <- successes |> bind_rows() |> distinct()
} else {
  # Off chance we download nothing, save an empty schema
  item_metadata <- tibble(
    item_id = character(),
    item_category = character(),
    item_background = character(),
    item_description = character(),
    item_proposed_by = character()
  )
}

# Save -------------------------------------------------------------------------

write_rds(item_metadata, out_path)
write_rds(log, log_path)
