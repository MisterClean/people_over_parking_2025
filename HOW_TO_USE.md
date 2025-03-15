# People Over Parking Act Analysis: User Guide

This guide provides instructions for using the R Markdown notebook to analyze and visualize the impact of the Illinois People Over Parking Act (HB3256) on the Chicago metropolitan area.

## Quick Start Guide

1. **Install R and RStudio** if you haven't already
2. **Clone or download** this repository
3. **Open `parking_minimums_map.Rmd`** in RStudio
4. **Install required packages** (code is included in the notebook)
5. **Run the notebook** by clicking "Run All" or pressing Ctrl+Alt+R

## What the Analysis Does

The analysis performs these steps:

1. Downloads GTFS data from three transit agencies:
   - Chicago Transit Authority (CTA)
   - Pace Suburban Bus
   - Metra Commuter Rail

2. Processes the data to identify "public transportation hubs" as defined in the legislation:
   - Rail transit stations (CTA and Metra)
   - Bus stops served by 2+ routes with ≤15 minute frequency during peak hours

3. Creates 1/2 mile buffer zones around these hubs

4. Visualizes the affected areas on an interactive map

5. Calculates statistics about the impact:
   - Total area affected
   - Percentage of Chicago city and metro area affected
   - Breakdown by transit type (rail vs. bus)

## Troubleshooting

### GTFS Data Download Issues

If the automatic download fails:

1. Manually download the GTFS files:
   - CTA: https://www.transitchicago.com/downloads/sch_data/google_transit.zip
   - Pace: https://www.pacebus.com/sites/default/files/2025-02/GTFS.zip
   - Metra: https://schedules.metrarail.com/gtfs/schedule.zip

2. Place them in known locations on your computer

3. Modify the notebook code to use your local files:
   ```r
   # Replace the download_gtfs function calls with direct paths
   cta_dir <- "path/to/extracted/cta/files"
   pace_dir <- "path/to/extracted/pace/files"
   metra_dir <- "path/to/extracted/metra/files"
   ```

### Other Common Issues

- **Memory problems**: The GTFS data is large. Close other applications to free up memory.
- **Package installation errors**: Ensure you have the latest version of R and try installing packages individually.
- **Slow processing**: The analysis involves large datasets. Be patient, especially during the bus hub identification step.

## Interpreting the Results

The interactive map shows:
- Blue areas: 1/2 mile buffer around rail stations
- Green areas: 1/2 mile buffer around major bus hubs
- Purple outline: Combined affected areas
- Blue points: Rail stations
- Green points: Major bus hubs

You can toggle different layers on and off using the control in the top-right corner of the map.

## Customizing the Analysis

You can modify the R Markdown notebook to:

- Change the buffer distance (currently set to 1/2 mile or 2640 feet)
- Adjust the peak hour definition (currently 7-9 AM and 4-6 PM)
- Modify the frequency threshold (currently 15 minutes)
- Add additional transit agencies if needed
- Change the map styling and visualization

## Exporting Results

- To save the interactive map as HTML: Click "Knit" to generate an HTML file
- To create static maps for presentations: Modify the code to use `ggplot2` instead of `leaflet`
- To export the data for other uses: Add code to save the results using `write.csv()` or `st_write()`

## Getting Help

If you encounter issues or have questions about the analysis, please open an issue in the GitHub repository.
