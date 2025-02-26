#!/bin/bash

#SBATCH --account=development              
#SBATCH --ntasks=190                     
#SBATCH --time=3-00:00:00           # takes around 50 minutes to generate a VCF file from a BAM file for chromosome 2
#SBATCH --mem=450G                       
#SBATCH --qos=normal                       
#SBATCH --mail-type=ALL                   
#SBATCH --mail-user=your_email@example.com  
#SBATCH --job-name=batch_vcf_parallel
#SBATCH --output=batch_generate_vcf.log   
#SBATCH --error=batch_generate_vcf.err   

# Load conda environment
source /path/to/bin/miniconda3/etc/profile.d/conda.sh
conda activate /path/to/conda_env

# Set GATK path
export GATK_HOME=/path/to/gatk_tool/gatk-4.2.6.1
export PATH=$GATK_HOME:$PATH

# Paths to the generated contaminated BAM files, named like contaminated_samples_chr2_DATE_OF_GENERATION
INPUT_DIR="/path/to/contaminated_samples_chr2_"
REFERENCE="/path/to/references/references_12.0/grch37_homo_sapiens_-d5-.fasta"
VCF_OUTPUT_DIR="./generated_VCF_files_chr2" 

# Create output directory if it doesn't exist
mkdir -p "$VCF_OUTPUT_DIR"

# Get list of BAM files
BAM_FILES=("$INPUT_DIR"/*.bam)
TOTAL_FILES=${#BAM_FILES[@]}
BATCH_SIZE=40  

# Maximum number of parallel jobs allowed at once
MAX_JOBS=40
current_jobs=0

# Process files in batches of $BATCH_SIZE
for ((i=0; i<TOTAL_FILES; i+=BATCH_SIZE)); do
    # Extract the current batch of files
    current_batch=("${BAM_FILES[@]:i:BATCH_SIZE}")
    
    # Run the command for each file in the batch in parallel
    for file in "${current_batch[@]}"; do
        INPUT_BAM="$file"
        INPUT_FILE_PREFIX=$(basename "$INPUT_BAM" .bam | sed 's/^modified_//')

        # Define the output VCF path with a unique task ID (to avoid overwrite)
        OUTPUT_VCF="$VCF_OUTPUT_DIR/${INPUT_FILE_PREFIX}_task${i}.vcf"

        # Run GATK HaplotypeCaller for the file in the background
        gatk --java-options "-Xmx11520m" HaplotypeCaller \
            -R "$REFERENCE" \
            -I "$INPUT_BAM" \
            -O "$OUTPUT_VCF" \
            --minimum-mapping-quality 20 \
            --min-base-quality-score 20 \
            -L 2 \
            -A AlleleFraction \
            -A Coverage \
            -A StrandBiasBySample &

        # Track number of running jobs
        ((current_jobs++))
        if ((current_jobs >= MAX_JOBS)); then
            wait -n  
            ((current_jobs--))
        fi
    done

    # Wait for all jobs in this batch to finish before moving to the next batch
    wait
done
