#!/bin/bash

#SBATCH --account=development
#SBATCH --ntasks=80  # Parallel execution
#SBATCH --time=1-00:00:00
#SBATCH --mem=180G
#SBATCH --qos=normal
#SBATCH --job-name=VerifyBamID_All
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your_email@example.com
#SBATCH --output=VerifyBamID_All.out
#SBATCH --error=VerifyBamID_All.err

# Activate the conda environment

source /path/to/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Define paths
RESOURCE_PATH="(VERIFY_BAM_ID_HOME)/resource"
REFERENCE_PATH="/path/to/human_g1k_v37.fasta"
BAM_DIR="/path/to/bam_files"
OUTPUT_DIR="./VerifyBamID_Output_3%_to_45%_contam"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Maximum number of parallel jobs allowed at once
MAX_JOBS=20
current_jobs=0

# Iterate over BAM files in the BAM directory
for BAM_FILE_PATH in "${BAM_DIR}"/*.bam; do
    # Check if any BAM files exist in the directory
    if [ ! -f "$BAM_FILE_PATH" ]; then
        echo "No BAM files found in ${BAM_DIR}. Exiting."
        exit 1
    fi

    # Extract the sample name including the contam* portion
    SAMPLE_NAME=$(basename "$BAM_FILE_PATH" | sed -e 's/^modified_//' -e 's/.bam$//')

    # Run verifybamid2 in the background
    /home/raziyeh.mohseni/.conda/envs/D_contamtool_RM/bin/verifybamid2 \
        --UDPath ${RESOURCE_PATH}/1000g.phase3.100k.b37.vcf.gz.dat.UD \
        --BedPath ${RESOURCE_PATH}/1000g.phase3.100k.b37.vcf.gz.dat.bed \
        --MeanPath ${RESOURCE_PATH}/1000g.phase3.100k.b37.vcf.gz.dat.mu \
        --SVDPrefix ${RESOURCE_PATH}/1000g.phase3.100k.b37.vcf.gz.dat \
        --Reference ${REFERENCE_PATH} \
        --BamFile "$BAM_FILE_PATH" \
        --Output "${OUTPUT_DIR}/result_${SAMPLE_NAME}" \
        > "${OUTPUT_DIR}/VerifyBamID_${SAMPLE_NAME}.out" \
        2> "${OUTPUT_DIR}/VerifyBamID_${SAMPLE_NAME}.err" &

    # Track the number of running jobs
    ((current_jobs++))

    # If the max number of jobs is reached, wait for one job to finish
    if ((current_jobs >= MAX_JOBS)); then
        wait -n  # Wait for at least one job to finish before continuing
        ((current_jobs--))
    fi
done

# Wait for all remaining jobs to finish
wait