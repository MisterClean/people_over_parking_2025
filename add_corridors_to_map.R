# Add Transit Corridors to Parking Minimums Map
# This script extends the existing parking minimums map to include
# "public transportation corridors" as defined in the updated legislation

# Load required packages
library(tidyverse)
library(sf)
library(data.table)
library(zip)
library(httr)
library(lubridate)

# Disable s2 processing to avoid geometry validation issues
sf_use_s2(FALSE)

# Source the existing GTFS processing functions
# (We'll reuse the download and normalization functions from the main Rmd)

# Function to download and extract GTFS data (reused from main script)
download_and_extract_gtfs <- function(agency_name, zip_link) {
  temp_dir <- file.path(tempdir(), agency_name)
  if (!dir.exists(temp_dir)) {
    dir.create(temp_dir, recursive = TRUE)
  }
  
  temp_file <- file.path(temp_dir, paste0(agency_name, "_gtfs.zip"))
  
  cache_dir <- "gtfs_cache"
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir)
  }
  cache_file <- file.path(cache_dir, paste0(agency_name, "_gtfs.zip"))
  
  tryCatch({
    options(timeout = 60)
    
    response <- httr::GET(
      zip_link,
      httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"),
      httr::write_disk(temp_file, overwrite = TRUE),
      httr::timeout(60)
    )
    
    if (httr::status_code(response) != 200) {
      stop(paste0("Failed to download with status code: ", httr::status_code(response)))
    }
    
    file.copy(temp_file, cache_file, overwrite = TRUE)
    
  }, error = function(e) {
    message(paste0("Download failed for ", agency_name, ": ", e$message))
    if (file.exists(cache_file)) {
      message(paste0("Using cached GTFS data for ", agency_name, " from ", cache_file))
      file.copy(cache_file, temp_file, overwrite = TRUE)
    } else {
      stop(paste0("Could not download GTFS data for ", agency_name, " and no cache available."), call. = FALSE)
    }
  })
  
  gtfs_files <- unzip(temp_file, exdir = temp_dir)
  return(temp_dir)
}

