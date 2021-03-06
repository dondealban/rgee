#' Pass an R date object to Earth Engine
#'
#' Pass an R date object ("Date", "Numeric", "character", "POSIXt",
#' and "POSIXct") to Google Earth Engine (ee$Date).
#'
#' @param date R date object
#' @param timestamp Logical. If TRUE, return the date in milliseconds
#' from the Unix Epoch (1970-01-01 00:00:00 UTC) otherwise return a
#' EE date object. By default FALSE.
#' @family date functions
#' @return \code{rdate_to_eedate} will return either a numeric timestamp or
#' an ee$Date depending on the \code{timestamp} argument.
#'
#' @examples
#' \dontrun{
#' library(rgee)
#' ee_reattach()
#' ee_Initialize()
#' rdate_to_eedate('2000-01-01')
#' rdate_to_eedate(315532800000) # float number
#' }
#' @export
rdate_to_eedate <- function(date, timestamp = FALSE) {
  condition <- any(class(date) %in% c('Date', 'character', 'POSIXt', 'POSIXct'))
  if (condition) {
    date <- date %>%
      as.POSIXct(origin = "1970-01-01", tz = "GMT") %>%
      as.numeric() %>%
      prod(1000)
  }
  if (isTRUE(timestamp)) {
    date
  } else {
    ee$Date(date)
  }
}

#' Pass an Earth Engine date object to R
#'
#' @param ee_date ee$date object (ee$Date)
#' @param timestamp Logical. If TRUE, return the date in milliseconds
#' from the Unix Epoch (1970-01-01 00:00:00 UTC) otherwise return the
#' date as a POSIXct object. By default FALSE.
#'
#' @details
#' \code{eedate_to_rdate} is essential to avoid potential errors that
#' might appear when users call to retrieve dates. Currently,
#' R integer only support 32 bit signed, such integers can only
#' count up to about 2 billion. This range is extremely insufficient for dealing
#' with Google Earth Engine date objects (ee$Date), which are represented
#' by timestamps in milliseconds since the UNIX epoch. \code{eedate_to_rdate}
#' use Python as a backend to obtain the date and convert it in float before
#' exporting to R.
#'
#' @return \code{eedate_to_rdate} will return either a numeric timestamp or
#' a POSIXct object depending on the \code{timestamp} argument.
#' @family date functions
#' @examples
#' \dontrun{
#' library(rgee)
#'
#' ee_reattach()
#' ee_Initialize()
#'
#' eeDate <- ee$Date$fromYMD(2010,1,1)
#' eedate_to_rdate(eeDate,timestamp = TRUE) # good
#' eeDate$getInfo()$value # bad
#' }
#' @export
eedate_to_rdate <- function(ee_date, timestamp = FALSE) {
  oauth_func_path <- system.file("python/ee_utils.py",
                                 package = "rgee")
  ee_utils <- ee_source_python(oauth_func_path)
  date_numeric <- ee_utils$eedate_to_rdate(ee$Date(ee_date)) %>%
    ee_utils_py_to_r()
  if (isTRUE(timestamp)) {
    date_numeric
  } else {
    as.POSIXct(x = date_numeric/1000, origin = "1970-01-01", tz = "GMT")
  }
}

