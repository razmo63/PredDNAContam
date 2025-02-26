#!/bin/bash

# Define the input and output directories
INPUT_DIR="path/to/VerifyBamID_Output"  
OUTPUT_FILE="path/to/contamination_results.txt"  

# Initialize the output file with column headers (using commas)
echo -e "SampleName,PredictedContamination" > "$OUTPUT_FILE"

# Loop through the .out files in the directory
for file in "$INPUT_DIR"/VerifyBamID_*.out; do
    # Extract sample name from the filename
    filename=$(basename "$file")
    sample_name=$(echo "$filename" | sed -E 's/^VerifyBamID_([^_]+)\.out$/\1/')

    # Extract predicted contamination from the file
    predicted_contam=$(grep -m 1 "FREEMIX(Alpha)" "$file" | sed -E 's/.*FREEMIX\(Alpha\):([0-9.eE+-]+)/\1/')

    # If no predicted contamination is found, set to NaN (or blank as a fallback)
    if [ -z "$predicted_contam" ]; then
        predicted_contam="NaN"
    fi

    
    # If the predicted contamination is numeric, format it to 8 decimal places
    if [[ "$predicted_contam" =~ ^[+-]?[0-9]*\.?[0-9]+$ ]]; then
        predicted_contam=$(printf "%.8f" "$predicted_contam")
    fi

    # Append the results to the output file
    echo -e "$sample_name,$predicted_contam" >> "$OUTPUT_FILE"
done

# Print completion message
echo "Contamination extraction completed. Results saved to $OUTPUT_FILE"