import os
import pandas as pd
import numpy as np
import joblib
from sklearn.preprocessing import StandardScaler


# Function to read the configuration file
def read_config(config_file):
    config = {}
    with open(config_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith("#") or not line:
                continue
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()
    return config

# Load the configuration from config_2.txt
config_file = 'config_2.txt'  
config = read_config(config_file)

# Directories and paths from the configuration file
input_dir = config.get('input_dir')
output_dir = config.get('output_dir')
model_filename = config.get('model_filename')
scaler_filename = config.get('scaler_filename')

# Ensure the output directory exists
os.makedirs(output_dir, exist_ok=True)

# Load the saved model and scaler
try:
    model = joblib.load(model_filename)
    scaler = joblib.load(scaler_filename)
    print(f"Model and scaler loaded successfully from {model_filename} and {scaler_filename}")
except Exception as e:
    print(f"Error loading model or scaler: {e}")
    exit()

# Input files to test
input_files = [f for f in os.listdir(input_dir) if f.endswith('.csv')]

# Columns to extract from the input files
columns_to_extract = ['GQ', 'DP', 'AF', 'VAF']

# Prepare the data for testing
X = []         # Features for the samples
file_names = []  

# Process each input file
for file_name in input_files:
    input_file_path = os.path.join(input_dir, file_name)
    
    # Load the CSV file into a DataFrame
    try:
        df = pd.read_csv(input_file_path, dtype={'CHROM': str}, low_memory=False)
    except Exception as e:
        print(f"Error reading {file_name}: {e}")
        continue
    
    # Check if the required columns are in the file
    missing_columns = [col for col in columns_to_extract if col not in df.columns]
    if missing_columns:
        print(f"Missing columns in {file_name}: {missing_columns}")
        continue

    # Extract only the specified columns
    df = df[columns_to_extract]
    
    # Report the original number of rows
    original_row_count = df.shape[0]
    
    # Remove rows with any NA values in the required columns
    df = df.dropna()
    
    # Report the number of removed rows (variants)
    removed_rows = original_row_count - df.shape[0]
    if removed_rows > 0:
        print(f"In {file_name}, removed {removed_rows} variant(s) due to missing values.")
    
    # If the dataframe becomes empty after dropping rows, skip this file
    if df.empty:
        print(f"Skipping {file_name} because all rows have NA values in the required columns.")
        continue
    
    # Extract features (mean and median)
    mean_GQ = np.mean(df['GQ'])
    mean_DP = np.mean(df['DP'])
    mean_AF = np.mean(df['AF'])
    mean_VAF = np.mean(df['VAF'])
    median_GQ = np.median(df['GQ'])
    median_DP = np.median(df['DP'])
    median_AF = np.median(df['AF'])
    median_VAF = np.median(df['VAF'])
    
    # Add aggregated features to the feature matrix for data
    X.append([mean_GQ, mean_DP, mean_AF, mean_VAF, median_GQ, median_DP, median_AF, median_VAF])
    file_names.append(file_name)

# Convert the lists into a numpy array
X = np.array(X)

# Preprocess the data using the scaler (standardization)
X_scaled = scaler.transform(X)

# Make predictions on the data using the trained model
y_pred = model.predict(X_scaled)

# Create a DataFrame for Predicted Contamination Levels
results_df = pd.DataFrame({
    "FileName": file_names,
    "PredictedContamination": y_pred
})

# Define the path for the output text file
output_txt_path = os.path.join(output_dir, "predicted_contamination_levels.txt")

# Save the DataFrame to a tab-delimited text file
results_df.to_csv(output_txt_path, sep='\t', index=False)
print(f"Predicted contamination levels saved as {output_txt_path}")

# Predicted Contamination Levels Summary
print("\nPredicted Contamination Levels:")
print(results_df)

