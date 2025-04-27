LandslideSusceptibilityR
================

# LandslideSusceptibilityR

**LandslideSusceptibilityR** is an R package that allows users to
automatically generate **landslide susceptibility maps** from minimal
inputs.

\*Note:\*\* Since the package downloads several global datasets (DEM,
precipitation, fault lines), performance may vary depending on your
computer’s RAM and internet speed.

------------------------------------------------------------------------

## About the Package

This package uses a **globally trained Random Forest model** (based on
the `ranger` package) to predict landslide susceptibility. The model was
trained **outside the package** using:

- **Presence data:** NASA’s **Global Landslide Catalog (GLC)**
- **Absence data:** Generated globally using slope thresholds (\< 3° =
  assumed stable).

The model uses the following **causal factors** for prediction: -
Slope - Aspect - Elevation - Hillshade - Flow Accumulation - NDVI
(Normalized Difference Vegetation Index) - Precipitation - Distance to
fault lines (binary buffer)

The package automatically prepares these layers for your study area by
downloading, clipping, buffering, calculating terrain metrics, and
stacking them consistently.

------------------------------------------------------------------------

## Causal Factors Automatically Used

- **Topography:** Slope, Aspect, Elevation, Hillshade, Flow Accumulation
- **Vegetation:** NDVI
- **Hydrology:** Precipitation
- **Geology:** Fault proximity (binary)

------------------------------------------------------------------------

## How It Works

- You provide **only two things**:
  - a **study area shapefile** (.shp)
  - a **user-supplied NDVI raster** (.tif)
- The package:
  1.  Downloads and clips DEM and precipitation.
  2.  Downloads and clips global fault lines.
  3.  Computes slope, aspect, flow accumulation, hillshade, etc.
  4.  Aligns and stacks all causal factors correctly.
  5.  Predicts landslide susceptibility using the **global Random Forest
      model**.
  6.  Outputs a **heatmap** raster of landslide susceptibility (0 = low,
      1 = high).

## Included Example Data

- inst/extdata/study_area.shp: Small example shapefile
- inst/extdata/ndvi.tif: Example NDVI raster
- inst/extdata/global_rf_model_ranger.rds: Pre-trained model

## Notes

- Global Scale: The model is trained globally, so it can work for any
  part of the world.
- RAM Warning: Processing very large study areas may require high RAM
  (\>16 GB recommended).
- Pre-Trained Model: No local model training needed — everything works
  automatically!

------------------------------------------------------------------------

## Example Usage

\`\`\`r \# Install the package (if not installed already) \#
install.packages(“devtools”)
devtools::install_github(“Mahnoor-Nadeem-1995/LandslideSusceptibilityR”)

library(LandslideSusceptibilityR) library(terra)

# Prepare input stack

stack \<- prepare_input_stack( shapefile_path = system.file(“extdata”,
“study_area.shp”, package = “LandslideSusceptibilityR”), ndvi_path =
system.file(“extdata”, “ndvi.tif”, package = “LandslideSusceptibilityR”)
)

# Predict landslide susceptibility

predict_landslide_susceptibility( stack = stack, model_path =
system.file(“extdata”, “global_rf_model_ranger.rds”, package =
“LandslideSusceptibilityR”), output_path = “susceptibility_map.tif” )

# Plot result

susceptibility_map \<- rast(“susceptibility_map.tif”)
plot(susceptibility_map)
