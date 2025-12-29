#' ZSR Plot Functions
#'
#' Core plotting functions for ZSR visualizations following Kieran Healy's
#' grammar of graphics approach

#' Plot reading heatmap (calendar style)
#'
#' Creates a GitHub-style calendar heatmap showing daily reading volume.
#' Improvements over Python version:
#' - Dynamic vmax based on data quantile (not hardcoded 75)
#' - Conditional annotations (only high values labeled)
#' - Viridis palette (colorblind-friendly, perceptually uniform)
#' - Better month boundary markers
#'
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return ggplot object
#' @export
plot_reading_heatmap <- function(df_dailies, year, config) {

  # Filter to specified year
  df_year <- df_dailies %>%
    dplyr::filter(lubridate::year(date) == year)

  if (nrow(df_year) == 0) {
    stop("No data found for year ", year)
  }

  # Aggregate by date (sum pages across all books)
  df_daily <- df_year %>%
    dplyr::group_by(date) %>%
    dplyr::summarize(daily_pages = sum(daily_pages, na.rm = TRUE),
                    .groups = "drop")

  # Create full year date range
  year_start <- lubridate::make_date(year, 1, 1)
  year_end <- lubridate::make_date(year, 12, 31)
  all_dates <- tibble::tibble(date = seq(year_start, year_end, by = "day"))

  # Join with actual data (fill missing days with 0)
  df_complete <- all_dates %>%
    dplyr::left_join(df_daily, by = "date") %>%
    dplyr::mutate(daily_pages = tidyr::replace_na(daily_pages, 0))

  # Calculate week and day of week
  # Week starts on Monday
  df_heatmap <- df_complete %>%
    dplyr::mutate(
      weekday = lubridate::wday(date, week_start = 1),  # 1 = Monday
      weekday_label = lubridate::wday(date, label = TRUE, week_start = 1),
      # Calculate week number (weeks start on Monday)
      week = as.integer((lubridate::yday(date) - weekday + 10) / 7)
    )

  # Dynamic vmax based on quantile
  vmax <- quantile(df_heatmap$daily_pages[df_heatmap$daily_pages > 0],
                  probs = config$heatmap$vmax_quantile,
                  na.rm = TRUE)

  # Cap values at vmax for color scaling
  df_heatmap <- df_heatmap %>%
    dplyr::mutate(pages_capped = pmin(daily_pages, vmax))

  # Create annotation data (only for high values)
  df_annotations <- df_heatmap %>%
    dplyr::filter(daily_pages >= config$heatmap$annotation_size_threshold)

  # Get month positions for x-axis labels
  month_starts <- df_heatmap %>%
    dplyr::group_by(month = lubridate::month(date)) %>%
    dplyr::slice_min(week, n = 1) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(month_label = lubridate::month(date, label = TRUE, abbr = TRUE))

  # Create plot
  p <- ggplot(df_heatmap, aes(x = week, y = fct_rev(weekday_label), fill = pages_capped)) +
    # Tiles with borders
    geom_tile(color = config$heatmap$cell_border_color, linewidth = 0.3) +

    # Annotations for high values
    geom_text(data = df_annotations,
             aes(label = daily_pages),
             size = 2.5,
             color = ifelse(df_annotations$pages_capped > vmax * 0.6,
                           config$heatmap$annotation_color_dark,
                           config$heatmap$annotation_color_light)) +

    # Viridis color scale
    scale_fill_viridis_c(
      option = "viridis",
      limits = c(0, vmax),
      breaks = seq(0, vmax, length.out = 5),
      labels = function(x) round(x),
      na.value = config$heatmap$zero_color,
      guide = guide_colorbar(
        title = "Pages",
        barwidth = 15,
        barheight = 0.5,
        title.position = "top",
        title.hjust = 0.5
      )
    ) +

    # Month labels on x-axis
    scale_x_continuous(
      breaks = month_starts$week,
      labels = month_starts$month_label,
      expand = c(0, 0)
    ) +

    # Y-axis (days of week)
    scale_y_discrete(expand = c(0, 0)) +

    # Labels and titles
    labs(
      title = format_year_title(year)$title,
      subtitle = "Daily Pages Read",
      x = NULL,
      y = NULL
    ) +

    # Fixed aspect ratio for square cells
    coord_fixed(ratio = 1) +

    # Apply custom theme
    theme_zsr_heatmap(base_size = config$fonts$axis_text_size) +
    theme(
      legend.position = "bottom",
      legend.direction = "horizontal",
      plot.title = element_text(size = config$fonts$title_size),
      plot.subtitle = element_text(size = config$fonts$subtitle_size)
    )

  return(p)
}

