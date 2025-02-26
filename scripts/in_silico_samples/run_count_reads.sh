#!/bin/bash

#SBATCH --account=development
#SBATCH --ntasks=36
#SBATCH --time=05:00:00 
#SBATCH --mem=180
#SBATCH --qos=normal
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your_email@example.com
#SBATCH --job-name=count_reads
#SBATCH --output=count_reads_%j.log
#SBATCH --error=count_reads_%j.err

# Load necessary modules 
source /path/to/bin/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Path to the sample list (each line contains the full path to a BAM file , chr2. 30 samples)
SAMPLE_LIST="/path/to/sample_list.txt"

# Output directory to store the read counts
OUTPUT_DIR="/path/to/read_counts"

# Check if the output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Function to log messages
log() {
    echo "$(date) - $1"
}


READ_COUNT_FILE="${OUTPUT_DIR}/read_counts.txt"
echo "Sample_Name,Read_Count" > "$READ_COUNT_FILE"  

# Read sample list into an array
SAMPLE_LIST_ARRAY=()
while IFS= read -r line; do
    SAMPLE_LIST_ARRAY+=("$line")
done < "$SAMPLE_LIST"

# Loop over each BAM file in the sample list
for SAMPLE in "${SAMPLE_LIST_ARRAY[@]}"; do
    SAMPLE_NAME=$(basename "$SAMPLE" .bam)  

    # Count the number of reads in the BAM file using samtools view -c
    READ_COUNT=$(samtools view -c "$SAMPLE")
    
    # Log the result to SLURM output file
    log "Sample: $SAMPLE_NAME - Read count: $READ_COUNT"

    # Append the result to the read count file (CSV format)
    echo "$SAMPLE_NAME,$READ_COUNT" >> "$READ_COUNT_FILE"
done