#' Get the date of a EE Image
#'
#' @param x ee$Image or ee$ImageCollection object
#' @param time_end Logical. If TRUE, the \code{system:time_end} property is
#' also returned. See details.
#'
#' @details
#' \code{system:time_start} set the start period of data acquisition while
#' \code{system:time_end} does the same for the end period. See the
#' \href{https://developers.google.com/earth-engine/glossary}{Earth Engine glossary}
#' for getting more information.
#'
#' @return An List object with the elements: id, time_start and time_end
#' (if the \code{time_end} argument is TRUE).
#' @family date functions
#' @examples
#' \dontrun{
#' library(rgee)
#'
#' ee_reattach()
#' ee_Initialize()
#'
#' l8 <- ee$Image('LANDSAT/LC08/C01/T1_TOA/LC08_044034_20140318')
#' ee_get_date_img(l8)
#' srtm <- ee$Image('CGIAR/SRTM90_V4')
#' ee_get_date_img(srtm, time_end = TRUE)
#' }
#' @export
ee_get_date_img <- function(x, time_end = FALSE) {
  time_start <- tryCatch(
    expr = eedate_to_rdate(x$get("system:time_start")),
    error = function(e) NA
  )
  if (isTRUE(time_end)) {
    time_end <- tryCatch(
      expr = eedate_to_rdate(x$get("system:time_end")),
      error = function(e) NA
    )
  } else {
    time_end <- NULL
  }
  # get id of the image
  image_id <- x$get("system:id")$getInfo()
  if (is.null(image_id)) {
    image_id <- "no_id"
  }
  if (is.null(time_end)) {
    list(image_id = image_id, time_start = time_start)
  } else {
    list(image_id = image_id, time_start = time_start, time_end = time_end)
  }
}

#' Get the date of a EE ImageCollection
#'
#' @param x ee$ImageCollection object
#' @param time_end Logical. If TRUE, the \code{system:time_end} property is
#' also returned. See details.
#'
#' @details
#' \code{system:time_start} set the start period of data acquisition while
#' \code{system:time_end} does the same for the end period. See the
#' \href{https://developers.google.com/earth-engine/glossary}{Earth Engine glossary}
#' for getting more information.
#'
#' @return A data.frame with the columns: \code{id} (ID of the image),
#' \code{time_start}, and \code{time_end} (If the argument \code{time_end} is
#' set as TRUE). The number of rows depends of the number of images
#' (\code{ee$ImageCollection$size}).
#'
#' @family date functions
#'
#' @examples
#' \dontrun{
#' library(rgee)
#' library(sf)
#'
#' ee_reattach()
#' ee_Initialize()
#'
#' nc <- st_read(system.file("shape/nc.shp", package = "sf")) %>%
#'   st_transform(4326) %>%
#'   sf_as_ee()
#'
#' ee_s2 <- ee$ImageCollection("COPERNICUS/S2")$
#'   filterDate("2016-01-01", "2016-01-31")$
#'   filterBounds(nc)
#'
#' ee_get_date_ic(ee_s2)
#' }
#' @export
ee_get_date_ic <- function(x, time_end = FALSE) {
  # Call Python module
  oauth_func_path <- system.file("python/ee_utils.py", package = "rgee")
  ee_utils <- ee_source_python(oauth_func_path)

  # Fetch the time_start of each Image
  time_start <- ee_utils_py_to_r(
    ee_utils$eedate_to_rdate_ic(x, "system:time_start")
  )

  if (is.null(time_start)) {
    time_start <- NA
  } else {
    time_start <- as.POSIXct(
      x = time_start / 1000,
      origin = "1970-01-01",
      tz = "GMT"
    )
  }

  # Getting time_end
  time_end <- ee_utils_py_to_r(
    ee_utils$eedate_to_rdate_ic(x, "system:time_end")
  )

  if (is.null(time_end)) {
    time_end <- NULL
  } else {
    time_end <- as.POSIXct(
      x = time_end / 1000,
      origin = "1970-01-01",
      tz = "GMT"
    )
  }

  # Getting ID
  image_id <- x$aggregate_array("system:id")$getInfo()
  if (is.null(image_id)) {
    image_id <- rep("no_id", x$size()$getInfo())
  }
  if (length(image_id) == 0) {
    image_id <- rep("no_id", x$size()$getInfo())
  }

  # Create data.frame
  if (is.null(time_end)) {
    data.frame(
      id = image_id,
      time_start = time_start,
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      id = image_id,
      time_start = time_start,
      time_end = time_end,
      stringsAsFactors = FALSE
    )
  }
}