# Function to read and normalize GTFS data (simplified version focusing on corridors)
read_gtfs_for_corridors <- function(agency_name, agency_dir) {
  # Read shapes data
  shapes_file <- file.path(agency_dir, "shapes.txt")
  if (file.exists(shapes_file)) {
    shapes <- fread(shapes_file)
    shapes[, agency := agency_name]
    shapes[, shape_id := as.character(shape_id)]
    shapes[, unique_shape_id := paste0(agency_name, "_", shape_id)]
  } else {
    shapes <- data.table(
      shape_id = character(),
      shape_pt_lat = numeric(),
      shape_pt_lon = numeric(),
      shape_pt_sequence = integer(),
      agency = character(),
      unique_shape_id = character()
    )
  }
  
  # Read trips to link routes to shapes
  trips_file <- file.path(agency_dir, "trips.txt")
  if (file.exists(trips_file)) {
    trips <- fread(trips_file)
    trips[, agency := agency_name]
    trips[, trip_id := as.character(trip_id)]
    trips[, route_id := as.character(route_id)]
    trips[, shape_id := as.character(shape_id)]
    trips[, unique_trip_id := paste0(agency_name, "_", trip_id)]
    trips[, unique_route_id := paste0(agency_name, "_", route_id)]
    trips[, unique_shape_id := paste0(agency_name, "_", shape_id)]
  } else {
    trips <- data.table(
      trip_id = character(),
      route_id = character(),
      shape_id = character(),
      service_id = character(),
      agency = character(),
      unique_trip_id = character(),
      unique_route_id = character(),
      unique_shape_id = character()
    )
  }
  
  # Read routes
  routes_file <- file.path(agency_dir, "routes.txt")
  if (file.exists(routes_file)) {
    routes <- fread(routes_file)
    routes[, agency := agency_name]
    routes[, route_id := as.character(route_id)]
    routes[, unique_route_id := paste0(agency_name, "_", route_id)]
  } else {
    routes <- data.table(
      route_id = character(),
      route_type = integer(),
      agency = character(),
      unique_route_id = character()
    )
  }
  
  # Read calendar for service filtering
  calendar_file <- file.path(agency_dir, "calendar.txt")
  if (file.exists(calendar_file)) {
    calendar <- fread(calendar_file)
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
  
  # Read stop_times for frequency analysis
  stop_times_file <- file.path(agency_dir, "stop_times.txt")
  if (file.exists(stop_times_file)) {
    stop_times <- fread(stop_times_file)
    stop_times[, agency := agency_name]
    stop_times[, trip_id := as.character(trip_id)]
    stop_times[, stop_id := as.character(stop_id)]
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
  
  return(list(
    shapes = shapes,
    trips = trips,
    routes = routes,
    calendar = calendar,
    stop_times = stop_times
  ))
}

# Function to calculate route frequency (reused from existing logic)
calculate_route_frequency <- function(stop_times_data, trips_data, calendar_data) {
  # Get weekday service
  weekday_service <- calendar_data[
    monday == 1 & tuesday == 1 & wednesday == 1 & thursday == 1 & friday == 1, 
    .(service_id, agency)
  ]
  
  # Get weekday trips
  weekday_trips <- merge(trips_data, weekday_service, by = c("service_id", "agency"))
  
  # Define peak hours
  morning_peak_start <- as.ITime("07:00:00")
  morning_peak_end <- as.ITime("09:00:00")
  evening_peak_start <- as.ITime("16:00:00")
  evening_peak_end <- as.ITime("18:00:00")
  
  # Process stop times for peak hours
  stop_times_data[, arrival_time_hhmmss := substr(arrival_time, 1, 8)]
  stop_times_data[, arrival_time_obj := as.ITime(arrival_time_hhmmss)]
  
  peak_stop_times <- stop_times_data[
    (arrival_time_obj >= morning_peak_start & arrival_time_obj <= morning_peak_end) |
    (arrival_time_obj >= evening_peak_start & arrival_time_obj <= evening_peak_end)
  ]
  
  # Join with trips to get route information
  peak_stop_times <- merge(
    peak_stop_times, 
    weekday_trips[, .(unique_trip_id, unique_route_id, agency)], 
    by = c("unique_trip_id", "agency")
  )
  
  # Calculate headways
  setorder(peak_stop_times, unique_stop_id, unique_route_id, arrival_time_obj)
  
  peak_stop_times[, time_diff := c(NA, diff(as.numeric(arrival_time_obj))), 
                 by = .(unique_stop_id, unique_route_id)]
  
  peak_stop_times[, headway_minutes := time_diff / 60]
  
  # Filter out unreasonable headways
  peak_stop_times <- peak_stop_times[!is.na(headway_minutes) & headway_minutes <= 60]
  
  # Calculate median headway for each route
  route_headways <- peak_stop_times[, .(
    median_headway = median(headway_minutes, na.rm = TRUE),
    num_observations = .N
  ), by = .(unique_route_id, agency)]
  
  # Filter to routes with sufficient observations
  route_headways <- route_headways[num_observations >= 3]
  
  # Identify routes that meet the 15-minute frequency criterion
  route_headways[, meets_frequency := median_headway <= 15]
  
  return(route_headways)
}

# Function to create route geometries from shapes
create_route_geometries <- function(shapes_data, trips_data, routes_data, qualifying_routes) {
  # Filter to qualifying routes only
  qualifying_trips <- trips_data[unique_route_id %in% qualifying_routes]
  
  # Get unique shape_ids for qualifying routes
  route_shapes <- qualifying_trips[, .(
    unique_route_id,
    unique_shape_id,
    agency
  )]
  route_shapes <- unique(route_shapes)
  
  # Filter shapes to only those used by qualifying routes
  qualifying_shapes <- shapes_data[unique_shape_id %in% route_shapes$unique_shape_id]
  
  # Create sf objects for each shape
  shape_geometries <- qualifying_shapes[, {
    # Order by sequence
    setorder(.SD, shape_pt_sequence)
    
    # Create linestring geometry
    if (.N >= 2) {
      coords <- matrix(c(shape_pt_lon, shape_pt_lat), ncol = 2)
      
      # Remove duplicate consecutive points to avoid degenerate edges
      if (nrow(coords) > 1) {
        diffs <- c(TRUE, diff(coords[,1]) != 0 | diff(coords[,2]) != 0)
        coords <- coords[diffs, , drop = FALSE]
      }
      
      # Only create geometry if we have at least 2 unique points
      if (nrow(coords) >= 2) {
        geom <- st_linestring(coords)
        list(geometry = st_sfc(geom, crs = 4326))
      } else {
        list(geometry = st_sfc(st_linestring(matrix(ncol = 2, nrow = 0)), crs = 4326))
      }
    } else {
      list(geometry = st_sfc(st_linestring(matrix(ncol = 2, nrow = 0)), crs = 4326))
    }
  }, by = .(unique_shape_id, agency)]
  
  # Convert to sf object
  shapes_sf <- st_sf(shape_geometries)
  
  # Filter out empty geometries
  shapes_sf <- shapes_sf[!st_is_empty(shapes_sf), ]
  
  # Join with route information
  route_geometries <- merge(
    shapes_sf,
    route_shapes,
    by = c("unique_shape_id", "agency")
  )
  
  # Add route details
  route_geometries <- merge(
    route_geometries,
    routes_data[, .(unique_route_id, route_short_name, route_long_name, agency)],
    by = c("unique_route_id", "agency"),
    all.x = TRUE
  )
  
  return(route_geometries)
}

# Function to filter geometries to Illinois boundary
filter_to_illinois <- function(geometries_sf) {
  # Load Illinois boundary (using the existing MSA counties)
  # For now, we'll use a simple latitude filter as in the existing code
  # Illinois-Wisconsin border is approximately at 42.5 degrees latitude
  
  # Get bounding box of geometries
  bbox <- st_bbox(geometries_sf)
  
  # Filter to Illinois (south of 42.5 degrees latitude)
  illinois_geometries <- geometries_sf[st_coordinates(geometries_sf)[, "Y"] <= 42.5, ]
  
  return(illinois_geometries)
}

# Main function to process corridors
process_transit_corridors <- function() {
  message("Processing transit corridors...")
  
  # Download GTFS data
  message("Downloading GTFS data...")
  cta_dir <- download_and_extract_gtfs("cta", "https://www.transitchicago.com/downloads/sch_data/google_transit.zip")
  pace_dir <- download_and_extract_gtfs("pace", "https://www.pacebus.com/sites/default/files/2025-02/GTFS.zip")
  
  # Read GTFS data
  message("Reading GTFS data...")
  cta_data <- read_gtfs_for_corridors("cta", cta_dir)
  pace_data <- read_gtfs_for_corridors("pace", pace_dir)
  
  # Combine data
  all_shapes <- rbindlist(list(cta_data$shapes, pace_data$shapes), fill = TRUE)
  all_trips <- rbindlist(list(cta_data$trips, pace_data$trips), fill = TRUE)
  all_routes <- rbindlist(list(cta_data$routes, pace_data$routes), fill = TRUE)
  all_calendar <- rbindlist(list(cta_data$calendar, pace_data$calendar), fill = TRUE)
  all_stop_times <- rbindlist(list(cta_data$stop_times, pace_data$stop_times), fill = TRUE)
  
  # Filter to bus routes only
  bus_routes <- all_routes[route_type == 3]  # route_type 3 = bus
  
  # Calculate route frequency
  message("Calculating route frequencies...")
  route_frequencies <- calculate_route_frequency(all_stop_times, all_trips, all_calendar)
  
  # Get qualifying routes (those meeting 15-minute frequency criterion)
  qualifying_routes <- route_frequencies[meets_frequency == TRUE, unique_route_id]
  
  # Filter to bus routes that qualify
  qualifying_bus_routes <- intersect(qualifying_routes, bus_routes$unique_route_id)
  
  message(paste("Found", length(qualifying_bus_routes), "qualifying bus routes"))
  
  # Create route geometries
  message("Creating route geometries...")
  route_geometries <- create_route_geometries(all_shapes, all_trips, all_routes, qualifying_bus_routes)
  
  # Filter to Illinois
  message("Filtering to Illinois boundary...")
  illinois_routes <- filter_to_illinois(route_geometries)
  
  # Create corridor buffers (1/8 mile = 660 feet)
  message("Creating corridor buffers...")
  
  # Transform to projected CRS for accurate buffer calculation
  routes_projected <- st_transform(illinois_routes, 3435)  # NAD83 / Illinois East (ftUS)
  
  # Create 1/8 mile buffers (660 feet)
  corridor_buffers <- st_buffer(routes_projected, 660)
  
  # Transform back to WGS84
  corridor_buffers_wgs84 <- st_transform(corridor_buffers, 4326)
  
  # Separate by agency
  cta_corridors <- corridor_buffers_wgs84[corridor_buffers_wgs84$agency == "cta", ]
  pace_corridors <- corridor_buffers_wgs84[corridor_buffers_wgs84$agency == "pace", ]
  
  # Union buffers by agency to avoid overlaps
  if (nrow(cta_corridors) > 0) {
    cta_corridors_union <- st_union(cta_corridors)
  } else {
    cta_corridors_union <- st_sfc(crs = 4326)
  }
  
  if (nrow(pace_corridors) > 0) {
    pace_corridors_union <- st_union(pace_corridors)
  } else {
    pace_corridors_union <- st_sfc(crs = 4326)
  }
  
  # Combine all corridors
  all_corridors_union <- st_union(c(cta_corridors_union, pace_corridors_union))
  
  # Return results
  return(list(
    cta_corridors = cta_corridors,
    pace_corridors = pace_corridors,
    cta_corridors_union = cta_corridors_union,
    pace_corridors_union = pace_corridors_union,
    all_corridors_union = all_corridors_union,
    route_frequencies = route_frequencies,
    qualifying_routes = qualifying_bus_routes
  ))
}

# Run the corridor processing
if (!exists("corridor_results")) {
  corridor_results <- process_transit_corridors()
  
  # Save results for reuse
  saveRDS(corridor_results, "corridor_results.rds")
  message("Corridor processing complete. Results saved to corridor_results.rds")
} else {
  message("Using existing corridor results")
}
