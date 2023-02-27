import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# DATA IMPORT
# Read progress data into data frame
df_2022 = pd.read_csv('/Users/kserickson/Documents/zsr/data/2022.csv')
df_dailies = pd.read_csv('/Users/kserickson/Documents/zsr/data/dailies.csv')

# Cast columns as correct data types while filling in any missing values
df_dailies['ean_isbn13'] = df_dailies['ean_isbn13'].astype(str).str.replace(r'\.0$', '')
df_dailies['date'] = pd.to_datetime(df_dailies['date'], format='%Y-%m-%d', errors="coerce")

print(df_dailies.dtypes)

# Create a GANTT chart of books I read in 2022

# Get the list of books and their start and end dates
books = df_2022[['began', 'completed']].values

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

# Create a line chart with multiple series that shows percent_complete over time for each unique ISBN

# sns.lineplot(data=df_dailies, x="date", y="percent_complete", hue='title_x')

# Show the plot
# plt.savefig(
#    '/Users/kserickson/Documents/zsr/figures/progress-over-time.png',
#    dpi=300,
#    transparent=True,
#    bbox_inches='tight'
#)

print(df_dailies.loc[:, ['title_x', 'date', 'percent_complete', 'daily_pages']])

min_date = df_dailies['date'].min()
max_date = df_dailies['date'].max()

all_dates = pd.date_range(start=min_date, end=max_date, freq='D')

df_dates = pd.DataFrame({'date': all_dates})
print(df_dailies.dtypes)
print(df_dates.dtypes)

df_dailies = pd.merge(df_dates, df_dailies, on='date', how='left').fillna(0)

titles = df_dailies['title_x'].unique()
grouped = df_dailies.groupby(['date', 'title_x'])['daily_pages'].sum().unstack()

# create a line chart
fig, ax1 = plt.subplots()

for title in titles:
    data = df_dailies[df_dailies['title_x'] == title]
    ax1.plot(data['date'], data['percent_complete'], label=title)

ax1.set_xlabel('Date')
ax1.set_xticks(df_dailies['date'])
ax1.set_xticklabels(ax1.get_xticklabels(), rotation=90)
ax1.set_ylabel('Percent Complete')

ax1.legend(fontsize=8, loc='upper left', bbox_to_anchor=(1.15, 1), borderaxespad=0.)

# create a stacked bar chart
ax2 = ax1.twinx()
# left = len(titles) * [0]
for idx, title in enumerate(titles):
    plt.bar(grouped.index, grouped[title])

ax2.set_ylabel('Daily Pages')

plt.title('Reading Progress 2023')

# show the plot
plt.savefig(
    '/Users/kserickson/Documents/zsr/figures/progress-over-time.png',
    dpi=300,
    transparent=True,
    bbox_inches='tight'
)
