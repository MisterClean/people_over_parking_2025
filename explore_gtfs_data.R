# GTFS Data Exploration Script for Pace and Metra
# This script downloads and explores the GTFS data from Pace and Metra transit agencies
# to understand their structure and prepare for integration with CTA data.

# Load required packages
library(tidyverse)
library(data.table)
library(zip)
library(httr)
library(lubridate)
library(sf)

# Create a cache directory if it doesn't exist
cache_dir <- "gtfs_cache"
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir)
}

# Function to download and extract GTFS data
download_and_extract_gtfs <- function(agency_name, zip_link) {
  # Create a temporary directory to store the downloaded file
  temp_dir <- file.path(tempdir(), agency_name)
  if (!dir.exists(temp_dir)) {
    dir.create(temp_dir, recursive = TRUE)
  }
  
  temp_file <- file.path(temp_dir, paste0(agency_name, "_gtfs.zip"))
  cache_file <- file.path(cache_dir, paste0(agency_name, "_gtfs.zip"))
  
  # Try to download or use cached data
  tryCatch({
    # Download the GTFS ZIP file with a timeout
    options(timeout = 60)  # Increase timeout to 60 seconds
    download.file(zip_link, temp_file, mode = "wb", quiet = TRUE)
    
    # Save a copy to cache
    file.copy(temp_file, cache_file, overwrite = TRUE)
    
  }, error = function(e) {
    message("Download failed: ", e$message)
    if (file.exists(cache_file)) {
      message("Using cached GTFS data from ", cache_file)
      file.copy(cache_file, temp_file, overwrite = TRUE)
    } else {
      stop("Could not download GTFS data and no cache available.", call. = FALSE)
    }
  })
  
  # Extract the files
  gtfs_files <- unzip(temp_file, exdir = temp_dir)
  
  # Return the directory containing the extracted files
  return(temp_dir)
}

# Download and extract GTFS data for Pace and Metra
pace_dir <- download_and_extract_gtfs("pace", "https://www.pacebus.com/sites/default/files/2025-02/GTFS.zip")
metra_dir <- download_and_extract_gtfs("metra", "https://schedules.metrarail.com/gtfs/schedule.zip")

# Function to list all files in a GTFS directory
list_gtfs_files <- function(dir_path) {
  files <- list.files(dir_path, pattern = "\\.txt$")
  return(files)
}

# List all files in each GTFS feed
cat("Pace GTFS files:\n")
pace_files <- list_gtfs_files(pace_dir)
print(pace_files)

cat("\nMetra GTFS files:\n")
metra_files <- list_gtfs_files(metra_dir)
print(metra_files)

# Function to examine the structure of a GTFS table
examine_table <- function(agency_name, dir_path, file_name) {
  if (!file.exists(file.path(dir_path, file_name))) {
    cat(paste0(file_name, " not found in ", agency_name, " GTFS feed\n"))
    return(NULL)
  }
  
  # Read the table
  table_data <- fread(file.path(dir_path, file_name))
  
  # Get column names and types
  col_info <- data.frame(
    agency = agency_name,
    file = file_name,
    column = names(table_data),
    type = sapply(table_data, class),
    sample_values = sapply(table_data, function(x) paste(head(unique(x), 3), collapse = ", ")),
    stringsAsFactors = FALSE
  )
  
  # Get row count
  row_count <- nrow(table_data)
  
  # Return information
  return(list(
    col_info = col_info,
    row_count = row_count,
    data = table_data
  ))
}

# Key tables to examine
key_tables <- c("agency.txt", "stops.txt", "routes.txt", "trips.txt", "stop_times.txt", "calendar.txt")

# Examine key tables for Pace
pace_tables <- lapply(key_tables, function(table) {
  examine_table("pace", pace_dir, table)
})
names(pace_tables) <- gsub("\\.txt$", "", key_tables)

# Examine key tables for Metra
metra_tables <- lapply(key_tables, function(table) {
  examine_table("metra", metra_dir, table)
})
names(metra_tables) <- gsub("\\.txt$", "", key_tables)

# Print summary information for each agency
print_agency_summary <- function(agency_name, tables) {
  cat(paste0("\n=== ", agency_name, " GTFS Summary ===\n"))
  
  for (table_name in names(tables)) {
    table_info <- tables[[table_name]]
    if (is.null(table_info)) {
      cat(paste0(table_name, ": Not available\n"))
      next
    }
    
    cat(paste0("\n", table_name, " (", table_info$row_count, " rows)\n"))
    print(table_info$col_info[, c("column", "type")])
    
    # Print a few sample rows for stops and routes
    if (table_name %in% c("stops", "routes", "agency")) {
      cat("\nSample data:\n")
      print(head(table_info$data, 3))
    }
  }
}

