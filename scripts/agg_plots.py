import pandas as pd
import matplotlib.pyplot as plt
from PIL import Image
import urllib
import os

# DATA IMPORT
# Read aggregates data into data frame
df_aggregates = pd.read_csv('Users/kserickson/Documents/zsr/data/aggregates.csv')
df_2022 = pd.read_csv('Users/kserickson/Documents/zsr/data/2022.csv')


# DATA VISUALIZATION
# Create a table of the books read by year
fig = plt.figure(figsize=(18,10), dpi=300)
ax = plt.subplot()

ncols = 8
nrows = df_aggregates.shape[0]

ax.set_xlim(0, ncols + 1)
ax.set_ylim(0, nrows + 1)

positions = [0.25, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5]
columns = ['year_completed', 'count', 'sum_length', 'avg_length', 'avg_duration', 'length_per_month', 'length_per_week', 'length_per_day']

for i in range (nrows):
    for j, column in enumerate(columns):
        if j == 0:
            ha = 'left'
        else:
            ha = 'center'
        if column == 'count':
            text_label = f'{df_aggregates[column].iloc[i]}'
            weight = 'bold'
        else:
            text_label = f'{df_aggregates[column].iloc[i]}'
        ax.annotate(
            xy=(positions[j], i + .5),
            text=text_label,
            ha=ha,
            va='center',
        )

column_names = ['Year', 'Books', 'Total Pages', 'Avg Length', 'Avg Days to Complete', 'Pages per Month', 'Pages per Week', 'Pages per Day']
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

ax.set_axis_off()
plt.savefig(
    '/Users/kserickson/Documents/zsr/figures/agg_books_by_year.png',
    dpi=300,
    transparent=True,
    bbox_inches='tight'
)

# Create a table of the books I read in df_2022
fig = plt.figure(figsize=(40,20), dpi=300)
ax = plt.subplot()

ncols = 7
nrows = df_2022.shape[0]

ax.set_xlim(0, ncols + 1)
ax.set_ylim(0, nrows + 1)

positions = [0.25, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5]
columns = ['title', 'creators', 'library', 'began', 'completed', 'duration', 'length']

for i in range (nrows):
    for j, column in enumerate(columns):
        if j == 0:
            ha = 'left'
        else:
            ha = 'center'
        if column == 'duration':
            text_label = f'{df_2022[column].iloc[i]}'
            weight = 'bold'
        else:
            text_label = f'{df_2022[column].iloc[i]}'
        ax.annotate(
            xy=(positions[j], i + .5),
            text=text_label,
            ha=ha,
            va='center',
        )

column_names = ['Title', 'Authors', 'Library', 'Began', 'Completed', 'Days', 'Pages']
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

ax.set_axis_off()
plt.savefig(
    '/Users/kserickson/Documents/zsr/figures/2022books.png',
    dpi=300,
    transparent=True,
    bbox_inches='tight'
)
