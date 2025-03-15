# GTFS Normalization Strategy for Chicagoland Transit Agencies

This document outlines the strategy used to normalize and combine GTFS data from three transit agencies in the Chicagoland region: Chicago Transit Authority (CTA), Pace Suburban Bus, and Metra Commuter Rail.

## Data Exploration Findings

The exploration of the GTFS data revealed several key differences between the agencies:

### Agency Types and Route Types
- **CTA**: Operates both rail (route_type = 1) and bus routes (route_type = 3)
- **Pace**: Operates exclusively bus routes (route_type = 3)
- **Metra**: Operates exclusively rail routes (route_type = 2)

### Schema Differences
- **Column Names**: Each agency has slightly different column names in their GTFS tables
- **Data Types**: 
  - Pace uses integer for trip_id while Metra uses character
  - Different location identifiers (geo_node_id in Pace, not in Metra)
- **Agency-Specific Fields**:
  - Pace: geo_node_id, stop_code, direction_text, wheelchair_accessible
  - Metra: stop_url, wheelchair_boarding, center_boarding, south_boarding, trip_headsign

### Service Frequency
- **Pace**: 1,528 stops with 2+ routes during peak hours
- **Metra**: Only 6 stops with 2+ routes during peak hours
- **CTA**: Multiple stops with 2+ routes during peak hours

### Coordinate Systems
- All agencies use the same coordinate system (WGS84)
- No missing coordinates in either Pace or Metra data

## Normalization Strategy

Based on these findings, the following normalization strategy was implemented:

### 1. Agency Identification
- Added an `agency` field to all tables to identify the source agency (cta, pace, metra)
- Created unique identifiers by prefixing IDs with the agency name (e.g., `cta_1234`, `pace_5678`)

### 2. Data Type Standardization
- Converted all ID fields (stop_id, route_id, trip_id) to character type for consistency
- Ensured numeric fields like coordinates maintained their precision

### 3. Schema Harmonization
- Added missing fields to each agency's data with appropriate NA values
- Standardized essential fields across all agencies:
  - stop_id, stop_name, stop_lat, stop_lon
  - route_id, route_type
  - trip_id, service_id
  - arrival_time, departure_time

### 4. Transit Hub Identification
- **Rail Stations**:
  - CTA: Identified using parent_station or location_type = 1
  - Metra: All stops are considered rail stations (route_type = 2), but filtered to include only Illinois stations (latitude ≤ 42.5°)
  - Pace: No rail stations
- **Bus Hubs**:
  - Identified stops with 2+ routes during peak hours
  - Applied to both CTA and Pace bus stops

### 5. Combined Processing
- Merged all normalized data into unified tables
- Processed the combined data to identify all qualifying transit hubs
- Created buffers around all hubs to visualize affected areas

### 6. Visualization Enhancements
- Added agency-specific coloring to distinguish between transit providers
- Included agency information in popups for each transit hub
- Added a legend showing the distribution of hubs by agency

## Implementation Details

The implementation follows these steps:

1. **Download and Extract**: Retrieve GTFS data from all three agencies
2. **Normalize**: Apply the normalization strategy to each agency's data
3. **Combine**: Merge the normalized data into unified tables
4. **Process**: Identify qualifying transit hubs according to the legislation
5. **Visualize**: Create an interactive map showing the affected areas

## Benefits of This Approach

This normalization strategy provides several benefits:

1. **Comprehensive Coverage**: Includes all transit agencies serving the Chicagoland region
2. **Consistent Processing**: Applies the same criteria to identify transit hubs across agencies
3. **Maintainable Code**: Structured approach makes it easy to update or add agencies
4. **Clear Visualization**: Distinguishes between different agencies in the final map
5. **Accurate Analysis**: Provides a more complete picture of areas affected by the legislation

## Future Improvements

Potential improvements to this approach could include:

1. **Frequency Calculation**: Implement more precise calculation of service frequency
2. **Agency Weighting**: Consider the relative importance of different transit types
3. **Boundary Analysis**: Use actual municipal boundaries for more precise area calculations
4. **Temporal Analysis**: Examine how service changes over time affect the covered areas
5. **Additional Agencies**: Framework allows for easy addition of other transit providers
