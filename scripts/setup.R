#!/usr/bin/env Rscript

#' Setup script for ZSR R visualization
#'
#' Checks dependencies and installs required packages.
#' Run this after installing R.

cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("  ZSR Setup - Installing R Packages\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Check R version
cat("Checking R version...\n")
r_version <- getRversion()
cat(paste0("  R version: ", r_version, "\n"))

if (r_version < "4.1.0") {
  stop("R version 4.1.0 or higher required. Please upgrade R.")
}
cat("  ✓ R version OK\n\n")

# Function to install package if not present
install_if_missing <- function(pkg, from = "CRAN") {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing ", pkg, "...\n"))
    if (from == "CRAN") {
      install.packages(pkg, repos = "https://cloud.r-project.org/", quiet = TRUE)
    }
    cat(paste0("  ✓ ", pkg, " installed\n"))
  } else {
    cat(paste0("  ✓ ", pkg, " already installed\n"))
  }
}

# Core packages
cat("Installing core packages...\n")
core_packages <- c(
  "tidyverse",      # Data manipulation and ggplot2
  "yaml",           # Config file parsing
  "jsonlite",       # Reading config.json
  "lubridate",      # Date handling
  "here",           # Path management
  "glue"            # String interpolation
)

for (pkg in core_packages) {
  install_if_missing(pkg)
}
cat("\n")

# Visualization packages
cat("Installing visualization packages...\n")
viz_packages <- c(
  "scales",         # Scale functions for ggplot2
  "viridis",        # Colorblind-friendly palettes
  "RColorBrewer",   # Color palettes
  "ggtext",         # Rich text in ggplot2
  "patchwork"       # Combining plots
)

for (pkg in viz_packages) {
  install_if_missing(pkg)
}
cat("\n")

# Check data files
cat("Checking for required data files...\n")
required_data <- c("data/library.csv", "data/dailies.csv")
missing_data <- c()

for (file in required_data) {
  if (file.exists(file)) {
    cat(paste0("  ✓ ", file, "\n"))
  } else {
    cat(paste0("  ✗ ", file, " NOT FOUND\n"))
    missing_data <- c(missing_data, file)
  }
}

if (length(missing_data) > 0) {
  cat("\nWARNING: Missing data files. Run python scripts/zsr.py first.\n")
} else {
  cat("\n  ✓ All data files present\n")
}
cat("\n")

# Test loading packages
cat("Testing package loading...\n")
test_packages <- c("tidyverse", "yaml", "viridis", "RColorBrewer")
all_ok <- TRUE

for (pkg in test_packages) {
  result <- tryCatch({
    library(pkg, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)
    TRUE
  }, error = function(e) {
    FALSE
  })

  if (result) {
    cat(paste0("  ✓ ", pkg, "\n"))
  } else {
    cat(paste0("  ✗ ", pkg, " FAILED\n"))
    all_ok <- FALSE
  }
}
cat("\n")

# Final status
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
if (all_ok && length(missing_data) == 0) {
  cat("✓ Setup complete! Ready to generate plots.\n")
  cat("\nRun: Rscript scripts/zsr_plots.R\n")
} else if (all_ok && length(missing_data) > 0) {
  cat("✓ Packages installed successfully.\n")
  cat("⚠ Missing data files - run Python pipeline first.\n")
  cat("\nNext steps:\n")
  cat("  1. python scripts/zsr.py\n")
  cat("  2. Rscript scripts/zsr_plots.R\n")
} else {
  cat("✗ Setup incomplete. Please fix errors above.\n")
}
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
