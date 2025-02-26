#!/bin/bash

#SBATCH --account=development
#SBATCH --ntasks=36
#SBATCH --time=3-00:00:00
#SBATCH --mem=180G
#SBATCH --qos=normal
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your_email@example.com
#SBATCH --job-name=in_silico_sample_processing
#SBATCH --output=in_silico_sample_processing_%j.log
#SBATCH --error=in_silico_sample_processing_%j.err

# Receive contamination level, output directory, and reference as arguments
CONTAM=$1
OUTPUT_DIR=$2
REFERENCE=$3
FINAL_SAMPLE_SIZE=48000000 # based on the smallest read counts among all the samples

# Function to log messages with timestamps
log() {
    echo "$(date) - $1"
}

# Read sample list into an array
SAMPLE_LIST=()
while read -r line; do
    SAMPLE_LIST+=("$line")
done < "/path/to/sample_list.txt"     #Includes the path to each sample. One sample per line. in our case 30 samples (Initial_data_chr2)

TOTAL_SAMPLES=${#SAMPLE_LIST[@]}

# Check if samples were found
if [ $TOTAL_SAMPLES -eq 0 ]; then
    log "No samples found in the sample_list.txt. Exiting."
    exit 1
fi

# Declare unique pairs for each contamination level
declare -A unique_pairs

# Process each sample pair for the given contamination level
for ((sample_num = 1; sample_num <= 10; sample_num++)); do
    while true; do
        TARGET_1_INDEX=$(( RANDOM % TOTAL_SAMPLES ))
        TARGET_2_INDEX=$(( RANDOM % TOTAL_SAMPLES ))

        # Ensure unique pair of samples
        if [ $TARGET_1_INDEX -ne $TARGET_2_INDEX ]; then
            pair_key="${TARGET_1_INDEX}_${TARGET_2_INDEX}"

            if [[ -z ${unique_pairs[$pair_key]} ]]; then
                unique_pairs[$pair_key]=1
                TARGET_1=${SAMPLE_LIST[$TARGET_1_INDEX]}
                TARGET_2=${SAMPLE_LIST[$TARGET_2_INDEX]}
                break
            fi
        fi
    done

    TARGET_1_PREFIX=$(basename "$TARGET_1" | cut -d'_' -f1)
    TARGET_2_PREFIX=$(basename "$TARGET_2" | cut -d'_' -f1)

    TARGET_1_PCT=$((100 - CONTAM))
    TARGET_2_PCT=$CONTAM

    # Define the decimal fractions 
    TARGET_1_DECIMAL=$(awk "BEGIN {printf \"%.2f\", $TARGET_1_PCT / 100}")
    TARGET_2_DECIMAL=$(awk "BEGIN {printf \"%.2f\", $TARGET_2_PCT / 100}")

    # Calculate how much to extract from each sample
    TARGET_1_EXTRACT=$(awk "BEGIN {printf \"%.2f\", $FINAL_SAMPLE_SIZE * $TARGET_1_DECIMAL}")
    TARGET_2_EXTRACT=$(awk "BEGIN {printf \"%.2f\", $FINAL_SAMPLE_SIZE * $TARGET_2_DECIMAL}")

    # Get read counts for each sample
    TARGET_1_COUNT=$(samtools view -c "$TARGET_1")
    TARGET_2_COUNT=$(samtools view -c "$TARGET_2")

    # Calculate sampling fractions
    TARGET_1_SAMPLING_FRACTION=$(awk "BEGIN {printf \"%.3f\", $TARGET_1_EXTRACT / $TARGET_1_COUNT}")
    TARGET_2_SAMPLING_FRACTION=$(awk "BEGIN {printf \"%.3f\", $TARGET_2_EXTRACT / $TARGET_2_COUNT}")

    log "TARGET_1_PCT: $TARGET_1_PCT, TARGET_2_PCT: $TARGET_2_PCT"
    log "TARGET_1_DECIMAL: $TARGET_1_DECIMAL, TARGET_2_DECIMAL: $TARGET_2_DECIMAL"
    log "TARGET_1_EXTRACT: $TARGET_1_EXTRACT, TARGET_2_EXTRACT: $TARGET_2_EXTRACT"
    log "TARGET_1_COUNT: $TARGET_1_COUNT, TARGET_2_COUNT: $TARGET_2_COUNT"
    log "Sampling fractions: TARGET_1_SAMPLING_FRACTION: $TARGET_1_SAMPLING_FRACTION, TARGET_2_SAMPLING_FRACTION: $TARGET_2_SAMPLING_FRACTION"

    # Round the sampling fractions
    TARGET_1_SAMPLING_FRACTION_ROUNDED=$(printf "%.2f" $TARGET_1_SAMPLING_FRACTION)
    TARGET_2_SAMPLING_FRACTION_ROUNDED=$(printf "%.2f" $TARGET_2_SAMPLING_FRACTION)

    log "Rounded TARGET_1_SAMPLING_FRACTION: $TARGET_1_SAMPLING_FRACTION_ROUNDED"
    log "Rounded TARGET_2_SAMPLING_FRACTION: $TARGET_2_SAMPLING_FRACTION_ROUNDED"

    # Extract samples from TARGET_1 and TARGET_2 using samtools
    samtools view -s "$TARGET_1_SAMPLING_FRACTION_ROUNDED" -b -T "$REFERENCE" "$TARGET_1" > "${OUTPUT_DIR}/${TARGET_1_PREFIX}_pct${TARGET_1_PCT}_contam${CONTAM}_${SLURM_JOB_ID}.bam" &
    pid1=$!

    samtools view -s "$TARGET_2_SAMPLING_FRACTION_ROUNDED" -b -T "$REFERENCE" "$TARGET_2" > "${OUTPUT_DIR}/${TARGET_2_PREFIX}_pct${TARGET_2_PCT}_contam${CONTAM}_${SLURM_JOB_ID}.bam" &
    pid2=$!

    wait $pid1 || { log "Error processing $TARGET_1"; continue; }
    wait $pid2 || { log "Error processing $TARGET_2"; continue; }

    # Merge the BAM files
    OUTPUT_FILENAME="${TARGET_1_PREFIX}_${TARGET_2_PREFIX}_contam${CONTAM}_${SLURM_JOB_ID}"

    samtools merge -f "${OUTPUT_DIR}/${OUTPUT_FILENAME}.bam" \
                   "${OUTPUT_DIR}/${TARGET_1_PREFIX}_pct${TARGET_1_PCT}_contam${CONTAM}_${SLURM_JOB_ID}.bam" \
                   "${OUTPUT_DIR}/${TARGET_2_PREFIX}_pct${TARGET_2_PCT}_contam${CONTAM}_${SLURM_JOB_ID}.bam" || {
        log "Error merging $OUTPUT_FILENAME"
        continue
    }

    # Create combined sample name for the header
    COMBINED_SAMPLE_NAME="${TARGET_1_PREFIX}_${TARGET_2_PREFIX}"

    # Modify the BAM header and store it in a unique temporary header file
    HEADER_FILE="${OUTPUT_DIR}/header_${TARGET_1_PREFIX}_${TARGET_1_PCT}_${SLURM_JOB_ID}.sam"
    samtools view -H "${OUTPUT_DIR}/${OUTPUT_FILENAME}.bam" > "$HEADER_FILE"
    sed -i "s/\(@RG.*SM:\)[^\t]*/\1$COMBINED_SAMPLE_NAME/" "$HEADER_FILE"
    sed -i '/^@PG/d' "$HEADER_FILE"

    # Reheader the BAM file using the unique header file
    samtools reheader "$HEADER_FILE" "${OUTPUT_DIR}/${OUTPUT_FILENAME}.bam" > "${OUTPUT_DIR}/modified_${OUTPUT_FILENAME}.bam"
    rm "$HEADER_FILE"  # Remove the unique header file
    log "Generated: modified_${OUTPUT_FILENAME}.bam"

    # Index the reheadered BAM file
    samtools index "${OUTPUT_DIR}/modified_${OUTPUT_FILENAME}.bam" || {
        log "Error indexing $OUTPUT_FILENAME"
        continue
    }

    # Clean up intermediate files (with SLURM_JOB_ID in the names)
    rm "${OUTPUT_DIR}/${TARGET_1_PREFIX}_pct${TARGET_1_PCT}_contam${CONTAM}_${SLURM_JOB_ID}.bam"
    rm "${OUTPUT_DIR}/${TARGET_2_PREFIX}_pct${TARGET_2_PCT}_contam${CONTAM}_${SLURM_JOB_ID}.bam"
    rm "${OUTPUT_DIR}/${OUTPUT_FILENAME}.bam"
done

