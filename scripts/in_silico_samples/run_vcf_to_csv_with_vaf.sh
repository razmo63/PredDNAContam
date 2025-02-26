#!/bin/bash

#SBATCH --account=development
#SBATCH --ntasks=40               
#SBATCH --time=5:00:00         
#SBATCH --mem=180G                
#SBATCH --qos=normal
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your_email@example.com 
#SBATCH --job-name=vcf_to_csv_with_vaf
#SBATCH --output=vcf_to_csv_with_vaf_%j.log
#SBATCH --error=vcf_to_csv_with_vaf_%j.err

# Load the conda environment
source /path/to/bin/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Set directories
VCF_DIR="/path/to/generated_VCF_files_chr2"
OUTPUT_DIR="./extracted_VCF_files_chr2"

# Check if the output directory exists, if not, create it
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Output directory does not exist. Creating $OUTPUT_DIR..."
    mkdir -p "$OUTPUT_DIR"
fi

# Path to the Python script
SCRIPT_PATH="/path/to/python/script/extract_vcf_info.py"

# Get the list of all VCF files
VCF_FILES=("$VCF_DIR"/*.vcf)

# Define the batch size
BATCH_SIZE=40

# Total number of files
TOTAL_FILES=${#VCF_FILES[@]}
echo "Found $TOTAL_FILES VCF files to process."

# Process files in batches
for ((i=0; i<TOTAL_FILES; i+=BATCH_SIZE)); do
    echo "Processing batch starting from file index $i..."

    # Create a sub-batch of files
    BATCH=("${VCF_FILES[@]:i:BATCH_SIZE}")

    # Process each file in the current batch in the background
    for vcf_file in "${BATCH[@]}"; do
        (
            echo "Processing $vcf_file..."
            python "$SCRIPT_PATH" "$vcf_file" "$OUTPUT_DIR"
            if [ $? -eq 0 ]; then
                echo "Successfully processed $vcf_file."
            else
                echo "Error processing $vcf_file." >&2
            fi
        ) &
    done

    # Wait for all files in the batch to complete
    wait
done

echo "All $TOTAL_FILES files processed."