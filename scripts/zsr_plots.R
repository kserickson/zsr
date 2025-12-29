#!/usr/bin/env Rscript

#' Main ZSR Visualization Script
#'
#' Generates all plots for all years in dataset using R and ggplot2.
#' Following Kieran Healy's data visualization principles.
#'
#' Usage:
#'   Rscript zsr_plots.R                    # Process all years
#'   Rscript zsr_plots.R 2024               # Process specific year
#'   Rscript zsr_plots.R --help             # Show help

# Suppress package startup messages
suppressPackageStartupMessages({
  library(tidyverse)
  library(yaml)
  library(jsonlite)
  library(lubridate)
  library(here)
  library(glue)
  library(viridis)
  library(RColorBrewer)
  library(gt)
  library(gtExtras)
})

# Source utility scripts
source(here("scripts", "theme_zsr.R"))
source(here("scripts", "color_palettes.R"))
source(here("scripts", "utils.R"))
source(here("scripts", "plot_functions.R"))

#' Main function to generate all plots
#'
#' @param years Vector of years to process (NULL = all years)
#' @param plot_types Vector of plot types to generate
main <- function(years = NULL,
                plot_types = c("heatmap", "overlay", "table", "session", "pace", "cumulative")) {

  cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
  cat("  ZSR Visualization (R/ggplot2)\n")
  cat("  Following Kieran Healy's principles\n")
  cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

  # Load configurations
  cat("Loading configuration...\n")
  config <- load_config(here("config"))

  # Load data
  cat("Loading data...\n")
  df_library <- load_library_data(config)
  df_dailies <- load_dailies_data(config)

  cat(glue("  Library: {nrow(df_library)} books\n"))
  cat(glue("  Dailies: {nrow(df_dailies)} reading sessions\n\n"))

  # Determine years to process
  if (is.null(years)) {
    years <- get_years(df_dailies)
  }

  cat(glue("Generating plots for years: {paste(years, collapse=', ')}\n\n"))

  # Generate plots for each year
  for (year in years) {
    cat(glue("━━━ Processing {year} ━━━\n"))

    plot_num <- 1
    total_plots <- length(plot_types)

    # Heatmap
    if ("heatmap" %in% plot_types) {
      cat(glue("  [{plot_num}/{total_plots}] Creating heatmap..."))
      tryCatch({
        p <- plot_reading_heatmap(df_dailies, year, config)
        save_plot(p,
                 glue("daily-pages-{year}.png"),
                 config,
                 height = config$dimensions$heatmap_height)
        cat(" ✓\n")
      }, error = function(e) {
        cat(glue(" ✗ Error: {e$message}\n"))
      })
      plot_num <- plot_num + 1
    }

    # Overlay chart
    if ("overlay" %in% plot_types) {
      chart_type <- if (isTRUE(config$overlay$facet_alternative)) "faceted" else "overlay"
      cat(glue("  [{plot_num}/{total_plots}] Creating {chart_type} chart..."))

      tryCatch({
        if (isTRUE(config$overlay$facet_alternative)) {
          p <- plot_overlay_faceted(df_dailies, year, config)
        } else {
          p <- plot_overlay_chart(df_dailies, year, config)
        }

        save_plot(p,
                 glue("overlay-chart-{year}.png"),
                 config,
                 height = config$dimensions$overlay_height)
        cat(" ✓\n")
      }, error = function(e) {
        cat(glue(" ✗ Error: {e$message}\n"))
      })
      plot_num <- plot_num + 1
    }

    # Books table
    if ("table" %in% plot_types) {
      cat(glue("  [{plot_num}/{total_plots}] Creating books table..."))
      tryCatch({
        table <- plot_books_table(df_library, df_dailies, year, config)

        # Save gt table as PNG
        output_path <- file.path(config$output_paths$figures, glue("books-table-{year}.png"))
        gt::gtsave(table, output_path, vwidth = 2000, vheight = 2000)
        cat(" ✓\n")
      }, error = function(e) {
        cat(glue(" ✗ Error: {e$message}\n"))
      })
      plot_num <- plot_num + 1
    }

    # Session distribution
    if ("session" %in% plot_types) {
      cat(glue("  [{plot_num}/{total_plots}] Creating session distribution..."))
      tryCatch({
        p <- plot_session_distribution(df_dailies, year, config)
        save_plot(p,
                 glue("session-distribution-{year}.png"),
                 config,
                 height = 6)
        cat(" ✓\n")
      }, error = function(e) {
        cat(glue(" ✗ Error: {e$message}\n"))
      })
      plot_num <- plot_num + 1
    }

    # Completion pace
    if ("pace" %in% plot_types) {
      cat(glue("  [{plot_num}/{total_plots}] Creating completion pace..."))
      tryCatch({
        p <- plot_completion_pace(df_library, df_dailies, year, config)
        save_plot(p,
                 glue("completion-pace-{year}.png"),
                 config,
                 height = 8)
        cat(" ✓\n")
      }, error = function(e) {
        cat(glue(" ✗ Error: {e$message}\n"))
      })
      plot_num <- plot_num + 1
    }

    # Cumulative progress
    if ("cumulative" %in% plot_types) {
      cat(glue("  [{plot_num}/{total_plots}] Creating cumulative progress..."))
      tryCatch({
        p <- plot_cumulative_progress(df_dailies, year, config)
        save_plot(p,
                 glue("cumulative-progress-{year}.png"),
                 config,
                 height = 6)
        cat(" ✓\n")
      }, error = function(e) {
        cat(glue(" ✗ Error: {e$message}\n"))
      })
      plot_num <- plot_num + 1
    }

    cat("\n")
  }

  cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
  cat(glue("✓ Done! Plots saved to: {config$output_paths$figures}\n"))
  cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

  invisible(NULL)
}

# Command-line interface
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) > 0 && args[1] == "--help") {
    cat("
ZSR Visualization Script (R/ggplot2)

Usage:
  Rscript zsr_plots.R                    Process all years
  Rscript zsr_plots.R YEAR               Process specific year
  Rscript zsr_plots.R --help             Show this help

Examples:
  Rscript zsr_plots.R                    # All years
  Rscript zsr_plots.R 2024               # Just 2024

Plot Types:
  - Heatmap: Daily reading calendar (GitHub-style)
  - Overlay Chart: Stacked bars + completion lines
  - Faceted Chart: Small multiples per book (set facet_alternative: true in config)

Configuration:
  Edit config/viz_config.yaml to customize:
  - Colors, fonts, dimensions
  - Plot-specific settings
  - Theme preferences

Output:
  PNG files saved to figures/ directory at 300 DPI

For more information, see the plan file or README.md
")
    quit(status = 0)
  } else if (length(args) > 0) {
    # Specific year provided
    year <- as.numeric(args[1])
    if (is.na(year)) {
      cat("Error: Invalid year specified\n")
      quit(status = 1)
    }
    main(years = year)
  } else {
    # No args - process all years
    main()
  }
}
