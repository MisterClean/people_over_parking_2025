# Verify Bus Transit Hubs Script
# This script verifies that bus transit hubs meet the criteria specified in the People Over Parking Act:
# - Bus stops must serve 2 or more bus routes
# - Each route must have a peak frequency of 15 minutes or less

# Load required packages
library(tidyverse)
library(data.table)
library(sf)
library(leaflet)
library(lubridate)
library(zip)
library(httr)

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
    # Download the GTFS ZIP file with a timeout and user agent
    options(timeout = 60)  # Increase timeout to 60 seconds
    
    # Use httr::GET with a user agent to avoid 403 Forbidden errors
    response <- httr::GET(
      zip_link,
      httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"),
      httr::write_disk(temp_file, overwrite = TRUE),
      httr::timeout(60)
    )
    
    # Check if the request was successful
    if (httr::status_code(response) != 200) {
      stop(paste0("Failed to download with status code: ", httr::status_code(response)))
    }
    
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

# Download and extract GTFS data for CTA and Pace
cta_dir <- download_and_extract_gtfs("cta", "https://www.transitchicago.com/downloads/sch_data/google_transit.zip")
pace_dir <- download_and_extract_gtfs("pace", "https://www.pacebus.com/sites/default/files/2025-02/GTFS.zip")

# Function to read and normalize GTFS data
read_normalize_gtfs <- function(agency_name, agency_dir) {
  # Read the stops data
  stops_file <- file.path(agency_dir, "stops.txt")
  if (file.exists(stops_file)) {
    stops <- fread(stops_file)
    # Add agency identifier
    stops[, agency := agency_name]
    
    # Normalize column names and types
    if (!"location_type" %in% names(stops)) {
      stops[, location_type := NA_integer_]
    }
    if (!"parent_station" %in% names(stops)) {
      stops[, parent_station := NA_character_]
    }
    
    # Ensure stop_id is character
    stops[, stop_id := as.character(stop_id)]
    
    # Create a unique ID that includes the agency
    stops[, unique_stop_id := paste0(agency_name, "_", stop_id)]
  } else {
    stops <- data.table(
      stop_id = character(),
      stop_name = character(),
      stop_lat = numeric(),
      stop_lon = numeric(),
      location_type = integer(),
      parent_station = character(),
      agency = character(),
      unique_stop_id = character()
    )
  }
  
  # Read the routes data
  routes_file <- file.path(agency_dir, "routes.txt")
  if (file.exists(routes_file)) {
    routes <- fread(routes_file)
    # Add agency identifier
    routes[, agency := agency_name]
    
    # Normalize route_id to character
    routes[, route_id := as.character(route_id)]
    
    # Create a unique ID that includes the agency
    routes[, unique_route_id := paste0(agency_name, "_", route_id)]
  } else {
    routes <- data.table(
      route_id = character(),
      route_type = integer(),
      agency = character(),
      unique_route_id = character()
    )
  }
  
  # Read trips data
  trips_file <- file.path(agency_dir, "trips.txt")
  if (file.exists(trips_file)) {
    trips <- fread(trips_file)
    # Add agency identifier
    trips[, agency := agency_name]
    
    # Normalize trip_id and route_id to character
    trips[, trip_id := as.character(trip_id)]
    trips[, route_id := as.character(route_id)]
    
    # Create unique IDs that include the agency
    trips[, unique_trip_id := paste0(agency_name, "_", trip_id)]
    trips[, unique_route_id := paste0(agency_name, "_", route_id)]
  } else {
    trips <- data.table(
      trip_id = character(),
      route_id = character(),
      service_id = character(),
      agency = character(),
      unique_trip_id = character(),
      unique_route_id = character()
    )
  }
  
  # Read stop_times data
  stop_times_file <- file.path(agency_dir, "stop_times.txt")
  if (file.exists(stop_times_file)) {
    stop_times <- fread(stop_times_file)
    # Add agency identifier
    stop_times[, agency := agency_name]
    
    # Normalize trip_id and stop_id to character
    stop_times[, trip_id := as.character(trip_id)]
    stop_times[, stop_id := as.character(stop_id)]
    
    # Create unique IDs that include the agency
    stop_times[, unique_trip_id := paste0(agency_name, "_", trip_id)]
    stop_times[, unique_stop_id := paste0(agency_name, "_", stop_id)]
  } else {
    stop_times <- data.table(
      trip_id = character(),
      stop_id = character(),
      arrival_time = character(),
      departure_time = character(),
      stop_sequence = integer(),
      agency = character(),
      unique_trip_id = character(),
      unique_stop_id = character()
    )
  }
  
  # Read calendar data
  calendar_file <- file.path(agency_dir, "calendar.txt")
  if (file.exists(calendar_file)) {
    calendar <- fread(calendar_file)
    # Add agency identifier
    calendar[, agency := agency_name]
  } else {
    calendar <- data.table(
      service_id = character(),
      monday = integer(),
      tuesday = integer(),
      wednesday = integer(),
      thursday = integer(),
      friday = integer(),
      saturday = integer(),
      sunday = integer(),
      start_date = integer(),
      end_date = integer(),
      agency = character()
    )
  }
  
  # Return all normalized tables
  return(list(
    stops = stops,
    routes = routes,
    trips = trips,
    stop_times = stop_times,
    calendar = calendar
  ))
}

