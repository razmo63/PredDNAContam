#!/bin/bash

#SBATCH --account=development
#SBATCH --ntasks=10
#SBATCH --time=01:00:00  
#SBATCH --mem=50G
#SBATCH --qos=normal
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your_email@example.com
#SBATCH --job-name=in_silico_sample_processing
#SBATCH --output=in_silico_sample_processing_%j.log
#SBATCH --error=in_silico_sample_processing_%j.err

# Load conda environment
source /path/to/bin/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Define the output directory for all contamination levels
CURRENT_DATE=$(date +'%Y-%m-%d')
OUTPUT_DIR="./contaminated_samples_chr2_${CURRENT_DATE}"
mkdir -p "$OUTPUT_DIR"  # Create the output directory

# Define the reference file path
REFERENCE="/path/to/references/references_12.0/grch37_homo_sapiens_-d5-.fasta"

# Submit a job for each contamination level
# Read contamination levels from contaminationlevels_1.txt
# Each line in this file contains a numerical contamination level (e.g., 3, 5, 10, 15, etc.)
#In order to limit the number of jobs, the contamination levels were divided into two files 

while read -r CONTAM; do
  # Submit a SLURM job for each contamination level
  sbatch generate_samples.sh "$CONTAM" "$OUTPUT_DIR" "$REFERENCE"
done < contaminationlevels_1.txt  # Reads contamination levels from the file