#!/bin/bash

#SBATCH --account=development              
#SBATCH --ntasks=30                     
#SBATCH --time=1-10:00:00            
#SBATCH --mem=100G                       
#SBATCH --qos=normal                       
#SBATCH --mail-type=ALL                   
#SBATCH --mail-user=your_email@example.com  
#SBATCH --job-name=batch_cram_to_vcf
#SBATCH --output=batch_cram_to_vcf.log   
#SBATCH --error=batch_cram_to_vcf.err   

# Load Conda environment
source /path/to/bin/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Set GATK path
export GATK_HOME=/path/to/gatk_tool/gatk-4.2.6.1
export PATH=$GATK_HOME:$PATH

# Paths
REFERENCE="/path/to/references_12.0/grch37_homo_sapiens_-d5-.fasta"
SAMPLE_LIST="/path/to/Data/sample/list/sample_part_8.txt"
BAM_OUTPUT_DIR="/path/to/ouput/bam_files"
VCF_OUTPUT_DIR="/path/to/output/vcf_files"

# Create output directories if they don't exist
mkdir -p "$BAM_OUTPUT_DIR" "$VCF_OUTPUT_DIR"

# Maximum number of parallel jobs
MAX_JOBS=5

# Check if sample list exists
if [[ ! -f "$SAMPLE_LIST" ]]; then
    echo "Sample list file $SAMPLE_LIST not found!"
    exit 1
fi

# Read CRAM files from the list and process them in parallel
current_jobs=0
while IFS= read -r CRAM_FILE; do
    if [[ ! -f "$CRAM_FILE" ]]; then
        echo "Warning: CRAM file $CRAM_FILE not found, skipping."
        continue
    fi

    PREFIX=$(basename "$CRAM_FILE" | cut -d'_' -f1)
    BAM_FILE="$BAM_OUTPUT_DIR/${PREFIX}.bam"
    BAM_INDEX="$BAM_OUTPUT_DIR/${PREFIX}.bai"
    OUTPUT_VCF="$VCF_OUTPUT_DIR/${PREFIX}.vcf"

    # Check if VCF already exists to avoid redundant processing
    if [[ -f "$OUTPUT_VCF" ]]; then
        echo "VCF for $CRAM_FILE already exists, skipping."
        continue
    fi

    echo "Processing $CRAM_FILE -> BAM -> VCF..."

    (
        # Convert CRAM to BAM
        samtools view -b -T "$REFERENCE" "$CRAM_FILE" -o "$BAM_FILE"

        # Index BAM file
        samtools index "$BAM_FILE"

        # Generate VCF using GATK HaplotypeCaller
        gatk --java-options "-Xmx10G" HaplotypeCaller \
            -R "$REFERENCE" \
            -I "$BAM_FILE" \
            -O "$OUTPUT_VCF" \
            --minimum-mapping-quality 20 \
            --min-base-quality-score 20 \
            -A AlleleFraction \
            -A Coverage \
            -A StrandBiasBySample > "$VCF_OUTPUT_DIR/${PREFIX}.log" 2> "$VCF_OUTPUT_DIR/${PREFIX}.err"

        echo "Finished processing $CRAM_FILE"
    ) &  # Run in background

    ((current_jobs++))
    if (( current_jobs >= MAX_JOBS )); then
        wait -n  # Wait for at least one job to finish before starting a new one
        ((current_jobs--))
    fi
done < "$SAMPLE_LIST"

# Wait for all background jobs to finish before exiting
wait

echo "All CRAM files processed."