#' Plot overlay chart (stacked bars + lines)
#'
#' Creates dual-axis chart with stacked bars (daily pages) and lines (% complete).
#' Improvements over Python version:
#' - LEGEND ENABLED (critical fix!)
#' - ColorBrewer Set2 palette (colorblind-friendly)
#' - Intelligent positioning and styling
#'
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return ggplot object
#' @export
plot_overlay_chart <- function(df_dailies, year, config) {

  # Filter to specified year and non-empty titles
  df_year <- df_dailies %>%
    dplyr::filter(lubridate::year(date) == year,
                 !is.na(title),
                 title != "")

  if (nrow(df_year) == 0) {
    stop("No data found for year ", year)
  }

  # Get unique books and create color palette
  n_books <- length(unique(df_year$title))
  colors <- get_zsr_palette("categorical", "set2", n = n_books)

  # Calculate scaling factor for dual axes
  max_pages <- max(df_year$daily_pages, na.rm = TRUE)
  scale_factor <- max_pages / 100  # Percent complete is 0-100

  # Create plot
  p <- ggplot(df_year, aes(x = date)) +
    # Stacked bars for daily pages
    geom_col(aes(y = daily_pages, fill = title),
            alpha = config$overlay$alpha_bars,
            position = "stack") +

    # Lines for percent complete (scaled to match bar axis)
    geom_line(aes(y = percent_complete * scale_factor,
                 color = title,
                 group = title),
             alpha = config$overlay$alpha_lines,
             linewidth = config$overlay$line_width) +

    # Color scales
    scale_fill_manual(values = colors, name = "Book") +
    scale_color_manual(values = colors, name = "Book") +

    # Dual y-axes
    scale_y_continuous(
      name = "Daily Pages",
      sec.axis = sec_axis(~ . / scale_factor,
                         name = "Percent Complete (%)")
    ) +

    # X-axis with month breaks
    scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b",
      expand = expansion(add = c(1, 1))
    ) +

    # Labels
    labs(
      title = format_year_title(year)$title,
      subtitle = "Daily Reading Volume and Progress",
      x = NULL
    ) +

    # Legend configuration (ENABLED!)
    guides(
      fill = guide_legend(
        title = "Book",
        ncol = config$overlay$legend_cols,
        override.aes = list(alpha = 1)
      ),
      color = guide_legend(
        title = "Book",
        ncol = config$overlay$legend_cols
      )
    ) +

    # Apply theme
    theme_zsr(base_size = config$fonts$axis_text_size) +
    theme(
      legend.position = config$overlay$legend_position,
      legend.box = "horizontal",
      plot.title = element_text(size = config$fonts$title_size),
      plot.subtitle = element_text(size = config$fonts$subtitle_size),
      axis.title.y.right = element_text(margin = margin(l = 10))
    )

  return(p)
}

#' Plot overlay chart as faceted small multiples
#'
#' Alternative to stacked overlay - each book gets its own panel.
#' Follows Healy's recommendation for small multiples (Chapter 4).
#'
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return ggplot object
#' @export
plot_overlay_faceted <- function(df_dailies, year, config) {

  # Filter to specified year
  df_year <- df_dailies %>%
    dplyr::filter(lubridate::year(date) == year,
                 !is.na(title),
                 title != "")

  if (nrow(df_year) == 0) {
    stop("No data found for year ", year)
  }

  # Create plot
  p <- ggplot(df_year, aes(x = date)) +
    # Bars for daily pages
    geom_col(aes(y = daily_pages),
            fill = config$colors$highlight,
            alpha = 0.7) +

    # Line for percent complete on secondary axis
    geom_line(aes(y = percent_complete * max(df_year$daily_pages) / 100),
             color = config$colors$text,
             linewidth = 1) +

    # Facet by book
    facet_wrap(~ title, ncol = 3, scales = "free_y") +

    # Date axis
    scale_x_date(date_breaks = "2 months", date_labels = "%b") +

    # Labels
    labs(
      title = format_year_title(year)$title,
      subtitle = "Reading Progress by Book (faceted view)",
      x = NULL,
      y = "Daily Pages / % Complete"
    ) +

    # Theme
    theme_zsr(base_size = config$fonts$axis_text_size) +
    theme(
      strip.text = element_text(size = config$fonts$strip_text_size, face = "bold"),
      plot.title = element_text(size = config$fonts$title_size),
      plot.subtitle = element_text(size = config$fonts$subtitle_size)
    )

  return(p)
}
