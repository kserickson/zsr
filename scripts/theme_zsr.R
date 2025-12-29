#' ZSR Custom ggplot2 Theme
#'
#' Based on Kieran Healy's data visualization principles from
#' "Data Visualization: A Practical Introduction" (https://socviz.co)
#'
#' Core principles:
#' - Clear, readable typography with hierarchical sizing
#' - Subtle gridlines that don't compete with data
#' - Generous white space
#' - Appropriate use of color
#' - Left-aligned titles for natural reading flow
#'
#' @param base_size Base font size in points
#' @param base_family Base font family
#' @param base_line_size Base line size
#' @param base_rect_size Base rectangle size
#' @return A ggplot2 theme object
#' @export
theme_zsr <- function(base_size = 11,
                      base_family = "Arial",
                      base_line_size = base_size/22,
                      base_rect_size = base_size/22) {

  theme_minimal(base_size = base_size,
                base_family = base_family,
                base_line_size = base_line_size,
                base_rect_size = base_rect_size) %+replace%
    theme(
      # Overall plot appearance
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),

      # Grid - subtle, doesn't compete with data
      panel.grid.major = element_line(color = "gray90", linewidth = rel(0.5)),
      panel.grid.minor = element_blank(),

      # Axes
      axis.line = element_line(color = "gray30", linewidth = rel(0.5)),
      axis.ticks = element_line(color = "gray30", linewidth = rel(0.3)),
      axis.ticks.length = unit(4, "pt"),
      axis.title = element_text(size = rel(0.9),
                               color = "gray20",
                               face = "plain"),
      axis.title.x = element_text(margin = margin(t = 8, b = 0)),
      axis.title.y = element_text(margin = margin(r = 8, l = 0)),
      axis.text = element_text(size = rel(0.8), color = "gray30"),

      # Titles - clear hierarchy, left-aligned for natural reading
      plot.title = element_text(size = rel(1.2),
                               face = "bold",
                               hjust = 0,
                               color = "gray10",
                               margin = margin(b = 10)),
      plot.subtitle = element_text(size = rel(1.0),
                                  face = "plain",
                                  hjust = 0,
                                  color = "gray30",
                                  margin = margin(b = 15)),
      plot.caption = element_text(size = rel(0.7),
                                 face = "italic",
                                 hjust = 1,
                                 color = "gray50",
                                 margin = margin(t = 10)),
      plot.title.position = "plot",  # Left-align with full plot, not just panel

      # Legend - clean, unobtrusive
      legend.background = element_rect(fill = "white", color = NA),
      legend.key = element_rect(fill = "white", color = NA),
      legend.title = element_text(size = rel(0.9), face = "bold"),
      legend.text = element_text(size = rel(0.8)),
      legend.position = "right",
      legend.justification = "left",
      legend.box.spacing = unit(10, "pt"),

      # Facets - for small multiples
      strip.background = element_rect(fill = "gray95", color = NA),
      strip.text = element_text(size = rel(0.9),
                               face = "bold",
                               color = "gray20",
                               margin = margin(4, 4, 4, 4)),
      panel.spacing = unit(15, "pt"),

      # Overall margins - generous white space
      plot.margin = margin(10, 10, 10, 10),

      # Complete specification
      complete = TRUE
    )
}

#' Variant for heatmaps - no gridlines or axes
#'
#' @inheritParams theme_zsr
#' @return A ggplot2 theme object optimized for heatmaps
#' @export
theme_zsr_heatmap <- function(base_size = 11,
                              base_family = "Arial",
                              base_line_size = base_size/22,
                              base_rect_size = base_size/22) {

  theme_zsr(base_size = base_size,
            base_family = base_family,
            base_line_size = base_line_size,
            base_rect_size = base_rect_size) %+replace%
    theme(
      # Remove gridlines and axes for cleaner heatmap
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_blank(),
      axis.ticks = element_blank(),

      # Keep axis text for labels
      axis.text = element_text(size = rel(0.8), color = "gray30"),

      complete = FALSE
    )
}

#' Variant for tables and minimal plots
#'
#' @inheritParams theme_zsr
#' @return A ggplot2 theme object with no axes or grids
#' @export
theme_zsr_minimal <- function(base_size = 11,
                              base_family = "Arial",
                              base_line_size = base_size/22,
                              base_rect_size = base_size/22) {

  theme_void(base_size = base_size,
             base_family = base_family,
             base_line_size = base_line_size,
             base_rect_size = base_rect_size) %+replace%
    theme(
      # Preserve titles
      plot.title = element_text(size = rel(1.2),
                               face = "bold",
                               hjust = 0,
                               color = "gray10",
                               margin = margin(b = 10)),
      plot.subtitle = element_text(size = rel(1.0),
                                  face = "plain",
                                  hjust = 0,
                                  color = "gray30",
                                  margin = margin(b = 15)),
      plot.margin = margin(10, 10, 10, 10),
      plot.title.position = "plot",

      complete = FALSE
    )
}
