import pandas as pd
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.patches as patches
from matplotlib import font_manager
from datetime import datetime
import seaborn as sns
import json
import os

# CONFIGURATION
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CONFIG_FILE = os.path.join(ROOT_DIR, 'config.json')

# Load configuration
with open(CONFIG_FILE, 'r') as config_file:
    config = json.load(config_file)

# Load styling information from style.json
with open('style.json', 'r') as style_file:
    style_data = json.load(style_file)

font = style_data.get('font', {})
titlefont = style_data.get('titlefont', {})
axesfont = style_data.get('axesfont', {})
labelfonts = style_data.get('labelfonts', {})
facecolors = style_data.get('facecolors', {})

# Setting global font family
mpl.rcParams['font.family'] = font['family']

# Setting global title font properties
mpl.rcParams['axes.titlesize'] = titlefont['size']
mpl.rcParams['axes.titleweight'] = titlefont['weight']
mpl.rcParams['axes.titlecolor'] = titlefont['color']

# Setting global axis label font properties
mpl.rcParams['axes.labelsize'] = axesfont['size']
mpl.rcParams['axes.labelcolor'] = axesfont['color']

# Setting global tick label font properties
mpl.rcParams['xtick.labelsize'] = labelfonts['size']
mpl.rcParams['ytick.labelsize'] = labelfonts['size']
mpl.rcParams['xtick.color'] = labelfonts['color']
mpl.rcParams['ytick.color'] = labelfonts['color']

# Setting facecolors globally
mpl.rcParams['figure.facecolor'] = facecolors["figure_facecolor"]
mpl.rcParams['axes.facecolor'] = facecolors["axes_facecolor"]

# FUNCTIONS
def clean_data(df_library, df_dailies):
    df_library['ean_isbn13'] = df_library['ean_isbn13'].astype(str).str.replace(r'\.0$', '', regex=True)
    df_dailies['ean_isbn13'] = df_dailies['ean_isbn13'].astype(str).str.replace(r'\.0$', '', regex=True)
    df_library['title'] = df_library['title'].replace(np.nan, '')
    df_dailies['title'] = df_dailies['title'].replace(np.nan, '')
    df_library['began'] = pd.to_datetime(df_library['began'], format='%Y-%m-%d', errors='raise')
    df_library['completed'] = pd.to_datetime(df_library['completed'], format='%Y-%m-%d', errors='raise')
    df_dailies['date'] = pd.to_datetime(df_dailies['date'], format='%Y-%m-%d', errors="coerce")
    return df_library
    return df_dailies

def plot_stacked_bar_and_line_charts(df, year):
    # Filter data for the specified year
    df = df[df['date'].dt.year == year]

    # Create a figure and subplots
    fig, ax1 = plt.subplots(figsize=(20, 2.5))
    ax2 = ax1.twinx()

    # Create an array of unique titles for this year's data
    titles = df['title'].unique()
    titles = titles[titles != '']

    # Create a DataFrame for stacked bar chart
    grouped = df.groupby(['date', 'title'])['daily_pages'].sum().unstack(fill_value=0)

    # Colors for lines
    colors = sns.color_palette('gist_stern_r', n_colors=len(titles))

    # Initialize vertical offset for stacked bar chart
    y_offset = np.zeros(len(grouped))

    # Plot stacked bars
    for idx, title in enumerate(titles):
        ax2.bar(grouped.index, grouped[title], bottom=y_offset, color=colors[idx], alpha=0.7)
        y_offset = y_offset + grouped[title]

    # Plot lines for percent complete
    for i, title in enumerate(titles):
        data = df[df['title'] == title]
        ax1.plot(data['date'], data['percent_complete'], label=title, color=colors[i])

    # Label and style the axes
    # x-axis
    ax1.set_xlabel('', fontdict=axesfont)
    start_date = df['date'].min() - pd.Timedelta(days=1)
    end_date = df['date'].max() + pd.Timedelta(days=1)
    ax1.set_xlim(start_date, end_date)

    # Calculate positions for every day of the year
    all_days = pd.date_range(start_date, end_date)
    all_day_positions = mdates.date2num(all_days)

    # Calculate positions for each month's first day
    month_starts = pd.date_range(start=f'{year}-01-01', end=f'{year}-12-31', freq='MS')
    month_start_positions = mdates.date2num(month_starts)

    # Set the tick positions and labels for the x-axis
    ax1.set_xticks(month_start_positions)
    ax1.set_xticklabels([date.strftime('%b') for date in month_starts], rotation=0, ha='left')

    # Apply font styles to tick labels
    for label in ax1.get_xticklabels() + ax1.get_yticklabels():
      label.set_fontsize(labelfonts['size'])
      label.set_color(labelfonts['color'])

    # y-axes
    ax1.set_ylabel('Percent Complete')
    ax2.set_ylabel('Daily Pages')

    # Add a legend
    # ax1.legend(fontsize=7, loc='lower left', bbox_to_anchor=(0, -.9), borderaxespad=0, ncol=3, frameon=False)

    # Add a title
    plt.title(f'{year} YEAR IN READING - Daily Pages and Completion Progress Over Time', loc='left')

    # Return the figure
    return fig

