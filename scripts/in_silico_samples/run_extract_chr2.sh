#!/bin/bash

#SBATCH --account=development
#SBATCH --ntasks=40
#SBATCH --time=4-00:00:00
#SBATCH --mem=180G
#SBATCH --qos=normal
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your_email@example.com
#SBATCH --job-name=extract_chr2
#SBATCH --output=extract_chr2_%j.log
#SBATCH --error=extract_chr2_%j.err

# Load conda environment
source /path/to/bin/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Define paths
REFERENCE="/path/to/references/references_12.0/grch37_homo_sapiens_-d5-.fasta"
OUTPUT_DIR="/path/to/output/Initial_data_chr2"
SAMPLE_LIST="/path/to/the/Cram_files/sample_list.txt" ##Includes the path to each sample. One sample per line. (in our case was 30 samples)

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting chromosome 2 extraction and indexing for all samples."

# Read the sample list into an array
mapfile -t SAMPLES < "$SAMPLE_LIST"
TOTAL_SAMPLES=${#SAMPLES[@]}

# Parameters for batching
BATCH_SIZE=10  # Number of samples per batch

# Loop through batches
for ((i=0; i<TOTAL_SAMPLES; i+=BATCH_SIZE)); do
    echo "Processing batch starting from file index $i..."

    # Process each file in the current batch
    for ((j=i; j<i+BATCH_SIZE && j<TOTAL_SAMPLES; j++)); do
        SAMPLE="${SAMPLES[j]}"
        SAMPLE_PREFIX=$(basename "$SAMPLE" | cut -d'_' -f1)  
        OUTPUT_BAM="${OUTPUT_DIR}/modified_${SAMPLE_PREFIX}_contam0_chr2.bam"

        # Run the job in the background
        (
            log "Extracting chr2 from $SAMPLE to $OUTPUT_BAM"

            # Extract reads for chromosome 2 using samtools
            samtools view -b -T "$REFERENCE" "$SAMPLE" "2" > "$OUTPUT_BAM"

            if [ $? -eq 0 ]; then
                log "Successfully extracted chr2 for $SAMPLE."

                # Index the BAM file
                log "Indexing $OUTPUT_BAM"
                samtools index "$OUTPUT_BAM"

                if [ $? -eq 0 ]; then
                    log "Successfully indexed $OUTPUT_BAM."
                else
                    log "Error indexing $OUTPUT_BAM."
                fi
            else
                log "Error extracting chr2 for $SAMPLE."
            fi
        ) &  # Run in the background
    done

    # Wait for all jobs in the current batch to finish
    wait
    echo "Batch starting at index $i completed."
done

log "Finished processing all samples."

