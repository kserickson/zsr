#' ZSR Utility Functions
#'
#' Helper functions for data loading, configuration, and common operations

#' Load configuration files
#'
#' Loads both the JSON path configuration and YAML visualization configuration.
#' Merges them into a single list for easy access.
#'
#' @param config_dir Directory containing config files
#' @return Named list with all configuration values
#' @export
load_config <- function(config_dir = here::here("config")) {
  # Load JSON path configuration
  config_json_path <- file.path(dirname(config_dir), "config.json")
  if (!file.exists(config_json_path)) {
    stop("config.json not found at: ", config_json_path)
  }
  config_paths <- jsonlite::fromJSON(config_json_path)

  # Load YAML visualization configuration
  viz_config_path <- file.path(config_dir, "viz_config.yaml")
  if (!file.exists(viz_config_path)) {
    stop("viz_config.yaml not found at: ", viz_config_path)
  }
  viz_config <- yaml::read_yaml(viz_config_path)

  # Merge configurations
  config <- c(config_paths, viz_config)

  return(config)
}

#' Load library data
#'
#' Loads and cleans the main library CSV file.
#'
#' @param config Configuration list from load_config()
#' @return Tibble with library data
#' @export
load_library_data <- function(config) {
  library_path <- file.path(config$output_paths$data, "library.csv")

  if (!file.exists(library_path)) {
    stop("library.csv not found at: ", library_path,
         "\nRun Python script zsr.py first to generate data files.")
  }

  df <- readr::read_csv(library_path,
                       show_col_types = FALSE,
                       col_types = readr::cols(
                         ean_isbn13 = readr::col_character(),
                         began = readr::col_date(),
                         completed = readr::col_date(),
                         added = readr::col_date()
                       ))

  # Clean and standardize
  df <- clean_library_data(df)

  return(df)
}

#' Load dailies data
#'
#' Loads and cleans the daily reading log CSV file.
#'
#' @param config Configuration list from load_config()
#' @return Tibble with dailies data
#' @export
load_dailies_data <- function(config) {
  dailies_path <- file.path(config$output_paths$data, "dailies.csv")

  if (!file.exists(dailies_path)) {
    stop("dailies.csv not found at: ", dailies_path,
         "\nRun Python script zsr.py first to generate data files.")
  }

  df <- readr::read_csv(dailies_path,
                       show_col_types = FALSE,
                       col_types = readr::cols(
                         date = readr::col_date(),
                         ean_isbn13 = readr::col_character()
                       ))

  # Clean and standardize
  df <- clean_dailies_data(df)

  return(df)
}

#' Clean library data
#'
#' Standardizes library data formatting.
#'
#' @param df Raw library data frame
#' @return Cleaned tibble
#' @export
clean_library_data <- function(df) {
  df %>%
    dplyr::mutate(
      # Ensure ISBN is character without trailing .0
      ean_isbn13 = stringr::str_replace(ean_isbn13, "\\.0$", ""),

      # Ensure dates are proper Date objects
      began = lubridate::as_date(began),
      completed = lubridate::as_date(completed),
      added = lubridate::as_date(added),

      # Clean text fields
      title = stringr::str_trim(title),
      creators = stringr::str_trim(creators),

      # Ensure numeric fields are numeric
      length = as.numeric(length),
      duration = as.numeric(duration)
    ) %>%
    # Remove rows with missing critical data
    dplyr::filter(!is.na(title))
}

#' Clean dailies data
#'
#' Standardizes daily reading log formatting.
#'
#' @param df Raw dailies data frame
#' @return Cleaned tibble
#' @export
clean_dailies_data <- function(df) {
  df %>%
    dplyr::mutate(
      # Ensure ISBN is character
      ean_isbn13 = as.character(ean_isbn13),
      ean_isbn13 = stringr::str_replace(ean_isbn13, "\\.0$", ""),

      # Ensure date is proper Date object
      date = lubridate::as_date(date),

      # Clean title
      title = stringr::str_trim(title),

      # Ensure numeric fields
      daily_pages = as.numeric(daily_pages),
      percent_complete = as.numeric(percent_complete)
    ) %>%
    # Remove rows without dates or with empty titles
    dplyr::filter(!is.na(date), title != "", !is.na(title))
}

#' Save a ggplot with standard settings
#'
#' Saves a ggplot object with consistent settings across all ZSR visualizations.
#'
#' @param plot ggplot object to save
#' @param filename Filename (will be saved to figures directory)
#' @param config Configuration list
#' @param width Width in inches (default from config)
#' @param height Height in inches (default from config)
#' @param dpi Resolution (default from config)
#' @export
save_plot <- function(plot, filename, config,
                     width = config$dimensions$width,
                     height = NULL,
                     dpi = config$dimensions$dpi) {

  # Determine output path
  output_dir <- config$output_paths$figures
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  output_path <- file.path(output_dir, filename)

  # Save with standard settings
  ggplot2::ggsave(
    filename = output_path,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"  # Ensure white background
  )

  message("Saved: ", output_path)
  invisible(output_path)
}

#' Get years from dailies data
#'
#' Extract unique years that have reading data.
#'
#' @param df_dailies Dailies data frame
#' @return Integer vector of years
#' @export
get_years <- function(df_dailies) {
  years <- df_dailies %>%
    dplyr::pull(date) %>%
    lubridate::year() %>%
    unique() %>%
    sort()

  return(years)
}

#' Format year for plot titles
#'
#' Creates consistent year title formatting.
#'
#' @param year Year as integer
#' @param subtitle Additional subtitle text
#' @return Named list with title and subtitle
#' @export
format_year_title <- function(year, subtitle = NULL) {
  title <- glue::glue("{year} YEAR IN READING")

  if (!is.null(subtitle)) {
    return(list(title = title, subtitle = subtitle))
  } else {
    return(list(title = title, subtitle = NULL))
  }
}

#' Smart text truncation
#'
#' Truncates text intelligently, preferring word boundaries.
#'
#' @param text Character vector to truncate
#' @param max_length Maximum length
#' @param ellipsis String to append when truncated
#' @return Truncated character vector
#' @export
smart_truncate <- function(text, max_length, ellipsis = "...") {
  truncated <- purrr::map_chr(text, function(x) {
    if (is.na(x)) return(NA_character_)
    if (nchar(x) <= max_length) return(x)

    # Try to break at word boundary
    substr_text <- substr(x, 1, max_length - nchar(ellipsis))
    last_space <- stringr::str_locate_all(substr_text, " ")[[1]]

    if (nrow(last_space) > 0) {
      # Break at last space
      break_point <- max(last_space[, "start"])
      paste0(substr(x, 1, break_point - 1), ellipsis)
    } else {
      # No spaces, just truncate
      paste0(substr_text, ellipsis)
    }
  })

  return(truncated)
}
