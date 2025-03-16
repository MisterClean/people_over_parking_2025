# Bus Transit Hub Verification Summary

## Overview

This document summarizes the findings from our verification of bus transit hubs according to the People Over Parking Act's definition. The legislation defines a "public transportation hub" to include "a bus connection stop of 2 or more major bus routes with a frequency of bus service interval of 15 minutes or less during the morning and afternoon peak commute periods."

## Key Findings

### Current Implementation vs. Strict Definition

| Metric | Count | Percentage |
|--------|-------|------------|
| Bus stops with 2+ routes (current implementation) | 3,392 | 100% |
| Bus stops with 2+ routes AND ≤15-min frequency | 1,895 | 55.9% |
| Difference | 1,497 | 44.1% |

The current implementation in `parking_minimums_map.Rmd` identifies bus hubs based solely on having 2 or more routes during peak hours, without explicitly verifying the frequency requirement. Our analysis shows that this approach significantly overestimates the number of qualifying bus hubs.

### Frequency Analysis

#### Distribution of Median Headways for Routes at Multi-Route Stops

```
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
 0.0000  0.0000  0.2208 11.9171 30.0000 60.0000
```

#### Headway Ranges

| Range | Count |
|-------|-------|
| 0-5 min | 2,872 |
| 5-10 min | 688 |
| 10-15 min | 1,118 |
| 15-20 min | 664 |
| 20-30 min | 4,566 |
| 30-60 min | 2,618 |
| >60 min | 0 |

Overall, 65.5% of routes at multi-route stops meet the 15-minute frequency criterion.

### Agency Comparison

| Agency | Total Routes | Qualifying Routes | Percentage Qualifying | Median Headway |
|--------|--------------|-------------------|----------------------|----------------|
| CTA | 13,414 | 13,411 | 99.98% | 0 min |
| Pace | 9,344 | 1,499 | 16.04% | 30 min |

This stark difference between agencies explains much of the discrepancy in qualifying bus hubs. CTA routes almost universally meet the frequency criterion, while Pace routes largely do not.

## Implications for the Analysis

The current implementation in `parking_minimums_map.Rmd` overestimates the areas that would qualify under the People Over Parking Act by including bus stops that don't meet the frequency requirement. This means:

1. The actual area affected by the legislation would be smaller than currently estimated
2. The impact would be more concentrated in areas served by CTA (primarily Chicago) rather than suburban areas served by Pace
3. The percentage of Chicago's area affected would be lower than the current estimate

## Recommendations for Updating the Main Rmd

To align the analysis with the strict definition in the legislation, the following changes should be made to `parking_minimums_map.Rmd`:

1. Implement the frequency calculation for each route at each stop during peak hours
2. Filter bus hubs to include only those where all routes meet the 15-minute frequency criterion
3. Update the affected areas calculation and visualization accordingly
4. Add a note about the distribution of qualifying hubs by agency

### Specific Code Changes

The key section to modify is where bus hubs are identified. Instead of just counting routes per stop:

```r
# Current approach
routes_per_stop <- peak_stop_times[, .(unique_routes = uniqueN(unique_route_id)), by = .(unique_stop_id, agency)]
multi_route_stops <- routes_per_stop[unique_routes >= 2]
```

The code should be updated to:

1. Calculate headways for each route at each stop
2. Identify routes that meet the frequency criterion
3. Filter to stops where all routes meet the criterion

The implementation in `verify_bus_transit_hubs.R` provides a template for these changes.

## Conclusion

The current implementation in `parking_minimums_map.Rmd` provides a good starting point but significantly overestimates the number of qualifying bus hubs by not enforcing the frequency criterion. Updating the analysis to include this criterion would provide a more accurate representation of the areas that would be affected by the People Over Parking Act.

The verification script (`verify_bus_transit_hubs.R`) and its results (`qualifying_bus_hubs.rds` and `current_bus_hubs.rds`) can be used as references for updating the main analysis.
