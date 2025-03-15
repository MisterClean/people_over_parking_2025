# People Over Parking Act Analysis for Chicagoland Region

## Overview

This repository contains an analysis of the potential impact of the Illinois "People Over Parking Act" (HB3256) on the Chicago metropolitan area. The act prohibits local governments from imposing minimum parking requirements on development projects within a 1/2 mile radius of public transportation hubs.

## Background

The People Over Parking Act (HB3256) is a proposed Illinois bill that aims to reduce mandatory parking requirements near transit, potentially enabling more transit-oriented development, addressing housing affordability issues, and reducing car dependency.

Key provisions of the bill:
- Prohibits minimum parking requirements within 1/2 mile of transit hubs
- Defines transit hubs as rail stations, ferry terminals, or bus stops with 2+ routes with ≤15 minute frequency during peak hours
- Allows local regulation of on-street parking and maximum parking requirements
- Takes effect June 1, 2025

## Analysis Contents

This repository includes:

1. **R Markdown notebook** (`parking_minimums_map.Rmd`): The main analysis document that:
   - Downloads and processes GTFS data from CTA, Pace, and Metra
   - Identifies public transportation hubs according to the bill's definition
   - Creates 1/2 mile buffers around these hubs
   - Visualizes the affected areas on an interactive map
   - Analyzes the extent of the affected areas

2. **Supplementary files**: The repository may also include:
   - Helper scripts for data processing
   - Sample output files
   - Visualizations for presentation

## Getting Started

### Prerequisites

The analysis requires R with the following packages:
- tidyverse
- sf
- leaflet
- leaflet.extras
- data.table
- zip
- httr
- lubridate
- mapview

### Running the Analysis

1. Clone this repository
2. Open the R Markdown file (`parking_minimums_map.Rmd`) in RStudio
3. Install any missing packages listed in the prerequisites
4. Run the notebook

The script will:
- Download the latest GTFS data from CTA, Pace, and Metra
- Process the data to identify transit hubs according to the bill's definition
- Create an interactive map showing areas affected by the legislation

### Troubleshooting GTFS Data

If you encounter issues with the automatic GTFS data download, you can manually download the files:

1. CTA: [CTA GTFS Data](https://www.transitchicago.com/downloads/sch_data/google_transit.zip)
2. Pace: [Pace GTFS Data](https://www.pacebus.com/sites/default/files/2025-02/GTFS.zip)
3. Metra: [Metra GTFS Data](https://schedules.metrarail.com/gtfs/schedule.zip)
4. Place them in known locations and modify the script accordingly

## Data Sources

- [Chicago Transit Authority (CTA) GTFS Data](https://www.transitchicago.com/downloads/sch_data/)
- [Pace Suburban Bus GTFS Data](https://www.pacebus.com/sites/default/files/2025-02/GTFS.zip)
- [Metra Commuter Rail GTFS Data](https://schedules.metrarail.com/gtfs/schedule.zip)
- [People Over Parking Act (HB3256)](https://www.ilga.gov/legislation/)

## Results

The analysis shows which parts of the Chicago metropolitan area would be affected by the removal of parking minimums, visualized through interactive maps. Key findings include:

- The extent of affected areas in square miles and as a percentage of the city and metropolitan area
- The distribution of transit hubs across the region
- The relative impact of rail stations versus major bus hubs
- The combined effect of multiple transit agencies serving the region

## Contributing

Contributions to improve the analysis are welcome. Please feel free to fork the repository and submit pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
