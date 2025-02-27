import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score, median_absolute_error
import matplotlib.pyplot as plt
import seaborn as sns
import re
import joblib
from matplotlib.backends.backend_pdf import PdfPages

# Function to read configuration from a file
def read_config(config_file):
    config = {}
    with open(config_file, 'r') as f:
        for line in f:
            # Skip comments and empty lines
            line = line.strip()
            if line.startswith("#") or not line:
                continue
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()
    return config

# Function to process the input CSV files and extract the features and labels
def process_files(input_dir, columns_to_extract, contam_pattern, window_size, step_size):
    X, y, block_ids = [], [], []
    block_count = 0

    input_files = [f for f in os.listdir(input_dir) if f.endswith('.csv')]

    for file_name in input_files:
        input_file_path = os.path.join(input_dir, file_name)

        # Extract contamination level from the filename
        match = contam_pattern.search(file_name)
        if match:
            contamination_level = int(match.group(1))
        else:
            print(f"Skipping file due to invalid name format: {file_name}")
            continue

        # Load the CSV file into a DataFrame
        try:
            df = pd.read_csv(input_file_path)
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

        # Create smaller blocks using the sliding window approach
        for start in range(0, len(df), step_size):
            end = start + window_size
            block = df.iloc[start:end]

            # Extract features (mean and median)
            mean_GQ = np.mean(block['GQ'])
            mean_DP = np.mean(block['DP'])
            mean_AF = np.mean(block['AF'])
            mean_VAF = np.mean(block['VAF'])
            median_GQ = np.median(block['GQ'])
            median_DP = np.median(block['DP'])
            median_AF = np.median(block['AF'])
            median_VAF = np.median(block['VAF'])

            # Add aggregated features to feature matrix
            X.append([mean_GQ, mean_DP, mean_AF, mean_VAF, median_GQ, median_DP, median_AF, median_VAF])
            y.append(contamination_level)
            block_ids.append(block_count)
            block_count += 1

    return np.array(X), np.array(y), np.array(block_ids)

# Function for standardizing the data
def preprocess_data(X_train, X_test):
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)
    return scaler, X_train, X_test

# Function for hyperparameter tuning and training the model
def train_model(X_train, y_train):
    param_grid = {
        'n_estimators': [100, 200, 300],
        'max_depth': [None, 10, 20, 30],
        'min_samples_split': [2, 5, 10],
        'min_samples_leaf': [1, 2, 4],
        'max_features': [1.0, 'sqrt', 'log2'], 
        'bootstrap': [True, False]
    }

    grid_search = GridSearchCV(estimator=RandomForestRegressor(random_state=42),
                               param_grid=param_grid,
                               cv=10,
                               scoring='r2',
                               verbose=2,
                               n_jobs=-1)
    grid_search.fit(X_train, y_train)
    return grid_search.best_estimator_

# Function to evaluate the model and save results
def evaluate_model(model, X_train, y_train, X_test, y_test, output_dir):
    y_pred_train = model.predict(X_train)
    y_pred_test = model.predict(X_test)

    mse_test = mean_squared_error(y_test, y_pred_test)
    mae_test = mean_absolute_error(y_test, y_pred_test)
    r2_test = r2_score(y_test, y_pred_test)
    medae_test = median_absolute_error(y_test, y_pred_test)

    mse_train = mean_squared_error(y_train, y_pred_train)
    mae_train = mean_absolute_error(y_train, y_pred_train)
    r2_train = r2_score(y_train, y_pred_train)
    medae_train = median_absolute_error(y_train, y_pred_train)

    evaluation_results = pd.DataFrame({
        "Metric": ["Mean Squared Error (MSE)", "Mean Absolute Error (MAE)", 
                   "R² Score", "Median Absolute Error (MedAE)"],
        "Training Set Performance": [f"{mse_train:.4f}", f"{mae_train:.4f}", f"{r2_train:.4f}", f"{medae_train:.4f}"],           
        "Test Set Performance": [f"{mse_test:.4f}", f"{mae_test:.4f}", f"{r2_test:.4f}", f"{medae_test:.4f}"]
    })

    # Save the evaluation results as a PDF
    plt.figure(figsize=(8, 4))
    plt.axis('tight')
    plt.axis('off')
    table = plt.table(cellText=evaluation_results.values, 
                      colLabels=evaluation_results.columns,
                      loc='center', 
                      cellLoc='center', 
                      colColours=["#D3D3D3"]*len(evaluation_results.columns))  
    table.auto_set_font_size(False)
    table.set_fontsize(12)
    table.scale(1.2, 1.2)
    for (i, j), cell in table.get_celld().items():
        if i == 0:
            cell.set_fontsize(10)
            cell.set_text_props(weight='bold')
            cell.set_facecolor('#B0C4DE')
        else:
            cell.set_fontsize(10)
            cell.set_text_props(weight='normal')
            if i % 2 == 0:
                cell.set_facecolor('#F5F5F5')
            else:
                cell.set_facecolor('white')

    # Save the table to PDF
    output_pdf_path = os.path.join(output_dir, "train_test_evaluation_results.pdf")
    with PdfPages(output_pdf_path) as pdf:
        pdf.savefig(bbox_inches="tight")
        plt.close()

    print(f"Training and test set evaluation table saved as {output_pdf_path}")
    return y_pred_test

