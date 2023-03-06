import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib import font_manager
import seaborn as sns

# DATA IMPORT
# Read progress data into data frame
df_2022 = pd.read_csv('/Users/kserickson/Documents/zsr/data/2022.csv')
df_dailies = pd.read_csv('/Users/kserickson/Documents/zsr/data/dailies.csv')

# DATA CLEANUP
# Cast columns as correct data types while filling in any missing values
df_dailies['ean_isbn13'] = df_dailies['ean_isbn13'].astype(str).str.replace(r'\.0$', '')
df_dailies['date'] = pd.to_datetime(df_dailies['date'], format='%Y-%m-%d', errors="coerce")
df_dailies['title'] = df_dailies['title'].replace(np.nan, '')

# STYLING
titlefont = {
    'family': 'Arial',
    'color': 'black',
    'weight': 'bold',
    'size': 10,
}

axesfont = {
    'family': 'Arial',
    'color': 'black',
    'size': 9,
}

labelfonts = {
    'family': 'Arial',
    'color': 'black',
    'size': 8,
}

# DATA VISUALIZATION
# Create a GANTT chart of books I read in 2022

# Get the list of books and their start and end dates
# books = df_2022[['began', 'completed']].values

# Get the y-coordinates for each book
#y_coords = range(len(books))

# Create the figure and axis
#fig, ax = plt.subplots()

# Plot the bars using broken_barh
# for i, (start, end) in enumerate(books):
#    ax.broken_barh([(start, end-start)], (y_coords[i]-0.4, 0.8), facecolors='blue')

# Set the y-axis tick labels to the book names
# ax.set_yticks(y_coords)
# ax.set_yticklabels(df_2022['title'])

# Set the x-axis limits to cover the entire year
# ax.set_xlim(df_2022['began'].min(), df_2022['completed'].max())

# Show the plot
# plt.savefig(
#    '/Users/kserickson/Documents/zsr/figures/2022books-gantt.png',
#    dpi=300,
#    transparent=True,
#    bbox_inches='tight'
#)

# Create a line chart with multiple series that shows percent_complete over time for each unique ISBN and a stacked bar chart that shows pages read per day

# Create an array of unique titles
titles = df_dailies['title'].unique()

# Remove title that was added to df_dailies when rows were created for day with no pages read
titles = titles[titles != '']

# Create DataFrame for stacked bar chart
grouped = df_dailies.groupby(['date', 'title'])['daily_pages'].sum().unstack().fillna(0)
colors = sns.color_palette('gist_stern_r', n_colors=len(titles))

# create a line chart
fig, ax1 = plt.subplots()

for i, title in enumerate(titles):
    data = df_dailies[df_dailies['title'] == title]
    ax1.plot(data['date'], data['percent_complete'], label=title, color=colors[i])

# create a stacked bar chart
ax2 = ax1.twinx()

# initialize vertical offset for stacked bar chart
y_offset = np.zeros(len(grouped))

# plot bars
for idx, title in enumerate(titles):
    plt.bar(grouped.index, grouped[title], bottom=y_offset, color=colors[idx])
    y_offset = y_offset + grouped[title]

# label the axes
ax1.set_xlabel('Date', fontdict=axesfont)

ax1.set_ylabel('Percent Complete', fontdict=axesfont)
ax1.yaxis.set_tick_params(labelsize=6)
ax1.set_ylim(-.5)

ax2.set_ylabel('Daily Pages', fontdict=axesfont)
ax2.yaxis.set_tick_params(labelsize=6)

# add tick labels for the first date of each month
last_month = None
tick_labels = []
for date in grouped.index:
    month = date.month
    if month != last_month:
        label = date.strftime('%b %Y')
        tick_labels.append(label)
        last_month = month
    else:
        tick_labels.append('')

# set the tick labels
ax1.xaxis.set_major_locator(mdates.DayLocator())
ax1.xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
ax1.set_xticklabels(tick_labels, fontdict=labelfonts)

# Add a legend
ax1.legend(fontsize=6, bbox_to_anchor=(0, -0.25, 1, 1), borderaxespad=0, ncol=2, frameon=False)

# Add a title
plt.title('2023 YEAR IN READING', fontdict=titlefont, loc='left')

# Show the plot
plt.savefig(
    '/Users/kserickson/Documents/zsr/figures/progress-over-time.png',
    dpi=300,
    transparent=True,
    bbox_inches='tight'
)