# Read and normalize GTFS data for CTA and Pace
cta_data <- read_normalize_gtfs("cta", cta_dir)
pace_data <- read_normalize_gtfs("pace", pace_dir)

# Combine data from both agencies
all_stops <- rbindlist(list(cta_data$stops, pace_data$stops), fill = TRUE)
all_routes <- rbindlist(list(cta_data$routes, pace_data$routes), fill = TRUE)
all_trips <- rbindlist(list(cta_data$trips, pace_data$trips), fill = TRUE)
all_stop_times <- rbindlist(list(cta_data$stop_times, pace_data$stop_times), fill = TRUE)
all_calendar <- rbindlist(list(cta_data$calendar, pace_data$calendar), fill = TRUE)

# Filter to bus routes only (route_type = 3)
bus_routes <- all_routes[route_type == 3]

# Filter to bus stops only
# For CTA: location_type == 0 or NA, and not a parent station
# For Pace: All stops are bus stops
bus_stops <- all_stops[
  (agency == "cta" & (is.na(location_type) | location_type == 0) & 
   (is.na(parent_station) | parent_station == "")) |
  (agency == "pace")
]

# Determine the service periods for weekdays (Monday-Friday)
weekday_service <- all_calendar[
  monday == 1 & tuesday == 1 & wednesday == 1 & thursday == 1 & friday == 1, 
  .(service_id, agency)
]

# Get the trips that operate on weekdays
weekday_trips <- merge(all_trips, weekday_service, by = c("service_id", "agency"))

# Filter to bus trips only
weekday_bus_trips <- weekday_trips[unique_route_id %in% bus_routes$unique_route_id]

# Define peak hours
morning_peak_start <- as.ITime("07:00:00")
morning_peak_end <- as.ITime("09:00:00")
evening_peak_start <- as.ITime("16:00:00")
evening_peak_end <- as.ITime("18:00:00")

# Process stop times for peak hours
all_stop_times[, arrival_time_hhmmss := substr(arrival_time, 1, 8)]
all_stop_times[, arrival_time_obj := as.ITime(arrival_time_hhmmss)]

# Filter stop times to peak hours
peak_stop_times <- all_stop_times[
  (arrival_time_obj >= morning_peak_start & arrival_time_obj <= morning_peak_end) |
  (arrival_time_obj >= evening_peak_start & arrival_time_obj <= evening_peak_end)
]

