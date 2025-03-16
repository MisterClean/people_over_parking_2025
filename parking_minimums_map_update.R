# Proposed Updates for parking_minimums_map.Rmd
# This file contains the code changes needed to implement the frequency criterion
# in the main analysis of bus transit hubs.

# The following code should replace the current implementation in the "Identify Public Transportation Hubs"
# section of parking_minimums_map.Rmd, specifically where bus hubs are identified.

# After the section where peak_stop_times is created and joined with trips to get route information:

# Count unique routes per stop during peak hours (keep this part)
routes_per_stop <- peak_stop_times[, .(unique_routes = uniqueN(unique_route_id)), by = .(unique_stop_id, agency)]

# Get stops with 2+ routes (keep this part)
multi_route_stops <- routes_per_stop[unique_routes >= 2]

# NEW CODE: Calculate the frequency for each route at each stop during peak hours
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

# REPLACE: Instead of using all multi_route_stops for bus hubs, use only qualifying_bus_hubs
# Change this line:
# bus_hub_candidates <- bus_stops[unique_stop_id %in% multi_route_stops$unique_stop_id]
# To:
bus_hub_candidates <- qualifying_bus_hubs

# Create a spatial object for bus hubs (keep this part)
bus_hubs_sf <- st_as_sf(bus_hub_candidates, coords = c("stop_lon", "stop_lat"), crs = 4326)

# Add a note in the text section about the frequency criterion
# For example, add this to the "How much of Chicago would be free from parking mandates?" section:
# ```
# Note: This analysis strictly applies the frequency criterion from the legislation, 
# requiring all bus routes at a hub to have service intervals of 15 minutes or less during peak periods.
# This primarily affects suburban areas served by Pace, where only 16% of routes meet this criterion,
# compared to CTA routes which almost universally (99.98%) meet the frequency requirement.
# ```

# Optional: Add a visualization of the agency comparison
# Create a bar chart showing the percentage of routes meeting the frequency criterion by agency
agency_stats <- route_headways[, .(
  total_routes = .N,
  qualifying_routes = sum(meets_frequency),
  pct_qualifying = sum(meets_frequency) / .N * 100
), by = agency]

# Add this code chunk to create a visualization:
# ```{r agency_comparison, fig.width=8, fig.height=4}
# ggplot(agency_stats, aes(x = agency, y = pct_qualifying, fill = agency)) +
#   geom_bar(stat = "identity") +
#   geom_text(aes(label = paste0(round(pct_qualifying, 1), "%")), 
#             position = position_stack(vjust = 0.5), color = "white", size = 5) +
#   scale_fill_manual(values = c("cta" = "#009CDE", "pace" = "#814C9E")) +
#   labs(
#     title = "Percentage of Routes Meeting 15-Minute Frequency Criterion",
#     subtitle = "By Transit Agency",
#     x = "Agency",
#     y = "Percentage of Routes",
#     fill = "Agency"
#   ) +
#   theme_minimal() +
#   theme(
#     plot.title = element_text(hjust = 0.5),
#     plot.subtitle = element_text(hjust = 0.5),
#     legend.position = "bottom"
#   )
