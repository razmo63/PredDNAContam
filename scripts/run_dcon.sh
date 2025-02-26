#!/bin/bash
#SBATCH --account=development
#SBATCH --ntasks=36
#SBATCH --time=90:00:00
#SBATCH --mem=180G
#SBATCH --qos=normal
#SBATCH --job-name=dcon_contamination
#SBATCH --mail-type=ALL             
#SBATCH --mail-user=your_email@example.com
#SBATCH --output=dcon_%j.out         
#SBATCH --error=dcon_%j.err         


#set -e
#set -o pipefail
#readonly PROGNAME=$(basename "$0")

#echo "Running on: $(hostname)"

# Activate the conda environment
source  path/to/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda/envs/D_python2.7_RM

# Define the absolute path to Dcon.py
DCON_PATH="/path/to/dcon-0.1.8/bin/Dcon.py"

# Define your project directory and input files
DATA_DIR="/path/to/Datadata_directory"

# List of BAM files to process
BAM_FILES=(
    "$DATA_DIR/alignment/sample1_sorted_md.bam"
    "$DATA_DIR/alignment/sample2_sorted_md.bam"
    "$DATA_DIR/alignment/sample3_sorted_md.bam"
)

# Define the VCF file
VCF_FILE="$DATA_DIR/path/to/sample_snv.vcf.gz"

# Set output prefix for the results
OUTPUT_PREFIX="/path/to/output_directory/dcon_output"

# Set Python path to include directories with DconModule
export PYTHONPATH="/path/to/dcon/lib:/path/to/dcon/build/lib:$PYTHONPATH"

# Check if Dcon.py exists at the specified path
if [ ! -f "$DCON_PATH" ]; then
    echo "Error: Dcon.py does not exist at $DCON_PATH"
    exit 1
fi

# Check if the VCF file exists
if [ ! -f "$VCF_FILE" ]; then
    echo "Warning: VCF file does not exist at $VCF_FILE. Please add the VCF file and re-run the script."
    exit 1
fi

# Check if the output directory exists, and create it if it does not
if [ ! -d "$OUTPUT_PREFIX" ]; then
    echo "Output directory does not exist. Creating it now."
    mkdir -p "$OUTPUT_PREFIX" || {
        echo "Error: Failed to create output directory $OUTPUT_PREFIX"
        exit 1
    }
fi

# Loop over each BAM file
for BAM_FILE in "${BAM_FILES[@]}"; do
    # Check if the BAM file exists
    if [ ! -f "$BAM_FILE" ]; then
        echo "Warning: BAM file does not exist at $BAM_FILE. Please add the BAM file and re-run the script."
        continue
    fi

    # Define the output file for this BAM
    OUTPUT_FILE="$OUTPUT_PREFIX/$(basename "$BAM_FILE" .bam)_dcon_output"

    # Run Dcon
    python2.7 "$DCON_PATH" -b "$BAM_FILE" -v "$VCF_FILE" -o "$OUTPUT_FILE" -n "$SLURM_NTASKS" -p 0.6 -z 3.0 || {
        echo "Error: Dcon.py failed to execute for $BAM_FILE."
        exit 1
    }
done