# Join with trips to get route information
peak_stop_times <- merge(
  peak_stop_times, 
  weekday_bus_trips[, .(unique_trip_id, unique_route_id, agency)], 
  by = c("unique_trip_id", "agency")
)

# Count unique routes per stop during peak hours
routes_per_stop <- peak_stop_times[, .(unique_routes = uniqueN(unique_route_id)), by = .(unique_stop_id, agency)]

# Get stops with 2+ routes
multi_route_stops <- routes_per_stop[unique_routes >= 2]

# Now calculate the frequency for each route at each stop during peak hours
# First, separate morning and evening peak periods
morning_peak_times <- peak_stop_times[
  arrival_time_obj >= morning_peak_start & arrival_time_obj <= morning_peak_end
]

evening_peak_times <- peak_stop_times[
  arrival_time_obj >= evening_peak_start & arrival_time_obj <= evening_peak_end
]

# Function to calculate headways for a given set of stop times
calculate_headways <- function(stop_times_data) {
  # Sort by stop, route, and time
  setorder(stop_times_data, unique_stop_id, unique_route_id, arrival_time_obj)
  
  # Calculate time difference between consecutive arrivals of the same route at the same stop
  stop_times_data[, time_diff := c(NA, diff(as.numeric(arrival_time_obj))), 
                 by = .(unique_stop_id, unique_route_id)]
  
  # Convert time difference from seconds to minutes
  stop_times_data[, headway_minutes := time_diff / 60]
  
  # Filter out unreasonable headways (e.g., when there's a large gap between trips)
  stop_times_data <- stop_times_data[!is.na(headway_minutes) & headway_minutes <= 60]
  
  return(stop_times_data)
}

# Calculate headways for morning and evening peak periods
morning_headways <- calculate_headways(morning_peak_times)
evening_headways <- calculate_headways(evening_peak_times)

# Combine morning and evening headways
all_headways <- rbind(morning_headways, evening_headways)

# Calculate median headway for each route at each stop
route_headways <- all_headways[, .(
  median_headway = median(headway_minutes, na.rm = TRUE),
  min_headway = min(headway_minutes, na.rm = TRUE),
  max_headway = max(headway_minutes, na.rm = TRUE),
  num_observations = .N
), by = .(unique_stop_id, unique_route_id, agency)]

# Filter to routes with sufficient observations (at least 3)
route_headways <- route_headways[num_observations >= 3]

# Identify routes that meet the 15-minute frequency criterion
route_headways[, meets_frequency := median_headway <= 15]

# For each stop with multiple routes, check if all routes meet the frequency criterion
stop_route_counts <- route_headways[, .(
  total_routes = .N,
  qualifying_routes = sum(meets_frequency),
  all_routes_qualify = all(meets_frequency)
), by = .(unique_stop_id, agency)]

# Filter to stops with 2+ routes
multi_route_stops_with_frequency <- stop_route_counts[total_routes >= 2]

# Identify stops where all routes meet the frequency criterion
qualifying_stops <- multi_route_stops_with_frequency[all_routes_qualify == TRUE]

# Get the full stop information for qualifying stops
qualifying_bus_hubs <- merge(
  bus_stops,
  qualifying_stops[, .(unique_stop_id, agency, total_routes, qualifying_routes)],
  by = c("unique_stop_id", "agency")
)

# Get the full stop information for stops with 2+ routes (current implementation)
current_bus_hubs <- merge(
  bus_stops,
  multi_route_stops[, .(unique_stop_id, agency, unique_routes)],
  by = c("unique_stop_id", "agency")
)

# Compare the two sets
print(paste0("Total bus stops with 2+ routes (current implementation): ", nrow(current_bus_hubs)))
print(paste0("Total bus stops with 2+ routes AND 15-min frequency: ", nrow(qualifying_bus_hubs)))

# Calculate the difference
difference_count <- nrow(current_bus_hubs) - nrow(qualifying_bus_hubs)
difference_percent <- difference_count / nrow(current_bus_hubs) * 100

