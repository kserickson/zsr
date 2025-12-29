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

  # Create annotation data (only for non-zero values)
  df_annotations <- df_heatmap %>%
    dplyr::filter(daily_pages > config$heatmap$annotation_size_threshold)

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
             size = 3.5,
             color = ifelse(df_annotations$pages_capped > vmax * 0.6,
                           config$heatmap$annotation_color_dark,
                           config$heatmap$annotation_color_light)) +

    # Greens color scale (better contrast for text)
    scale_fill_gradientn(
      colors = RColorBrewer::brewer.pal(9, "Greens"),
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

#' Plot books table
#'
#' Creates a formatted table of books read during the year with inline progress bars.
#' Equivalent to Python version using gt package.
#'
#' @param df_library Library data frame
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return gt table object
#' @export
plot_books_table <- function(df_library, df_dailies, year, config) {

  # Filter to books read at least one day this year
  books_read_in_year <- df_dailies %>%
    dplyr::filter(lubridate::year(date) == year) %>%
    dplyr::pull(title) %>%
    unique()

  df <- df_library %>%
    dplyr::filter(
      title %in% books_read_in_year,
      status %in% c("Completed", "In progress")
    ) %>%
    dplyr::arrange(desc(began))

  # Get percent_complete as of end of year
  end_of_year <- lubridate::make_date(year, 12, 31)
  df_dailies_year <- df_dailies %>%
    dplyr::filter(date <= end_of_year) %>%
    dplyr::group_by(ean_isbn13) %>%
    dplyr::slice_tail(n = 1) %>%
    dplyr::ungroup() %>%
    dplyr::select(ean_isbn13, percent_complete)

  # Merge and prepare data
  df <- df %>%
    dplyr::left_join(df_dailies_year, by = "ean_isbn13") %>%
    dplyr::mutate(
      percent_complete = tidyr::replace_na(percent_complete, 0),
      percent_complete = as.integer(percent_complete),

      # Truncate long titles and authors
      title_display = smart_truncate(title, config$table$title_truncate_length),
      creators_display = smart_truncate(creators, config$table$author_truncate_length),

      # Format dates
      began_display = format(began, "%Y-%b-%d"),
      completed_display = ifelse(is.na(completed), "-", format(completed, "%Y-%b-%d")),

      # Format duration
      duration_display = ifelse(is.na(duration) | duration == 0, "-", as.character(duration))
    )

  # Create gt table
  table <- df %>%
    dplyr::select(
      Title = title_display,
      Authors = creators_display,
      Pages = length,
      Began = began_display,
      Completed = completed_display,
      `% Complete` = percent_complete,
      `Time to Complete (Days)` = duration_display
    ) %>%
    gt::gt() %>%

    # Add inline progress bars using gtExtras
    gtExtras::gt_plt_bar_pct(
      column = `% Complete`,
      scaled = TRUE,
      fill = "#2ca25f",  # Green color matching Python version
      background = "#f0f0f0"
    ) %>%

    # Styling
    gt::tab_header(
      title = glue::glue("{year} YEAR IN READING - Books Read ≥ 1 Day")
    ) %>%

    # Column alignment
    gt::cols_align(
      align = "left",
      columns = c(Title)
    ) %>%
    gt::cols_align(
      align = "center",
      columns = c(Authors, Pages, Began, Completed, `% Complete`, `Time to Complete (Days)`)
    ) %>%

    # Table styling
    gt::tab_options(
      heading.align = "left",
      heading.title.font.size = gt::px(16),
      heading.title.font.weight = "bold",
      table.font.size = gt::px(10),
      table.border.top.style = "solid",
      table.border.top.width = gt::px(2),
      table.border.top.color = "black",
      table.border.bottom.style = "solid",
      table.border.bottom.width = gt::px(2),
      table.border.bottom.color = "black",
      column_labels.border.bottom.style = "solid",
      column_labels.border.bottom.width = gt::px(2),
      column_labels.border.bottom.color = "black",
      column_labels.font.weight = "bold",
      data_row.padding = gt::px(5)
    ) %>%

    # Alternating row colors
    gt::opt_row_striping(row_striping = TRUE)

  return(table)
}
