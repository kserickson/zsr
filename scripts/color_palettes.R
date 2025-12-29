#' ZSR Color Palettes
#'
#' All palettes are colorblind-friendly following Kieran Healy's recommendations
#' from "Data Visualization: A Practical Introduction"
#'
#' Palette sources:
#' - Okabe-Ito: Designed specifically for colorblind accessibility
#' - Viridis: Perceptually uniform, works in grayscale
#' - ColorBrewer: Cynthia Brewer's carefully designed palettes
#'
#' @name color_palettes
NULL

#' ZSR color palette definitions
#'
#' @export
zsr_palettes <- list(
  # Sequential palettes (for heatmaps, gradients, ordered data)
  sequential = list(
    viridis = "viridis",      # Default - excellent perceptual uniformity
    magma = "magma",          # Alternative warm palette
    plasma = "plasma",        # Alternative purple-yellow
    greens = "Greens",        # ColorBrewer greens
    blues = "Blues",          # ColorBrewer blues
    oranges = "Oranges"       # ColorBrewer oranges
  ),

  # Categorical palettes (for discrete unordered groups)
  categorical = list(
    set2 = "Set2",            # ColorBrewer - up to 8 colors, excellent distinction
    dark2 = "Dark2",          # ColorBrewer - darker version of Set2
    okabe_ito = c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
                  "#0072B2", "#D55E00", "#CC79A7", "#999999")  # 8 colors
  ),

  # Diverging palettes (for showing deviation from midpoint)
  diverging = list(
    rd_bu = "RdBu",           # Red-Blue - classic diverging
    br_bg = "BrBG",           # Brown-Blue-Green
    pu_or = "PuOr",           # Purple-Orange
    rd_gy = "RdGy"            # Red-Gray
  ),

  # Single highlight colors
  highlight = "#E69F00",      # Okabe-Ito orange - stands out well
  accent = "#56B4E9"          # Okabe-Ito sky blue
)

#' Get a ZSR color palette
#'
#' Retrieve colors from the ZSR palette system. Handles both named palettes
#' (from viridis or RColorBrewer) and custom palettes.
#'
#' @param palette_type Type of palette: "sequential", "categorical", or "diverging"
#' @param palette_name Name of the specific palette within that type
#' @param n Number of colors needed (for continuous palettes)
#' @param reverse Logical, should the palette be reversed?
#' @return A character vector of hex color codes
#' @export
#'
#' @examples
#' # Get Okabe-Ito categorical palette
#' get_zsr_palette("categorical", "okabe_ito")
#'
#' # Get 10 colors from viridis
#' get_zsr_palette("sequential", "viridis", n = 10)
#'
#' # Get reversed diverging palette
#' get_zsr_palette("diverging", "rd_bu", n = 11, reverse = TRUE)
get_zsr_palette <- function(palette_type, palette_name, n = NULL, reverse = FALSE) {
  # Input validation
  if (!palette_type %in% names(zsr_palettes)) {
    stop("palette_type must be one of: ",
         paste(names(zsr_palettes), collapse = ", "))
  }

  # Handle single color cases
  if (palette_type %in% c("highlight", "accent")) {
    return(zsr_palettes[[palette_type]])
  }

  # Get the palette specification
  palette_spec <- zsr_palettes[[palette_type]][[palette_name]]

  if (is.null(palette_spec)) {
    stop("palette_name '", palette_name, "' not found in ", palette_type, " palettes")
  }

  # Handle different palette types
  colors <- if (is.character(palette_spec) && length(palette_spec) == 1) {
    # Named palette from viridis or RColorBrewer
    if (palette_spec %in% c("viridis", "magma", "plasma", "inferno", "cividis")) {
      # Viridis family
      if (is.null(n)) n <- 256  # Default for continuous
      viridis::viridis(n, option = palette_spec)
    } else {
      # Assume RColorBrewer
      if (is.null(n)) {
        # Get maximum colors for this palette
        palette_info <- RColorBrewer::brewer.pal.info[palette_spec, ]
        n <- palette_info$maxcolors
      }
      # Handle case where n exceeds palette max
      palette_info <- RColorBrewer::brewer.pal.info[palette_spec, ]
      if (n > palette_info$maxcolors) {
        # Interpolate for more colors
        base_colors <- RColorBrewer::brewer.pal(palette_info$maxcolors, palette_spec)
        grDevices::colorRampPalette(base_colors)(n)
      } else if (n < palette_info$mincolors) {
        # Get minimum and subset
        RColorBrewer::brewer.pal(palette_info$mincolors, palette_spec)[1:n]
      } else {
        RColorBrewer::brewer.pal(n, palette_spec)
      }
    }
  } else {
    # Custom palette (vector of colors)
    if (is.null(n)) {
      palette_spec
    } else if (n <= length(palette_spec)) {
      # Subset if fewer colors needed
      palette_spec[1:n]
    } else {
      # Interpolate if more colors needed
      grDevices::colorRampPalette(palette_spec)(n)
    }
  }

  # Reverse if requested
  if (reverse) {
    colors <- rev(colors)
  }

  return(colors)
}

#' Get Okabe-Ito palette
#'
#' Convenience function for the Okabe-Ito colorblind-safe palette.
#' This is the gold standard for accessible categorical colors.
#'
#' @param n Number of colors (max 8)
#' @return Character vector of hex colors
#' @export
okabe_ito <- function(n = 8) {
  if (n > 8) {
    warning("Okabe-Ito palette only has 8 colors. Repeating colors.")
    colors <- zsr_palettes$categorical$okabe_ito
    rep(colors, length.out = n)
  } else {
    zsr_palettes$categorical$okabe_ito[1:n]
  }
}

#' Display a palette
#'
#' Visualize a ZSR color palette to help with selection.
#'
#' @param palette_type Type of palette
#' @param palette_name Name of palette
#' @param n Number of colors to display
#' @export
#'
#' @examples
#' display_palette("categorical", "okabe_ito")
#' display_palette("sequential", "viridis", 20)
display_palette <- function(palette_type, palette_name, n = NULL) {
  colors <- get_zsr_palette(palette_type, palette_name, n)

  # Create a simple visualization
  n_colors <- length(colors)
  par(mar = c(0.5, 0.5, 2, 0.5))
  barplot(rep(1, n_colors),
          col = colors,
          border = "white",
          space = 0,
          axes = FALSE,
          main = paste0(palette_type, ": ", palette_name, " (", n_colors, " colors)"))
  invisible(colors)
}