def plot_reading_heatmap(df, year):
    # Filter data for the specified year
    df = df[df['date'].dt.year == year]

    # Ensure the data is aggregated by date, summing over the 'daily_pages' column
    daily_data = df.groupby('date')['daily_pages'].sum().reset_index()
    
    # Create a date range for the year
    start_date = pd.Timestamp(f"{year}-01-01")
    end_date = pd.Timestamp(f"{year}-12-31")
    all_dates = pd.date_range(start=start_date, end=end_date)
    
    # Create a DataFrame with all dates in the year
    calendar_df = pd.DataFrame({'date': all_dates})
    
    # Merge the reading data with the full year's date range, filling missing days with zeros
    calendar_df = calendar_df.merge(daily_data, how='left', on='date').fillna(0)

    # Determine the first Monday of the year
    first_monday = calendar_df[calendar_df['date'].dt.weekday == 0]['date'].min()
    if first_monday > start_date:
        first_monday -= pd.Timedelta(days=7)
    
    # Calculate week and day numbers for each date in the DataFrame
    calendar_df['week'] = (calendar_df['date'] - first_monday).dt.days // 7 + 1
    calendar_df['day'] = calendar_df['date'].dt.weekday

    # Find the week number for the first day of each month
    month_starts = pd.date_range(start=f'{year}-01-01', end=f'{year}-12-31', freq='MS')
    month_weeks = ((month_starts - first_monday).days // 7 + 1).tolist()
    
    # Pivot the DataFrame to prepare for the heatmap
    heatmap_data = calendar_df.pivot(index="day", columns="week", values="daily_pages")
    
    # Create the heatmap plot
    fig, ax = plt.subplots(figsize=(20, 2.5))  # Aspect ratio adjusted for visual clarity
    cmap = sns.color_palette("Greens", as_cmap=True)
    cmap.set_under('white')  # Set color for zero values
    
    # Draw the heatmap with white cells for zeros and black lines for borders
    formatted_annotation = heatmap_data.fillna(0).applymap(lambda x: f'{int(x):d}' if x != 0 else '')
    sns.heatmap(heatmap_data, cmap=cmap, linewidths=0.5, linecolor='black', cbar=True, annot=formatted_annotation, fmt="", annot_kws={'fontsize':8}, square=True, vmax=75, ax=ax)
    
    # Set the aspect of the plot to equal for square cells
    ax.set_aspect('equal')
    
    # Define the month's positions and labels for the x-axis
    ax.set_xticks(month_weeks)
    ax.set_xticklabels([date.strftime('%b') for date in month_starts], ha='left')
    ax.set_xlabel('')
    
    # Define the labels for the y-axis
    day_labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    ax.set_yticks(np.arange(len(day_labels)))
    ax.set_yticklabels(day_labels, rotation=0, va='top')
    ax.set_ylabel('')
    
    # Adjust the layout to add padding and display the plot clearly
    plt.tight_layout(pad=2)

    # Add a title
    plt.title(f'{year} YEAR IN READING - Daily Pages', loc='left')

    return fig

def plot_books_table(df, df_dailies, year):

    # Filter df to only titles that were read at least one day this year, sort df
    books_read_in_year = df_dailies[df_dailies['date'].dt.year == year]['title'].unique()
    df = df[df['title'].isin(books_read_in_year) & df['status'].isin(['Completed', 'In progress'])]
    df.sort_values(by='began', ascending=False, inplace=True)

    # Aggregate the most recent percent_complete for each title in df_dailies
    df_dailies = df_dailies.groupby('ean_isbn13')['percent_complete'].last().reset_index()

    # Merge df_dailies with df, convert values to integers
    df = df.merge(df_dailies, on='ean_isbn13', how='left')
    df['percent_complete'] = df['percent_complete'].fillna(0).apply(lambda x: int(x))

    # Truncate long titles and authors
    df['title'] = df['title'].apply(lambda x: x[:30] + '...' if len(x) > 30 else x)
    df['creators'] = df['creators'].apply(lambda x: x[:30] + '...' if len(x) > 30 else x)

    # Replace "NaT" with "-" and format dates
    df['completed'] = df['completed'].apply(lambda x: x.strftime('%Y-%b-%d') if pd.notna(x) else '-')
    df['began'] = df['began'].dt.strftime('%Y-%b-%d')
    df['duration'] = df['duration'].replace({0: '-'})

    # Create the table plot
    fig, ax = plt.subplots(figsize=(20, 10))

    ncols = 7
    nrows = df.shape[0]

    ax.set_xlim(0, ncols + 1)
    ax.set_ylim(0, nrows + 1)

    positions = [0, 2.25, 3.25, 4.25, 5.25, 6.25, 7.25]
    columns = ['title', 'creators', 'length', 'began', 'completed', 'percent_complete', 'duration']

    for i in range (nrows):
        for j, column in enumerate(columns):
            text_ha = 'left' if j == 0 else 'center'
            text_label = f'{df[column].iloc[i]}'

            if column == 'percent_complete':
                # Draw a bar chart in the cell
                completion = df[column].iloc[i] / 100  # Convert percentage to a fraction
                cell_width = positions[j+1] - positions[j]  # Calculate the full cell width
                rect_x_start = positions[j] - cell_width / 3  # Adjust to get the left edge
                rect_width = completion * cell_width * .7  # Calculate the width of the rectangle based on the % complete
                color = sns.color_palette("Greens")[int(completion * (len(sns.color_palette("Greens")) - 1))]
                rect = patches.Rectangle((rect_x_start, i), rect_width, 1, color=color)
                ax.add_patch(rect)
                # Add text overlay on the rectangle
                ax.text(positions[j], i + 0.5, f'{df[column].iloc[i]}%', 
                    ha='center', va='center', color='white' if completion > 0.5 else 'black')
                continue

            ax.annotate(
                text=text_label,
                xy=(positions[j], i + 0.5),
                ha=text_ha,
                va='center',
                fontsize=10,
            )

    column_names = ['Title', 'Authors', 'Pages', 'Began', 'Completed', '% Complete', 'Time to Complete (Days)']
    
    for index, c in enumerate(column_names):
        if index == 0:
            ha = 'left'
        else:
            ha = 'center'
        ax.annotate(
            xy=(positions[index], nrows + .25),
            text=column_names[index],
            ha=ha,
            va='bottom',
            weight='bold'
        )

    # Add dividing lines
    ax.plot([ax.get_xlim()[0], ax.get_xlim()[1]], [nrows, nrows], lw=1.5, color='black', marker='', zorder=4)
    ax.plot([ax.get_xlim()[0], ax.get_xlim()[1]], [0, 0], lw=1.5, color='black', marker='', zorder=4)
    for x in range(1, nrows):
        ax.plot([ax.get_xlim()[0], ax.get_xlim()[1]], [x, x], lw=1.15, color='gray', ls=':', zorder=3 , marker='')

    # Remove axis border and ticks
    ax.set_axis_off()

    # Set x and y labels to empty (if needed)
    ax.set_xlabel('')
    ax.set_ylabel('')

    # Add a title
    plt.title(f'{year} YEAR IN READING - Books Read ≥ 1 Day', loc='left')

    return fig

def save_plot(
    figure,
    file_name,
    output_dir=config['output_paths']['figures'],
    dpi=300,
    transparent=True,
    bbox_inches='tight',
):
    """
    Save a matplotlib figure to a file.

    Args:
        figure (matplotlib.figure.Figure): The figure to save.
        file_name (str): The name of the output file (e.g., 'plot.png').
        output_dir (str): The directory where the file should be saved.
        dpi (int): The DPI (dots per inch) for the saved image.
        transparent (bool): Whether the saved image should have a transparent background.
        bbox_inches (str or Bbox): Bounding box in inches: 'tight' or Bbox object.
    """

    # Get global facecolors
    global_figure_facecolor = mpl.rcParams['figure.facecolor']

    # Save the figure to the specified file
    figure.savefig(
        os.path.join(output_dir, file_name),
        dpi=dpi,
        transparent=transparent,
        bbox_inches=bbox_inches,
        facecolor=global_figure_facecolor
    )

def main():
    # Extract data file paths
    data_paths = config.get('input_paths', {})

    # Import data into DataFrames
    df_dailies = pd.read_csv(data_paths.get('dailies', ''))
    df_library = pd.read_csv(data_paths.get('library', ''))

    # Clean and transform data
    clean_data(df_library, df_dailies)

    # Find years in dataset
    years = df_dailies['date'].dt.year.unique()

    #Create and save plots for each year
    for year in years:
        fig1 = plot_stacked_bar_and_line_charts(df_dailies, year)
        save_plot(fig1, f'overlay-chart-{year}.png')

        fig2 = plot_reading_heatmap(df_dailies, year)
        save_plot(fig2, f'daily-pages-{year}.png')

        fig3 = plot_books_table(df_library, df_dailies, year)
        save_plot(fig3, f'books-table-{year}.png')

if __name__ == "__main__":
    main()
