#!/usr/bin/env Rscript

# Script to calculate the land area (in square miles) of the Illinois portion 
# of the Chicago Metropolitan Statistical Area.

# Install required packages if not already installed
required_packages <- c("sf", "tigris", "dplyr", "units")
new_packages <- required_packages[!required_packages %in% installed.packages()[,"Package"]]
if(length(new_packages) > 0) {
  install.packages(new_packages, repos = "https://cran.rstudio.com/")
}

# Load required libraries
library(sf)        # For spatial data handling
library(tigris)    # For accessing Census TIGER/Line shapefiles
library(dplyr)     # For data manipulation
library(units)     # For unit conversion

# Define the Illinois counties in the Chicago MSA
il_msa_counties <- c(
  "Cook", 
  "DuPage", 
  "Kane", 
  "Lake", 
  "McHenry", 
  "Will"
)

# Set tigris options
options(tigris_use_cache = TRUE)

# Download Illinois counties shapefile
message("Downloading Illinois county data...")
illinois_counties <- counties(state = "IL", cb = FALSE, year = 2022)

# Filter to only include Chicago MSA counties in Illinois
chicago_msa_il <- illinois_counties %>%
  filter(NAME %in% il_msa_counties)

# Transform to an equal area projection for accurate area calculation
# Using USA Contiguous Albers Equal Area projection (EPSG:5070)
chicago_msa_il_projected <- st_transform(chicago_msa_il, 5070)

# Calculate area in square meters
chicago_msa_il_projected$area_sq_meters <- st_area(chicago_msa_il_projected)

# Convert to square miles (1 sq mile = 2,589,988.11 sq meters)
chicago_msa_il_projected$area_sq_miles <- units::set_units(chicago_msa_il_projected$area_sq_meters, "m^2") %>%
  units::set_units("mi^2") %>%
  as.numeric()

# Calculate total area
total_area_sq_miles <- sum(chicago_msa_il_projected$area_sq_miles)

# Print results for each county and the total
cat("\nIllinois Counties in Chicago MSA:\n")
cat(paste(rep("-", 40), collapse = ""), "\n")
cat(sprintf("%-15s %-20s\n", "County", "Area (sq miles)"))
cat(paste(rep("-", 40), collapse = ""), "\n")

for(i in 1:nrow(chicago_msa_il_projected)) {
  cat(sprintf("%-15s %.2f\n", 
              chicago_msa_il_projected$NAME[i], 
              chicago_msa_il_projected$area_sq_miles[i]))
}

cat(paste(rep("-", 40), collapse = ""), "\n")
cat(sprintf("%-15s %.2f\n", "TOTAL", total_area_sq_miles))
cat(paste(rep("-", 40), collapse = ""), "\n")

cat("\nThe Illinois portion of the Chicago Metropolitan Statistical Area\n")
cat(sprintf("covers %.2f square miles of land.\n", total_area_sq_miles))

# Save result to a variable that can be used in the RMD file
cat(sprintf("\nTOTAL_AREA_SQ_MILES=%.2f\n", total_area_sq_miles))