print_agency_summary("Pace", pace_tables)
print_agency_summary("Metra", metra_tables)

# Analyze route types
analyze_route_types <- function(agency_name, routes_table) {
  if (is.null(routes_table)) {
    cat(paste0("Routes table not available for ", agency_name, "\n"))
    return(NULL)
  }
  
  # Count route types
  route_type_counts <- table(routes_table$data$route_type)
  
  cat(paste0("\n=== ", agency_name, " Route Types ===\n"))
  print(route_type_counts)
  
  # GTFS route type reference:
  # 0: Tram, Streetcar, Light rail
  # 1: Subway, Metro
  # 2: Rail
  # 3: Bus
  # 4: Ferry
  # 5: Cable car
  # 6: Gondola, Suspended cable car
  # 7: Funicular
  
  # Map route types to descriptions
  route_type_desc <- c(
    "0" = "Tram/Streetcar/Light rail",
    "1" = "Subway/Metro",
    "2" = "Rail",
    "3" = "Bus",
    "4" = "Ferry",
    "5" = "Cable car",
    "6" = "Gondola/Suspended cable car",
    "7" = "Funicular"
  )
  
  for (type in names(route_type_counts)) {
    desc <- route_type_desc[type]
    if (is.na(desc)) desc <- "Unknown"
    cat(paste0("Type ", type, " (", desc, "): ", route_type_counts[type], " routes\n"))
  }
}

analyze_route_types("Pace", pace_tables$routes)
analyze_route_types("Metra", metra_tables$routes)

# Analyze stops with coordinates
analyze_stops <- function(agency_name, stops_table) {
  if (is.null(stops_table)) {
    cat(paste0("Stops table not available for ", agency_name, "\n"))
    return(NULL)
  }
  
  stops_data <- stops_table$data
  
  # Check for location_type field
  has_location_type <- "location_type" %in% names(stops_data)
  
  if (has_location_type) {
    location_type_counts <- table(stops_data$location_type, useNA = "ifany")
    
    cat(paste0("\n=== ", agency_name, " Stop Location Types ===\n"))
    print(location_type_counts)
    
    # GTFS location_type reference:
    # 0 or empty: Stop (or Platform)
    # 1: Station
    # 2: Entrance/Exit
    # 3: Generic Node
    # 4: Boarding Area
    
    location_type_desc <- c(
      "0" = "Stop/Platform",
      "1" = "Station",
      "2" = "Entrance/Exit",
      "3" = "Generic Node",
      "4" = "Boarding Area"
    )
    
    for (type in names(location_type_counts)) {
      type_key <- if(type == "") "0" else type
      desc <- location_type_desc[type_key]
      if (is.na(desc)) desc <- "Unknown"
      count <- location_type_counts[type]
      cat(paste0("Type ", if(type == "") "empty/0" else type, " (", desc, "): ", count, " stops\n"))
    }
  } else {
    cat(paste0(agency_name, " stops table does not have a location_type field\n"))
  }
  
  # Check for parent_station field
  has_parent_station <- "parent_station" %in% names(stops_data)
  
  if (has_parent_station) {
    parent_station_count <- sum(!is.na(stops_data$parent_station) & stops_data$parent_station != "")
    
    cat(paste0("\n", agency_name, " stops with parent stations: ", parent_station_count, 
               " (", round(parent_station_count/nrow(stops_data)*100, 1), "%)\n"))
  } else {
    cat(paste0(agency_name, " stops table does not have a parent_station field\n"))
  }
  
  # Check for coordinates
  has_coords <- all(c("stop_lat", "stop_lon") %in% names(stops_data))
  
  if (has_coords) {
    missing_coords <- sum(is.na(stops_data$stop_lat) | is.na(stops_data$stop_lon))
    
    cat(paste0("\n", agency_name, " stops missing coordinates: ", missing_coords, 
               " (", round(missing_coords/nrow(stops_data)*100, 1), "%)\n"))
    
    # Create a spatial object for stops with coordinates
    valid_stops <- stops_data[!is.na(stops_data$stop_lat) & !is.na(stops_data$stop_lon), ]
    
    if (nrow(valid_stops) > 0) {
      stops_sf <- st_as_sf(valid_stops, coords = c("stop_lon", "stop_lat"), crs = 4326)
      
      # Calculate bounding box
      bbox <- st_bbox(stops_sf)
      
      cat(paste0("\n", agency_name, " stops bounding box:\n"))
      print(bbox)
    }
  } else {
    cat(paste0(agency_name, " stops table does not have coordinate fields\n"))
  }
}

analyze_stops("Pace", pace_tables$stops)
analyze_stops("Metra", metra_tables$stops)

