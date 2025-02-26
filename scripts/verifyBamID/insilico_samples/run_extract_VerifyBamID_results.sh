#!/bin/bash

# Define the input and output directories
INPUT_DIR="/path/to/VerifyBamID_Output_3%_to_45%_contam"
OUTPUT_FILE="/path/to/contamination_results_3%_to_45%.txt"

# Initialize the output file with column headers (using commas)
echo -e "SampleName,TrueContamination,PredictedContamination" > "$OUTPUT_FILE"

# Loop through the files in the directory
for file in "$INPUT_DIR"/VerifyBamID_*.out; do
    # Extract sample name and true contamination level from the filename
    filename=$(basename "$file")
    
    # Extract sample name (this pattern assumes the format: VerifyBamID_<sample_name>_contam<true_contam>_... .out)
    sample_name=$(echo "$filename" | sed -E 's/^VerifyBamID_([^_]+_[^_]+)_contam[0-9]+\.out$/\1/')
    true_contam=$(echo "$filename" | grep -oP 'contam\d+' | grep -oP '\d+')

    # Extract predicted contamination from the file
    predicted_contam=$(grep -m 1 "FREEMIX(Alpha)" "$file" | sed -E 's/.*FREEMIX\(Alpha\):([0-9.eE+-]+)/\1/')
    
    # If no predicted contamination is found, set to NaN (or blank as a fallback)
    if [ -z "$predicted_contam" ]; then
        predicted_contam="NaN"
    fi

    # If the predicted contamination is "NaN", keep it as is, else format it as a float
    if [[ "$predicted_contam" != "NaN" && "$predicted_contam" =~ ^[+-]?[0-9]*\.?[0-9]+$ ]]; then
        predicted_contam=$(printf "%.8f" "$predicted_contam")  # Format to 8 decimal places for consistency
    fi
    
    # Append the results to the output file, ensuring proper comma separation and no extra spaces
    echo -e "$sample_name,$true_contam,$predicted_contam" >> "$OUTPUT_FILE"
done

# Print completion message
echo "Contamination extraction completed. Results saved to $OUTPUT_FILE"