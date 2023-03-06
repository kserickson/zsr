import pandas as pd
import numpy as np
import datetime

# DATA IMPORT

# Read libib data exports into data frames
df_zsreglau = pd.read_csv('/Users/kserickson/Documents/zsr/data/library_zsreglau.csv')
df_kindle = pd.read_csv('/Users/kserickson/Documents/zsr/data/library_kindle.csv')
df_borrowed = pd.read_csv('/Users/kserickson/Documents/zsr/data/library_borrowed.csv')
df_emeritus = pd.read_csv('/Users/kserickson/Documents/zsr/data/library_emeritus.csv')
df_daily = pd.read_csv('/Users/kserickson/Documents/zsr/data/daily_log.csv')

# Add columns to dataframe indicating which library they came from
df_zsreglau['library'] = 'zsreglau'
df_kindle['library'] = 'kindle'
df_borrowed['library'] = 'borrowed'
df_emeritus['library'] = 'emeritus'

# Concatenate all four library dataframes into a single dataframe
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
    'upc_isbn10'
    ], inplace=True)

# Cast columns as correct data types while filling in any missing values
df_library['length'] = df_library['length'].fillna(0).astype(int)
df_library['publish_date'] = pd.to_datetime(df_library['publish_date'], format='%Y-%m-%d', errors="coerce")
df_library['began'] = pd.to_datetime(df_library['began'], format='%Y-%m-%d', errors='coerce')
df_library['completed'] = pd.to_datetime(df_library['completed'], format='%Y-%m-%d', errors='coerce')
df_library['added'] = pd.to_datetime(df_library['added'], format='%Y-%m-%d', errors='coerce')
df_library['ean_isbn13'] = df_library['ean_isbn13'].astype(str).str.replace(r'\.0$', '')

df_daily['ean_isbn13'] = df_daily['ean_isbn13'].astype(str).str.replace(r'\.0$', '')
df_daily['date'] = pd.to_datetime(df_daily['date'], format='%m/%d/%Y', errors="coerce")

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
df_library.loc[df_library['title'] == "Deschooling Society (Open Forum)", 'length'] = 116
df_library.loc[df_library['title'] == "The Sovereignty of Good (Routledge Great Minds)", 'length'] = 105

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

# Join in length column from df_library for books in progress

df_dailies = pd.merge(df_daily, df_library, how = 'left', on=['ean_isbn13', 'title'])
df_dailies = df_dailies[df_dailies['status'].isin(['In progress', 'Completed'])]

drop_columns = ['creators', 'publisher', 'publish_date', 'status', 'began', 'completed', 'added', 'library', 'duration','year_completed']
df_dailies = df_dailies.drop(columns=drop_columns)

# Add percent_complete column

df_dailies['percent_complete'] = df_dailies['end_page'] / df_dailies['length'] * 100
df_dailies['percent_complete'] = df_dailies['percent_complete'].round(2)

# Add daily_pages column

df_dailies['daily_pages'] = df_dailies['end_page'] - df_dailies['start_page']

# Add rows for days when I didn't read any pages

min_date = df_dailies['date'].min()
max_date = df_dailies['date'].max()

all_dates = pd.date_range(start=min_date, end=max_date, freq='D')

df_dates = pd.DataFrame({'date': all_dates})

df_dailies = pd.merge(df_dates, df_dailies, on='date', how='left')
numeric_cols = df_dailies.select_dtypes(include=['int64', 'float64']).columns
df_dailies[numeric_cols] = df_dailies[numeric_cols].fillna(0)

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

# Write df_library to disk
df_library.to_csv('/Users/kserickson/Documents/zsr/data/library.csv', index=False)
df_aggregates.to_csv('/Users/kserickson/Documents/zsr/data/aggregates.csv', index=False)
df_2022.to_csv('/Users/kserickson/Documents/zsr/data/2022.csv')
df_dailies.to_csv('/Users/kserickson/Documents/zsr/data/dailies.csv')
