#' Prepare input stack from shapefile and user-provided NDVI
#'
#' Downloads DEM, computes topographic layers, clips user-supplied NDVI,
#' downloads + clips average annual precipitation, rasterizes buffered fault lines,
#' and finally returns a clean aligned SpatRaster stack.
#'
#' @param shapefile_path Path to study area shapefile (.shp)
#' @param ndvi_path Path to user-provided NDVI raster (.tif)
#' @param out_dir Directory where results should be saved
#' @return A SpatRaster stack with aligned and correctly named layers
#' @import terra
#' @import sf
#' @import elevatr
#' @export
prepare_input_stack <- function(shapefile_path, ndvi_path, out_dir = tempdir()) {
  library(sf)
  library(terra)
  library(elevatr)

  message("Reading shapefile...")
  shape <- st_read(shapefile_path, quiet = TRUE)
  if (st_crs(shape)$epsg != 4326) {
    shape <- st_transform(shape, 4326)
  }

  # ------------------------------
  # DEM
  # ------------------------------
  message("Downloading DEM...")
  elev <- get_elev_raster(locations = shape, z = 10, clip = "locations", prj = "EPSG:4326")
  dem <- terra::rast(elev)
  writeRaster(dem, file.path(out_dir, "dem.tif"), overwrite = TRUE)
  message("DEM raster saved...")

  # ------------------------------
  # Topographic layers
  # ------------------------------
  message("Calculating slope, aspect, hillshade, and flow accumulation...")
  slope <- terrain(dem, v = "slope", unit = "degrees")
  aspect <- terrain(dem, v = "aspect", unit = "degrees")
  hillshade <- shade(terrain(dem, v = "slope", unit = "radians"),
                     terrain(dem, v = "aspect", unit = "radians"))
  flow_acc <- flowAccumulation(dem)

  writeRaster(slope, file.path(out_dir, "slope.tif"), overwrite = TRUE)
  writeRaster(aspect, file.path(out_dir, "aspect.tif"), overwrite = TRUE)
  writeRaster(hillshade, file.path(out_dir, "hillshade.tif"), overwrite = TRUE)
  writeRaster(flow_acc, file.path(out_dir, "flow_accum.tif"), overwrite = TRUE)

  message("Slope, aspect, hillshade, and flow accumulation rasters saved...")

  # ------------------------------
  # NDVI
  # ------------------------------
  message("Clipping NDVI...")
  ndvi <- terra::rast(ndvi_path)
  ndvi_clipped <- crop(ndvi, vect(shape))
  ndvi_clipped <- mask(ndvi_clipped, vect(shape))
  writeRaster(ndvi_clipped, file.path(out_dir, "ndvi.tif"), overwrite = TRUE)

  # ------------------------------
  # Precipitation
  # ------------------------------

  zip_url <- "https://geodata.ucdavis.edu/climate/worldclim/2_1/base/wc2.1_2.5m_prec.zip"
  zip_path <- file.path(out_dir, "wc2.1_2.5m_prec.zip")
  unzip_dir <- file.path(out_dir, "prec_raw")

  message("Average annual precipitation raster saved...")

  if (!file.exists(zip_path)) {
    message("Downloading WorldClim precipitation data...")
    download.file(zip_url, zip_path, mode = "wb")
  }
  if (!dir.exists(unzip_dir)) {
    unzip(zip_path, exdir = unzip_dir)
  }

  monthly_files <- list.files(unzip_dir, pattern = "\\.tif$", full.names = TRUE)
  if (length(monthly_files) != 12) {
    stop("❌ Failed to extract 12 monthly precipitation files. Check unzip_dir: ", unzip_dir)
  }

  prec_stack <- rast(monthly_files)
  prec_avg <- mean(prec_stack)
  prec_clipped <- crop(prec_avg, vect(shape)) |> mask(vect(shape))
  writeRaster(prec_clipped, file.path(out_dir, "precipitation.tif"), overwrite = TRUE)

  message("Average annual precipitation raster saved...")

  # ------------------------------
  # Fault lines
  # ------------------------------
  message("Downloading and processing fault lines...")
  fault_url <- "https://github.com/Mahnoor-Nadeem-1995/Active_Fault_Lines/raw/main/gem_active_faults.gpkg"
  fault_gpkg <- tempfile(fileext = ".gpkg")
  download.file(fault_url, fault_gpkg, mode = "wb")

  faults <- st_read(fault_gpkg, quiet = TRUE)
  faults <- st_zm(faults, drop = TRUE, what = "ZM")
  if (is.na(st_crs(faults))) st_crs(faults) <- 4326

  faults <- st_transform(faults, crs = st_crs(shape))
  faults_clipped <- st_intersection(faults, shape)

  faults_buffered <- st_buffer(faults_clipped, dist = 0.3)
  faults_vect <- terra::vect(faults_buffered)
  faults_vect <- terra::project(faults_vect, crs(dem))

  fault_raster <- terra::rasterize(faults_vect, dem, field = 1)
  fault_raster[is.na(fault_raster)] <- 0
  writeRaster(fault_raster, file.path(out_dir, "fault_binary.tif"), overwrite = TRUE)

  message("Rasterized and buffered fault lines data saved...")

  # ------------------------------
  # 📦 Stack and align
  # ------------------------------
  message("Stacking and aligning layers...")

  # Template = slope
  template <- slope

  layers_paths <- list(
    aspect = file.path(out_dir, "aspect.tif"),
    dem = file.path(out_dir, "dem.tif"),
    fault_binary = file.path(out_dir, "fault_binary.tif"),
    flow_accum = file.path(out_dir, "flow_accum.tif"),
    hillshade = file.path(out_dir, "hillshade.tif"),
    ndvi = file.path(out_dir, "ndvi.tif"),
    precipitation = file.path(out_dir, "precipitation.tif"),
    slope = file.path(out_dir, "slope.tif")
  )

  aligned_layers <- lapply(layers_paths, function(p) {
    r <- rast(p)
    resample(r, template, method = "bilinear")
  })

  raster_stack <- rast(aligned_layers)
  names(raster_stack) <- names(layers_paths)

  message("Input stack ready!")

  return(raster_stack)
}
