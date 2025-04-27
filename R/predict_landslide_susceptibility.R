#' Predict landslide susceptibility from a prepared input stack
#'
#' @param input_stack SpatRaster stack with named layers: aspect, dem, fault_binary, flow_accum, hillshade, ndvi, precipitation, slope
#' @param model_path Path to trained global Random Forest model (.rds)
#' @param output_path Path to save the predicted susceptibility raster (.tif)
#' @return The predicted SpatRaster
#' @import terra
#' @export
predict_landslide_susceptibility <- function(input_stack, model_path, output_path) {
  library(terra)

  message("Loading trained model...")
  rf_model <- readRDS(model_path)

  message("Predicting landslide susceptibility...")
  susceptibility_raster <- terra::predict(
    input_stack,
    rf_model,
    type = "response",   # because model was trained with probability = TRUE
    filename = output_path,
    overwrite = TRUE,
    na.rm = TRUE
  )

  message("Susceptibility raster saved to: ", output_path)
  return(susceptibility_raster)
}
