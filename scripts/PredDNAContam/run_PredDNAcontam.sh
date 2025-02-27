#!/bin/bash

#SBATCH --account=development
#SBATCH --ntasks=190                
#SBATCH --mem=450G
#SBATCH --time=02:00:00                   
#SBATCH --qos=normal
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your_email@example.com 
#SBATCH --job-name=PredDNAcontam
#SBATCH --output=run_PredDNAcontam_%j.out
#SBATCH --error=run_PredDNAcontam_%j.err

# Load the conda environment
source /path/to/bin/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Define the path to the Python script
python_path="/path/to/python/script/PredDNAcontam.py"

# Run the Python script with the configuration file
python $python_path 