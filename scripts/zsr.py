import pandas as pd
import numpy as np
import datetime
import json
import os
import logging

# CONFIGURATION
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CONFIG_FILE = os.path.join(ROOT_DIR, 'config.json')

# Load configuration
with open(CONFIG_FILE, 'r') as config_file:
    config = json.load(config_file)

# Extract paths from the configuration
DATA_DIR = os.path.join(ROOT_DIR, 'data')
MISSING_DATA_FILE = os.path.join(DATA_DIR, 'missing_data.json')
LOG_FILE_PATH = config.get('log_file_path')
OUTPUT_PATH = config.get('output_paths', '')

#Configure logging
logging.basicConfig(
    filename=LOG_FILE_PATH,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# FUNCTIONS
def load_missing_data(filename=MISSING_DATA_FILE):
    try:
        with open(filename, 'r') as file:
            missing_data = json.load(file)
        return missing_data
    except FileNotFoundError as e:
        logging.error(f"Missing data file '{filename}' not found: {e}")
        return None

def clean_data(df_library, missing_data):
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

    # Strip whitespace
    df_library['status'] = df_library['status'].str.strip()
    df_library['began'] = df_library['began'].str.strip()
    df_library['completed'] = df_library['completed'].str.strip()

    # Cast columns as correct data types while filling in any missing values
    df_library['length'] = df_library['length'].fillna(0).astype(int)
    df_library['publish_date'] = pd.to_datetime(df_library['publish_date'], format='%Y-%m-%d', errors="coerce")
    df_library['began'] = pd.to_datetime(df_library['began'], format='%Y-%m-%d', errors='raise')
    df_library['completed'] = pd.to_datetime(df_library['completed'], format='%Y-%m-%d', errors='raise')
    df_library['added'] = pd.to_datetime(df_library['added'], format='%Y-%m-%d', errors='coerce')
    df_library['ean_isbn13'] = df_library['ean_isbn13'].astype(str).str.replace(r'\.0$', '', regex=True)

    # Fill in missing data using the missing_data dictionary
    if missing_data is not None:
        # Fill in missing lengths
        if 'missing_lengths' in missing_data:
            for title, length in missing_data['missing_lengths'].items():
                df_library.loc[df_library['title'] == title, 'length'] = length

        # Fill in missing ISBN13 values
        if 'missing_isbn13' in missing_data:
            for title, isbn13 in missing_data['missing_isbn13'].items():
                df_library.loc[df_library['title'] == title, 'ean_isbn13'] = isbn13

        # Fill in missing publishers
        if 'missing_publishers' in missing_data:
            for title, publisher in missing_data['missing_publishers'].items():
                df_library.loc[df_library['title'] == title, 'publisher'] = publisher

        # Fill in missing publication dates
        if 'missing_publish_dates' in missing_data:
            for title, publish_date in missing_data['missing_publish_dates'].items():
                df_library.loc[df_library['title'] == title, 'publish_date'] = publish_date

    # Check for missing page lengths
    df_missing_pgs = df_library[(df_library['length'] == 0)]
    if not df_missing_pgs.empty:
        logging.warning("Books with missing page lengths:")
        logging.warning(df_missing_pgs.loc[:, ['title', 'length']])

    # Check for missing authors
    df_missing_authors = df_library[df_library['creators'].isna()]
    if not df_missing_authors.empty:
        logging.warning("Books with missing authors:")
        logging.warning(df_missing_authors.loc[:, ['title', 'creators']])

    # Check for missing publishers
    df_missing_publishers = df_library[df_library['publisher'].isna()]
    if not df_missing_publishers.empty:
        logging.warning("Books with missing publishers:")
        logging.warning(df_missing_publishers.loc[:, ['title', 'publisher']])

    # Check for missing publication dates
    df_missing_dates = df_library[df_library['publish_date'].isna()]
    if not df_missing_dates.empty:
        logging.warning("Books with missing publication dates:")
        logging.warning(df_missing_dates.loc[:, ['title', 'publish_date']])

    # Check for missing ISBN 13
    df_missing_isbn13s = df_library[df_library['ean_isbn13'] == "nan"]
    if not df_missing_isbn13s.empty:
        logging.warning("Books with missing ISBN 13s:")
        logging.warning(df_missing_isbn13s.loc[:, ['title', 'ean_isbn13']])

    # Return the cleaned DataFrame
    return df_library

def add_derived_columns(df_library, df_daily):
    # Type conversions for df_daily before merging
    df_daily['ean_isbn13'] = df_daily['ean_isbn13'].astype(str)
    df_daily['title'] = df_daily['title'].astype(str)
    df_daily['date'] = pd.to_datetime(df_daily['date'], format='%Y-%m-%d', errors='coerce')

    # Compute the number of days between the began and completed dates and add it to a new column: duration
    df_library['duration'] = (df_library['completed'] - df_library['began']).apply(lambda x: x.days + 1)
    df_library['duration'] = df_library['duration'].round().fillna(0).astype(int)

    # Extract the year from the completed date and add it to a new column: year_completed
    df_library['year_completed'] = df_library['completed'].apply(lambda x: x.year).astype(str)
    df_library['year_completed'] = df_library['year_completed'].str.replace(r'\.0$', '', regex=True)

    # Create new DataFrame by merging df_daily and df_library, filter to books in progress only
    df_dailies = pd.merge(df_daily, df_library, how='left', on=['ean_isbn13', 'title'])
    df_dailies = df_dailies[df_dailies['status'].isin(['In progress', 'Completed'])]

    drop_columns = ['creators', 'publisher', 'publish_date', 'status', 'began', 'completed', 'added', 'library', 'duration', 'year_completed']
    df_dailies = df_dailies.drop(columns=drop_columns)

    # Add percent_complete column
    df_dailies['percent_complete'] = df_dailies['end_page'] / df_dailies['length'] * 100
    df_dailies['percent_complete'] = df_dailies['percent_complete'].round(2)

    # Add daily_pages column
    df_dailies['daily_pages'] = df_dailies['end_page'] - df_dailies['start_page']

    # Add rows for days when no pages were read
    min_date = df_dailies['date'].min()
    max_date = df_dailies['date'].max()
    all_dates = pd.date_range(start=min_date, end=max_date, freq='D')
    df_dates = pd.DataFrame({'date': all_dates})
    df_dailies = pd.merge(df_dates, df_dailies, on='date', how='left')
    numeric_cols = df_dailies.select_dtypes(include=['int64', 'float64']).columns
    df_dailies[numeric_cols] = df_dailies[numeric_cols].fillna(0)

    return df_dailies

def add_aggregate_columns(df_library):
    # Create a dataframe that aggregates book and page totals and averages by year completed
    df_completed = df_library[(df_library['status'] == "Completed")]

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

    return df_aggregates

def save_dataframes(df_library, df_aggregates, df_dailies, config):
    # Access 'output_dir' from the global configuration
    data_output_path = OUTPUT_PATH.get('data', '')

    # Define file paths for CSV files
    library_csv_path = os.path.join(data_output_path, 'library.csv')
    aggregates_csv_path = os.path.join(data_output_path, 'aggregates.csv')
    dailies_csv_path = os.path.join(data_output_path, 'dailies.csv')

    try:
        # Save DataFrames to CSV files
        df_library.to_csv(library_csv_path, index=False)
        df_aggregates.to_csv(aggregates_csv_path, index=False)
        df_dailies.to_csv(dailies_csv_path, index=False)
    except Exception as e:
        logging.error(f"Error saving DataFrames to CSV files: {e}")

def main():
    # Load missing data
    missing_data = load_missing_data(MISSING_DATA_FILE)

    # Extract data file paths
    data_paths = config.get('input_paths', {})

    # Create an empty list to store DataFrames
    dfs = []

    # Iterate through the data_paths dictionary to create DataFrames
    for library, file_path in data_paths.items():
        if library not in ["daily", "dailies", "library"]:
            # Read the CSV file and add the 'library' column
            df = pd.read_csv(file_path)
            df['library'] = library
            dfs.append(df)

    # Concatenate individual library DataFrames into a single DataFrame
    df_library = pd.concat(dfs, ignore_index=True)

    # Create a DataFrame for the daily library
    df_daily = pd.read_csv(data_paths.get('daily', ''))

    # Clean and transform data
    clean_data(df_library, missing_data)

    # Add derived columns
    df_dailies = add_derived_columns(df_library, df_daily)

    # Add aggregate columns
    df_aggregates = add_aggregate_columns(df_library)

    # Save DataFrames to CSV files
    save_dataframes(df_library, df_aggregates, df_dailies, config)

if __name__ == "__main__":
    main()
