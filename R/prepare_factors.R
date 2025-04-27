#' Prepare and normalize raster layers for landslide susceptibility modeling
#'
#' This function reads, aligns, and normalizes a list of raster layers to a common extent and resolution.
#'
#' @param raster_files A character vector of file paths to input raster layers.
#' @return A `SpatRaster` stack with normalized values (0 to 1).
#' @import terra
#' @export
prepare_factors <- function(raster_files) {
  library(terra)

  # Read all rasters
  rasters <- lapply(raster_files, rast)

  # Use the first raster as the template
  template <- rasters[[1]]

  # Align all rasters to the template's extent and resolution
  aligned <- lapply(rasters, function(r) {
    resample(r, template, method = "bilinear")
  })

  # Normalize each raster to 0–1
  normalized <- lapply(aligned, function(r) {
    (r - minmax(r)[1]) / (minmax(r)[2] - minmax(r)[1])
  })

  # Stack them into one multi-layer raster
  result_stack <- rast(normalized)
  return(result_stack)
}