# Function to save the model and scaler
def save_model(model, scaler, output_dir):
    model_filename = os.path.join(output_dir, "Random_Forest_Contamination_Model.joblib")
    joblib.dump(model, model_filename)
    print(f"Model saved as {model_filename}")

    scaler_path = os.path.join(output_dir, "scaler.joblib")
    joblib.dump(scaler, scaler_path)
    print(f"Scaler saved as {scaler_path}")

def plot_predictions_vs_true(y_test, y_pred_test, output_dir):
    """
    Creates a plot for Predicted vs True Contamination Levels.
    """
    plt.figure(figsize=(8, 6))
    plt.scatter(y_test, y_pred_test, alpha=0.7, color='blue')
    plt.plot([min(y_test), max(y_test)], [min(y_test), max(y_test)], color='red', linestyle='--')
    plt.title("Predicted vs True Contamination Levels")
    plt.xlabel("True Contamination Level")
    plt.ylabel("Predicted Contamination Level")
    plt.tight_layout()

    predicted_vs_actual_path = os.path.join(output_dir, "predicted_vs_True.png")
    plt.savefig(predicted_vs_actual_path)
    plt.close()

    print(f"Predicted vs True contamination plot saved as {predicted_vs_actual_path}")

def plot_predicted_contamination_levels(y_test, y_pred_test, output_dir):

    unique_contamination_levels = np.unique(y_test)
    plots_per_row = 3
    total_plots = len(unique_contamination_levels)
    num_rows = (total_plots // plots_per_row) + (1 if total_plots % plots_per_row != 0 else 0)
    fig, axes = plt.subplots(num_rows, plots_per_row, figsize=(plots_per_row * 5, num_rows * 5))

    axes = axes.flatten()

    # Loop through each contamination level and plot on its respective axis
    for i, contam_level in enumerate(unique_contamination_levels):
      
        indices = np.where(y_test == contam_level)
        predictions_for_level = y_pred_test[indices]
        mean_prediction_for_level = np.mean(predictions_for_level)
        axes[i].scatter(np.arange(len(predictions_for_level)), predictions_for_level, alpha=0.7, color='blue', label="Predicted Contamination Levels")
        axes[i].axhline(y=mean_prediction_for_level, color='red', linestyle='--', label=f"Mean Prediction: {mean_prediction_for_level:.3f}")
        axes[i].set_title(f"Predicted contamination level for True Contam {contam_level}")
        axes[i].set_xlabel("Blocks (Samples)")
        axes[i].set_ylabel("Predicted Contamination Level")
        axes[i].legend()

    # Remove any empty subplots if the last row is incomplete
    for j in range(total_plots, len(axes)):
        fig.delaxes(axes[j])

    
    plt.tight_layout()

    # Save the combined image with all the subplots
    output_plot_path = os.path.join(output_dir, "predictions_by_contamination_level.png")
    plt.savefig(output_plot_path)

   
    plt.close()

    print(f"Predicted contamination levels plot saved as {output_plot_path}")

 
def plot_predicted_contamination_distribution(y_test, y_pred_test, output_dir):
  
    unique_contamination_levels = np.unique(y_test)
    plots_per_row = 3
    total_plots = len(unique_contamination_levels)
    num_rows = (total_plots // plots_per_row) + (1 if total_plots % plots_per_row != 0 else 0)
    fig, axes = plt.subplots(num_rows, plots_per_row, figsize=(plots_per_row * 5, num_rows * 5))

    axes = axes.flatten()

    # Loop through each contamination level and plot on its respective axis
    for i, contam_level in enumerate(unique_contamination_levels):
    
        indices = np.where(y_test == contam_level)
        y_pred_for_level = y_pred_test[indices]

        axes[i].hist(y_pred_for_level, bins=20, edgecolor='black', alpha=0.7)
        axes[i].set_title(f"Predicted contamination level for True Contam {contam_level}")
        axes[i].set_xlabel('Predicted Contamination Level')
        axes[i].set_ylabel('Frequency')

    # Remove any empty subplots if the last row is incomplete
    for j in range(total_plots, len(axes)):
        fig.delaxes(axes[j])

    plt.tight_layout()

    # Save the feature importance plot
    predictions_distribution_path = os.path.join(output_dir, "predictions_distribution.png")
    plt.savefig(predictions_distribution_path)
    plt.close()

    print(f"Predictions distribution plot saved as {predictions_distribution_path}")


# Function to calculate bias and standard deviation for each contamination level
def bias_and_std_analysis(y_test, y_pred_test, output_dir):
    contamination_levels = np.unique(y_test)
    bias_std_results = []

    for level in contamination_levels:
        errors = y_pred_test[y_test == level] - level
        bias = np.mean(errors)
        std_dev = np.std(errors)
        bias_rounded = round(bias, 3)
        std_dev_rounded = round(std_dev, 3)
        bias_std_results.append([level, bias_rounded, std_dev_rounded])

    bias_std_df = pd.DataFrame(bias_std_results, columns=['Contamination Level', 'Bias', 'Standard Deviation'])
    
    # Save Bias and Standard Deviation Table as PDF
    plt.figure(figsize=(8, 4))
    plt.axis('tight')
    plt.axis('off')
    table = plt.table(cellText=bias_std_df.values, 
                      colLabels=bias_std_df.columns,
                      loc='center', 
                      cellLoc='center', 
                      colColours=["#D3D3D3"]*len(bias_std_df.columns))  
    table.auto_set_font_size(False)
    table.set_fontsize(12)
    table.scale(1.2, 1.2)
    for (i, j), cell in table.get_celld().items():
        if i == 0:
            cell.set_fontsize(10)
            cell.set_text_props(weight='bold')
            cell.set_facecolor('#B0C4DE')
        else:
            cell.set_fontsize(10)
            cell.set_text_props(weight='normal')
            if i % 2 == 0:
                cell.set_facecolor('#F5F5F5')
            else:
                cell.set_facecolor('white')

    # Save the table to PDF
    output_pdf_path = os.path.join(output_dir, "contamination_level_bias_std_table.pdf")
    with PdfPages(output_pdf_path) as pdf:
        pdf.savefig(bbox_inches="tight")
        plt.close()
    
    print(f"Bias and standard deviation table saved as {output_pdf_path}")

# Function to save true vs predicted contamination levels
def save_true_vs_predicted(y_test, y_pred_test, output_dir):
    output_txt_path = os.path.join(output_dir, "true_vs_predicted_contamination.txt")
    with open(output_txt_path, 'w') as f:
        for true, pred in zip(y_test, y_pred_test):
            f.write(f"{true}\t{pred}\n")
    print(f"True vs Predicted contamination levels saved as {output_txt_path}")

# Main function to orchestrate the pipeline
def main():
    config_file = 'config.txt'
    config = read_config(config_file)

    input_dir = config.get('input_dir')
    output_dir = config.get('output_dir')
    os.makedirs(output_dir, exist_ok=True)

    contam_pattern = re.compile(r'_contam(\d+)[_.]')
    columns_to_extract = ['GQ', 'DP', 'AF', 'VAF']

    window_size = 120000
    step_size = 60000

    # Process the files
    X, y, block_ids = process_files(input_dir, columns_to_extract, contam_pattern, window_size, step_size)

    # Train-test split
    X_train, X_test, y_train, y_test, block_ids_train, block_ids_test = train_test_split(
        X, y, block_ids, test_size=0.2, random_state=42
    )

    # Print the number of samples in the training and test sets
    print(f"Number of samples in the training set: {len(X_train)}")
    print(f"Number of samples in the test set: {len(X_test)}")

    # Preprocess the data
    scaler, X_train, X_test = preprocess_data(X_train, X_test)

    # Train the model
    model = train_model(X_train, y_train)

    # Evaluate the model
    y_pred_test = evaluate_model(model, X_train, y_train, X_test, y_test, output_dir)

    # Save the model and scaler
    save_model(model, scaler, output_dir)
    
    # Call the function to plot predicted contamination levels
    plot_predicted_contamination_levels(y_test, y_pred_test, output_dir)
    
    # Call the function to plot predicted contamination distribution
    plot_predicted_contamination_distribution(y_test, y_pred_test, output_dir)
    
    plot_predictions_vs_true(y_test, y_pred_test, output_dir)
    
    # Bias and Standard Deviation Analysis
    bias_and_std_analysis(y_test, y_pred_test, output_dir)

    # Save true vs predicted contamination levels
    save_true_vs_predicted(y_test, y_pred_test, output_dir)

if __name__ == "__main__":
    main()