# Analyze service frequency
analyze_frequency <- function(agency_name, trips_table, stop_times_table, calendar_table) {
  if (is.null(trips_table) || is.null(stop_times_table) || is.null(calendar_table)) {
    cat(paste0("Required tables not available for ", agency_name, "\n"))
    return(NULL)
  }
  
  # Get weekday service
  weekday_service <- calendar_table$data[
    monday == 1 & tuesday == 1 & wednesday == 1 & thursday == 1 & friday == 1, 
    service_id
  ]
  
  # Get weekday trips
  weekday_trips <- trips_table$data[service_id %in% weekday_service]
  
  # Define peak hours
  morning_peak_start <- as.ITime("07:00:00")
  morning_peak_end <- as.ITime("09:00:00")
  evening_peak_start <- as.ITime("16:00:00")
  evening_peak_end <- as.ITime("18:00:00")
  
  # Process stop times
  stop_times_data <- stop_times_table$data
  
  # Handle different time formats
  if ("arrival_time" %in% names(stop_times_data)) {
    # Try to convert arrival_time to ITime
    tryCatch({
      stop_times_data[, arrival_time_hhmmss := substr(arrival_time, 1, 8)]
      stop_times_data[, arrival_time_obj := as.ITime(arrival_time_hhmmss)]
      
      # Filter for peak hours
      peak_stop_times <- stop_times_data[
        (arrival_time_obj >= morning_peak_start & arrival_time_obj <= morning_peak_end) |
        (arrival_time_obj >= evening_peak_start & arrival_time_obj <= evening_peak_end)
      ]
      
      # Join with trips to get route information
      peak_stop_times <- merge(
        peak_stop_times, 
        weekday_trips[, .(trip_id, route_id)], 
        by = "trip_id"
      )
      
      # Count unique routes per stop during peak hours
      routes_per_stop <- peak_stop_times[, .(unique_routes = uniqueN(route_id)), by = stop_id]
      
      # Get stops with 2+ routes
      multi_route_stops <- routes_per_stop[unique_routes >= 2]
      
      cat(paste0("\n=== ", agency_name, " Service Frequency Analysis ===\n"))
      cat(paste0("Total stops with service during peak hours: ", length(unique(peak_stop_times$stop_id)), "\n"))
      cat(paste0("Stops with 2+ routes during peak hours: ", nrow(multi_route_stops), "\n"))
      
      # Distribution of route counts
      route_count_dist <- table(routes_per_stop$unique_routes)
      cat("\nDistribution of route counts per stop:\n")
      print(route_count_dist)
      
    }, error = function(e) {
      cat(paste0("Error processing ", agency_name, " stop times: ", e$message, "\n"))
    })
  } else {
    cat(paste0(agency_name, " stop_times table does not have an arrival_time field\n"))
  }
}

analyze_frequency("Pace", pace_tables$trips, pace_tables$stop_times, pace_tables$calendar)
analyze_frequency("Metra", metra_tables$trips, metra_tables$stop_times, metra_tables$calendar)

# Compare schemas across agencies
compare_schemas <- function() {
  # Function to get column info for a table
  get_columns <- function(agency, table_name) {
    tables <- if (agency == "pace") pace_tables else metra_tables
    
    if (table_name %in% names(tables) && !is.null(tables[[table_name]])) {
      cols <- tables[[table_name]]$col_info$column
      return(data.frame(agency = agency, table = table_name, column = cols, stringsAsFactors = FALSE))
    } else {
      return(data.frame(agency = character(), table = character(), column = character(), stringsAsFactors = FALSE))
    }
  }
  
  # Get columns for each key table and agency
  all_columns <- rbind(
    do.call(rbind, lapply(gsub("\\.txt$", "", key_tables), function(table) get_columns("pace", table))),
    do.call(rbind, lapply(gsub("\\.txt$", "", key_tables), function(table) get_columns("metra", table)))
  )
  
  # Pivot to show which columns exist in which agencies
  schema_comparison <- all_columns %>%
    group_by(table, column) %>%
    summarize(
      pace = "pace" %in% agency,
      metra = "metra" %in% agency,
      .groups = "drop"
    )
  
  # Print schema comparison
  cat("\n=== Schema Comparison Across Agencies ===\n")
  for (table_name in unique(schema_comparison$table)) {
    cat(paste0("\nTable: ", table_name, "\n"))
    table_schema <- schema_comparison %>% filter(table == table_name)
    print(table_schema)
  }
}

compare_schemas()

# Summary of findings
cat("\n=== Summary of Findings ===\n")
cat("This exploration script has analyzed the GTFS data from Pace and Metra transit agencies.\n")
cat("The key findings will inform our normalization strategy for integrating these datasets with CTA data.\n")
cat("Please review the output above for detailed information about each agency's data structure.\n")
