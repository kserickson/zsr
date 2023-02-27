import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
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

titles = df_dailies['title'].unique()
grouped = df_dailies.groupby(['date', 'title'])['daily_pages'].sum().unstack()

# create a line chart
fig, ax1 = plt.subplots()

for title in titles:
    data = df_dailies[df_dailies['title'] == title]
    ax1.plot(data['date'], data['percent_complete'], label=title)

# create a stacked bar chart
ax2 = ax1.twinx()
for idx, title in enumerate(titles):
    plt.bar(grouped.index, grouped[title])

# label the axes
ax1.set_ylabel('Percent Complete')
ax2.set_ylabel('Daily Pages')
ax1.set_xlabel('Date')

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
ax1.set_xticklabels(tick_labels)

# Add a legend
ax1.legend(fontsize=8, loc='upper left', bbox_to_anchor=(1.15, 1), borderaxespad=0.)

# Add a title
plt.title('Reading Progress 2023')

# Show the plot
plt.savefig(
    '/Users/kserickson/Documents/zsr/figures/progress-over-time.png',
    dpi=300,
    transparent=True,
    bbox_inches='tight'
)
