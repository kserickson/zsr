import pandas as pd
import matplotlib.pyplot as plt
import datetime

from PIL import Image
import urllib
import os

# DATA IMPORT

# Read libib data exports into data frames
df_zsreglau = pd.read_csv('/Users/kserickson/Downloads/library_zsreglau.csv')
df_kindle = pd.read_csv('/Users/kserickson/Downloads/library_kindle.csv')
df_borrowed = pd.read_csv('/Users/kserickson/Downloads/library_borrowed.csv')
df_emeritus = pd.read_csv('/Users/kserickson/Downloads/library_emeritus.csv')

# Add columns to dataframe indicating which library they came from
df_zsreglau['library'] = 'zsreglau'
df_kindle['library'] = 'kindle'
df_borrowed['library'] = 'borrowed'
df_emeritus['library'] = 'emeritus'

# Concatenate all four dataframes into a single dataframe
df_library = pd.concat([df_zsreglau, df_kindle, df_borrowed, df_emeritus]).reset_index(drop=True)

# DATA CLEANUP

# Drop unneeded columns
df_library.drop(columns=[
    'item_type',
    'first_name',
    'last_name',
    'description',
    'group',
    'tags',
    'notes',
    'price',
    'number_of_discs',
    'number_of_players',
    'age_group',
    'ensemble',
    'aspect_ratio',
    'esrb',
    'rating',
    'review',
    'review_date',
    'copies',
    'upc_isbn10',
    'ean_isbn13'
    ], inplace=True)

# Cast columns as correct data types while filling in any missing values
df_library['length'] = df_library['length'].fillna(0).astype(int)
df_library['publish_date'] = pd.to_datetime(df_library['publish_date'], format='%Y-%m-%d', errors="coerce")
df_library['began'] = pd.to_datetime(df_library['began'], format='%Y-%m-%d', errors='coerce')
df_library['completed'] = pd.to_datetime(df_library['completed'], format='%Y-%m-%d', errors='coerce')
df_library['added'] = pd.to_datetime(df_library['added'], format='%Y-%m-%d', errors='coerce')

# Strip whitespace from 'status' values
df_library['status'] = df_library['status'].str.strip()

# Add page lengths for books with missing 'length' values
df_library.loc[df_library['title'] == "The Collected Works, Vol. 8", 'length'] = 1251
df_library.loc[df_library['title'] == "Upheavals of Thought: The Intelligence of Emotions", 'length'] = 751
df_library.loc[df_library['title'] == "Political Liberalism", 'length'] = 464
df_library.loc[df_library['title'] == "The Ethnic Origins of Nations", 'length'] = 312
df_library.loc[df_library['title'] == "Montesquieu And Rousseau: Forerunners Of Sociology", 'length'] = 155
df_library.loc[df_library['title'] == "Truth and Method. Second, Revised Edition.", 'length'] = 594
df_library.loc[df_library['title'] == "The Last Unicorn (Deluxe Edition)", 'length'] = 289
df_library.loc[df_library['title'] == "The Dream Machine", 'length'] = 527
df_library.loc[df_library['title'] == "The Revolt of the Public", 'length'] = 448
df_library.loc[df_library['title'] == "The Art of Doing Science and Engineering", 'length'] = 432
df_library.loc[df_library['title'] == "August", 'length'] = 304
df_library.loc[df_library['title'] == "American Poetry: The Nineteenth Century. Volumes I &amp; II. [2 volumes. Vol. 1: Philip Freneau to Walt Whitman. Vol. 2: Herman Melville to Stickney; American Indian Poetry; Folk Songs and Spirituals]", 'length'] = 1050
df_library.loc[df_library['title'] == "American Earth: Environmental Writing Since Thoreau", 'length'] = 1047
df_library.loc[df_library['title'] == "Harry Potter and the Order of the Phoenix", 'length'] = 896
df_library.loc[df_library['title'] == "In the Shadow of Tomorrow", 'length'] = 167
df_library.loc[df_library['title'] == "Pieces of the Action", 'length'] = 376
df_library.loc[df_library['title'] == "Kenogaia (a Gnostic Tale)", 'length'] = 432
df_library.loc[df_library['title'] == "The Org: How The Office Really Works", 'length'] = 320
df_library.loc[df_library['title'] == "Grand Hotel Abyss", 'length'] = 336
df_library.loc[df_library['title'] == "We Have Never Been Modern", 'length'] = 157
df_library.loc[df_library['title'] == "Snow", 'length'] = 320
df_library.loc[df_library['title'] == "Courage to Grow", 'length'] = 224
df_library.loc[df_library['title'] == "In Praise of Older Women The Amorous Recollections of Andras Vajda by Vizinczey, Stephen ( Author ) ON Mar-04-2010, Paperback", 'length'] = 181
df_library.loc[df_library['title'] == "The Collected Works of John Stuart Mill, Vol. 7", 'length'] = 1251
df_library.loc[df_library['title'] == "Game Theory: A Very Short Introduction (Very Short Introductions) By Ken Binmore", 'length'] = 184
df_library.loc[df_library['title'] == "Applied Mainline Economics", 'length'] = 167
df_library.loc[df_library['title'] == "Introduction to IT Privacy", 'length'] = 271
df_library.loc[df_library['title'] == "The Hobbit", 'length'] = 317

# Check for missing page lengths in any new books
df_missing = df_library[(df_library['length'] == 0)]
print("Here is a list of books with missing page lengths:")
print(df_missing.loc[:, ['title', 'length']])

# DERIVED COLUMNS

# Compute the number of days between the began and completed dates and add it to a new column: duration

df_library['duration'] = (df_library['completed'] - df_library['began']).apply(lambda x: x.days + 1)

df_library['duration'] = df_library['duration'].round().fillna(0).astype(int)

# Extract the year from the completed date and add it to a new column: year_completed
df_library['year_completed'] = df_library['completed'].apply(lambda x: x.year).astype(str)

df_library['year_completed'] = df_library['year_completed'].str.replace(r'\.0$', '')

# AGGREGATES
# Create a dataframe that aggregates book and page totals and averages by year completed

df_completed = df_library[(df_library['status'] == "Completed") & (df_library['year_completed'] != "nan")].sort_values(by='year_completed')

df_aggregates = df_completed.groupby('year_completed').agg(
    count=('year_completed', 'count'),
    sum_length=('length', 'sum'),
    avg_length=('length', 'mean'),
    avg_duration=('duration', 'mean'),
    length_per_month=('length', lambda x: x.sum() / 12),
    length_per_week=('length', lambda x: x.sum() / 52),
    length_per_day=('length', lambda x: x.sum() / 365)
).reset_index()

df_aggregates[['avg_length', 'avg_duration', 'length_per_month', 'length_per_week', 'length_per_day']] = df_aggregates[['avg_length', 'avg_duration', 'length_per_month', 'length_per_week', 'length_per_day']].apply(lambda x: x.round(2))

# Check the above aggregates are correct
# pd.options.display.max_rows = len(df_completed)
# print(df_completed.loc[:, ['title', 'length', 'year_completed']])

# Create a dataframe that includes only books I completed in 2022.
df_2022 = df_library[(df_library['status'] == "Completed") & (df_library['year_completed'] == "2022")].sort_values(by='completed', ascending=False).reset_index(drop=True)

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

# Write df_library to read_csv
# df_library.to_csv('/Users/kserickson/Downloads/library.csv', index=False)

# Display df_library
# print(df_2022)
