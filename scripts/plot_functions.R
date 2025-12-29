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
#' @param show_title Whether to show the year title (default TRUE)
#' @return ggplot object
#' @export
plot_reading_heatmap <- function(df_dailies, year, config, show_title = TRUE) {

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
      title = if (show_title) format_year_title(year)$title else "Daily Pages Read",
      subtitle = if (show_title) "Daily Pages Read" else NULL,
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
#' @param show_legend Whether to show legend (default from config)
#' @param color_mapping Optional named vector of colors for books
#' @param show_title Whether to show the year title (default TRUE)
#' @return ggplot object
#' @export
plot_overlay_chart <- function(df_dailies, year, config, show_legend = NULL, color_mapping = NULL, show_title = TRUE) {

  # Use config default if not specified
  if (is.null(show_legend)) {
    show_legend <- config$overlay$show_legend
  }

  # Filter to specified year and non-empty titles
  df_year <- df_dailies %>%
    dplyr::filter(lubridate::year(date) == year,
                 !is.na(title),
                 title != "")

  if (nrow(df_year) == 0) {
    stop("No data found for year ", year)
  }

  # Get unique books and create color palette
  # Abbreviate long titles for legend
  df_year <- df_year %>%
    dplyr::mutate(
      title_display = ifelse(nchar(title) > 35,
                             paste0(substr(title, 1, 32), "..."),
                             title)
    )

  n_books <- length(unique(df_year$title))

  # Use provided color mapping or generate new one
  if (!is.null(color_mapping)) {
    colors <- color_mapping
  } else {
    colors <- get_zsr_palette("categorical", "set2", n = n_books)
    names(colors) <- unique(df_year$title_display)
  }

  # Calculate scaling factor for dual axes
  max_pages <- max(df_year$daily_pages, na.rm = TRUE)
  scale_factor <- max_pages / 100  # Percent complete is 0-100

  # Create plot
  p <- ggplot(df_year, aes(x = date)) +
    # Stacked bars for daily pages
    geom_col(aes(y = daily_pages, fill = title_display),
            alpha = config$overlay$alpha_bars,
            position = "stack") +

    # Lines for percent complete (scaled to match bar axis)
    geom_line(aes(y = percent_complete * scale_factor,
                 color = title_display,
                 group = title),
             alpha = config$overlay$alpha_lines,
             linewidth = config$overlay$line_width) +

    # Color scales
    scale_fill_manual(values = colors, name = "Book") +
    scale_color_manual(values = colors, name = "Book") +

    # Dual y-axes - no gap at bottom
    scale_y_continuous(
      name = "Daily Pages",
      sec.axis = sec_axis(~ . / scale_factor,
                         name = "Percent Complete (%)"),
      expand = expansion(mult = c(0, 0.05))  # No gap at 0, small gap at top
    ) +

    # X-axis with month breaks
    scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b",
      expand = expansion(add = c(1, 1))
    ) +

    # Labels
    labs(
      title = if (show_title) format_year_title(year)$title else "Daily Reading Volume and Progress",
      subtitle = if (show_title) "Daily Reading Volume and Progress" else NULL,
      x = NULL
    ) +

    # Legend configuration
    {if (show_legend) {
      guides(
        fill = guide_legend(
          title = if (isTRUE(config$overlay$legend_show_title)) "Book" else NULL,
          ncol = if (config$overlay$legend_position == "right") 1 else config$overlay$legend_cols,
          override.aes = list(alpha = 1)
        ),
        color = guide_legend(
          title = if (isTRUE(config$overlay$legend_show_title)) "Book" else NULL,
          ncol = if (config$overlay$legend_position == "right") 1 else config$overlay$legend_cols
        )
      )
    } else {
      guides(fill = "none", color = "none")
    }} +

    # Apply theme
    theme_zsr(base_size = config$fonts$axis_text_size) +
    theme(
      legend.position = if (config$overlay$legend_position == "inside") {
        c(0.02, 0.98)  # top-left corner
      } else {
        config$overlay$legend_position
      },
      legend.box = "vertical",
      legend.justification = if (config$overlay$legend_position == "inside") {
        c(0, 1)  # left-top justification
      } else if (config$overlay$legend_position == "bottom") {
        c(0, 0.5)  # left-align for bottom
      } else {
        "center"
      },
      legend.background = if (config$overlay$legend_position == "inside") {
        element_rect(fill = alpha("white", 0.9), color = "gray50", linewidth = 0.5)
      } else {
        element_blank()
      },
      legend.key.size = unit(0.35, "cm"),
      legend.text = element_text(size = 7),
      legend.title = element_text(size = 8, face = "bold"),
      legend.spacing.y = unit(0.1, "cm"),
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
#' @param color_mapping Optional named vector of colors for books (for year-in-review)
#' @param show_title Whether to show the full year title (default TRUE)
#' @return gt table object
#' @export
plot_books_table <- function(df_library, df_dailies, year, config, color_mapping = NULL, show_title = TRUE) {

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
      duration_display = ifelse(is.na(duration) | duration == 0, "-", as.character(duration)),

      # Add color if mapping provided
      book_color = if (!is.null(color_mapping)) {
        # Abbreviate title same way as overlay chart for matching
        title_abbrev <- ifelse(nchar(title) > 35,
                              paste0(substr(title, 1, 32), "..."),
                              title)
        color_mapping[title_abbrev]
      } else {
        NA_character_
      }
    )

  # Create gt table with or without color column
  if (!is.null(color_mapping)) {
    table <- df %>%
      dplyr::select(
        ` ` = book_color,  # Color indicator column
        Title = title_display,
        Authors = creators_display,
        Pages = length,
        Began = began_display,
        Completed = completed_display,
        `% Complete` = percent_complete,
        `Time to Complete (Days)` = duration_display
      ) %>%
      gt::gt() %>%
      # Color the first column with book colors
      gt::tab_style(
        style = list(
          gt::cell_fill(color = gt::from_column(column = " "))
        ),
        locations = gt::cells_body(columns = " ")
      ) %>%
      gt::cols_width(
        ` ` ~ gt::px(20)
      )
  } else {
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
      gt::gt()
  }

  # Add progress bars with matching colors
  if (!is.null(color_mapping)) {
    table <- table %>%
      gtExtras::gt_plt_bar_pct(
        column = `% Complete`,
        scaled = TRUE,
        fill = gt::from_column(column = " "),  # Use book color for each bar
        background = "#f0f0f0"
      )
  } else {
    table <- table %>%
      gtExtras::gt_plt_bar_pct(
        column = `% Complete`,
        scaled = TRUE,
        fill = "#2ca25f",  # Default green
        background = "#f0f0f0"
      )
  }

  table <- table %>%

    # Styling
    gt::tab_header(
      title = if (show_title) {
        glue::glue("{year} YEAR IN READING - Books Read ≥ 1 Day")
      } else {
        "Books Read (At Least One Day)"
      }
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

    # Table styling - minimal and unified
    gt::tab_options(
      heading.align = "left",
      heading.title.font.size = gt::px(12),
      heading.title.font.weight = "bold",
      table.font.size = gt::px(9),
      table.border.top.style = "none",
      table.border.bottom.style = "none",
      column_labels.border.bottom.style = "solid",
      column_labels.border.bottom.width = gt::px(1),
      column_labels.border.bottom.color = "gray80",
      column_labels.font.weight = "bold",
      column_labels.font.size = gt::px(9),
      data_row.padding = gt::px(4),
      heading.padding = gt::px(0)
    ) %>%

    # Subtle alternating row colors
    gt::tab_style(
      style = gt::cell_fill(color = "gray97"),
      locations = gt::cells_body(rows = seq(2, nrow(df), 2))
    )

  return(table)
}

#' Plot year-in-review combined chart
#'
#' Combines heatmap, overlay chart (no legend), and books table (with color indicators)
#' into a single comprehensive year-in-review visualization.
#'
#' @param df_library Library data frame
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return Combined plot object
#' @export

#' Plot reading session distribution
#'
#' Shows the distribution of daily page counts using violin plots (Healy Ch. 6).
#' Reveals typical reading session sizes and variability by month.
#'
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return ggplot object
#' @export
plot_session_distribution <- function(df_dailies, year, config) {

  # Aggregate daily pages per day across all books, grouped by month
  df_daily_totals <- df_dailies %>%
    dplyr::filter(lubridate::year(date) == year) %>%
    dplyr::group_by(date) %>%
    dplyr::summarize(daily_pages = sum(daily_pages, na.rm = TRUE), .groups = "drop") %>%
    dplyr::mutate(
      month = lubridate::month(date, label = TRUE, abbr = TRUE)
    )

  if (nrow(df_daily_totals) == 0) {
    stop("No reading data found for year ", year)
  }

  # Create plot
  p <- ggplot(df_daily_totals, aes(x = month, y = daily_pages, fill = month)) +
    # Violin plot for distribution shape
    geom_violin(alpha = 0.5, color = NA) +

    # Box plot overlay for quartiles
    geom_boxplot(width = 0.2, alpha = 0.7, outlier.shape = NA) +

    # Individual points for actual sessions (jittered)
    geom_jitter(width = 0.15, alpha = 0.3, size = 1, color = config$colors$text) +

    # Median line emphasized
    stat_summary(fun = median, geom = "point", shape = 23,
                size = 3, fill = "white", color = config$colors$text) +

    # Color scale
    scale_fill_viridis_d(option = "viridis", guide = "none") +

    # Y-axis
    scale_y_continuous(
      name = "Pages Read Per Day",
      expand = expansion(mult = c(0, 0.05))
    ) +

    # Labels
    labs(
      title = glue("{year} Reading Session Distribution"),
      subtitle = "How many pages did you typically read each day?",
      x = NULL
    ) +

    # Theme
    theme_minimal(base_family = config$fonts$base_family) +
    theme(
      text = element_text(color = config$colors$text),
      plot.title = element_text(size = 14, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = 11, hjust = 0, margin = margin(0, 0, 10, 0)),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "gray92", linewidth = 0.3),
      plot.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(15, 20, 15, 20)
    )

  return(p)
}

#' Plot completion pace dot plot
#'
#' Cleveland dot plot showing pages per day for each book (Healy Ch. 5).
#' Reveals which books you read quickly vs. slowly.
#'
#' @param df_library Library data frame
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return ggplot object
#' @export
plot_completion_pace <- function(df_library, df_dailies, year, config) {

  # Get books read this year with completion data
  df_year <- df_library %>%
    dplyr::filter(
      !is.na(began),
      !is.na(duration),
      duration > 0,
      lubridate::year(began) == year | lubridate::year(completed) == year
    ) %>%
    dplyr::mutate(
      pages_per_day = length / duration,
      title_display = smart_truncate(title, 40)
    ) %>%
    dplyr::arrange(pages_per_day)

  if (nrow(df_year) == 0) {
    stop("No completed books with duration data for year ", year)
  }

  # Reorder for plotting
  df_year <- df_year %>%
    dplyr::mutate(title_display = forcats::fct_reorder(title_display, pages_per_day))

  # Create plot
  p <- ggplot(df_year, aes(x = pages_per_day, y = title_display)) +
    # Segments from 0 to value
    geom_segment(aes(x = 0, xend = pages_per_day, y = title_display, yend = title_display),
                color = "gray70", linewidth = 0.5) +
    
    # Dots at values
    geom_point(size = 3, color = config$colors$highlight) +
    
    # X-axis
    scale_x_continuous(
      name = "Pages Per Day",
      expand = expansion(mult = c(0, 0.05))
    ) +
    
    # Labels
    labs(
      title = glue("{year} Reading Pace"),
      subtitle = "How quickly did you read each book?",
      y = NULL
    ) +
    
    # Theme
    theme_minimal(base_family = config$fonts$base_family) +
    theme(
      text = element_text(color = config$colors$text),
      plot.title = element_text(size = 14, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = 11, hjust = 0, margin = margin(0, 0, 10, 0)),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(color = "gray92", linewidth = 0.3),
      axis.text.y = element_text(size = 8),
      plot.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(15, 20, 15, 20)
    )

  return(p)
}

#' Plot reading streak calendar
#'
#' Enhanced calendar heatmap highlighting consecutive reading days.
#' Shows reading consistency patterns.
#'
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return ggplot object
#' @export

#' Plot cumulative reading progress
#'
#' Line chart showing running total of pages read over time with milestone markers.
#' Shows reading momentum and pace throughout the year.
#'
#' @param df_dailies Dailies data frame
#' @param year Year to plot
#' @param config Configuration list
#' @return ggplot object
#' @export
plot_cumulative_progress <- function(df_dailies, year, config) {

  # Aggregate daily totals
  df_year <- df_dailies %>%
    dplyr::filter(lubridate::year(date) == year) %>%
    dplyr::group_by(date) %>%
    dplyr::summarize(daily_pages = sum(daily_pages, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(date) %>%
    dplyr::mutate(cumulative_pages = cumsum(daily_pages))

  # Add milestones every 1000 pages
  total_pages <- max(df_year$cumulative_pages)
  milestones <- seq(1000, floor(total_pages / 1000) * 1000, by = 1000)
  
  milestone_data <- tibble::tibble()
  for (milestone in milestones) {
    milestone_date <- df_year %>%
      dplyr::filter(cumulative_pages >= milestone) %>%
      dplyr::slice(1) %>%
      dplyr::pull(date)
    
    if (length(milestone_date) > 0) {
      milestone_data <- dplyr::bind_rows(
        milestone_data,
        tibble::tibble(date = milestone_date, pages = milestone)
      )
    }
  }

  # Create plot
  p <- ggplot(df_year, aes(x = date, y = cumulative_pages)) +
    # Area under curve
    geom_area(fill = config$colors$highlight, alpha = 0.2) +
    
    # Main line
    geom_line(color = config$colors$highlight, linewidth = 1.2) +
    
    # Milestone markers
    {if (nrow(milestone_data) > 0) {
      geom_point(
        data = milestone_data,
        aes(x = date, y = pages),
        size = 3, color = config$colors$text, fill = "white",
        shape = 21, stroke = 1.5
      )
    }} +
    
    # Milestone labels
    {if (nrow(milestone_data) > 0) {
      geom_text(
        data = milestone_data,
        aes(x = date, y = pages, label = scales::comma(pages)),
        vjust = -1, size = 3, family = config$fonts$base_family,
        color = config$colors$text
      )
    }} +
    
    # Scales
    scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b",
      expand = expansion(mult = c(0.02, 0.02))
    ) +
    scale_y_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0, 0.1))
    ) +
    
    # Labels
    labs(
      title = glue("{year} Cumulative Reading Progress"),
      subtitle = glue("Total: {scales::comma(total_pages)} pages"),
      x = NULL,
      y = "Cumulative Pages"
    ) +
    
    # Theme
    theme_minimal(base_family = config$fonts$base_family) +
    theme(
      text = element_text(color = config$colors$text),
      plot.title = element_text(size = 14, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = 11, hjust = 0, margin = margin(0, 0, 10, 0)),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray92", linewidth = 0.3),
      plot.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(15, 20, 15, 20)
    )

  return(p)
}

