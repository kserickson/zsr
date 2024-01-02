# ZSR
---

Scripts for cleaning, enriching, and visualizing data about your library and reading habits.

ZSR currently supports three visualizations:
1. A **nicely formatted table** of all books started or completed in a given year.
2. A **Github contribution-style grid** of pages read daily in a given year.
3. An **overlaid line and stacked bar chart** that shows, by book, number of pages read each day and progress toward completion over time

![](/figures/daily-pages.png)
![](/figures/overlay-chart.png)

## Requirements

ZSR scripts are compatible with `python 3.9.6` and make use of the following python libraries and modules:

* [`pandas`](https://pandas.pydata.org/) for data manipulation
* [`numpy`](https://numpy.org/) for certain mathemetical operations 
* [`matplotlib`](https://matplotlib.org/) for data visualization
* [`seaborn`](https://seaborn.pydata.org/) for data visualization and styling

## Data

To track the books in my personal library, I use [Libib](https://www.libib.com/), a library management web application. Libib enables users to organize their books in different libraries (I have separate ones for Kindle books, borrowed books, and physical books). Users can export data for each of their libraries in CSV format. ZSR is written to work out of the box with the Libib schema and related data quirks (e.g., leading whitespace in certain columns).

To track daily reading habits, I maintain a spreadsheet `daily_log.csv` separately from Libib with the following fields:
* data
* title
* isbn13
* start_page
* end_page

## Set-up

If you'd like to use ZSR yourself, follow these steps to set it up.

1. Prepare your development environment. Install all the libraries in the Requirements section above.

2. Clone this repo.

3. Save your library data (whether from Libib or somewhere else) and your daily reading log in CSV format to the `data` directory.

4. Update the `config.json` file to specify the paths on your machine for the data inputs and script outputs.

5. Run `zsr.py` to clean and enrich your data. Then run `zsr_plots.py` to visualize your data.

## Credits

The table plot owes a lot to [this tutorial](https://www.sonofacorner.com/beautiful-tables/) from [sonofacorner](https://github.com/sonofacorner), whose plots are stunning.

## Why ZSR?

This project is named for the [Z. Smith Reynolds Library](https://zsr.wfu.edu/) at Wake Forest University, where I spent many happy hours napping, and a few reading.