print(paste0("Difference: ", difference_count, " stops (", round(difference_percent, 1), "%)"))

# Create spatial objects for mapping
qualifying_bus_hubs_sf <- st_as_sf(qualifying_bus_hubs, coords = c("stop_lon", "stop_lat"), crs = 4326)
current_bus_hubs_sf <- st_as_sf(current_bus_hubs, coords = c("stop_lon", "stop_lat"), crs = 4326)

# Create a map to visualize the difference
map <- leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  # Add current implementation stops
  addCircleMarkers(
    data = current_bus_hubs_sf,
    radius = 4,
    color = "blue",
    fillOpacity = 0.5,
    stroke = FALSE,
    group = "Current Implementation (2+ routes)",
    popup = ~paste0(
      "<strong>", stop_name, "</strong><br>",
      "Agency: ", agency, "<br>",
      "Routes: ", unique_routes
    )
  ) %>%
  # Add qualifying stops
  addCircleMarkers(
    data = qualifying_bus_hubs_sf,
    radius = 4,
    color = "green",
    fillOpacity = 0.8,
    stroke = FALSE,
    group = "Qualifying Stops (2+ routes with ≤15 min frequency)",
    popup = ~paste0(
      "<strong>", stop_name, "</strong><br>",
      "Agency: ", agency, "<br>",
      "Routes: ", total_routes
    )
  ) %>%
  # Add layer controls
  addLayersControl(
    baseGroups = c("CartoDB Positron"),
    overlayGroups = c(
      "Current Implementation (2+ routes)",
      "Qualifying Stops (2+ routes with ≤15 min frequency)"
    ),
    options = layersControlOptions(collapsed = FALSE)
  ) %>%
  # Add legend
  addLegend(
    position = "bottomright",
    colors = c("blue", "green"),
    labels = c(
      "Current Implementation (2+ routes)",
      "Qualifying Stops (2+ routes with ≤15 min frequency)"
    ),
    opacity = 0.7
  )

# Display the map
print("Displaying map of bus transit hubs...")
map

# Save the results for further analysis
saveRDS(qualifying_bus_hubs, "qualifying_bus_hubs.rds")
saveRDS(current_bus_hubs, "current_bus_hubs.rds")

# Additional analysis: Distribution of headways
print("Distribution of median headways for routes at multi-route stops:")
summary(route_headways$median_headway)

# Count routes by headway ranges
headway_ranges <- cut(
  route_headways$median_headway,
  breaks = c(0, 5, 10, 15, 20, 30, 60, Inf),
  labels = c("0-5 min", "5-10 min", "10-15 min", "15-20 min", "20-30 min", "30-60 min", ">60 min")
)
headway_distribution <- table(headway_ranges)
print(headway_distribution)

# Calculate percentage of routes that meet the 15-minute criterion
pct_routes_qualifying <- sum(route_headways$meets_frequency) / nrow(route_headways) * 100
print(paste0("Percentage of routes meeting 15-minute frequency criterion: ", round(pct_routes_qualifying, 1), "%"))

# Analyze by agency
agency_stats <- route_headways[, .(
  total_routes = .N,
  qualifying_routes = sum(meets_frequency),
  pct_qualifying = sum(meets_frequency) / .N * 100,
  median_headway = median(median_headway)
), by = agency]

print("Statistics by agency:")
print(agency_stats)

# Recommendations based on findings
print("Recommendations:")
if (difference_percent > 20) {
  print("The current implementation significantly overestimates qualifying bus hubs.")
  print("Consider updating the main Rmd to include the frequency criterion.")
} else if (difference_percent > 5) {
  print("The current implementation moderately overestimates qualifying bus hubs.")
  print("Consider updating the main Rmd to include the frequency criterion for more accuracy.")
} else {
  print("The current implementation closely matches the strict definition in the legislation.")
  print("No major changes needed in the main Rmd.")
}
