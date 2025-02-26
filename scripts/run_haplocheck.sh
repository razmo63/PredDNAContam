#!/bin/bash
#SBATCH --account=development
#SBATCH --ntasks=20
#SBATCH --time=20:00:00
#SBATCH --mem=100G
#SBATCH --qos=normal
#SBATCH --job-name=haplocheck_contamination
#SBATCH --mail-type=ALL
#SBATCH --output=haplocheck_%j.out      
#SBATCH --error=haplocheck_%j.err       
#SBATCH --mail-user=your_email@example.com

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Prevent errors in a pipeline from being masked
readonly PROGNAME=$(basename "$0")

#echo "Running on: $(hostname)"

# Load Conda environment
source /path/to/miniconda3/etc/profile.d/conda.sh
conda activate D_contamtool_RM

# Define input and output files
INPUT_VCF="/path/to/input_file.vcf.gz"  
OUTPUT_DIR="/path/to/output_directory" 
OUTPUT_FILE="$OUTPUT_DIR/haplocheck_report.csv"

# Define the path to your haplocheck executable
HAPLOCHECK_EXEC="/path/to/haplocheck"  

# Check if input VCF file exists
if [ ! -f "$INPUT_VCF" ]; then
    echo "Error: Input VCF file $INPUT_VCF not found."
    exit 1
fi

# Create the output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory $OUTPUT_DIR..."
    mkdir -p "$OUTPUT_DIR"
fi

# Ensure haplocheck executable has proper permissions
chmod +x "$HAPLOCHECK_EXEC"

# Run haplocheck with the input VCF and output file
echo "Running haplocheck..."
"$HAPLOCHECK_EXEC" --out "$OUTPUT_FILE" "$INPUT_VCF"

